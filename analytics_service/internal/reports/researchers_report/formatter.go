package researchers_report

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"strings"
)

type Formatter struct{}

func (f *Formatter) ToJSON(data []DataRow) ([]byte, error) {
	return json.Marshal(data)
}

func (f *Formatter) ToCSV(data []DataRow, totals map[string]float64) ([]byte, error) {
	var buf strings.Builder
	w := csv.NewWriter(&buf)
	w.Write([]string{"ID", "Researcher", "Achievement", "Баллы достижений", "Status", "Result", "Participation", "Баллы разработки", "Итоговые баллы"})

	var lastResearcherID int
	var researcherSubtotal float64
	var lastDevPoints float64

	for i, d := range data {
		if i > 0 && d.ResearcherID != lastResearcherID {
			combined := researcherSubtotal + lastDevPoints
			w.Write([]string{"", "SUBTOTAL", "", fmt.Sprintf("%.1f", researcherSubtotal), "", "", "", fmt.Sprintf("%.1f", lastDevPoints), fmt.Sprintf("%.1f", combined)})
			researcherSubtotal = 0
		}

		w.Write([]string{
			fmt.Sprintf("%d", d.ID),
			d.ResearcherName,
			d.Achievement,
			fmt.Sprintf("%.1f", d.Points),
			d.Status,
			d.Result,
			d.Participation,
			"",
			"",
		})

		lastResearcherID = d.ResearcherID
		lastDevPoints = d.DevPoints
		researcherSubtotal += d.Points
	}

	if len(data) > 0 {
		combined := researcherSubtotal + lastDevPoints
		w.Write([]string{"", "SUBTOTAL", "", fmt.Sprintf("%.1f", researcherSubtotal), "", "", "", fmt.Sprintf("%.1f", lastDevPoints), fmt.Sprintf("%.1f", combined)})
	}

	totalCombined := totals["points"] + totals["dev_points"]
	w.Write([]string{"TOTAL", "", "", fmt.Sprintf("%.1f", totals["points"]), "", "", "", fmt.Sprintf("%.1f", totals["dev_points"]), fmt.Sprintf("%.1f", totalCombined)})
	w.Flush()
	return []byte(buf.String()), nil
}

