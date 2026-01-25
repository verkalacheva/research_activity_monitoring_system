package researchers_report

import (
	"analytics_service/pb"
	"context"
	"database/sql"
)

type Handler struct {
	repo      *Repository
	formatter *Formatter
}

func NewHandler(db *sql.DB) *Handler {
	return &Handler{
		repo:      &Repository{db: db},
		formatter: &Formatter{},
	}
}

func (h *Handler) Generate(ctx context.Context, req *pb.ReportRequest) (*pb.ReportResponse, error) {
	data, totalCount, totals, err := h.repo.FetchData(req)
	if err != nil {
		return nil, err
	}

	var result []byte
	if req.Format == "csv" {
		result, err = h.formatter.ToCSV(data, totals)
	} else {
		result, err = h.formatter.ToJSON(data)
	}

	if err != nil {
		return nil, err
	}

	return &pb.ReportResponse{
		Data:         result,
		Format:       req.Format,
		TotalCount:   totalCount,
		ColumnTotals: totals,
	}, nil
}

