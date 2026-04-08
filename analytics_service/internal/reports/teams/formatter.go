package teams

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
	w.Write([]string{"ID", "Название команды", "Руководитель", "Количество участников", "Баллы достижений", "Баллы разработки", "Итоговые баллы"})

	for _, d := range data {
		w.Write([]string{
			fmt.Sprintf("%d", d.ID),
			d.Title,
			d.LeaderName,
			fmt.Sprintf("%d", d.MembersCount),
			fmt.Sprintf("%.1f", d.TotalPoints),
			fmt.Sprintf("%.1f", d.DevPoints),
			fmt.Sprintf("%.1f", d.CombinedPoints),
		})
	}

	w.Write([]string{"ИТОГО", "", "", fmt.Sprintf("%.0f", totals["members_count"]), fmt.Sprintf("%.1f", totals["total_points"]), fmt.Sprintf("%.1f", totals["dev_points"]), fmt.Sprintf("%.1f", totals["combined_points"])})
	w.Flush()
	return []byte(buf.String()), nil
}
