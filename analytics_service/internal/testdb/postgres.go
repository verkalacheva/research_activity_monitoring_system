// Package testdb — PostgreSQL для интеграционных тестов analytics_service.
// Общая БД и схема — как в docker-compose (db-test + test-db-schema).
package testdb

import (
	"database/sql"
	"os"
	"testing"

	_ "github.com/lib/pq"
)

func SkipIfNoDSN(t *testing.T) {
	t.Helper()
	if os.Getenv("TEST_DATABASE_URL") == "" {
		t.Skip("set TEST_DATABASE_URL to run integration tests against PostgreSQL")
	}
}

func Open(t *testing.T) *sql.DB {
	t.Helper()
	SkipIfNoDSN(t)
	dsn := os.Getenv("TEST_DATABASE_URL")
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		t.Fatalf("db.Ping: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	return db
}

// EnsureTestAdmin creates (or finds) the shared integration-test admin user and returns its ID.
// Idempotent — safe to call from multiple tests without a DB reset between them.
func EnsureTestAdmin(t *testing.T, db *sql.DB) int64 {
	t.Helper()
	var id int64
	err := db.QueryRow(
		`INSERT INTO users (email, password_digest, role, is_active, created_at, updated_at)
		 VALUES ('testadmin@integration.test', 'x', 'admin', true, NOW(), NOW())
		 ON CONFLICT (email) DO UPDATE SET updated_at = NOW()
		 RETURNING id`,
	).Scan(&id)
	if err != nil {
		t.Fatalf("ensure test admin: %v", err)
	}
	return id
}

// TruncateAllReportTables очищает данные между тестами.
func TruncateAllReportTables(t *testing.T, db *sql.DB) {
	t.Helper()
	_, err := db.Exec(`
TRUNCATE TABLE
	researcher_achievements,
	achievements,
	researcher_dev_activities,
	team_dev_activities,
	team_dev_criteria,
	researchers_teams,
	teams,
	researchers,
	achievement_types,
	achievement_statuses,
	achievement_results,
	achievement_participations,
	dev_project_criteria,
	dev_employee_activity_types
RESTART IDENTITY CASCADE`)
	if err != nil {
		t.Fatalf("truncate: %v", err)
	}
}
