//go:build go1.21

package researcher_activity

import (
	"database/sql"
	"os"
	"strconv"
	"testing"

	"analytics_service/internal/testdb"
	"analytics_service/pb"

	_ "github.com/lib/pq"
)

func setupResearcherActivityRepo(t *testing.T) *Repository {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return &Repository{db: db}
}

func TestResearcherActivityFetchData_CountError(t *testing.T) {
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
	repo := &Repository{db: db}
	_, _, _, err = repo.FetchData(&pb.ReportRequest{})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestResearcherActivityFetchData_EmptyResult(t *testing.T) {
	repo := setupResearcherActivityRepo(t)
	data, total, totals, err := repo.FetchData(&pb.ReportRequest{Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(data) != 0 {
		t.Errorf("expected 0 rows, got %d", len(data))
	}
	if total != 0 {
		t.Errorf("expected totalCount=0, got %d", total)
	}
	_ = totals
}

func TestResearcherActivityFetchData_WithRows(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	testdb.InsertAchievementGraph(t, db)

	repo := &Repository{db: db}
	data, total, totals, err := repo.FetchData(&pb.ReportRequest{Limit: 20})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(data) != 1 {
		t.Errorf("expected 1 row, got %d", len(data))
	}
	if total != 1 {
		t.Errorf("expected totalCount=1, got %d", total)
	}
	if totals["points"] != 5.0 {
		t.Errorf("expected points=5.0, got %v", totals["points"])
	}
}

func TestResearcherActivityFetchData_WithFilters(t *testing.T) {
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	rid, _, achID := testdb.InsertAchievementGraph(t, db)
	var statusID, typeID int64
	if err := db.QueryRow(
		`SELECT achievement_status_id, achievement_type_id FROM achievements WHERE id = $1`, achID,
	).Scan(&statusID, &typeID); err != nil {
		t.Fatal(err)
	}

	repo := &Repository{db: db}
	req := &pb.ReportRequest{
		Limit: 20,
		Filters: []*pb.Filter{
			{Field: "status", Operator: "eq", Value: strconv.FormatInt(statusID, 10)},
			{Field: "achievement_type", Operator: "eq", Value: strconv.FormatInt(typeID, 10)},
			{Field: "researcher_id", Operator: "eq", Value: strconv.FormatInt(rid, 10)},
			{Field: "degree_level", Operator: "contains", Value: "к.т.н"},
			{Field: "points", Operator: "gt", Value: "4"},
			{Field: "submission_date", Value: "2024-01-01,2024-12-31"},
			{Field: "unknown", Value: "ignored"},
		},
	}
	_, _, _, err := repo.FetchData(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestResearcherActivityFetchData_WithSorts(t *testing.T) {
	repo := setupResearcherActivityRepo(t)
	req := &pb.ReportRequest{
		Limit: 20,
		Sorts: []*pb.Sort{
			{Field: "points", Descending: true},
			{Field: "a.id", Descending: false},
		},
	}
	_, _, _, err := repo.FetchData(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}
