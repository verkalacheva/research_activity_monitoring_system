package dashboard_overview

import (
	"encoding/json"
)

type Formatter struct{}

func (f *Formatter) ToJSON(data *DashboardData) ([]byte, error) {
	return json.Marshal(data)
}





