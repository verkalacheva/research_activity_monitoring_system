//go:build go1.21

package teams

import (
	"database/sql"
	"strconv"
	"testing"

	"analytics_service/pb"
)

func TestTeamsRepository_AdminFilter(t *testing.T) {
	db := setupTeamsTestDB(t)
	if !columnExists(t, db, "teams", "admin_id") {
		t.Skip("teams.admin_id column required")
	}

	var adminA, adminB int64
	if err := db.QueryRow(`INSERT INTO users (email, password_digest, role, is_active, created_at, updated_at)
		VALUES ('admin-a@test', 'x', 'admin', true, NOW(), NOW()) RETURNING id`).Scan(&adminA); err != nil {
		t.Fatalf("insert admin A: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO users (email, password_digest, role, is_active, created_at, updated_at)
		VALUES ('admin-b@test', 'x', 'admin', true, NOW(), NOW()) RETURNING id`).Scan(&adminB); err != nil {
		t.Fatalf("insert admin B: %v", err)
	}

	insertTeam := func(adminID int64, title string) {
		t.Helper()
		if _, err := db.Exec(`INSERT INTO teams (title, admin_id, created_at, updated_at)
			VALUES ($1, $2, NOW(), NOW())`, title, adminID); err != nil {
			t.Fatalf("insert team %q: %v", title, err)
		}
	}
	insertTeam(adminA, "Team A")
	insertTeam(adminB, "Team B")

	repo := &Repository{db: db}

	req := &pb.ReportRequest{
		Format: "json",
		Limit:  20,
		Filters: []*pb.Filter{
			{Field: "admin_id", Operator: "eq", Value: "999999"},
		},
	}
	data, total, _, err := repo.FetchData(req)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if total != 0 || len(data) != 0 {
		t.Fatalf("expected empty for unknown admin, got total=%d len=%d", total, len(data))
	}

	req.Filters[0].Value = strconv.FormatInt(adminA, 10)
	data, total, _, err = repo.FetchData(req)
	if err != nil {
		t.Fatalf("fetch admin A: %v", err)
	}
	if total != 1 || len(data) != 1 {
		t.Fatalf("expected 1 team for admin A, got total=%d len=%d", total, len(data))
	}
	if data[0].Title != "Team A" {
		t.Fatalf("expected Team A, got %q", data[0].Title)
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
