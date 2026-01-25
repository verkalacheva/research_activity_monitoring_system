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
}

func (r *Repository) FetchData(req *pb.ReportRequest) ([]DataRow, int32, map[string]float64, error) {
	baseQuery := "SELECT a.id, r.id, " +
		"TRIM(CONCAT_WS(' ', r.surname, r.name, r.second_name)), " +
		"COALESCE(at.title, ''), a.points, COALESCE(s.title, ''), COALESCE(res.title, ''), COALESCE(p.title, '') " +
		"FROM achievements a " +
		"JOIN researcher_achievements ra ON a.id = ra.achievement_id " +
		"JOIN researchers r ON ra.researcher_id = r.id " +
		"LEFT JOIN achievement_types at ON a.achievement_type_id = at.id " +
		"LEFT JOIN achievement_statuses s ON a.achievement_status_id = s.id " +
		"LEFT JOIN achievement_results res ON a.achievement_result_id = res.id " +
		"LEFT JOIN achievement_participations p ON a.achievement_participation_id = p.id"

	baseQuery = reports.AppendSoftDelete(baseQuery, "a")
	baseQuery = reports.AppendSoftDelete(baseQuery, "r")
	baseQuery = reports.AppendSoftDelete(baseQuery, "at")
	baseQuery = reports.AppendSoftDelete(baseQuery, "s")
	baseQuery = reports.AppendSoftDelete(baseQuery, "res")
	baseQuery = reports.AppendSoftDelete(baseQuery, "p")

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
			cond = fmt.Sprintf("r.id IN (SELECT researcher_id FROM researchers_teams WHERE %s)", innerCond)
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
			} else {
				cond, val = reports.BuildFilterCondition("a.submission_date::date", f.Operator, argCount, f.Value, false)
			}
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

	// Column totals
	totalsQuery := "SELECT ROUND(COALESCE(SUM(points), 0)::numeric, 1) FROM (" + baseQuery + ") as sub"
	var totalPoints float64
	_ = r.db.QueryRow(totalsQuery, args...).Scan(&totalPoints)

	// Sorting - default by researcher name to help with grouping
	query := baseQuery
	if len(req.Sorts) > 0 {
		query += " ORDER BY "
		var sortParts []string
		for _, s := range req.Sorts {
			dir := "ASC"
			if s.Descending {
				dir = "DESC"
			}
			sortParts = append(sortParts, fmt.Sprintf("%s %s", s.Field, dir))
		}
		query += strings.Join(sortParts, ", ")
	} else {
		query += " ORDER BY r.surname, r.name, r.second_name"
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
		if err := rows.Scan(&d.ID, &d.ResearcherID, &d.ResearcherName, &d.Achievement, &d.Points, &d.Status, &d.Result, &d.Participation); err != nil {
			return nil, 0, nil, err
		}
		data = append(data, d)
	}

	totals := map[string]float64{"points": totalPoints}
	return data, totalCount, totals, nil
}
