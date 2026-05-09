//go:build go1.21

package dashboard_overview

import (
	"encoding/json"
	"testing"
)

func TestDashboardFormatterToJSON_Empty(t *testing.T) {
	f := &Formatter{}
	data := &DashboardData{
		TypeDistribution:   []DistributionItem{},
		StatusDistribution: []DistributionItem{},
		TopResearchers:     []ResearcherItem{},
		Dynamics:           []DynamicsItem{},
	}

	b, err := f.ToJSON(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var decoded map[string]interface{}
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("json decode: %v", err)
	}
	if _, ok := decoded["type_distribution"]; !ok {
		t.Error("type_distribution should be present in JSON")
	}
	if _, ok := decoded["top_researchers"]; !ok {
		t.Error("top_researchers should be present in JSON")
	}
}

func TestDashboardFormatterToJSON_WithData(t *testing.T) {
	f := &Formatter{}
	data := &DashboardData{
		TypeDistribution: []DistributionItem{
			{Name: "Статья", Value: 42.0},
			{Name: "Грант", Value: 7.0},
		},
		StatusDistribution: []DistributionItem{
			{Name: "ВАК", Value: 15.0},
		},
		TopResearchers: []ResearcherItem{
			{Name: "Иванов И.", Points: 33.5, AchievementPoints: 30.0, DevPoints: 3.5, TotalPoints: 33.5},
		},
		Dynamics: []DynamicsItem{
			{Date: "2024-01", Value: 5},
			{Date: "2024-02", Value: 3},
		},
	}

	b, err := f.ToJSON(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var decoded map[string]interface{}
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("json decode: %v", err)
	}

	typeDistRaw, ok := decoded["type_distribution"].([]interface{})
	if !ok || len(typeDistRaw) != 2 {
		t.Errorf("type_distribution: expected 2 items, got %v", decoded["type_distribution"])
	}

	topRaw, ok := decoded["top_researchers"].([]interface{})
	if !ok || len(topRaw) != 1 {
		t.Errorf("top_researchers: expected 1 item, got %v", decoded["top_researchers"])
	}

	dynRaw, ok := decoded["dynamics"].([]interface{})
	if !ok || len(dynRaw) != 2 {
		t.Errorf("dynamics: expected 2 items, got %v", decoded["dynamics"])
	}
}

func TestDashboardFormatterToJSON_Roundtrip(t *testing.T) {
	f := &Formatter{}
	original := &DashboardData{
		TypeDistribution: []DistributionItem{{Name: "Публикация", Value: 10.0}},
		TopResearchers:   []ResearcherItem{{Name: "Смирнов С.", TotalPoints: 25.5}},
	}

	b, err := f.ToJSON(original)
	if err != nil {
		t.Fatalf("ToJSON error: %v", err)
	}

	var decoded DashboardData
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if len(decoded.TypeDistribution) != 1 || decoded.TypeDistribution[0].Name != "Публикация" {
		t.Errorf("type_distribution roundtrip failed: %+v", decoded.TypeDistribution)
	}
	if len(decoded.TopResearchers) != 1 || decoded.TopResearchers[0].TotalPoints != 25.5 {
		t.Errorf("top_researchers roundtrip failed: %+v", decoded.TopResearchers)
	}
}
