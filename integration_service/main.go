package main

import (
	"context"
	"database/sql"
	"log"
	"net"
	"os"

	"integration_service/internal/integrations"
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

func (s *server) SyncAllAchievements(ctx context.Context, req *pb.SyncRequest) (*pb.SyncResponse, error) {
	log.Printf("Starting full sync for provider: %s", req.Provider)

	researchers, err := s.researcherRepository.GetAllWithOrcidID()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "database error: %v", err)
	}

	provider, err := s.registry.GetProvider(req.Provider)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid provider: %v", err)
	}

	var results []*pb.ResearcherAchievements
	for _, res := range researchers {
		achievements, err := provider.FetchAchievements(ctx, res.OrcidID)
		if err != nil {
			log.Printf("Error syncing for researcher %d (%s): %v", res.ID, res.OrcidID, err)
			continue
		}

		if len(achievements) > 0 {
			results = append(results, &pb.ResearcherAchievements{
				ResearcherId: res.ID,
				OrcidId:      res.OrcidID,
				Achievements: achievements,
			})
		}
	}

	return &pb.SyncResponse{
		Results: results,
	}, nil
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

	s := grpc.NewServer()
	pb.RegisterIntegrationServiceServer(s, &server{
		registry:             registry,
		researcherRepository: repository.NewResearcherRepository(db),
	})

	log.Printf("Integration Service listening on :%s", port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
