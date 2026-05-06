package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"time"

	"analytics_service/internal/reports"
	"analytics_service/internal/reports/dashboard_overview"
	"analytics_service/internal/reports/researchers_report"
	"analytics_service/internal/reports/teams"
	"analytics_service/internal/reports/dev_teams"
	"analytics_service/internal/reports/dev_researchers"
	"analytics_service/pb"

	_ "github.com/lib/pq"
	"google.golang.org/grpc"
)

type server struct {
	pb.UnimplementedAnalyticsServiceServer
	registry *reports.Registry
}

func startHealthHTTPServer(db *sql.DB, addr string) *http.Server {
	mux := http.NewServeMux()
	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := db.PingContext(ctx); err != nil {
			http.Error(w, fmt.Sprintf("db: %v", err), http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
	})
	srv := &http.Server{Addr: addr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("health http: %v", err)
		}
	}()
	return srv
}

func (s *server) GenerateReport(ctx context.Context, req *pb.ReportRequest) (*pb.ReportResponse, error) {
	log.Printf("Received report request: %v", req)

	handler, err := s.registry.GetHandler(req.ReportType)
	if err != nil {
		log.Printf("Error getting handler: %v", err)
		return nil, err
	}

	return handler.Generate(ctx, req)
}

func main() {
	dbConn := os.Getenv("DATABASE_URL")
	if dbConn == "" {
		dbConn = "postgres://postgres:password@db:5432/research_activity_monitoring_system_development?sslmode=disable"
	}

	db, err := sql.Open("postgres", dbConn)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		log.Fatalf("database ping: %v", err)
	}

	healthPort := os.Getenv("HEALTH_HTTP_PORT")
	if healthPort == "" {
		healthPort = "8080"
	}
	startHealthHTTPServer(db, ":"+healthPort)
	log.Printf("Health HTTP on :%s (live, ready)", healthPort)

	// Initialize registry and register handlers
	registry := reports.NewRegistry()
	registry.Register("researchers_report", researchers_report.NewHandler(db))
	registry.Register("teams", teams.NewHandler(db))
	registry.Register("dashboard_overview", dashboard_overview.NewHandler(db))
	registry.Register("dev_teams_report", dev_teams.NewHandler(db))
	registry.Register("dev_researchers_report", dev_researchers.NewHandler(db))

	port := os.Getenv("PORT")
	if port == "" {
		port = "50051"
	}
	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	pb.RegisterAnalyticsServiceServer(s, &server{registry: registry})

	log.Printf("Analytics Service listening on :%s", port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
