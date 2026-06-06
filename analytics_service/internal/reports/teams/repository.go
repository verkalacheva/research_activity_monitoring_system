package teams

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
	Title          string  `json:"title"`
	LeaderName     string  `json:"leader_name"`
	MembersCount   int     `json:"members_count"`
	TotalPoints    float64 `json:"total_points"`
	DevPoints      float64 `json:"dev_points"`
	CombinedPoints float64 `json:"combined_points"`
}

func (r *Repository) FetchData(req *pb.ReportRequest) ([]DataRow, int32, map[string]float64, error) {
	var args []interface{}
	argCount := 1
	var achievDateCond string

	// Pre-scan: extract submission_date filter so it can be embedded in the
	// achievement points subquery with correct $N param numbers.
	for _, f := range req.Filters {
		if f.Value == "" || f.Field != "submission_date" {
			continue
		}
		dates := strings.Split(f.Value, ",")
		if len(dates) == 2 {
			if dates[0] != "" {
				achievDateCond += fmt.Sprintf(" AND a.submission_date::date >= $%d", argCount)
				args = append(args, dates[0])
				argCount++
			}
			if dates[1] != "" {
				achievDateCond += fmt.Sprintf(" AND a.submission_date::date <= $%d", argCount)
				args = append(args, dates[1])
				argCount++
			}
		}
	}

	baseQuery := "SELECT t.id, t.title, " +
		"TRIM(CONCAT_WS(' ', r.surname, r.name, r.second_name)) as leader_name, " +
		"(SELECT COUNT(*) FROM researchers_teams rt " +
		" JOIN researchers r2 ON r2.id = rt.researcher_id AND r2.deleted_at IS NULL" + reports.MatchAdminColumn("r2.admin_id", "t") +
		" WHERE rt.team_id = t.id) as members_count, " +
		"COALESCE((" +
		"    SELECT ROUND(SUM(a.points)::numeric, 1) " +
		"    FROM achievements a " +
		"    JOIN researcher_achievements ra ON a.id = ra.achievement_id " +
		"    JOIN researchers_teams rt ON ra.researcher_id = rt.researcher_id " +
		"    JOIN researchers r3 ON r3.id = rt.researcher_id AND r3.deleted_at IS NULL" + reports.MatchAdminColumn("r3.admin_id", "t") +
		"    JOIN achievement_types at ON a.achievement_type_id = at.id AND at.deleted_at IS NULL" + reports.MatchAdminColumn("at.admin_id", "t") +
		"    WHERE rt.team_id = t.id" + achievDateCond + " " +
		"      AND a.deleted_at IS NULL " +
		"), 0) as total_points, " +
		"COALESCE((" +
		"    SELECT SUM(dpc.points) FROM team_dev_criteria tdc " +
		"    JOIN dev_project_criteria dpc ON tdc.dev_project_criterion_id = dpc.id" + reports.MatchAdminColumn("dpc.admin_id", "t") +
		"    WHERE tdc.team_id = t.id " +
		"), 0) AS criteria_sum, " +
		"COALESCE((" +
		"    SELECT SUM(rda.count * deat.points) " +
		"    FROM researcher_dev_activities rda " +
		"    JOIN dev_employee_activity_types deat ON rda.dev_employee_activity_type_id = deat.id" + reports.MatchAdminColumn("deat.admin_id", "t") +
		"    WHERE rda.team_id = t.id " +
		"), 0) AS activity_sum " +
		"FROM teams t " +
		"LEFT JOIN researchers r ON t.leader_id = r.id AND (t.leader_id IS NULL OR (r.deleted_at IS NULL AND r.admin_id = t.admin_id))"

	whereParts := []string{"t.deleted_at IS NULL"}

	adminID := reports.AdminIDFromRequest(req)
	if adminID > 0 {
		whereParts = append(whereParts, fmt.Sprintf("t.admin_id = $%d", argCount))
		args = append(args, adminID)
		argCount++
	}

	for _, f := range req.Filters {
		if f.Value == "" || f.Field == "submission_date" || f.Field == "admin_id" {
			continue
		}
		var cond string
		var val interface{}

		switch f.Field {
		case "team_id":
			cond, val = reports.BuildFilterCondition("t.id", f.Operator, argCount, f.Value, true)
		case "leader_id":
			cond, val = reports.BuildFilterCondition("t.leader_id", f.Operator, argCount, f.Value, true)
		default:
			continue
		}

		whereParts = append(whereParts, cond)
		args = append(args, val)
		argCount++
	}

	baseQuery += " WHERE " + strings.Join(whereParts, " AND ")

	// Count total
	countQuery := "SELECT COUNT(*) FROM (" + baseQuery + ") as sub"
	var totalCount int32
	err := r.db.QueryRow(countQuery, args...).Scan(&totalCount)
	if err != nil {
		return nil, 0, nil, err
	}

	// Totals
	totalsQuery := "SELECT ROUND(COALESCE(SUM(total_points), 0)::numeric, 1), COALESCE(SUM(members_count), 0), " +
		"ROUND(COALESCE(SUM(criteria_sum * activity_sum), 0)::numeric, 1) FROM (" + baseQuery + ") as sub"
	var sumPoints float64
	var sumMembers float64
	var sumDevPoints float64
	_ = r.db.QueryRow(totalsQuery, args...).Scan(&sumPoints, &sumMembers, &sumDevPoints)

	// Wrap in CTE to expose dev_points and combined_points for sorting
	cteQuery := fmt.Sprintf(`
		WITH base AS (%s)
		SELECT id, title, leader_name, members_count, total_points,
		       ROUND((criteria_sum * activity_sum)::numeric, 1) AS dev_points,
		       ROUND((total_points + criteria_sum * activity_sum)::numeric, 1) AS combined_points
		FROM base
	`, baseQuery)

	// Sorting
	query := cteQuery
	if len(req.Sorts) > 0 {
		var sortParts []string
		for _, s := range req.Sorts {
			dir := "ASC"
			if s.Descending {
				dir = "DESC"
			}
			field := s.Field
			if field == "id" || field == "t.id" {
				field = "id"
			}
			sortParts = append(sortParts, fmt.Sprintf("%s %s", field, dir))
		}
		if len(sortParts) > 0 {
			query += " ORDER BY " + strings.Join(sortParts, ", ")
		} else {
			query += " ORDER BY title ASC"
		}
	} else {
		query += " ORDER BY title ASC"
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
		if err := rows.Scan(&d.ID, &d.Title, &d.LeaderName, &d.MembersCount, &d.TotalPoints, &d.DevPoints, &d.CombinedPoints); err != nil {
			return nil, 0, nil, err
		}
		data = append(data, d)
	}

	totals := map[string]float64{
		"total_points":    sumPoints,
		"members_count":   sumMembers,
		"dev_points":      sumDevPoints,
		"combined_points": sumPoints + sumDevPoints,
	}
	return data, totalCount, totals, nil
}
