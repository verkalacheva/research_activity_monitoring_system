package repository

import (
	"database/sql"
	"fmt"
)

type Researcher struct {
	ID         int64
	OrcidID    sql.NullString
	OpenAlexID sql.NullString
}

type ResearcherRepository struct {
	db *sql.DB
}

func NewResearcherRepository(db *sql.DB) *ResearcherRepository {
	return &ResearcherRepository{db: db}
}

func (r *ResearcherRepository) ExistsByOrcidID(orcidID string) (bool, error) {
	var exists bool
	query := "SELECT EXISTS(SELECT 1 FROM researchers WHERE orcid_id = $1 AND deleted_at IS NULL)"
	err := r.db.QueryRow(query, orcidID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("error checking orcid_id existence: %w", err)
	}
	return exists, nil
}

func (r *ResearcherRepository) ExistsByOpenAlexID(openAlexID string) (bool, error) {
	var exists bool
	query := "SELECT EXISTS(SELECT 1 FROM researchers WHERE openalex_id = $1 AND deleted_at IS NULL)"
	err := r.db.QueryRow(query, openAlexID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("error checking openalex_id existence: %w", err)
	}
	return exists, nil
}

func (r *ResearcherRepository) GetAllWithExternalID(provider string, adminID int64) ([]Researcher, error) {
	if adminID <= 0 {
		return nil, fmt.Errorf("admin_id is required")
	}

	var query string
	switch provider {
	case "orcid":
		query = "SELECT id, orcid_id, openalex_id FROM researchers WHERE admin_id = $1 AND orcid_id IS NOT NULL AND deleted_at IS NULL"
	case "openalex":
		query = "SELECT id, orcid_id, openalex_id FROM researchers WHERE admin_id = $1 AND openalex_id IS NOT NULL AND deleted_at IS NULL"
	case "all":
		query = "SELECT id, orcid_id, openalex_id FROM researchers WHERE admin_id = $1 AND (orcid_id IS NOT NULL OR openalex_id IS NOT NULL) AND deleted_at IS NULL"
	default:
		return nil, fmt.Errorf("unsupported provider: %s", provider)
	}

	rows, err := r.db.Query(query, adminID)
	if err != nil {
		return nil, fmt.Errorf("error querying researchers: %w", err)
	}
	defer rows.Close()

	var researchers []Researcher
	for rows.Next() {
		var res Researcher
		if err := rows.Scan(&res.ID, &res.OrcidID, &res.OpenAlexID); err != nil {
			return nil, err
		}
		researchers = append(researchers, res)
	}
	return researchers, nil
}
