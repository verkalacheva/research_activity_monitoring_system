package reports

import (
	"analytics_service/pb"
	"context"
	"database/sql"
	"fmt"
	"strconv"
	"strings"
)

// ReportHandler defines the interface for all reports
type ReportHandler interface {
	Generate(ctx context.Context, req *pb.ReportRequest) (*pb.ReportResponse, error)
}

// SoftDeleteCondition is the default condition for filtering out deleted records
const SoftDeleteCondition = "deleted_at IS NULL"

// AppendSoftDelete adds the soft delete condition to a query
func AppendSoftDelete(query string, alias string) string {
	condition := SoftDeleteCondition
	if alias != "" {
		condition = alias + "." + condition
	}

	if strings.Contains(strings.ToUpper(query), "WHERE") {
		return query + " AND " + condition
	}
	return query + " WHERE " + condition
}

// RowData map for report rows
type RowData map[string]interface{}

// MatchAdminColumn correlates tenant tables in subqueries, e.g. r2.admin_id = t.admin_id.
func MatchAdminColumn(column, reference string) string {
	return fmt.Sprintf(" AND %s = %s.admin_id", column, reference)
}

// AdminIDFromRequest returns tenant admin_id injected by the Rails API.
func AdminIDFromRequest(req *pb.ReportRequest) int64 {
	if req == nil {
		return 0
	}
	for _, f := range req.Filters {
		if f.Field == "admin_id" && strings.TrimSpace(f.Value) != "" {
			if id, err := strconv.ParseInt(f.Value, 10, 64); err == nil && id > 0 {
				return id
			}
		}
	}
	return 0
}

// AdminFilterSQL appends AND column = $N for each column when admin_id is set.
func AdminFilterSQL(adminID int64, argCount int, args []interface{}, columns ...string) (sql string, newArgs []interface{}, newArgCount int) {
	if adminID <= 0 || len(columns) == 0 {
		return "", args, argCount
	}
	parts := make([]string, 0, len(columns))
	for _, col := range columns {
		parts = append(parts, fmt.Sprintf("%s = $%d", col, argCount))
		args = append(args, adminID)
		argCount++
	}
	return " AND " + strings.Join(parts, " AND "), args, argCount
}

// Helper to get SQL operator
func GetOperator(op string) string {
	switch op {
	case "eq":
		return "="
	case "gt":
		return ">"
	case "lt":
		return "<"
	case "contains":
		return "ILIKE"
	case "in":
		return "IN"
	default:
		return "="
	}
}

// BuildFilterCondition builds a SQL condition for a filter.
// isNumeric should be true if the field is numeric (int, float, etc.) to use correct casting for IN.
func BuildFilterCondition(field string, operator string, argCount int, value string, isNumeric bool) (string, interface{}) {
	sqlOp := GetOperator(operator)
	if sqlOp == "ILIKE" {
		return fmt.Sprintf("%s ILIKE $%d", field, argCount), "%" + value + "%"
	}
	if sqlOp == "IN" {
		if isNumeric {
			return fmt.Sprintf("%s = ANY(string_to_array($%d, ',')::bigint[])", field, argCount), value
		}
		return fmt.Sprintf("%s = ANY(string_to_array($%d, ','))", field, argCount), value
	}

	if isNumeric {
		if i, err := strconv.ParseInt(value, 10, 64); err == nil {
			return fmt.Sprintf("%s %s $%d", field, sqlOp, argCount), i
		}
		if f, err := strconv.ParseFloat(value, 64); err == nil {
			return fmt.Sprintf("%s %s $%d", field, sqlOp, argCount), f
		}
	}

	return fmt.Sprintf("%s %s $%d", field, sqlOp, argCount), value
}

// BaseReport contains common dependencies for report handlers
type BaseReport struct {
	DB *sql.DB
}
