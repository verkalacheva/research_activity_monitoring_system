package dev_teams

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
	"team":          true,
	"criteria_sum":  true,
	"criteria_list": true,
	"activity_sum":  true,
	"total_score":   true,
}

func (h *Handler) Generate(ctx context.Context, req *pb.ReportRequest) (*pb.ReportResponse, error) {
	var args []interface{}
	argCount := 1

	outerConds := "t.deleted_at IS NULL"
	var actSubConds string

	adminID := reports.AdminIDFromRequest(req)
	if adminID > 0 {
		var adminSQL string
		adminSQL, args, argCount = reports.AdminFilterSQL(adminID, argCount, args, "t.admin_id")
		outerConds += adminSQL
	}

	for _, f := range req.Filters {
		if f.Value == "" || f.Field == "admin_id" {
			continue
		}
		switch f.Field {
		case "team_id":
			outerConds += fmt.Sprintf(" AND t.id = $%d", argCount)
			args = append(args, f.Value)
			argCount++
		case "activity_date":
			dates := strings.Split(f.Value, ",")
			if len(dates) == 2 {
				if dates[0] != "" {
					actSubConds += fmt.Sprintf(" AND rda.date >= $%d", argCount)
					args = append(args, dates[0])
					argCount++
				}
				if dates[1] != "" {
					actSubConds += fmt.Sprintf(" AND rda.date <= $%d", argCount)
					args = append(args, dates[1])
					argCount++
				}
			}
		}
	}

	// actSubConds is injected into the activity subquery so that date filtering
	// is applied consistently when computing team activity totals.
	baseQuery := fmt.Sprintf(`
		SELECT
			t.title AS team,
			COALESCE(SUM(dpc.points), 0) AS criteria_sum,
			COALESCE(ARRAY_TO_STRING(ARRAY_AGG(DISTINCT dpc.title), ', '), '') AS criteria_list,
			(
				SELECT COALESCE(SUM(rda.count * deat.points), 0)
				FROM researcher_dev_activities rda
				JOIN dev_employee_activity_types deat ON rda.dev_employee_activity_type_id = deat.id%s
				WHERE rda.team_id = t.id%s
			) AS activity_sum
		FROM teams t
		LEFT JOIN team_dev_criteria tdc ON t.id = tdc.team_id
		LEFT JOIN dev_project_criteria dpc ON tdc.dev_project_criterion_id = dpc.id%s
		WHERE %s
		GROUP BY t.id, t.title
	`, reports.MatchAdminColumn("deat.admin_id", "t"), actSubConds, reports.MatchAdminColumn("dpc.admin_id", "t"), outerConds)

	countQuery := "SELECT COUNT(*) FROM (" + baseQuery + ") AS sub"
	var totalCount int32
	if err := h.db.QueryRowContext(ctx, countQuery, args...).Scan(&totalCount); err != nil {
		return nil, err
	}

	// Wrap in CTE so total_score (criteria_sum * activity_sum) is available for sorting.
	query := fmt.Sprintf(`
		WITH base AS (%s)
		SELECT team, criteria_sum, criteria_list, activity_sum,
		       criteria_sum * activity_sum AS total_score
		FROM base
	`, baseQuery)

	if len(req.Sorts) > 0 {
		var sortParts []string
		for _, s := range req.Sorts {
			if allowedSorts[s.Field] {
				dir := "ASC"
				if s.Descending {
					dir = "DESC"
				}
				sortParts = append(sortParts, fmt.Sprintf("%s %s", s.Field, dir))
			}
		}
		if len(sortParts) > 0 {
			query += " ORDER BY " + strings.Join(sortParts, ", ")
		} else {
			query += " ORDER BY team ASC"
		}
	} else {
		query += " ORDER BY team ASC"
	}

	limit := req.Limit
	if limit <= 0 {
		limit = 20
	}
	query += fmt.Sprintf(" LIMIT %d OFFSET %d", limit, req.Offset)

	rows, err := h.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []map[string]interface{}
	var totalCriteria, totalActivity float64

	for rows.Next() {
		var team, criteriaList string
		var criteriaSum, activitySum, totalScore float64
		if err := rows.Scan(&team, &criteriaSum, &criteriaList, &activitySum, &totalScore); err != nil {
			return nil, err
		}
		results = append(results, map[string]interface{}{
			"team":          team,
			"criteria_sum":  criteriaSum,
			"criteria_list": criteriaList,
			"activity_sum":  activitySum,
			"total_score":   totalScore,
		})
		totalCriteria += criteriaSum
		totalActivity += activitySum
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
			"criteria_sum": totalCriteria,
			"activity_sum": totalActivity,
		},
	}, nil
}
