//go:build go1.21

package teams

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestTeamsFormatterToJSON_Empty(t *testing.T) {
	f := &Formatter{}
	b, err := f.ToJSON(nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if string(b) != "null" {
		t.Errorf("empty: got %q, want null", string(b))
	}
}

func TestTeamsFormatterToJSON_SingleRow(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{
			ID:             1,
			Title:          "Команда А",
			LeaderName:     "Иванов Иван",
			MembersCount:   5,
			TotalPoints:    10.5,
			DevPoints:      3.2,
			CombinedPoints: 13.7,
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
	if decoded[0]["title"] != "Команда А" {
		t.Errorf("title: got %v", decoded[0]["title"])
	}
	if decoded[0]["leader_name"] != "Иванов Иван" {
		t.Errorf("leader_name: got %v", decoded[0]["leader_name"])
	}
}

func TestTeamsFormatterToJSON_MultipleRows(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{ID: 1, Title: "Команда А"},
		{ID: 2, Title: "Команда Б"},
		{ID: 3, Title: "Команда В"},
	}
	b, err := f.ToJSON(rows)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var decoded []map[string]interface{}
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("json decode: %v", err)
	}
	if len(decoded) != 3 {
		t.Errorf("expected 3 rows, got %d", len(decoded))
	}
}

func TestTeamsFormatterToCSV_Headers(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{ID: 1, Title: "Команда А", LeaderName: "Иванов", MembersCount: 3, TotalPoints: 5.0, DevPoints: 2.0, CombinedPoints: 7.0},
	}
	totals := map[string]float64{
		"members_count":   3.0,
		"total_points":    5.0,
		"dev_points":      2.0,
		"combined_points": 7.0,
	}
	b, err := f.ToCSV(rows, totals)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	csv := string(b)

	if !strings.Contains(csv, "Название команды") {
		t.Error("CSV should contain team name header")
	}
	if !strings.Contains(csv, "Руководитель") {
		t.Error("CSV should contain leader header")
	}
	if !strings.Contains(csv, "Итоговые баллы") {
		t.Error("CSV should contain total points header")
	}
}

func TestTeamsFormatterToCSV_TotalsRow(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{ID: 1, Title: "Команда А", LeaderName: "Иванов", MembersCount: 3, TotalPoints: 5.0, DevPoints: 2.0, CombinedPoints: 7.0},
		{ID: 2, Title: "Команда Б", LeaderName: "Петров", MembersCount: 4, TotalPoints: 6.0, DevPoints: 1.0, CombinedPoints: 7.0},
	}
	totals := map[string]float64{
		"members_count":   7.0,
		"total_points":    11.0,
		"dev_points":      3.0,
		"combined_points": 14.0,
	}
	b, err := f.ToCSV(rows, totals)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	csv := string(b)

	if !strings.Contains(csv, "ИТОГО") {
		t.Error("CSV should contain ИТОГО row")
	}
	if !strings.Contains(csv, "11.0") {
		t.Error("CSV should contain total_points sum")
	}
	if !strings.Contains(csv, "Команда А") {
		t.Error("CSV should contain first team name")
	}
}

func TestTeamsFormatterToCSV_EmptyData(t *testing.T) {
	f := &Formatter{}
	totals := map[string]float64{
		"members_count": 0, "total_points": 0, "dev_points": 0, "combined_points": 0,
	}
	b, err := f.ToCSV(nil, totals)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(string(b), "ИТОГО") {
		t.Error("empty CSV should still have ИТОГО row")
	}
}

func TestTeamsFormatterToCSV_FormatsNumbers(t *testing.T) {
	f := &Formatter{}
	rows := []DataRow{
		{ID: 42, Title: "Т", LeaderName: "Л", MembersCount: 7, TotalPoints: 12.5, DevPoints: 3.7, CombinedPoints: 16.2},
	}
	totals := map[string]float64{"members_count": 7, "total_points": 12.5, "dev_points": 3.7, "combined_points": 16.2}
	b, _ := f.ToCSV(rows, totals)
	csv := string(b)
	if !strings.Contains(csv, "42") {
		t.Error("should contain team ID")
	}
	if !strings.Contains(csv, "12.5") {
		t.Error("should contain formatted total_points")
	}
	if !strings.Contains(csv, "7") {
		t.Error("should contain member count")
	}
}
