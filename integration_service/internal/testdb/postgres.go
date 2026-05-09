// Package testdb — подключение к PostgreSQL для интеграционных тестов (реальные INSERT/SELECT).
// В Docker: общая БД db-test (research_activity_monitoring_system_test), схема — сервис test-db-schema в docker-compose.yml.
package testdb

import (
	"database/sql"
	"os"
	"testing"

	_ "github.com/lib/pq"
)

// SkipIfNoDSN пропускает тест, если не задана тестовая БД.
func SkipIfNoDSN(t *testing.T) {
	t.Helper()
	if os.Getenv("TEST_DATABASE_URL") == "" {
		t.Skip("set TEST_DATABASE_URL to run integration tests against PostgreSQL")
	}
}

// Open открывает пул к TEST_DATABASE_URL и закрывает его в t.Cleanup.
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

func mustExec(t *testing.T, db *sql.DB, q string, args ...any) {
	t.Helper()
	if _, err := db.Exec(q, args...); err != nil {
		t.Fatalf("exec %q: %v", q, err)
	}
}

// EnsureResearchersTable создаёт таблицу researchers под запросы ResearcherRepository.
func EnsureResearchersTable(t *testing.T, db *sql.DB) {
	t.Helper()
	mustExec(t, db, `
CREATE TABLE IF NOT EXISTS researchers (
	id BIGSERIAL PRIMARY KEY,
	orcid_id TEXT,
	openalex_id TEXT,
	deleted_at TIMESTAMP
)`)
}

// TruncateResearchers очищает таблицу между тестами.
func TruncateResearchers(t *testing.T, db *sql.DB) {
	t.Helper()
	mustExec(t, db, `TRUNCATE researchers RESTART IDENTITY CASCADE`)
}

// EnsureDevCatalogTables — dev_employee_activity_types и dev_project_criteria для github.Client.
func EnsureDevCatalogTables(t *testing.T, db *sql.DB) {
	t.Helper()
	mustExec(t, db, `
CREATE TABLE IF NOT EXISTS dev_employee_activity_types (
	id BIGSERIAL PRIMARY KEY,
	title VARCHAR NOT NULL,
	points DECIMAL(10,2) DEFAULT 0,
	created_at TIMESTAMP NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
	check_key VARCHAR
)`)
	mustExec(t, db, `
CREATE TABLE IF NOT EXISTS dev_project_criteria (
	id BIGSERIAL PRIMARY KEY,
	title VARCHAR NOT NULL,
	points DECIMAL(10,2) DEFAULT 0,
	created_at TIMESTAMP NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
	check_key VARCHAR
)`)
}

// TruncateDevCatalog очищает справочники GitHub-синка.
func TruncateDevCatalog(t *testing.T, db *sql.DB) {
	t.Helper()
	mustExec(t, db, `TRUNCATE dev_employee_activity_types RESTART IDENTITY CASCADE`)
	mustExec(t, db, `TRUNCATE dev_project_criteria RESTART IDENTITY CASCADE`)
}
