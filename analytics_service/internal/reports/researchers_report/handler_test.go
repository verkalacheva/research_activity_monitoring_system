//go:build go1.21

package researchers_report

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

func setupResearchersHandler(t *testing.T) *Handler {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return NewHandler(db)
}

func TestResearchersHandlerNewHandler(t *testing.T) {
	h := setupResearchersHandler(t)
	if h == nil {
		t.Fatal("expected non-nil handler")
	}
}

func TestResearchersHandlerGenerate_DBError(t *testing.T) {
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

func TestResearchersHandlerGenerate_EmptyResult_JSON(t *testing.T) {
	h := setupResearchersHandler(t)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Format != "json" {
		t.Errorf("expected format=json, got %q", resp.Format)
	}
}

func TestResearchersHandlerGenerate_EmptyResult_CSV(t *testing.T) {
	h := setupResearchersHandler(t)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "csv", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Format != "csv" {
		t.Errorf("expected format=csv, got %q", resp.Format)
	}
}

func TestResearchersHandlerGenerate_WithRows(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	rid, teamID, _ := testdb.InsertAchievementGraph(t, db)
	deatID := testdb.InsertActivityType(t, db, "Commits", "c")
	testdb.InsertDevTeamExtras(t, db, teamID, rid, deatID, "readme_res_report")

	h := NewHandler(db)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json", Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.TotalCount != 1 {
		t.Errorf("expected TotalCount=1, got %d", resp.TotalCount)
	}
}

func TestResearchersHandlerGenerate_WithFilters(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	rid, teamID, _ := testdb.InsertAchievementGraph(t, db)
	var statusID, typeID, resID, partID int64
	if err := db.QueryRow(`SELECT achievement_status_id, achievement_type_id, achievement_result_id, achievement_participation_id
		FROM achievements LIMIT 1`).Scan(&statusID, &typeID, &resID, &partID); err != nil {
		t.Fatal(err)
	}

	h := NewHandler(db)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  20,
		Filters: []*pb.Filter{
			{Field: "researcher_id", Operator: "eq", Value: strconv.FormatInt(rid, 10)},
			{Field: "status", Operator: "eq", Value: strconv.FormatInt(statusID, 10)},
			{Field: "achievement_type", Operator: "eq", Value: strconv.FormatInt(typeID, 10)},
			{Field: "team_id", Operator: "eq", Value: strconv.FormatInt(teamID, 10)},
			{Field: "submission_date", Operator: "eq", Value: "2024-01-01,2024-12-31"},
			{Field: "points", Operator: "gt", Value: "4"},
			{Field: "degree_level", Operator: "contains", Value: "к.т.н"},
			{Field: "achievement_result_id", Operator: "eq", Value: strconv.FormatInt(resID, 10)},
			{Field: "achievement_participation_id", Operator: "eq", Value: strconv.FormatInt(partID, 10)},
			{Field: "unknown_field", Value: "ignored"},
		},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
	if resp.TotalCount < 1 {
		t.Fatalf("expected at least one row, got %d", resp.TotalCount)
	}
}

func TestResearchersHandlerGenerate_WithGroupSorts(t *testing.T) {
	h := setupResearchersHandler(t)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  20,
		Sorts:  []*pb.Sort{{Field: "a.points", Descending: true}},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
}

func TestResearchersHandlerGenerate_WithDevPointsSort(t *testing.T) {
	h := setupResearchersHandler(t)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  20,
		Sorts:  []*pb.Sort{{Field: "dev_points", Descending: false}},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
}
