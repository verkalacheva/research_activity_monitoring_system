package dev_researchers

import (
	"analytics_service/internal/reports"
	"analytics_service/pb"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
)

type Handler struct {
	db *sql.DB
}

func NewHandler(db *sql.DB) *Handler {
	return &Handler{db: db}
}

var allowedSorts = map[string]bool{
	"researcher":      true,
	"team":            true,
	"activity_type":   true,
	"activity_points": true,
	"criteria_sum":    true,
	"dev_points":      true,
}

func (h *Handler) Generate(ctx context.Context, req *pb.ReportRequest) (*pb.ReportResponse, error) {
	var args []interface{}
	argCount := 1

	// WHERE conditions for base tables (researcher, team filters + soft-delete).
	outerConds := " AND r.deleted_at IS NULL AND t.deleted_at IS NULL"
	adminID := reports.AdminIDFromRequest(req)
	if adminID > 0 {
		var adminSQL string
		adminSQL, args, argCount = reports.AdminFilterSQL(adminID, argCount, args, "r.admin_id", "t.admin_id")
		outerConds += adminSQL
	}
	// JOIN conditions for LEFT JOIN on rda (date range must go here so that
	// researchers without activities in the range still appear).
	var rdaJoinConds string
	// Conditions for the correlated total_activity_sum subquery.
	var actSubConds string

	for _, f := range req.Filters {
		if f.Value == "" || f.Field == "admin_id" {
			continue
		}
		switch f.Field {
		case "team_id":
			outerConds += fmt.Sprintf(" AND t.id = $%d", argCount)
			args = append(args, f.Value)
			argCount++
		case "researcher_id":
			outerConds += fmt.Sprintf(" AND r.id = $%d", argCount)
			args = append(args, f.Value)
			argCount++
		case "activity_date":
			dates := strings.Split(f.Value, ",")
			if len(dates) == 2 {
				if dates[0] != "" {
					rdaJoinConds += fmt.Sprintf(" AND rda.date >= $%d", argCount)
					actSubConds += fmt.Sprintf(" AND rda2.date >= $%d", argCount)
					args = append(args, dates[0])
					argCount++
				}
				if dates[1] != "" {
					rdaJoinConds += fmt.Sprintf(" AND rda.date <= $%d", argCount)
					actSubConds += fmt.Sprintf(" AND rda2.date <= $%d", argCount)
					args = append(args, dates[1])
					argCount++
				}
			}
		}
	}

	// One row per unique researcher+team+activity_type combination.
	// Researchers who are team members but have no matching activities still
	// appear (with zero counts) because we start from researchers_teams and
	// LEFT JOIN activities.
	baseQuery := fmt.Sprintf(`
		SELECT
			r.id AS researcher_id,
			r.surname || ' ' || r.name || ' ' || COALESCE(r.second_name, '') AS researcher,
			t.title AS team,
			COALESCE(deat.title, '') AS activity_type,
			COALESCE(SUM(rda.count), 0) AS count,
			COALESCE(deat.points, 0) AS type_points,
			COALESCE(SUM(rda.count) * deat.points, 0) AS activity_points,
			(
				SELECT COALESCE(SUM(dpc2.points), 0)
				FROM team_dev_criteria tdc2
				JOIN dev_project_criteria dpc2 ON tdc2.dev_project_criterion_id = dpc2.id%s
				WHERE tdc2.team_id = t.id
			) AS criteria_sum,
			(
				SELECT COALESCE(SUM(rda2.count * deat2.points), 0)
				FROM researcher_dev_activities rda2
				JOIN dev_employee_activity_types deat2 ON rda2.dev_employee_activity_type_id = deat2.id%s
				WHERE rda2.researcher_id = r.id AND rda2.team_id = t.id%s
			) AS total_activity_sum
		FROM researchers r
		JOIN researchers_teams rt ON rt.researcher_id = r.id
		JOIN teams t ON rt.team_id = t.id%s
		LEFT JOIN researcher_dev_activities rda
			ON rda.researcher_id = r.id AND rda.team_id = t.id%s
		LEFT JOIN dev_employee_activity_types deat
			ON deat.id = rda.dev_employee_activity_type_id%s
		WHERE 1=1%s
		GROUP BY r.id, r.surname, r.name, r.second_name, t.id, t.title, deat.id, deat.title, deat.points
	`, reports.MatchAdminColumn("dpc2.admin_id", "t"), reports.MatchAdminColumn("deat2.admin_id", "r"), actSubConds,
		reports.MatchAdminColumn("t.admin_id", "r"), rdaJoinConds, reports.MatchAdminColumn("deat.admin_id", "t"), outerConds)

	// Count distinct researcher+team groups (not individual rows) so that
	// pagination controls reflect the number of researchers, not activity rows.
	groupCountQuery := fmt.Sprintf(`
		WITH base AS (%s)
		SELECT COUNT(*) FROM (SELECT DISTINCT researcher_id, team FROM base) AS _gc
	`, baseQuery)
	var totalCount int32
	if err := h.db.QueryRowContext(ctx, groupCountQuery, args...).Scan(&totalCount); err != nil {
		return nil, err
	}

	// Sum dev_points once per researcher+team group to avoid double-counting.
	totalsQuery := fmt.Sprintf(`
		WITH base AS (%s)
		SELECT COALESCE(SUM(dp), 0)
		FROM (
			SELECT MAX(criteria_sum) * MAX(total_activity_sum) AS dp
			FROM base
			GROUP BY researcher_id, team
		) AS grouped
	`, baseQuery)
	var totalDevPoints float64
	_ = h.db.QueryRowContext(ctx, totalsQuery, args...).Scan(&totalDevPoints)

	// Determine sort expressions.
	// groupSortExpr: used in group_page to order researcher groups.
	// fullSortExpr:  used in the final SELECT to order individual rows within groups.
	groupSortExpr := "researcher ASC, team ASC"
	fullSortExpr := "researcher ASC, team ASC, activity_type ASC"
	if len(req.Sorts) > 0 {
		for _, s := range req.Sorts {
			if !allowedSorts[s.Field] {
				continue
			}
			dir := "ASC"
			if s.Descending {
				dir = "DESC"
			}
			switch s.Field {
			case "dev_points":
				groupSortExpr = fmt.Sprintf("dev_points %s, researcher ASC, team ASC", dir)
				fullSortExpr = fmt.Sprintf("dev_points %s, researcher ASC, team ASC, activity_type ASC", dir)
			case "criteria_sum":
				groupSortExpr = fmt.Sprintf("criteria_sum %s, researcher ASC, team ASC", dir)
				fullSortExpr = fmt.Sprintf("criteria_sum %s, researcher ASC, team ASC, activity_type ASC", dir)
			case "researcher":
				groupSortExpr = fmt.Sprintf("researcher %s, team ASC", dir)
				fullSortExpr = fmt.Sprintf("researcher %s, team ASC, activity_type ASC", dir)
			case "team":
				groupSortExpr = fmt.Sprintf("team %s, researcher ASC", dir)
				fullSortExpr = fmt.Sprintf("team %s, researcher ASC, activity_type ASC", dir)
		case "activity_points":
			// Sort groups by their total activity sum; rows within each group follow the same direction.
			groupSortExpr = fmt.Sprintf("total_activity_sum %s, researcher ASC, team ASC", dir)
			fullSortExpr = fmt.Sprintf("total_activity_sum %s, researcher ASC, team ASC, activity_points %s", dir, dir)
		default:
			groupSortExpr = "researcher ASC, team ASC"
			fullSortExpr = fmt.Sprintf("researcher ASC, team ASC, %s %s", s.Field, dir)
		}
			break
		}
	}

	limit := req.Limit
	if limit <= 0 {
		limit = 20
	}

	// Group-aware pagination: first select N researcher+team groups via group_page,
	// then return all activity rows that belong to those groups. This prevents
	// researcher groups from being split across page boundaries.
	query := fmt.Sprintf(`
		WITH base AS (%s),
		computed AS (
			SELECT researcher_id, researcher, team, activity_type, count, type_points,
			       activity_points, criteria_sum, total_activity_sum,
			       criteria_sum * total_activity_sum AS dev_points
			FROM base
		),
		group_page AS (
			SELECT researcher_id, team
			FROM (
			SELECT researcher_id, team,
			       MAX(researcher)           AS researcher,
			       MAX(dev_points)           AS dev_points,
			       MAX(criteria_sum)         AS criteria_sum,
			       MAX(total_activity_sum)   AS total_activity_sum
			FROM computed
			GROUP BY researcher_id, team
			) AS grp
			ORDER BY %s
			LIMIT %d OFFSET %d
		)
		SELECT c.researcher_id, c.researcher, c.team, c.activity_type,
		       c.count, c.type_points, c.activity_points, c.criteria_sum,
		       c.total_activity_sum, c.dev_points
		FROM computed c
		INNER JOIN group_page gp ON c.researcher_id = gp.researcher_id AND c.team = gp.team
		ORDER BY %s
	`, baseQuery, groupSortExpr, limit, req.Offset, fullSortExpr)

	rows, err := h.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []map[string]interface{}

	for rows.Next() {
		var researcherID int
		var researcher, team, activityType string
		var count int
		var typePoints, activityPoints, criteriaSum, totalActivitySum, devPoints float64

		if err := rows.Scan(
			&researcherID, &researcher, &team, &activityType,
			&count, &typePoints, &activityPoints,
			&criteriaSum, &totalActivitySum, &devPoints,
		); err != nil {
			return nil, err
		}

		results = append(results, map[string]interface{}{
			"researcher_id":      researcherID,
			"researcher":         researcher,
			"team":               team,
			"activity_type":      activityType,
			"count":              count,
			"type_points":        typePoints,
			"activity_points":    activityPoints,
			"criteria_sum":       criteriaSum,
			"total_activity_sum": totalActivitySum,
			"dev_points":         devPoints,
		})
	}

	jsonData, err := json.Marshal(results)
	if err != nil {
		return nil, err
	}

	return &pb.ReportResponse{
		Data:       jsonData,
		Format:     "json",
		TotalCount: totalCount,
		ColumnTotals: map[string]float64{
			"dev_points": totalDevPoints,
		},
	}, nil
}
