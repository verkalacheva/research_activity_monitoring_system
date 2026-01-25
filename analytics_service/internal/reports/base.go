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

// Common model for data rows
type RowData map[string]interface{}

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
