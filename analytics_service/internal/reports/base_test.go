//go:build go1.21

package reports

import (
	"strings"
	"testing"

	"analytics_service/pb"
)

// ---------------------------------------------------------------------------
// AppendSoftDelete
// ---------------------------------------------------------------------------

func TestAppendSoftDelete(t *testing.T) {
	tests := []struct {
		name  string
		query string
		alias string
		want  string
	}{
		{
			name:  "no WHERE — adds WHERE clause",
			query: "SELECT * FROM researchers",
			alias: "",
			want:  "SELECT * FROM researchers WHERE deleted_at IS NULL",
		},
		{
			name:  "existing WHERE — appends AND",
			query: "SELECT * FROM researchers WHERE name = 'foo'",
			alias: "",
			want:  "SELECT * FROM researchers WHERE name = 'foo' AND deleted_at IS NULL",
		},
		{
			name:  "alias prefix added",
			query: "SELECT * FROM researchers",
			alias: "r",
			want:  "SELECT * FROM researchers WHERE r.deleted_at IS NULL",
		},
		{
			name:  "alias with existing WHERE",
			query: "SELECT * FROM researchers r WHERE r.id > 0",
			alias: "r",
			want:  "SELECT * FROM researchers r WHERE r.id > 0 AND r.deleted_at IS NULL",
		},
		{
			name:  "case-insensitive WHERE detection",
			query: "select * from researchers where id = 1",
			alias: "",
			want:  "select * from researchers where id = 1 AND deleted_at IS NULL",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := AppendSoftDelete(tc.query, tc.alias)
			if got != tc.want {
				t.Errorf("AppendSoftDelete(%q, %q)\n got:  %q\n want: %q", tc.query, tc.alias, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// GetOperator
// ---------------------------------------------------------------------------

func TestGetOperator(t *testing.T) {
	tests := []struct {
		op   string
		want string
	}{
		{"eq", "="},
		{"gt", ">"},
		{"lt", "<"},
		{"contains", "ILIKE"},
		{"in", "IN"},
		{"unknown", "="},
		{"", "="},
	}
	for _, tc := range tests {
		t.Run(tc.op, func(t *testing.T) {
			got := GetOperator(tc.op)
			if got != tc.want {
				t.Errorf("GetOperator(%q) = %q, want %q", tc.op, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// BuildFilterCondition
// ---------------------------------------------------------------------------

func TestBuildFilterCondition(t *testing.T) {
	tests := []struct {
		name      string
		field     string
		operator  string
		argCount  int
		value     string
		isNumeric bool
		wantCond  string
		wantArg   interface{}
	}{
		{
			name:      "equals string",
			field:     "r.name", operator: "eq", argCount: 1, value: "Иван", isNumeric: false,
			wantCond: "r.name = $1", wantArg: "Иван",
		},
		{
			name:      "equals integer",
			field:     "r.id", operator: "eq", argCount: 2, value: "42", isNumeric: true,
			wantCond: "r.id = $2", wantArg: int64(42),
		},
		{
			name:      "equals float",
			field:     "a.points", operator: "eq", argCount: 1, value: "3.5", isNumeric: true,
			wantCond: "a.points = $1", wantArg: float64(3.5),
		},
		{
			name:      "contains produces ILIKE with %",
			field:     "r.name", operator: "contains", argCount: 1, value: "Иван", isNumeric: false,
			wantCond: "r.name ILIKE $1", wantArg: "%Иван%",
		},
		{
			name:      "in operator string",
			field:     "r.name", operator: "in", argCount: 1, value: "A,B,C", isNumeric: false,
			wantCond: "r.name = ANY(string_to_array($1, ','))", wantArg: "A,B,C",
		},
		{
			name:      "in operator numeric",
			field:     "r.id", operator: "in", argCount: 1, value: "1,2,3", isNumeric: true,
			wantCond: "r.id = ANY(string_to_array($1, ',')::bigint[])", wantArg: "1,2,3",
		},
		{
			name:      "gt operator",
			field:     "a.points", operator: "gt", argCount: 3, value: "5", isNumeric: true,
			wantCond: "a.points > $3", wantArg: int64(5),
		},
		{
			name:      "lt operator string field",
			field:     "a.submission_date", operator: "lt", argCount: 1, value: "2024-01-01", isNumeric: false,
			wantCond: "a.submission_date < $1", wantArg: "2024-01-01",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cond, arg := BuildFilterCondition(tc.field, tc.operator, tc.argCount, tc.value, tc.isNumeric)

			if cond != tc.wantCond {
				t.Errorf("condition: got %q, want %q", cond, tc.wantCond)
			}
			if arg != tc.wantArg {
				t.Errorf("arg: got %v (%T), want %v (%T)", arg, arg, tc.wantArg, tc.wantArg)
			}
		})
	}
}

func TestBuildFilterCondition_ContainsPercentWrapping(t *testing.T) {
	cond, arg := BuildFilterCondition("r.degree_level", "contains", 1, "к.т.н", false)
	if !strings.Contains(cond, "ILIKE") {
		t.Errorf("contains should produce ILIKE, got %q", cond)
	}
	s, ok := arg.(string)
	if !ok || s != "%к.т.н%" {
		t.Errorf("arg should be %%к.т.н%%, got %q", s)
	}
}

func TestAdminIDFromRequest(t *testing.T) {
	req := &pb.ReportRequest{
		Filters: []*pb.Filter{{Field: "admin_id", Operator: "eq", Value: "42"}},
	}
	if got := AdminIDFromRequest(req); got != 42 {
		t.Fatalf("AdminIDFromRequest() = %d, want 42", got)
	}
}

func TestAdminFilterSQL(t *testing.T) {
	sql, args, argCount := AdminFilterSQL(7, 1, nil, "t.admin_id", "r.admin_id")
	if sql != " AND t.admin_id = $1 AND r.admin_id = $2" {
		t.Fatalf("unexpected sql: %q", sql)
	}
	if len(args) != 2 || args[0] != int64(7) || args[1] != int64(7) {
		t.Fatalf("unexpected args: %#v", args)
	}
	if argCount != 3 {
		t.Fatalf("argCount = %d, want 3", argCount)
	}
}
