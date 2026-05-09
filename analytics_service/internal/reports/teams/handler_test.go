//go:build go1.21

package teams

import (
	"context"
	"database/sql"
	"strconv"
	"testing"

	"analytics_service/internal/testdb"
	"analytics_service/pb"
)

func setupTeamsTestDB(t *testing.T) *sql.DB {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return db
}

func TestTeamsHandlerNewHandler(t *testing.T) {
	db := setupTeamsTestDB(t)
	h := NewHandler(db)
	if h == nil || h.repo == nil || h.formatter == nil {
		t.Fatal("expected non-nil handler components")
	}
}

func TestTeamsHandlerGenerate_EmptyResult_JSON(t *testing.T) {
	db := setupTeamsTestDB(t)
	h := NewHandler(db)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Format != "json" {
		t.Errorf("format: got %q", resp.Format)
	}
	if resp.TotalCount != 0 {
		t.Errorf("TotalCount: got %d", resp.TotalCount)
	}
}

func TestTeamsHandlerGenerate_EmptyResult_CSV(t *testing.T) {
	db := setupTeamsTestDB(t)
	h := NewHandler(db)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "csv", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Format != "csv" {
		t.Errorf("format: got %q", resp.Format)
	}
}

func TestTeamsHandlerGenerate_WithData(t *testing.T) {
	db := setupTeamsTestDB(t)
	rid, teamID, _ := testdb.InsertAchievementGraph(t, db)
	deatID := testdb.InsertActivityType(t, db, "Commits", "commits")
	testdb.InsertDevTeamExtras(t, db, teamID, rid, deatID, "readme_teams_handler")

	h := NewHandler(db)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.TotalCount < 1 {
		t.Fatalf("expected at least one team row, got %d", resp.TotalCount)
	}
	if len(resp.Data) == 0 {
		t.Fatal("expected non-empty data")
	}
	_ = teamID
}

func TestTeamsHandlerGenerate_WithSorts(t *testing.T) {
	db := setupTeamsTestDB(t)
	testdb.InsertAchievementGraph(t, db)
	h := NewHandler(db)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  10,
		Sorts:  []*pb.Sort{{Field: "title", Descending: true}},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("nil response")
	}
}

func TestTeamsHandlerGenerate_WithFilters(t *testing.T) {
	db := setupTeamsTestDB(t)
	_, teamID, _ := testdb.InsertAchievementGraph(t, db)
	h := NewHandler(db)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  20,
		Filters: []*pb.Filter{
			{Field: "team_id", Operator: "eq", Value: strconv.FormatInt(teamID, 10)},
			{Field: "submission_date", Operator: "eq", Value: "2024-01-01,2024-12-31"},
			{Field: "unknown", Value: "ignored"},
		},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("nil response")
	}
}
