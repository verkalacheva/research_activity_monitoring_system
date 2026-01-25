package achievements_summary

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
	AchievementType string  `json:"achievement_type"`
	Count           int     `json:"count"`
	TotalPoints     float64 `json:"total_points"`
}

func (r *Repository) FetchData(req *pb.ReportRequest) ([]DataRow, int32, map[string]float64, error) {
	baseQuery := "SELECT COALESCE(at.title, ''), COUNT(a.id), ROUND(COALESCE(SUM(a.points), 0)::numeric, 1) " +
		"FROM achievement_types at " +
		"LEFT JOIN achievements a ON at.id = a.achievement_type_id AND a.deleted_at IS NULL "

	whereConditions := []string{"at.deleted_at IS NULL"}
	var args []interface{}
	argCount := 1

	for _, f := range req.Filters {
		var cond string
		var val interface{}

		switch f.Field {
		case "status":
			cond, val = reports.BuildFilterCondition("a.achievement_status_id", f.Operator, argCount, f.Value, true)
		case "achievement_type":
			cond, val = reports.BuildFilterCondition("at.id", f.Operator, argCount, f.Value, true)
		case "submission_date":
			dates := strings.Split(f.Value, ",")
			if len(dates) == 2 && (dates[0] != "" || dates[1] != "") {
				if dates[0] != "" {
					whereConditions = append(whereConditions, fmt.Sprintf("a.submission_date::date >= $%d", argCount))
					args = append(args, dates[0])
					argCount++
				}
				if dates[1] != "" {
					whereConditions = append(whereConditions, fmt.Sprintf("a.submission_date::date <= $%d", argCount))
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

		whereConditions = append(whereConditions, cond)
		args = append(args, val)
		argCount++
	}

	if len(whereConditions) > 0 {
		baseQuery += " WHERE " + strings.Join(whereConditions, " AND ")
	}

	baseQuery += " GROUP BY at.title"

	rows, err := r.db.Query(baseQuery, args...)
	if err != nil {
		return nil, 0, nil, err
	}
	defer rows.Close()

	var data []DataRow
	var totalAllPoints float64
	for rows.Next() {
		var d DataRow
		if err := rows.Scan(&d.AchievementType, &d.Count, &d.TotalPoints); err != nil {
			return nil, 0, nil, err
		}
		data = append(data, d)
		totalAllPoints += d.TotalPoints
	}

	totals := map[string]float64{"total_points": float64(int(totalAllPoints*10+0.5)) / 10}
	return data, int32(len(data)), totals, nil
}
