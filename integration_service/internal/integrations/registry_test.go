//go:build go1.21

package integrations

import (
	"context"
	"testing"

	"integration_service/pb"
)

// stubProvider implements Provider for test purposes.
type stubProvider struct {
	name         string
	achievements []*pb.Achievement
	err          error
}

func (s *stubProvider) FetchAchievements(_ context.Context, _ string) ([]*pb.Achievement, error) {
	return s.achievements, s.err
}

func TestRegistry_RegisterAndGet(t *testing.T) {
	r := NewRegistry()

	p := &stubProvider{name: "orcid"}
	r.Register("orcid", p)

	got, err := r.GetProvider("orcid")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != p {
		t.Error("returned provider is not the registered one")
	}
}

func TestRegistry_GetUnknownProvider(t *testing.T) {
	r := NewRegistry()

	_, err := r.GetProvider("nonexistent")
	if err == nil {
		t.Fatal("expected error for unknown provider, got nil")
	}
}

func TestRegistry_OverwriteProvider(t *testing.T) {
	r := NewRegistry()

	first := &stubProvider{name: "first"}
	second := &stubProvider{name: "second"}

	r.Register("orcid", first)
	r.Register("orcid", second)

	got, err := r.GetProvider("orcid")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != second {
		t.Error("re-registering should overwrite; expected second provider")
	}
}

func TestRegistry_MultipleProviders(t *testing.T) {
	r := NewRegistry()
	r.Register("orcid", &stubProvider{name: "orcid"})
	r.Register("openalex", &stubProvider{name: "openalex"})

	if _, err := r.GetProvider("orcid"); err != nil {
		t.Errorf("orcid: %v", err)
	}
	if _, err := r.GetProvider("openalex"); err != nil {
		t.Errorf("openalex: %v", err)
	}
	if _, err := r.GetProvider("github"); err == nil {
		t.Error("github should not be found")
	}
}

func TestRegistry_EmptyRegistry(t *testing.T) {
	r := NewRegistry()
	if r.providers == nil {
		t.Error("providers map should be initialized")
	}
}
