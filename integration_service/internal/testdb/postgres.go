// Package testdb — подключение к PostgreSQL для интеграционных тестов (реальные INSERT/SELECT).
// Ожидается полная схема Rails (backend/db/schema.rb): db:schema:load в TEST_DATABASE_URL
// (CI: шаг перед go test; локально: docker-compose test-db-schema или bundle exec rails db:schema:load из backend).
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

func assertPublicTableExists(t *testing.T, db *sql.DB, table string) {
	t.Helper()
	var n int
	err := db.QueryRow(
		`SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = $1`,
		table,
	).Scan(&n)
	if err != nil {
		t.Fatalf("schema check %q: %v", table, err)
	}
	if n != 1 {
		t.Fatalf("missing table %q: load Rails schema (cd backend && RAILS_ENV=test DATABASE_URL=$TEST_DATABASE_URL bundle exec rails db:schema:load)", table)
	}
}

// EnsureResearchersTable проверяет, что в БД есть таблица researchers из схемы Rails.
func EnsureResearchersTable(t *testing.T, db *sql.DB) {
	t.Helper()
	assertPublicTableExists(t, db, "researchers")
}

// TruncateResearchers очищает таблицу между тестами.
func TruncateResearchers(t *testing.T, db *sql.DB) {
	t.Helper()
	mustExec(t, db, `TRUNCATE researchers RESTART IDENTITY CASCADE`)
}

// InsertAdmin создаёт admin-пользователя и возвращает id.
func InsertAdmin(t *testing.T, db *sql.DB, email string) int64 {
	t.Helper()
	var id int64
	err := db.QueryRow(
		`INSERT INTO users (email, password_digest, role, is_active, created_at, updated_at)
		 VALUES ($1, 'x', 'admin', true, NOW(), NOW()) RETURNING id`,
		email,
	).Scan(&id)
	if err != nil {
		t.Fatalf("insert admin %q: %v", email, err)
	}
	return id
}

// InsertResearcherORCID вставляет исследователя с ORCID для указанного admin.
func InsertResearcherORCID(t *testing.T, db *sql.DB, adminID int64, orcid string) {
	t.Helper()
	_, err := db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES ($1, NULL, $2, NULL, NOW(), NOW())`,
		orcid, adminID,
	)
	if err != nil {
		t.Fatalf("insert researcher orcid %q: %v", orcid, err)
	}
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

// EnsureDevCatalogTables проверяет таблицы dev_employee_activity_types и dev_project_criteria (схема Rails).
func EnsureDevCatalogTables(t *testing.T, db *sql.DB) {
	t.Helper()
	assertPublicTableExists(t, db, "dev_employee_activity_types")
	assertPublicTableExists(t, db, "dev_project_criteria")
}

// TruncateDevCatalog очищает справочники GitHub-синка.
func TruncateDevCatalog(t *testing.T, db *sql.DB) {
	t.Helper()
	mustExec(t, db, `TRUNCATE dev_employee_activity_types RESTART IDENTITY CASCADE`)
	mustExec(t, db, `TRUNCATE dev_project_criteria RESTART IDENTITY CASCADE`)
}
