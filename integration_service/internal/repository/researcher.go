package repository

import (
	"database/sql"
	"fmt"
)

type Researcher struct {
	ID      int64
	OrcidID string
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
		return false, fmt.Errorf("error checking researcher existence: %w", err)
	}
	return exists, nil
}

func (r *ResearcherRepository) GetAllWithOrcidID() ([]Researcher, error) {
	query := "SELECT id, orcid_id FROM researchers WHERE orcid_id IS NOT NULL AND deleted_at IS NULL"
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("error querying researchers: %w", err)
	}
	defer rows.Close()

	var researchers []Researcher
	for rows.Next() {
		var res Researcher
		if err := rows.Scan(&res.ID, &res.OrcidID); err != nil {
			return nil, err
		}
		researchers = append(researchers, res)
	}
	return researchers, nil
}
