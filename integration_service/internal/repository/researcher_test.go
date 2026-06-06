//go:build go1.21

package repository

import (
	"testing"

	"integration_service/internal/testdb"
)

func TestNewResearcherRepository(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	repo := NewResearcherRepository(db)
	if repo == nil {
		t.Fatal("expected non-nil repository")
	}
	if repo.db == nil {
		t.Fatal("expected non-nil db")
	}
}

func TestExistsByOrcidID_Found(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := testdb.InsertAdmin(t, db, "exists-orcid@test")
	testdb.InsertResearcherORCID(t, db, adminID, "0000-0001-2345-6789")

	repo := NewResearcherRepository(db)
	exists, err := repo.ExistsByOrcidID("0000-0001-2345-6789")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !exists {
		t.Error("expected exists=true")
	}
}

func TestExistsByOrcidID_NotFound(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)

	repo := NewResearcherRepository(db)
	exists, err := repo.ExistsByOrcidID("0000-9999-9999-9999")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if exists {
		t.Error("expected exists=false")
	}
}

func TestExistsByOrcidID_SoftDeletedIgnored(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := testdb.InsertAdmin(t, db, "soft-del@test")

	_, err := db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES ($1, NULL, $2, NOW(), NOW(), NOW())`,
		"0000-0001-9999-0001", adminID,
	)
	if err != nil {
		t.Fatalf("insert: %v", err)
	}

	repo := NewResearcherRepository(db)
	exists, err := repo.ExistsByOrcidID("0000-0001-9999-0001")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if exists {
		t.Error("soft-deleted row must not count as existing")
	}
}

func TestExistsByOpenAlexID_Found(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := testdb.InsertAdmin(t, db, "openalex-exists@test")

	_, err := db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES (NULL, $1, $2, NULL, NOW(), NOW())`,
		"A1234567890", adminID,
	)
	if err != nil {
		t.Fatalf("insert: %v", err)
	}

	repo := NewResearcherRepository(db)
	exists, err := repo.ExistsByOpenAlexID("A1234567890")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !exists {
		t.Error("expected exists=true")
	}
}

func TestGetAllWithExternalID_Orcid(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := testdb.InsertAdmin(t, db, "orcid-all@test")

	for _, orcid := range []string{"0000-0001-2345-6789", "0000-0002-3456-7890"} {
		testdb.InsertResearcherORCID(t, db, adminID, orcid)
	}

	repo := NewResearcherRepository(db)
	researchers, err := repo.GetAllWithExternalID("orcid", adminID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(researchers) != 2 {
		t.Fatalf("expected 2 researchers, got %d", len(researchers))
	}
	seen := map[string]bool{}
	for _, r := range researchers {
		if !r.OrcidID.Valid {
			t.Error("expected valid OrcidID")
		}
		seen[r.OrcidID.String] = true
	}
	if !seen["0000-0001-2345-6789"] || !seen["0000-0002-3456-7890"] {
		t.Errorf("unexpected orcid set: %+v", seen)
	}
}

func TestGetAllWithExternalID_OpenAlex(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := testdb.InsertAdmin(t, db, "openalex-all@test")

	_, err := db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES (NULL, $1, $2, NULL, NOW(), NOW())`,
		"A1234567890", adminID,
	)
	if err != nil {
		t.Fatalf("insert: %v", err)
	}

	repo := NewResearcherRepository(db)
	researchers, err := repo.GetAllWithExternalID("openalex", adminID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(researchers) != 1 {
		t.Fatalf("expected 1 researcher, got %d", len(researchers))
	}
	if !researchers[0].OpenAlexID.Valid || researchers[0].OpenAlexID.String != "A1234567890" {
		t.Errorf("openalex: %+v", researchers[0].OpenAlexID)
	}
}

func TestGetAllWithExternalID_All(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := testdb.InsertAdmin(t, db, "all-providers@test")

	testdb.InsertResearcherORCID(t, db, adminID, "0000-0001-1111-1111")
	_, err := db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES (NULL, $1, $2, NULL, NOW(), NOW())`,
		"A9876543210", adminID,
	)
	if err != nil {
		t.Fatalf("insert2: %v", err)
	}

	repo := NewResearcherRepository(db)
	researchers, err := repo.GetAllWithExternalID("all", adminID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(researchers) != 2 {
		t.Fatalf("expected 2 researchers, got %d", len(researchers))
	}
}

func TestGetAllWithExternalID_UnsupportedProvider(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	repo := NewResearcherRepository(db)
	_, err := repo.GetAllWithExternalID("github", 1)
	if err == nil {
		t.Fatal("expected error for unsupported provider, got nil")
	}
}

func TestGetAllWithExternalID_EmptyResult(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := testdb.InsertAdmin(t, db, "empty@test")

	repo := NewResearcherRepository(db)
	researchers, err := repo.GetAllWithExternalID("orcid", adminID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(researchers) != 0 {
		t.Errorf("expected 0 researchers, got %d", len(researchers))
	}
}
