package testdb

import (
	"database/sql"
	"errors"
	"testing"
)

// StashGitHubToken удаляет строку app_settings.github_token (если была) и в t.Cleanup
// восстанавливает прежнее значение и description. Нужен для тестов resolveToken без постоянного загрязнения БД.
func StashGitHubToken(t *testing.T, db *sql.DB) {
	t.Helper()
	assertPublicTableExists(t, db, "app_settings")
	var value, description sql.NullString
	var adminID sql.NullInt64
	var had bool
	switch err := db.QueryRow(
		`SELECT value, description, admin_id FROM app_settings WHERE key = 'github_token'`,
	).Scan(&value, &description, &adminID); {
	case err == nil:
		had = true
	case errors.Is(err, sql.ErrNoRows):
		had = false
	default:
		t.Fatalf("stash github_token: %v", err)
	}
	t.Cleanup(func() {
		if _, err := db.Exec(`DELETE FROM app_settings WHERE key = 'github_token'`); err != nil {
			t.Logf("stash cleanup delete: %v", err)
		}
		if !had {
			return
		}
		if _, err := db.Exec(
			`INSERT INTO app_settings (key, value, description, admin_id, created_at, updated_at)
			 VALUES ('github_token', $1, $2, $3, NOW(), NOW())`,
			value, description, adminID,
		); err != nil {
			t.Logf("stash restore insert: %v", err)
		}
	})
	if _, err := db.Exec(`DELETE FROM app_settings WHERE key = 'github_token'`); err != nil {
		t.Fatalf("stash delete github_token: %v", err)
	}
}
