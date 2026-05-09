//go:build go1.21

package dev_teams

import (
	"context"
	"database/sql"
	"os"
	"strconv"
	"testing"

	"analytics_service/internal/testdb"
	"analytics_service/pb"

	_ "github.com/lib/pq"
)

func setupDevTeamsDB(t *testing.T) *Handler {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return NewHandler(db)
}

func TestDevTeamsHandlerNewHandler(t *testing.T) {
	h := setupDevTeamsDB(t)
	if h == nil {
		t.Fatal("expected non-nil handler")
	}
}

func TestDevTeamsHandlerGenerate_DBErrorOnCount(t *testing.T) {
	testdb.SkipIfNoDSN(t)
	dsn := os.Getenv("TEST_DATABASE_URL")
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		t.Fatalf("db.Ping: %v", err)
	}
	testdb.TruncateAllReportTables(t, db)
	_ = db.Close()
	h := NewHandler(db)
	_, err = h.Generate(context.Background(), &pb.ReportRequest{Format: "json"})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestDevTeamsHandlerGenerate_EmptyResult(t *testing.T) {
	h := setupDevTeamsDB(t)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.TotalCount != 0 {
		t.Errorf("expected TotalCount=0, got %d", resp.TotalCount)
	}
}

func TestDevTeamsHandlerGenerate_WithRows(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	deatID := testdb.InsertActivityType(t, db, "Commits", "commits")
	r1, team1, _ := testdb.InsertAchievementGraph(t, db)
	testdb.InsertDevTeamExtras(t, db, team1, r1, deatID, "readme_devt_rows_a")
	testdb.InsertSecondTeamWithDev(t, db, testdb.InsertActivityType(t, db, "PR", "pr"))

	h := NewHandler(db)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.TotalCount != 2 {
		t.Errorf("expected TotalCount=2, got %d", resp.TotalCount)
	}
	if len(resp.Data) == 0 {
		t.Error("expected non-empty response data")
	}
}

func TestDevTeamsHandlerGenerate_WithSorts(t *testing.T) {
	h := setupDevTeamsDB(t)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  10,
		Sorts: []*pb.Sort{
			{Field: "total_score", Descending: true},
			{Field: "criteria_sum", Descending: false},
			{Field: "invalid_field", Descending: false},
		},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
}

func TestDevTeamsHandlerGenerate_WithFilters(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	deatID := testdb.InsertActivityType(t, db, "Commits", "commits2")
	r1, team1, _ := testdb.InsertAchievementGraph(t, db)
	testdb.InsertDevTeamExtras(t, db, team1, r1, deatID, "readme_devt_filters")

	h := NewHandler(db)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  20,
		Filters: []*pb.Filter{
			{Field: "team_id", Value: strconv.FormatInt(team1, 10)},
			{Field: "activity_date", Value: "2024-01-01,2024-12-31"},
			{Field: "unknown", Value: "ignored"},
			{Field: "activity_date", Value: ""},
		},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
}

func TestDevTeamsHandlerGenerate_DefaultLimit(t *testing.T) {
	h := setupDevTeamsDB(t)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 0})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
}
