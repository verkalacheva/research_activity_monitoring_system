//go:build go1.21

package reports

import (
	"analytics_service/pb"
	"context"
	"errors"
	"testing"
)

// stubHandler implements ReportHandler for testing.
type stubHandler struct {
	called bool
	err    error
}

func (s *stubHandler) Generate(_ context.Context, _ *pb.ReportRequest) (*pb.ReportResponse, error) {
	s.called = true
	if s.err != nil {
		return nil, s.err
	}
	return &pb.ReportResponse{Format: "json"}, nil
}

func TestReportsRegistry_RegisterAndGet(t *testing.T) {
	r := NewRegistry()
	h := &stubHandler{}
	r.Register("researchers_report", h)

	got, err := r.GetHandler("researchers_report")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != h {
		t.Error("returned handler is not the registered one")
	}
}

func TestReportsRegistry_GetUnknown(t *testing.T) {
	r := NewRegistry()
	_, err := r.GetHandler("nonexistent")
	if err == nil {
		t.Fatal("expected error for unknown handler, got nil")
	}
}

func TestReportsRegistry_OverwriteHandler(t *testing.T) {
	r := NewRegistry()
	first := &stubHandler{}
	second := &stubHandler{}
	r.Register("teams", first)
	r.Register("teams", second)

	got, err := r.GetHandler("teams")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != second {
		t.Error("expected second handler after overwrite")
	}
}

func TestReportsRegistry_HandlerCalledCorrectly(t *testing.T) {
	r := NewRegistry()
	h := &stubHandler{}
	r.Register("test_report", h)

	handler, _ := r.GetHandler("test_report")
	resp, err := handler.Generate(context.Background(), &pb.ReportRequest{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !h.called {
		t.Error("expected handler to be called")
	}
	if resp.Format != "json" {
		t.Errorf("format: got %q, want json", resp.Format)
	}
}

func TestReportsRegistry_HandlerErrorPropagated(t *testing.T) {
	r := NewRegistry()
	expectedErr := errors.New("db error")
	h := &stubHandler{err: expectedErr}
	r.Register("failing_report", h)

	handler, _ := r.GetHandler("failing_report")
	_, err := handler.Generate(context.Background(), &pb.ReportRequest{})
	if !errors.Is(err, expectedErr) {
		t.Errorf("expected %v, got %v", expectedErr, err)
	}
}
