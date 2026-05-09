//go:build go1.21

package dashboard_overview

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"analytics_service/internal/testdb"
	"analytics_service/pb"
)

func setupDashboardHandler(t *testing.T) *Handler {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return NewHandler(db)
}

func TestDashboardHandlerNewHandler(t *testing.T) {
	h := setupDashboardHandler(t)
	if h == nil {
		t.Fatal("expected non-nil handler")
	}
	if h.repo == nil || h.formatter == nil {
		t.Fatal("expected non-nil repo and formatter")
	}
}

func TestDashboardHandlerGenerate_EmptyDB(t *testing.T) {
	h := setupDashboardHandler(t)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
	if resp.Format != "json" {
		t.Errorf("expected format=json, got %q", resp.Format)
	}
}

func TestDashboardHandlerGenerate_WithData(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	rid, teamID, achID := testdb.InsertAchievementGraph(t, db)
	if _, err := db.Exec(`UPDATE achievements SET submission_date = NOW() - INTERVAL '10 days' WHERE id = $1`, achID); err != nil {
		t.Fatal(err)
	}
	deatID := testdb.InsertActivityType(t, db, "Commits", "dash-commits")
	testdb.InsertDevTeamExtras(t, db, teamID, rid, deatID, "readme_dash_overview")

	h := NewHandler(db)
	resp, err := h.Generate(context.Background(), &pb.ReportRequest{Format: "json"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var decoded struct {
		TypeDistribution []interface{} `json:"type_distribution"`
	}
	if err := json.Unmarshal(resp.Data, &decoded); err != nil {
		t.Fatalf("json: %v", err)
	}
	if len(decoded.TypeDistribution) == 0 {
		t.Error("expected type_distribution entries")
	}
	if !strings.Contains(string(resp.Data), "Статья ВАК") {
		t.Error("expected achievement type title in payload")
	}
}

func TestDashboardHandlerGenerate_WithDateFilters(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	testdb.InsertAchievementGraph(t, db)

	h := NewHandler(db)
	req := &pb.ReportRequest{
		Format: "json",
		Filters: []*pb.Filter{
			{Field: "start_date", Value: "2024-01-01"},
			{Field: "end_date", Value: "2024-12-31"},
		},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error with date filters: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
	var decoded struct {
		TypeDistribution []interface{} `json:"type_distribution"`
	}
	if err := json.Unmarshal(resp.Data, &decoded); err != nil {
		t.Fatalf("json: %v", err)
	}
	if len(decoded.TypeDistribution) == 0 {
		t.Error("expected type_distribution in filtered date range")
	}
}

func TestDashboardHandlerGenerate_DateRangeExcludesAll(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	testdb.InsertAchievementGraph(t, db)

	h := NewHandler(db)
	req := &pb.ReportRequest{
		Format: "json",
		Filters: []*pb.Filter{
			{Field: "start_date", Value: "2000-01-01"},
			{Field: "end_date", Value: "2000-12-31"},
		},
	}
	resp, err := h.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
	var decoded struct {
		TypeDistribution []interface{} `json:"type_distribution"`
	}
	if err := json.Unmarshal(resp.Data, &decoded); err != nil {
		t.Fatalf("json: %v", err)
	}
	if len(decoded.TypeDistribution) != 0 {
		t.Errorf("expected no achievements in 2000 range, got %d type buckets", len(decoded.TypeDistribution))
	}
}
