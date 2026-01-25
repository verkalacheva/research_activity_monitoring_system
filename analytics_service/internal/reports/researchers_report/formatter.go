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
	w.Write([]string{"ID", "Researcher", "Achievement", "Points", "Status", "Result", "Participation"})

	var lastResearcherID int
	var researcherSubtotal float64

	for i, d := range data {
		if i > 0 && d.ResearcherID != lastResearcherID {
			// Write subtotal for previous researcher
			w.Write([]string{"", "SUBTOTAL", "", fmt.Sprintf("%.1f", researcherSubtotal), "", "", ""})
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
		})

		lastResearcherID = d.ResearcherID
		researcherSubtotal += d.Points
	}

	if len(data) > 0 {
		w.Write([]string{"", "SUBTOTAL", "", fmt.Sprintf("%.1f", researcherSubtotal), "", "", ""})
	}

	w.Write([]string{"TOTAL", "", "", fmt.Sprintf("%.1f", totals["points"]), "", "", ""})
	w.Flush()
	return []byte(buf.String()), nil
}

