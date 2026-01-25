package reports

import (
	"fmt"
)

type Registry struct {
	handlers map[string]ReportHandler
}

func NewRegistry() *Registry {
	return &Registry{
		handlers: make(map[string]ReportHandler),
	}
}

func (r *Registry) Register(reportType string, handler ReportHandler) {
	r.handlers[reportType] = handler
}

func (r *Registry) GetHandler(reportType string) (ReportHandler, error) {
	handler, ok := r.handlers[reportType]
	if !ok {
		return nil, fmt.Errorf("report type %s not found", reportType)
	}
	return handler, nil
}



