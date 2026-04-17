package main

import (
	"context"
	"database/sql"
	"log"
	"net"
	"os"
	"strings"
	"sync"

	"integration_service/internal/github"
	"integration_service/internal/integrations"
	"integration_service/internal/openalex"
	"integration_service/internal/orcid"
	"integration_service/internal/repository"
	"integration_service/pb"

	_ "github.com/lib/pq"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type server struct {
	pb.UnimplementedIntegrationServiceServer
	registry             *integrations.Registry
	researcherRepository *repository.ResearcherRepository
	githubClient         *github.Client
}

func (s *server) FetchOrcidAchievements(ctx context.Context, req *pb.OrcidRequest) (*pb.OrcidResponse, error) {
	log.Printf("Received ORCID request for ID: %s", req.OrcidId)

	// Check if researcher exists in base
	exists, err := s.researcherRepository.ExistsByOrcidID(req.OrcidId)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "database error: %v", err)
	}
	if !exists {
		return nil, status.Errorf(codes.NotFound, "researcher with ORCID %s not found in database", req.OrcidId)
	}

	provider, err := s.registry.GetProvider("orcid")
	if err != nil {
		return nil, status.Errorf(codes.Internal, "provider error: %v", err)
	}

	achievements, err := provider.FetchAchievements(ctx, req.OrcidId)
	if err != nil {
		log.Printf("Error fetching ORCID achievements: %v", err)
		return nil, status.Errorf(codes.Unavailable, "external api error: %v", err)
	}

	return &pb.OrcidResponse{
		Achievements: achievements,
	}, nil
}

func (s *server) FetchOpenAlexAchievements(ctx context.Context, req *pb.OpenAlexRequest) (*pb.OpenAlexResponse, error) {
	log.Printf("Received OpenAlex request for ID: %s", req.OpenalexId)

	// Check if researcher exists in base
	exists, err := s.researcherRepository.ExistsByOpenAlexID(req.OpenalexId)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "database error: %v", err)
	}
	if !exists {
		return nil, status.Errorf(codes.NotFound, "researcher with OpenAlex ID %s not found in database", req.OpenalexId)
	}

	provider, err := s.registry.GetProvider("openalex")
	if err != nil {
		return nil, status.Errorf(codes.Internal, "provider error: %v", err)
	}

	achievements, err := provider.FetchAchievements(ctx, req.OpenalexId)
	if err != nil {
		log.Printf("Error fetching OpenAlex achievements: %v", err)
		return nil, status.Errorf(codes.Unavailable, "external api error: %v", err)
	}

	return &pb.OpenAlexResponse{
		Achievements: achievements,
	}, nil
}

func (s *server) SyncAllAchievements(ctx context.Context, req *pb.SyncRequest) (*pb.SyncResponse, error) {
	log.Printf("Starting full sync for provider: %s", req.Provider)

	researchers, err := s.researcherRepository.GetAllWithExternalID(req.Provider)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "database error: %v", err)
	}

	var mu sync.Mutex
	var wg sync.WaitGroup
	var results []*pb.ResearcherAchievements

	providers := make(map[string]integrations.Provider)
	if req.Provider == "all" {
		p1, _ := s.registry.GetProvider("orcid")
		p2, _ := s.registry.GetProvider("openalex")
		if p1 != nil {
			providers["orcid"] = p1
		}
		if p2 != nil {
			providers["openalex"] = p2
		}
	} else {
		p, err := s.registry.GetProvider(req.Provider)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid provider: %v", err)
		}
		providers[req.Provider] = p
	}

	for _, res := range researchers {
		wg.Add(1)
		go func(r repository.Researcher) {
			defer wg.Done()

			var allAchievements []*pb.Achievement
			var achievementsMu sync.Mutex
			var innerWg sync.WaitGroup

			for pName, p := range providers {
				var extID string
				switch pName {
				case "orcid":
					extID = r.OrcidID.String
				case "openalex":
					extID = r.OpenAlexID.String
				}

				if extID == "" {
					continue
				}

				innerWg.Add(1)
				go func(provider integrations.Provider, id string) {
					defer innerWg.Done()
					ach, err := provider.FetchAchievements(ctx, id)
					if err != nil {
						log.Printf("Error syncing for researcher %d: %v", r.ID, err)
						return
					}
					if len(ach) > 0 {
						achievementsMu.Lock()
						allAchievements = append(allAchievements, ach...)
						achievementsMu.Unlock()
					}
				}(p, extID)
			}
			innerWg.Wait()

			if len(allAchievements) > 0 {
				// Deduplicate achievements for this researcher
				deduped := deduplicate(allAchievements)

				mu.Lock()
				results = append(results, &pb.ResearcherAchievements{
					ResearcherId: r.ID,
					OrcidId:      r.OrcidID.String,
					OpenalexId:   r.OpenAlexID.String,
					Achievements: deduped,
				})
				mu.Unlock()
			}
		}(res)
	}

	wg.Wait()

	return &pb.SyncResponse{
		Results: results,
	}, nil
}

func (s *server) CrawlDevActivity(ctx context.Context, req *pb.DevActivityRequest) (*pb.DevActivityResponse, error) {
	log.Printf("CrawlDevActivity for: %s (researcher: %d, team: %d)", req.GithubUsername, req.ResearcherId, req.TeamId)

	if req.GithubUsername == "" {
		return &pb.DevActivityResponse{}, nil
	}

	var activities []*pb.DevActivity
	var activityDetails []*pb.ActivityDetail
	var criteria []string
	var err error

	// If it's a repo URL, fetch repo activity, otherwise fetch user activity
	if strings.HasPrefix(req.GithubUsername, "http") || strings.Contains(req.GithubUsername, "/") {
		activities, activityDetails, criteria, err = s.githubClient.GetRepoActivity(ctx, req.GithubUsername)
	} else {
		activities, activityDetails, criteria, err = s.githubClient.GetUserActivity(ctx, req.GithubUsername)
	}

	if err != nil {
		log.Printf("Error fetching GitHub data: %v", err)
		return nil, status.Errorf(codes.Internal, "github error: %v", err)
	}

	return &pb.DevActivityResponse{
		Activities:         activities,
		ProjectCriteriaMet: criteria,
		ActivityDetails:    activityDetails,
	}, nil
}

func deduplicate(achievements []*pb.Achievement) []*pb.Achievement {
	seen := make(map[string]bool)
	var result []*pb.Achievement

	for _, a := range achievements {
		// Use Title + Date or ExternalId as key for deduplication
		key := a.Title
		if a.ExternalId != "" {
			key = a.ExternalId
		}
		key = strings.ToLower(strings.TrimSpace(key))

		if !seen[key] {
			seen[key] = true
			result = append(result, a)
		}
	}
	return result
}


func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:password@db:5432/research_activity_monitoring_system_development?sslmode=disable"
	}

	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	port := os.Getenv("PORT")
	if port == "" {
		port = "50052"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	registry := integrations.NewRegistry()
	registry.Register("orcid", orcid.NewClient())
	registry.Register("openalex", openalex.NewClient())

	githubClient := github.NewClient(db)

	s := grpc.NewServer()
	pb.RegisterIntegrationServiceServer(s, &server{
		registry:             registry,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         githubClient,
	})

	log.Printf("Integration Service listening on :%s", port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
