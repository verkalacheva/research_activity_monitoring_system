//go:build go1.21

package dev_teams

import (
	"context"
	"database/sql"
	"encoding/json"
	"strconv"
	"testing"

	"analytics_service/internal/testdb"
	"analytics_service/pb"
)

func TestDevTeamsHandler_AdminFilter(t *testing.T) {
	db := setupDevTeamsTestDB(t)
	if !columnExists(t, db, "teams", "admin_id") {
		t.Skip("teams.admin_id column required")
	}

	adminA, adminB := insertDevTeamsAdmin(t, db, "admin-a-devt@test"), insertDevTeamsAdmin(t, db, "admin-b-devt@test")
	insertDevTeam(t, db, adminA, "Team A")
	insertDevTeam(t, db, adminB, "Team B")

	handler := NewHandler(db)
	req := &pb.ReportRequest{
		Format: "json",
		Limit:  20,
		Filters: []*pb.Filter{
			{Field: "admin_id", Operator: "eq", Value: strconv.FormatInt(adminA, 10)},
		},
	}

	resp, err := handler.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("generate admin A: %v", err)
	}
	if resp.TotalCount != 1 {
		t.Fatalf("expected 1 team for admin A, got %d", resp.TotalCount)
	}

	var rows []map[string]interface{}
	if err := json.Unmarshal(resp.Data, &rows); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(rows) != 1 || rows[0]["team"] != "Team A" {
		t.Fatalf("unexpected rows: %+v", rows)
	}

	req.Filters[0].Value = "999999"
	resp, err = handler.Generate(context.Background(), req)
	if err != nil {
		t.Fatalf("generate unknown admin: %v", err)
	}
	if resp.TotalCount != 0 {
		t.Fatalf("expected 0 teams for unknown admin, got %d", resp.TotalCount)
	}
}

func setupDevTeamsTestDB(t *testing.T) *sql.DB {
	t.Helper()
	db := testdb.Open(t)
	testdb.TruncateAllReportTables(t, db)
	return db
}

func insertDevTeamsAdmin(t *testing.T, db *sql.DB, email string) int64 {
	t.Helper()
	var id int64
	if err := db.QueryRow(`INSERT INTO users (email, password_digest, role, is_active, created_at, updated_at)
		VALUES ($1, 'x', 'admin', true, NOW(), NOW()) RETURNING id`, email).Scan(&id); err != nil {
		t.Fatalf("insert admin: %v", err)
	}
	return id
}

func insertDevTeam(t *testing.T, db *sql.DB, adminID int64, title string) {
	t.Helper()
	if _, err := db.Exec(`INSERT INTO teams (title, admin_id, created_at, updated_at)
		VALUES ($1, $2, NOW(), NOW())`, title, adminID); err != nil {
		t.Fatalf("insert team: %v", err)
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
