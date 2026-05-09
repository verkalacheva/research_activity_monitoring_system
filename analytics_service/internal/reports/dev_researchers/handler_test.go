//go:build go1.21

package dev_researchers

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

func setupDevResearchersDB(t *testing.T) *Handler {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return NewHandler(db)
}

func TestDevResearchersHandlerNewHandler(t *testing.T) {
	h := setupDevResearchersDB(t)
	if h == nil {
		t.Fatal("expected non-nil handler")
	}
}

func TestDevResearchersHandlerGenerate_CountError(t *testing.T) {
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

func TestDevResearchersHandlerGenerate_EmptyResult(t *testing.T) {
	h := setupDevResearchersDB(t)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.TotalCount != 0 {
		t.Errorf("expected TotalCount=0, got %d", resp.TotalCount)
	}
}

func TestDevResearchersHandlerGenerate_WithRows(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	deatID := testdb.InsertActivityType(t, db, "Коммиты", "commits")
	r1, team1, _ := testdb.InsertAchievementGraph(t, db)
	testdb.InsertDevTeamExtras(t, db, team1, r1, deatID, "readme_devr_rows")

	h := NewHandler(db)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.TotalCount < 1 {
		t.Errorf("expected TotalCount>=1, got %d", resp.TotalCount)
	}
	if len(resp.Data) == 0 {
		t.Error("expected non-empty data")
	}
}

func TestDevResearchersHandlerGenerate_WithFilters(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	deatID := testdb.InsertActivityType(t, db, "Коммиты", "commits2")
	r1, team1, _ := testdb.InsertAchievementGraph(t, db)
	testdb.InsertDevTeamExtras(t, db, team1, r1, deatID, "readme_devr_filters")

	h := NewHandler(db)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  20,
		Filters: []*pb.Filter{
			{Field: "team_id", Value: strconv.FormatInt(team1, 10)},
			{Field: "researcher_id", Value: strconv.FormatInt(r1, 10)},
			{Field: "activity_date", Value: "2024-01-01,2024-12-31"},
			{Field: "activity_date", Value: "2024-01-01,"},
			{Field: "activity_date", Value: ",2024-12-31"},
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

func TestDevResearchersHandlerGenerate_WithSorts(t *testing.T) {
	h := setupDevResearchersDB(t)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  10,
		Sorts:  []*pb.Sort{{Field: "dev_points", Descending: true}},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
}

func TestDevResearchersHandlerGenerate_AllSortFields(t *testing.T) {
	sortFields := []string{"researcher", "team", "activity_type", "activity_points", "criteria_sum", "dev_points"}
	for _, field := range sortFields {
		t.Run("sort_by_"+field, func(t *testing.T) {
			h := setupDevResearchersDB(t)
			resp, err := h.Generate(context.Background(), &pb.ReportRequest{
				Format: "json",
				Limit:  20,
				Sorts:  []*pb.Sort{{Field: field, Descending: true}},
			})
			if err != nil {
				t.Fatalf("sort by %s: unexpected error: %v", field, err)
			}
			if resp == nil {
				t.Fatalf("sort by %s: expected non-nil response", field)
			}
		})
	}
}

func TestDevResearchersHandlerGenerate_DefaultLimit(t *testing.T) {
	h := setupDevResearchersDB(t)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 0})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
}
