package researchers_report

import (
	"database/sql"
	"fmt"
	"strings"

	"analytics_service/internal/reports"
	"analytics_service/pb"
)

type Repository struct {
	db *sql.DB
}

type DataRow struct {
	ID             int     `json:"id"`
	ResearcherID   int     `json:"researcher_id"`
	ResearcherName string  `json:"researcher_name"`
	Achievement    string  `json:"achievement"`
	Points         float64 `json:"points"`
	Status         string  `json:"status"`
	Result         string  `json:"result"`
	Participation  string  `json:"participation"`
	DevPoints      float64 `json:"dev_points"`
}

func (r *Repository) FetchData(req *pb.ReportRequest) ([]DataRow, int32, map[string]float64, error) {
	devPointsSubquery := "(SELECT COALESCE(SUM(cs * als), 0) FROM (" +
		"SELECT (SELECT COALESCE(SUM(dpc2.points), 0) FROM team_dev_criteria tdc2 " +
		"JOIN dev_project_criteria dpc2 ON tdc2.dev_project_criterion_id = dpc2.id WHERE tdc2.team_id = rt2.team_id) AS cs, " +
		"(SELECT COALESCE(SUM(rda2.count * deat2.points), 0) FROM researcher_dev_activities rda2 " +
		"JOIN dev_employee_activity_types deat2 ON rda2.dev_employee_activity_type_id = deat2.id WHERE rda2.researcher_id = r.id AND rda2.team_id = rt2.team_id) AS als " +
		"FROM researchers_teams rt2 " +
		"JOIN teams t2 ON t2.id = rt2.team_id AND t2.deleted_at IS NULL " +
		"WHERE rt2.researcher_id = r.id) dp) AS dev_points"

	baseQuery := "SELECT a.id AS achievement_id, r.id AS researcher_id, " +
		"TRIM(CONCAT_WS(' ', r.surname, r.name, r.second_name)) AS researcher_name, " +
		"COALESCE(at.title, '') AS achievement, " +
		"a.points AS points, " +
		"COALESCE(s.title, '') AS status, " +
		"COALESCE(res.title, '') AS result, " +
		"COALESCE(p.title, '') AS participation, " +
		devPointsSubquery + " " +
		"FROM achievements a " +
		"JOIN researcher_achievements ra ON a.id = ra.achievement_id " +
		"JOIN researchers r ON ra.researcher_id = r.id " +
		"LEFT JOIN achievement_types at ON a.achievement_type_id = at.id AND at.deleted_at IS NULL " +
		"LEFT JOIN achievement_statuses s ON a.achievement_status_id = s.id AND s.deleted_at IS NULL " +
		"LEFT JOIN achievement_results res ON a.achievement_result_id = res.id AND res.deleted_at IS NULL " +
		"LEFT JOIN achievement_participations p ON a.achievement_participation_id = p.id AND p.deleted_at IS NULL " +
		"WHERE a.deleted_at IS NULL AND r.deleted_at IS NULL"

	var args []interface{}
	argCount := 1

	for _, f := range req.Filters {
		var cond string
		var val interface{}

		switch f.Field {
		case "status":
			cond, val = reports.BuildFilterCondition("a.achievement_status_id", f.Operator, argCount, f.Value, true)
		case "achievement_type":
			cond, val = reports.BuildFilterCondition("a.achievement_type_id", f.Operator, argCount, f.Value, true)
		case "researcher_id":
			cond, val = reports.BuildFilterCondition("r.id", f.Operator, argCount, f.Value, true)
		case "team_id":
			// For team_id, we still need the subquery but we can use BuildFilterCondition for the inner part
			innerCond, innerVal := reports.BuildFilterCondition("team_id", f.Operator, argCount, f.Value, true)
			cond = fmt.Sprintf("r.id IN (SELECT rt.researcher_id FROM researchers_teams rt JOIN teams t ON t.id = rt.team_id AND t.deleted_at IS NULL WHERE %s)", innerCond)
			val = innerVal
		case "achievement_result_id":
			cond, val = reports.BuildFilterCondition("res.id", f.Operator, argCount, f.Value, true)
		case "achievement_participation_id":
			cond, val = reports.BuildFilterCondition("p.id", f.Operator, argCount, f.Value, true)
		case "degree_level":
			cond, val = reports.BuildFilterCondition("r.degree_level", f.Operator, argCount, f.Value, false)
		case "points":
			cond, val = reports.BuildFilterCondition("a.points", f.Operator, argCount, f.Value, true)
		case "submission_date":
			if strings.TrimSpace(f.Value) == "" {
				continue
			}
			dates := strings.Split(f.Value, ",")
			if len(dates) == 2 && (dates[0] != "" || dates[1] != "") {
				if dates[0] != "" {
					baseQuery += fmt.Sprintf(" AND a.submission_date::date >= $%d", argCount)
					args = append(args, dates[0])
					argCount++
				}
				if dates[1] != "" {
					baseQuery += fmt.Sprintf(" AND a.submission_date::date <= $%d", argCount)
					args = append(args, dates[1])
					argCount++
				}
				continue
			}
			cond, val = reports.BuildFilterCondition("a.submission_date::date", f.Operator, argCount, f.Value, false)
		default:
			continue
		}

		baseQuery += " AND " + cond
		args = append(args, val)
		argCount++
	}

	// Count total
	countQuery := "SELECT COUNT(*) FROM (" + baseQuery + ") as sub"
	var totalCount int32
	err := r.db.QueryRow(countQuery, args...).Scan(&totalCount)
	if err != nil {
		return nil, 0, nil, err
	}

	// Column totals: achievement points and dev_points (deduped per researcher)
	totalsQuery := "SELECT " +
		"ROUND(COALESCE(SUM(points), 0)::numeric, 1), " +
		"ROUND(COALESCE(SUM(researcher_dev_pts), 0)::numeric, 1) " +
		"FROM (SELECT researcher_id, SUM(points) AS points, MAX(dev_points) AS researcher_dev_pts " +
		"FROM (" + baseQuery + ") AS inner_sub GROUP BY researcher_id) AS sub"
	var totalPoints float64
	var totalDevPoints float64
	_ = r.db.QueryRow(totalsQuery, args...).Scan(&totalPoints, &totalDevPoints)

	// Sorting. For group-aware fields (a.points, dev_points, combined_points) we
	// wrap the base query in a CTE that computes per-researcher aggregates via
	// window functions so that all rows of the same researcher stay together and
	// the groups are ordered by the chosen aggregate. For other fields the base
	// query is used directly.
	groupSortField := ""
	for _, s := range req.Sorts {
		switch s.Field {
		case "a.points", "dev_points", "combined_points":
			groupSortField = s.Field
		}
	}

	var query string
	if groupSortField != "" {
		query = fmt.Sprintf(`
			WITH base AS (
				SELECT *,
					SUM(points) OVER (PARTITION BY researcher_id) AS researcher_total_points,
					SUM(points) OVER (PARTITION BY researcher_id) + dev_points AS researcher_combined_points
				FROM (%s) AS inner_q
			)
			SELECT achievement_id, researcher_id, researcher_name, achievement, points, status, result, participation, dev_points
			FROM base
		`, baseQuery)

		var sortParts []string
		for _, s := range req.Sorts {
			dir := "ASC"
			if s.Descending {
				dir = "DESC"
			}
			switch s.Field {
			case "a.points":
				sortParts = append(sortParts,
					fmt.Sprintf("researcher_total_points %s, researcher_name ASC, points %s", dir, dir))
			case "dev_points":
				sortParts = append(sortParts,
					fmt.Sprintf("dev_points %s, researcher_name ASC", dir))
			case "combined_points":
				sortParts = append(sortParts,
					fmt.Sprintf("researcher_combined_points %s, researcher_name ASC, points %s", dir, dir))
			default:
				sortParts = append(sortParts, fmt.Sprintf("%s %s", s.Field, dir))
			}
		}
		query += " ORDER BY " + strings.Join(sortParts, ", ")
	} else {
		query = baseQuery
		if len(req.Sorts) > 0 {
			var sortParts []string
			for _, s := range req.Sorts {
				dir := "ASC"
				if s.Descending {
					dir = "DESC"
				}
				sortParts = append(sortParts, fmt.Sprintf("%s %s", s.Field, dir))
			}
			query += " ORDER BY " + strings.Join(sortParts, ", ")
		} else {
			query += " ORDER BY r.surname, r.name, r.second_name"
		}
	}

	// Pagination
	query += fmt.Sprintf(" LIMIT %d OFFSET %d", req.Limit, req.Offset)

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, 0, nil, err
	}
	defer rows.Close()

	var data []DataRow
	for rows.Next() {
		var d DataRow
		if err := rows.Scan(&d.ID, &d.ResearcherID, &d.ResearcherName, &d.Achievement, &d.Points, &d.Status, &d.Result, &d.Participation, &d.DevPoints); err != nil {
			return nil, 0, nil, err
		}
		data = append(data, d)
	}

	totals := map[string]float64{
		"points":     totalPoints,
		"dev_points": totalDevPoints,
	}
	return data, totalCount, totals, nil
}
