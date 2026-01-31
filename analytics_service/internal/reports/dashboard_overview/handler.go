package dashboard_overview

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
	data, err := h.repo.FetchData(req)
	if err != nil {
		return nil, err
	}

	result, err := h.formatter.ToJSON(data)
	if err != nil {
		return nil, err
	}

	return &pb.ReportResponse{
		Data:   result,
		Format: "json",
	}, nil
}





