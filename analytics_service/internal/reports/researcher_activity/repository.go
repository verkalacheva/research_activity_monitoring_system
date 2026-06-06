package researcher_activity

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
	ID          int     `json:"id"`
	Researcher  string  `json:"researcher"`
	Achievement string  `json:"achievement"`
	Points      float64 `json:"points"`
	Status      string  `json:"status"`
}

func (r *Repository) FetchData(req *pb.ReportRequest) ([]DataRow, int32, map[string]float64, error) {
	baseQuery := "SELECT a.id, COALESCE(r.surname, ''), COALESCE(at.title, ''), a.points, COALESCE(s.title, '') " +
		"FROM achievements a " +
		"JOIN researcher_achievements ra ON a.id = ra.achievement_id " +
		"JOIN researchers r ON ra.researcher_id = r.id " +
		"LEFT JOIN achievement_types at ON a.achievement_type_id = at.id" + reports.MatchAdminColumn("at.admin_id", "r") +
		" LEFT JOIN achievement_statuses s ON a.achievement_status_id = s.id" + reports.MatchAdminColumn("s.admin_id", "r")

	baseQuery = reports.AppendSoftDelete(baseQuery, "a")
	baseQuery = reports.AppendSoftDelete(baseQuery, "r")
	baseQuery = reports.AppendSoftDelete(baseQuery, "at")
	baseQuery = reports.AppendSoftDelete(baseQuery, "s")

	var args []interface{}
	argCount := 1

	adminID := reports.AdminIDFromRequest(req)
	if adminID > 0 {
		var adminSQL string
		adminSQL, args, argCount = reports.AdminFilterSQL(adminID, argCount, args, "r.admin_id", "at.admin_id")
		baseQuery += adminSQL
	}

	for _, f := range req.Filters {
		if f.Field == "admin_id" {
			continue
		}
		var cond string
		var val interface{}

		switch f.Field {
		case "status":
			cond, val = reports.BuildFilterCondition("a.achievement_status_id", f.Operator, argCount, f.Value, true)
		case "achievement_type":
			cond, val = reports.BuildFilterCondition("a.achievement_type_id", f.Operator, argCount, f.Value, true)
		case "researcher_id":
			cond, val = reports.BuildFilterCondition("r.id", f.Operator, argCount, f.Value, true)
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

	// Column totals
	totalsQuery := "SELECT ROUND(COALESCE(SUM(points), 0)::numeric, 1) FROM (" + baseQuery + ") as sub"
	var totalPoints float64
	_ = r.db.QueryRow(totalsQuery, args...).Scan(&totalPoints)

	// Sorting
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
		if err := rows.Scan(&d.ID, &d.Researcher, &d.Achievement, &d.Points, &d.Status); err != nil {
			return nil, 0, nil, err
		}
		data = append(data, d)
	}

	totals := map[string]float64{"points": totalPoints}
	return data, totalCount, totals, nil
}
