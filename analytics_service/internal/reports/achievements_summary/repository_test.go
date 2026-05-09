//go:build go1.21

package achievements_summary

import (
	"strconv"
	"testing"

	"analytics_service/internal/testdb"
	"analytics_service/pb"
)

func setupRepoDB(t *testing.T) *Repository {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return &Repository{db: db}
}

func TestAchievementsSummaryFetchData_Empty(t *testing.T) {
	repo := setupRepoDB(t)
	data, total, totals, err := repo.FetchData(&pb.ReportRequest{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(data) != 0 {
		t.Errorf("rows: %d", len(data))
	}
	if total != 0 {
		t.Errorf("total: %d", total)
	}
	if totals["total_points"] != 0 {
		t.Errorf("totals: %v", totals)
	}
}

func TestAchievementsSummaryFetchData_WithRows(t *testing.T) {
	repo := setupRepoDB(t)
	// два типа достижений, по одному достижению
	var t1, t2 int64
	if err := repo.db.QueryRow(`INSERT INTO achievement_types (title, points, created_at, updated_at)
		VALUES ('Статья ВАК', 1, NOW(), NOW()) RETURNING id`).Scan(&t1); err != nil {
		t.Fatal(err)
	}
	if err := repo.db.QueryRow(`INSERT INTO achievement_types (title, points, created_at, updated_at)
		VALUES ('Грант', 1, NOW(), NOW()) RETURNING id`).Scan(&t2); err != nil {
		t.Fatal(err)
	}
	var pid, rid, sid int64
	for _, q := range []struct {
		sql string
		id  *int64
	}{
		{`INSERT INTO achievement_participations (title, points, created_at, updated_at) VALUES ('p',1,NOW(),NOW()) RETURNING id`, &pid},
		{`INSERT INTO achievement_results (title, points, created_at, updated_at) VALUES ('r',1,NOW(),NOW()) RETURNING id`, &rid},
		{`INSERT INTO achievement_statuses (title, points, created_at, updated_at) VALUES ('s',1,NOW(),NOW()) RETURNING id`, &sid},
	} {
		if err := repo.db.QueryRow(q.sql).Scan(q.id); err != nil {
			t.Fatal(err)
		}
	}
	insAch := func(typeID int64, pts float64) {
		_, err := repo.db.Exec(`INSERT INTO achievements (
			achievement_type_id, achievement_status_id, achievement_result_id, achievement_participation_id,
			points, created_at, updated_at, submission_date)
			VALUES ($1,$2,$3,$4,$5,NOW(),NOW(),'2024-05-01')`, typeID, sid, rid, pid, pts)
		if err != nil {
			t.Fatal(err)
		}
	}
	insAch(t1, 3)
	insAch(t1, 2)
	insAch(t1, 10)
	for i := 0; i < 2; i++ {
		insAch(t2, 5)
	}

	data, total, totals, err := repo.FetchData(&pb.ReportRequest{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(data) < 2 {
		t.Fatalf("expected at least 2 groups, got %d", len(data))
	}
	if total != int32(len(data)) {
		t.Errorf("total %d vs len %d", total, len(data))
	}
	if totals["total_points"] < 25 {
		t.Errorf("expected aggregated points, got %v", totals["total_points"])
	}
}

func TestAchievementsSummaryFetchData_WithFilters(t *testing.T) {
	repo := setupRepoDB(t)
	_, _, achID := testdb.InsertAchievementGraph(t, repo.db)
	var statusID, typeID int64
	if err := repo.db.QueryRow(
		`SELECT achievement_status_id, achievement_type_id FROM achievements WHERE id = $1`, achID,
	).Scan(&statusID, &typeID); err != nil {
		t.Fatal(err)
	}
	req := &pb.ReportRequest{
		Filters: []*pb.Filter{
			{Field: "status", Operator: "eq", Value: strconv.FormatInt(statusID, 10)},
			{Field: "achievement_type", Operator: "eq", Value: strconv.FormatInt(typeID, 10)},
			{Field: "submission_date", Value: "2024-01-01,2024-12-31"},
			{Field: "unknown", Value: "ignored"},
		},
	}
	data, total, _, err := repo.FetchData(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if total < 1 || len(data) < 1 {
		t.Fatalf("expected matching rows, total=%d len=%d", total, len(data))
	}
}
