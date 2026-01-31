package dashboard_overview

import (
	"analytics_service/pb"
	"database/sql"
	"fmt"
)

type Repository struct {
	db *sql.DB
}

type DashboardData struct {
	TypeDistribution   []DistributionItem `json:"type_distribution"`
	StatusDistribution []DistributionItem `json:"status_distribution"`
	TopResearchers     []ResearcherItem   `json:"top_researchers"`
	Dynamics           []DynamicsItem     `json:"dynamics"`
}

type DistributionItem struct {
	Name  string  `json:"name"`
	Value float64 `json:"value"`
}

type ResearcherItem struct {
	Name   string  `json:"name"`
	Points float64 `json:"points"`
}

type DynamicsItem struct {
	Date  string `json:"date"`
	Value int    `json:"value"`
}

func (r *Repository) FetchData(req *pb.ReportRequest) (*DashboardData, error) {
	data := &DashboardData{
		TypeDistribution:   []DistributionItem{},
		StatusDistribution: []DistributionItem{},
		TopResearchers:     []ResearcherItem{},
		Dynamics:           []DynamicsItem{},
	}

	var startDate, endDate string
	for _, f := range req.Filters {
		if f.Field == "start_date" && f.Value != "" {
			startDate = f.Value
		} else if f.Field == "end_date" && f.Value != "" {
			endDate = f.Value
		}
	}

	dateCond := ""
	var args []interface{}
	argCount := 1

	if startDate != "" {
		dateCond += fmt.Sprintf(" AND a.submission_date >= $%d", argCount)
		args = append(args, startDate)
		argCount++
	}
	if endDate != "" {
		dateCond += fmt.Sprintf(" AND a.submission_date <= $%d", argCount)
		args = append(args, endDate)
		argCount++
	}

	// 1. Type Distribution
	typeRows, err := r.db.Query(fmt.Sprintf(`
		SELECT COALESCE(at.title, ''), COUNT(a.id)::float8
		FROM achievements a
		JOIN achievement_types at ON a.achievement_type_id = at.id
		WHERE a.deleted_at IS NULL AND at.deleted_at IS NULL
		%s
		GROUP BY at.title
	`, dateCond), args...)
	if err == nil {
		defer typeRows.Close()
		for typeRows.Next() {
			var item DistributionItem
			if err := typeRows.Scan(&item.Name, &item.Value); err == nil {
				data.TypeDistribution = append(data.TypeDistribution, item)
			}
		}
	}

	// 2. Status Distribution
	statusRows, err := r.db.Query(fmt.Sprintf(`
		SELECT COALESCE(s.title, ''), COUNT(a.id)::float8
		FROM achievements a
		JOIN achievement_statuses s ON a.achievement_status_id = s.id
		WHERE a.deleted_at IS NULL AND s.deleted_at IS NULL
		%s
		GROUP BY s.title
	`, dateCond), args...)
	if err == nil {
		defer statusRows.Close()
		for statusRows.Next() {
			var item DistributionItem
			if err := statusRows.Scan(&item.Name, &item.Value); err == nil {
				data.StatusDistribution = append(data.StatusDistribution, item)
			}
		}
	}

	// 3. Top Researchers
	topResearcherCond := dateCond
	topResearcherArgs := args
	if startDate == "" && endDate == "" {
		topResearcherCond = " AND a.submission_date > CURRENT_DATE - INTERVAL '3 months'"
	}

	researcherRows, err := r.db.Query(fmt.Sprintf(`
		SELECT TRIM(CONCAT_WS(' ', r.surname, SUBSTRING(r.name, 1, 1) || '.')), ROUND(COALESCE(SUM(a.points), 0)::numeric, 1) as total_points
		FROM researchers r
		JOIN researcher_achievements ra ON r.id = ra.researcher_id
		JOIN achievements a ON ra.achievement_id = a.id
		WHERE r.deleted_at IS NULL AND a.deleted_at IS NULL
		%s
		GROUP BY r.id, r.surname, r.name
		ORDER BY total_points DESC
		LIMIT 5
	`, topResearcherCond), topResearcherArgs...)
	if err == nil {
		defer researcherRows.Close()
		for researcherRows.Next() {
			var item ResearcherItem
			if err := researcherRows.Scan(&item.Name, &item.Points); err == nil {
				data.TopResearchers = append(data.TopResearchers, item)
			}
		}
	}

	// 4. Dynamics
	var seriesStart, seriesEnd string
	var seriesArgs []interface{}
	if startDate != "" && endDate != "" {
		seriesStart = "date_trunc('month', $1::date)"
		seriesEnd = "date_trunc('month', $2::date)"
		seriesArgs = []interface{}{startDate, endDate}
	} else {
		seriesStart = "date_trunc('month', CURRENT_DATE) - INTERVAL '11 months'"
		seriesEnd = "date_trunc('month', CURRENT_DATE)"
	}

	dynamicsRows, err := r.db.Query(fmt.Sprintf(`
		SELECT 
			TO_CHAR(month, 'YYYY-MM'), 
			COUNT(a.id)
		FROM 
			generate_series(
				%s, 
				%s, 
				'1 month'::interval
			) month
		LEFT JOIN achievements a ON 
			date_trunc('month', a.submission_date) = month 
			AND a.deleted_at IS NULL
		GROUP BY month
		ORDER BY month
	`, seriesStart, seriesEnd), seriesArgs...)
	if err == nil {
		defer dynamicsRows.Close()
		for dynamicsRows.Next() {
			var item DynamicsItem
			if err := dynamicsRows.Scan(&item.Date, &item.Value); err == nil {
				data.Dynamics = append(data.Dynamics, item)
			}
		}
	}

	return data, nil
}
