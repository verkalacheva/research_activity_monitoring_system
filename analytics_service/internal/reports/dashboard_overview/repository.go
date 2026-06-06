package dashboard_overview

import (
	"analytics_service/internal/reports"
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
	Name              string  `json:"name"`
	Points            float64 `json:"points"`
	AchievementPoints float64 `json:"achievement_points"`
	DevPoints         float64 `json:"dev_points"`
	TotalPoints       float64 `json:"total_points"`
}

type DynamicsItem struct {
	Date  string `json:"date"`
	Value int    `json:"value"`
}

func appendDateFilters(startDate, endDate string, argCount int, args []interface{}) (cond string, newArgs []interface{}, newArgCount int) {
	if startDate != "" {
		cond += fmt.Sprintf(" AND a.submission_date >= $%d", argCount)
		args = append(args, startDate)
		argCount++
	}
	if endDate != "" {
		cond += fmt.Sprintf(" AND a.submission_date <= $%d", argCount)
		args = append(args, endDate)
		argCount++
	}
	return cond, args, argCount
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

	adminID := reports.AdminIDFromRequest(req)

	// 1. Type Distribution
	typeArgs := []interface{}{}
	typeArgCount := 1
	typeAdminCond := ""
	if adminID > 0 {
		var adminSQL string
		adminSQL, typeArgs, typeArgCount = reports.AdminFilterSQL(adminID, typeArgCount, typeArgs, "at.admin_id")
		typeAdminCond = adminSQL
	}
	typeDateCond, typeArgs, _ := appendDateFilters(startDate, endDate, typeArgCount, typeArgs)

	typeRows, err := r.db.Query(fmt.Sprintf(`
		SELECT COALESCE(at.title, ''), COUNT(a.id)::float8
		FROM achievements a
		JOIN achievement_types at ON a.achievement_type_id = at.id
		WHERE a.deleted_at IS NULL AND at.deleted_at IS NULL
		%s%s
		GROUP BY at.title
	`, typeAdminCond, typeDateCond), typeArgs...)
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
	statusArgs := []interface{}{}
	statusArgCount := 1
	statusAdminCond := ""
	if adminID > 0 {
		var adminSQL string
		adminSQL, statusArgs, statusArgCount = reports.AdminFilterSQL(adminID, statusArgCount, statusArgs, "s.admin_id")
		statusAdminCond = adminSQL
	}
	statusDateCond, statusArgs, _ := appendDateFilters(startDate, endDate, statusArgCount, statusArgs)

	statusRows, err := r.db.Query(fmt.Sprintf(`
		SELECT COALESCE(s.title, ''), COUNT(a.id)::float8
		FROM achievements a
		JOIN achievement_statuses s ON a.achievement_status_id = s.id
		WHERE a.deleted_at IS NULL AND s.deleted_at IS NULL
		%s%s
		GROUP BY s.title
	`, statusAdminCond, statusDateCond), statusArgs...)
	if err == nil {
		defer statusRows.Close()
		for statusRows.Next() {
			var item DistributionItem
			if err := statusRows.Scan(&item.Name, &item.Value); err == nil {
				data.StatusDistribution = append(data.StatusDistribution, item)
			}
		}
	}

	// 3. Top Researchers (by combined achievement + dev score)
	topArgs := []interface{}{}
	topArgCount := 1
	researcherAdminCond := ""
	if adminID > 0 {
		researcherAdminCond = fmt.Sprintf(" AND r.admin_id = $%d", topArgCount)
		topArgs = append(topArgs, adminID)
		topArgCount++
	}

	achDateCond := ""
	if startDate == "" && endDate == "" {
		achDateCond = " AND a.submission_date > CURRENT_DATE - INTERVAL '3 months'"
	} else {
		achDateCond, topArgs, _ = appendDateFilters(startDate, endDate, topArgCount, topArgs)
	}

	researcherRows, err := r.db.Query(fmt.Sprintf(`
		SELECT
			name,
			achievement_points,
			dev_points,
			achievement_points + dev_points AS total_points
		FROM (
			SELECT
				TRIM(CONCAT_WS(' ', r.surname, SUBSTRING(r.name, 1, 1) || '.')) AS name,
				ROUND(COALESCE((
					SELECT SUM(a.points)
					FROM researcher_achievements ra
					JOIN achievements a ON ra.achievement_id = a.id
					JOIN achievement_types at ON a.achievement_type_id = at.id
						AND at.deleted_at IS NULL AND at.admin_id = r.admin_id
					WHERE ra.researcher_id = r.id AND a.deleted_at IS NULL%s
				), 0)::numeric, 1) AS achievement_points,
				ROUND(COALESCE((
					SELECT SUM(cs * als)
					FROM (
						SELECT
							(SELECT COALESCE(SUM(dpc.points), 0)
							 FROM team_dev_criteria tdc
							 JOIN dev_project_criteria dpc ON tdc.dev_project_criterion_id = dpc.id
								AND dpc.admin_id = r.admin_id
							 JOIN teams t ON t.id = tdc.team_id AND t.deleted_at IS NULL AND t.admin_id = r.admin_id
							 WHERE tdc.team_id = rt2.team_id) AS cs,
							(SELECT COALESCE(SUM(rda.count * deat.points), 0)
							 FROM researcher_dev_activities rda
							 JOIN dev_employee_activity_types deat ON rda.dev_employee_activity_type_id = deat.id
								AND deat.admin_id = r.admin_id
							 WHERE rda.researcher_id = r.id AND rda.team_id = rt2.team_id) AS als
						FROM researchers_teams rt2
						JOIN teams t2 ON t2.id = rt2.team_id AND t2.deleted_at IS NULL AND t2.admin_id = r.admin_id
						WHERE rt2.researcher_id = r.id
					) dp
				), 0)::numeric, 1) AS dev_points
			FROM researchers r
			WHERE r.deleted_at IS NULL%s
		) sub
		WHERE achievement_points > 0 OR dev_points > 0
		ORDER BY total_points DESC
		LIMIT 5
	`, achDateCond, researcherAdminCond), topArgs...)
	if err == nil {
		defer researcherRows.Close()
		for researcherRows.Next() {
			var item ResearcherItem
			if err := researcherRows.Scan(&item.Name, &item.AchievementPoints, &item.DevPoints, &item.TotalPoints); err == nil {
				item.Points = item.TotalPoints
				data.TopResearchers = append(data.TopResearchers, item)
			}
		}
	}

	// 4. Dynamics
	var seriesStart, seriesEnd string
	dynamicsArgs := []interface{}{}
	dynamicsArgCount := 1
	dynamicsAdminCond := ""
	if adminID > 0 {
		dynamicsAdminCond = fmt.Sprintf(" AND at.admin_id = $%d", dynamicsArgCount)
		dynamicsArgs = append(dynamicsArgs, adminID)
		dynamicsArgCount++
	}

	if startDate != "" && endDate != "" {
		seriesStart = fmt.Sprintf("date_trunc('month', $%d::date)", dynamicsArgCount)
		dynamicsArgs = append(dynamicsArgs, startDate)
		dynamicsArgCount++
		seriesEnd = fmt.Sprintf("date_trunc('month', $%d::date)", dynamicsArgCount)
		dynamicsArgs = append(dynamicsArgs, endDate)
	} else {
		seriesStart = "date_trunc('month', CURRENT_DATE) - INTERVAL '11 months'"
		seriesEnd = "date_trunc('month', CURRENT_DATE)"
	}

	dynamicsRows, err := r.db.Query(fmt.Sprintf(`
		SELECT 
			TO_CHAR(month, 'YYYY-MM'), 
			COUNT(at.id)
		FROM 
			generate_series(
				%s, 
				%s, 
				'1 month'::interval
			) month
		LEFT JOIN achievements a ON 
			date_trunc('month', a.submission_date) = month 
			AND a.deleted_at IS NULL
		LEFT JOIN achievement_types at ON a.achievement_type_id = at.id AND at.deleted_at IS NULL%s
		GROUP BY month
		ORDER BY month
	`, seriesStart, seriesEnd, dynamicsAdminCond), dynamicsArgs...)
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
