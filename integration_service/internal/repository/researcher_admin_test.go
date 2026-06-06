//go:build go1.21

package repository

import (
	"testing"

	"integration_service/internal/testdb"
)

func TestGetAllWithExternalID_RequiresAdminID(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	repo := NewResearcherRepository(db)

	_, err := repo.GetAllWithExternalID("orcid", 0)
	if err == nil {
		t.Fatal("expected error when admin_id is missing")
	}
}

func TestGetAllWithExternalID_AdminFilter(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)

	adminA := testdb.InsertAdmin(t, db, "admin-a@test")
	adminB := testdb.InsertAdmin(t, db, "admin-b@test")

	_, err := db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES ($1, NULL, $2, NULL, NOW(), NOW())`,
		"0000-0001-2345-6789", adminA,
	)
	if err != nil {
		t.Fatalf("insert A: %v", err)
	}
	_, err = db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES ($1, NULL, $2, NULL, NOW(), NOW())`,
		"0000-0002-3456-7890", adminB,
	)
	if err != nil {
		t.Fatalf("insert B: %v", err)
	}

	repo := NewResearcherRepository(db)
	researchers, err := repo.GetAllWithExternalID("orcid", adminA)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(researchers) != 1 {
		t.Fatalf("expected 1 researcher for admin A, got %d", len(researchers))
	}
	if !researchers[0].OrcidID.Valid || researchers[0].OrcidID.String != "0000-0001-2345-6789" {
		t.Fatalf("unexpected orcid: %+v", researchers[0].OrcidID)
	}
}
