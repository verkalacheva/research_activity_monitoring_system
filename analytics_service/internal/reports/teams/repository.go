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
	ID           int     `json:"id"`
	Title        string  `json:"title"`
	LeaderName   string  `json:"leader_name"`
	MembersCount int     `json:"members_count"`
	TotalPoints  float64 `json:"total_points"`
}

func (r *Repository) FetchData(req *pb.ReportRequest) ([]DataRow, int32, map[string]float64, error) {
	baseQuery := "SELECT t.id, t.title, " +
		"TRIM(CONCAT_WS(' ', r.surname, r.name, r.second_name)) as leader_name, " +
		"(SELECT COUNT(*) FROM researchers_teams rt WHERE rt.team_id = t.id) as members_count, " +
		"COALESCE(( " +
		"    SELECT ROUND(SUM(a.points)::numeric, 1) " +
		"    FROM achievements a " +
		"    JOIN researcher_achievements ra ON a.id = ra.achievement_id " +
		"    JOIN researchers_teams rt ON ra.researcher_id = rt.researcher_id " +
		"    WHERE rt.team_id = t.id " +
		"), 0) as total_points " +
		"FROM teams t " +
		"LEFT JOIN researchers r ON t.leader_id = r.id"

	baseQuery = reports.AppendSoftDelete(baseQuery, "t")
	baseQuery = reports.AppendSoftDelete(baseQuery, "r")

	var args []interface{}
	argCount := 1
	whereAdded := false

	for _, f := range req.Filters {
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

		if !whereAdded {
			baseQuery += " WHERE "
			whereAdded = true
		} else {
			baseQuery += " AND "
		}
		baseQuery += cond
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

	// Totals
	totalsQuery := "SELECT ROUND(COALESCE(SUM(total_points), 0)::numeric, 1), COALESCE(SUM(members_count), 0) FROM (" + baseQuery + ") as sub"
	var sumPoints float64
	var sumMembers float64
	_ = r.db.QueryRow(totalsQuery, args...).Scan(&sumPoints, &sumMembers)

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
			field := s.Field
			// Map frontend field names to backend if necessary
			if field == "id" {
				field = "t.id"
			}
			sortParts = append(sortParts, fmt.Sprintf("%s %s", field, dir))
		}
		query += strings.Join(sortParts, ", ")
	} else {
		query += " ORDER BY t.title ASC"
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
		if err := rows.Scan(&d.ID, &d.Title, &d.LeaderName, &d.MembersCount, &d.TotalPoints); err != nil {
			return nil, 0, nil, err
		}
		data = append(data, d)
	}

	totals := map[string]float64{
		"total_points":  sumPoints,
		"members_count": sumMembers,
	}
	return data, totalCount, totals, nil
}
