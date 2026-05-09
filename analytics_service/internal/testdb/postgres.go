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
