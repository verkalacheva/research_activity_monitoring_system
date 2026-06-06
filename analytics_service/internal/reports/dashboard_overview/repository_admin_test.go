//go:build go1.21

package dashboard_overview

import (
	"database/sql"
	"strconv"
	"testing"

	"analytics_service/internal/testdb"
	"analytics_service/pb"
)

func TestDashboardOverviewRepository_AdminFilter(t *testing.T) {
	db := setupDashboardTestDB(t)
	if !columnExists(t, db, "researchers", "admin_id") {
		t.Skip("researchers.admin_id column required")
	}

	adminA, adminB := insertDashboardAdmin(t, db, "admin-a-dash@test"), insertDashboardAdmin(t, db, "admin-b-dash@test")
	insertDashboardAchievement(t, db, adminA, "Type A")
	insertDashboardAchievement(t, db, adminB, "Type B")

	repo := &Repository{db: db}
	req := &pb.ReportRequest{
		Format: "json",
		Filters: []*pb.Filter{
			{Field: "admin_id", Operator: "eq", Value: strconv.FormatInt(adminA, 10)},
		},
	}

	data, err := repo.FetchData(req)
	if err != nil {
		t.Fatalf("fetch admin A: %v", err)
	}
	if len(data.TypeDistribution) != 1 {
		t.Fatalf("expected 1 type bucket for admin A, got %d", len(data.TypeDistribution))
	}
	if data.TypeDistribution[0].Name != "Type A" {
		t.Fatalf("expected Type A, got %q", data.TypeDistribution[0].Name)
	}

	req.Filters[0].Value = "999999"
	data, err = repo.FetchData(req)
	if err != nil {
		t.Fatalf("fetch unknown admin: %v", err)
	}
	if len(data.TypeDistribution) != 0 {
		t.Fatalf("expected empty type distribution, got %+v", data.TypeDistribution)
	}
}

func setupDashboardTestDB(t *testing.T) *sql.DB {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return db
}

func insertDashboardAdmin(t *testing.T, db *sql.DB, email string) int64 {
	t.Helper()
	var id int64
	if err := db.QueryRow(`INSERT INTO users (email, password_digest, role, is_active, created_at, updated_at)
		VALUES ($1, 'x', 'admin', true, NOW(), NOW()) RETURNING id`, email).Scan(&id); err != nil {
		t.Fatalf("insert admin: %v", err)
	}
	return id
}

func insertDashboardAchievement(t *testing.T, db *sql.DB, adminID int64, typeTitle string) {
	t.Helper()
	var typeID, statusID, resultID, partID, researcherID int64

	if err := db.QueryRow(`INSERT INTO achievement_types (title, points, admin_id, created_at, updated_at)
		VALUES ($1, 1, $2, NOW(), NOW()) RETURNING id`, typeTitle, adminID).Scan(&typeID); err != nil {
		t.Fatalf("insert type: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO achievement_statuses (title, admin_id, created_at, updated_at)
		VALUES ('Не указано', $1, NOW(), NOW()) RETURNING id`, adminID).Scan(&statusID); err != nil {
		t.Fatalf("insert status: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO achievement_results (title, admin_id, created_at, updated_at)
		VALUES ('Участие', $1, NOW(), NOW()) RETURNING id`, adminID).Scan(&resultID); err != nil {
		t.Fatalf("insert result: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO achievement_participations (title, admin_id, created_at, updated_at)
		VALUES ('Индивидуальный', $1, NOW(), NOW()) RETURNING id`, adminID).Scan(&partID); err != nil {
		t.Fatalf("insert participation: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO researchers (name, surname, admin_id, created_at, updated_at)
		VALUES ('Ivan', 'Ivanov', $1, NOW(), NOW()) RETURNING id`, adminID).Scan(&researcherID); err != nil {
		t.Fatalf("insert researcher: %v", err)
	}
	var achievementID int64
	if err := db.QueryRow(`INSERT INTO achievements (achievement_type_id, achievement_status_id, achievement_result_id, achievement_participation_id, points, submission_date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, 1, NOW(), NOW(), NOW()) RETURNING id`,
		typeID, statusID, resultID, partID).Scan(&achievementID); err != nil {
		t.Fatalf("insert achievement: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO researcher_achievements (researcher_id, achievement_id, created_at, updated_at)
		VALUES ($1, $2, NOW(), NOW())`, researcherID, achievementID); err != nil {
		t.Fatalf("insert link: %v", err)
	}
}

func columnExists(t *testing.T, db *sql.DB, table, column string) bool {
	t.Helper()
	var exists bool
	err := db.QueryRow(`SELECT EXISTS (
		SELECT 1 FROM information_schema.columns
		WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2
	)`, table, column).Scan(&exists)
	if err != nil {
		t.Fatalf("columnExists: %v", err)
	}
	return exists
}
