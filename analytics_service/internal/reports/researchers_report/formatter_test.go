//go:build go1.21

package researchers_report

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestFormatterToJSON_Empty(t *testing.T) {
	f := &Formatter{}
	b, err := f.ToJSON(nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if string(b) != "null" {
		t.Errorf("empty slice: got %q, want null", string(b))
	}
}

func TestFormatterToJSON_SingleRow(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{
			ID:             1,
			ResearcherID:   10,
			ResearcherName: "Иванов Иван",
			Achievement:    "Статья",
			Points:         3.0,
			Status:         "ВАК",
			Result:         "Победа",
			Participation:  "Единственный автор",
			DevPoints:      5.5,
		},
	}
	b, err := f.ToJSON(rows)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var decoded []map[string]interface{}
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("json decode: %v", err)
	}
	if len(decoded) != 1 {
		t.Fatalf("expected 1 row, got %d", len(decoded))
	}
	if decoded[0]["researcher_name"] != "Иванов Иван" {
		t.Errorf("researcher_name: got %v", decoded[0]["researcher_name"])
	}
	if decoded[0]["achievement"] != "Статья" {
		t.Errorf("achievement: got %v", decoded[0]["achievement"])
	}
}

func TestFormatterToJSON_MultipleRows(t *testing.T) {
	f := &Formatter{}
	rows := make([]DataRow, 5)
	for i := range rows {
		rows[i] = DataRow{ID: i + 1, ResearcherName: "Name"}
	}
	b, err := f.ToJSON(rows)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var decoded []map[string]interface{}
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("json decode: %v", err)
	}
	if len(decoded) != 5 {
		t.Errorf("expected 5 rows, got %d", len(decoded))
	}
}

func TestFormatterToCSV_Headers(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{ID: 1, ResearcherName: "Петров Пётр", Achievement: "Грант", Points: 5.0},
	}
	totals := map[string]float64{"points": 5.0, "dev_points": 2.0}

	b, err := f.ToCSV(rows, totals)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	csv := string(b)

	if !strings.Contains(csv, "Researcher") {
		t.Error("CSV should contain Researcher header")
	}
	if !strings.Contains(csv, "Баллы достижений") {
		t.Error("CSV should contain points header in Russian")
	}
}

func TestFormatterToCSV_ContainsTotalRow(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{ID: 1, ResearcherID: 1, ResearcherName: "Иванов", Achievement: "Статья", Points: 3.0, DevPoints: 2.0},
	}
	totals := map[string]float64{"points": 3.0, "dev_points": 2.0}

	b, err := f.ToCSV(rows, totals)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	csv := string(b)

	if !strings.Contains(csv, "TOTAL") {
		t.Error("CSV should contain TOTAL row")
	}
	if !strings.Contains(csv, "5.0") {
		t.Error("CSV should contain combined total (3.0 + 2.0 = 5.0)")
	}
}

func TestFormatterToCSV_SubtotalBetweenResearchers(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{ID: 1, ResearcherID: 1, ResearcherName: "Иванов", Achievement: "Статья", Points: 3.0, DevPoints: 1.0},
		{ID: 2, ResearcherID: 1, ResearcherName: "Иванов", Achievement: "Грант", Points: 5.0, DevPoints: 1.0},
		{ID: 3, ResearcherID: 2, ResearcherName: "Петров", Achievement: "Статья", Points: 2.0, DevPoints: 0.5},
	}
	totals := map[string]float64{"points": 10.0, "dev_points": 2.5}

	b, err := f.ToCSV(rows, totals)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	csv := string(b)

	// Should have SUBTOTAL rows between researcher groups
	subtotalCount := strings.Count(csv, "SUBTOTAL")
	if subtotalCount < 2 {
		t.Errorf("expected at least 2 SUBTOTAL rows, got %d in:\n%s", subtotalCount, csv)
	}
}

func TestFormatterToCSV_EmptyData(t *testing.T) {
	f := &Formatter{}
	totals := map[string]float64{"points": 0.0, "dev_points": 0.0}

	b, err := f.ToCSV(nil, totals)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	csv := string(b)

	if !strings.Contains(csv, "TOTAL") {
		t.Error("empty CSV should still have TOTAL row")
	}
}
