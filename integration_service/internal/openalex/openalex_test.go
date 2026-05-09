//go:build go1.21

package openalex

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAPIBaseFromEnv(t *testing.T) {
	t.Run("default when empty", func(t *testing.T) {
		t.Setenv(EnvOpenAlexAPIBase, "")
		got := APIBaseFromEnv()
		if got != defaultOpenAlexAPIBase {
			t.Errorf("got %q, want %q", got, defaultOpenAlexAPIBase)
		}
	})

	t.Run("trailing slash removed", func(t *testing.T) {
		t.Setenv(EnvOpenAlexAPIBase, "https://custom.openalex.org/")
		got := APIBaseFromEnv()
		if got != "https://custom.openalex.org" {
			t.Errorf("got %q, trailing slash should be stripped", got)
		}
	})

	t.Run("custom value without slash returned verbatim", func(t *testing.T) {
		t.Setenv(EnvOpenAlexAPIBase, "https://custom.openalex.org")
		got := APIBaseFromEnv()
		if got != "https://custom.openalex.org" {
			t.Errorf("got %q", got)
		}
	})
}

// mockWorksPage builds a minimal valid openAlexWorksPage JSON response.
func mockWorksPage(t *testing.T, results []workEntry, nextCursor *string) []byte {
	t.Helper()
	page := openAlexWorksPage{
		Meta:    struct{ NextCursor *string `json:"next_cursor"` }{NextCursor: nextCursor},
		Results: results,
	}
	b, err := json.Marshal(page)
	if err != nil {
		t.Fatalf("marshal mock page: %v", err)
	}
	return b
}

func TestFetchWorks_SinglePage(t *testing.T) {
	work := workEntry{
		Title: "Test Paper",
		Type:  "journal-article",
		Ids: struct {
			Openalex string `json:"openalex"`
			Doi      string `json:"doi"`
		}{Openalex: "W123", Doi: "10.1234/test"},
		PublicationYear: 2023,
		Authorships: []struct {
			Author struct {
				DisplayName string `json:"display_name"`
			} `json:"author"`
		}{
			{Author: struct {
				DisplayName string `json:"display_name"`
			}{DisplayName: "Author One"}},
		},
		PrimaryLocation: struct {
			Source struct {
				DisplayName string `json:"display_name"`
			} `json:"source"`
			LandingPageUrl string `json:"landing_page_url"`
		}{
			Source:         struct{ DisplayName string `json:"display_name"` }{DisplayName: "Nature"},
			LandingPageUrl: "https://doi.org/10.1234/test",
		},
	}

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(mockWorksPage(t, []workEntry{work}, nil))
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), apiBase: srv.URL}
	achievements, err := c.FetchWorks(context.Background(), "A12345678")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(achievements) != 1 {
		t.Fatalf("expected 1 achievement, got %d", len(achievements))
	}
	a := achievements[0]
	if a.Title != "Test Paper" {
		t.Errorf("title: got %q, want %q", a.Title, "Test Paper")
	}
	if a.ExternalId != "10.1234/test" {
		t.Errorf("external_id: got %q, want doi", a.ExternalId)
	}
	if a.AuthorCount != 1 {
		t.Errorf("author_count: got %d, want 1", a.AuthorCount)
	}
	if a.JournalTitle != "Nature" {
		t.Errorf("journal_title: got %q, want %q", a.JournalTitle, "Nature")
	}
	if a.Date != "2023" {
		t.Errorf("date: got %q, want %q", a.Date, "2023")
	}
}

func TestFetchWorks_FallsBackToOpenAlexIDWhenNoDOI(t *testing.T) {
	work := workEntry{
		Title: "No DOI Paper",
		Type:  "preprint",
		Ids: struct {
			Openalex string `json:"openalex"`
			Doi      string `json:"doi"`
		}{Openalex: "W999"},
	}

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(mockWorksPage(t, []workEntry{work}, nil))
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), apiBase: srv.URL}
	achievements, err := c.FetchWorks(context.Background(), "A99999999")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(achievements) != 1 {
		t.Fatalf("expected 1 achievement, got %d", len(achievements))
	}
	if achievements[0].ExternalId != "W999" {
		t.Errorf("expected openalex id fallback, got %q", achievements[0].ExternalId)
	}
}

func TestFetchWorks_EmptyResultSet(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(mockWorksPage(t, nil, nil))
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), apiBase: srv.URL}
	achievements, err := c.FetchWorks(context.Background(), "A00000000")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(achievements) != 0 {
		t.Errorf("expected empty slice, got %d items", len(achievements))
	}
}

func TestFetchWorks_HTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), apiBase: srv.URL}
	_, err := c.FetchWorks(context.Background(), "A12345678")
	if err == nil {
		t.Fatal("expected error on non-200 status, got nil")
	}
}

func TestFetchWorks_PaginationFollowsCursor(t *testing.T) {
	page := 0
	cursors := []*string{strPtr("cursor_page2"), nil}
	pages := [][]workEntry{
		{{Title: "Work 1", Type: "article"}},
		{{Title: "Work 2", Type: "article"}},
	}

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(mockWorksPage(t, pages[page], cursors[page]))
		page++
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), apiBase: srv.URL}
	achievements, err := c.FetchWorks(context.Background(), "A12345678")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(achievements) != 2 {
		t.Errorf("expected 2 achievements across pages, got %d", len(achievements))
	}
}

func TestFetchWorks_OpenAlexURLIDExtracted(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("filter")
		// The ID should be extracted as "A123" (path component)
		if q != "author.id:A123" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write(mockWorksPage(t, nil, nil))
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), apiBase: srv.URL}
	// Pass as URL form; the function should extract path component
	_, err := c.FetchWorks(context.Background(), "https://openalex.org/A123")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func strPtr(s string) *string { return &s }

func TestNewClient(t *testing.T) {
	t.Run("creates client with default base", func(t *testing.T) {
		t.Setenv(EnvOpenAlexAPIBase, "")
		c := NewClient()
		if c == nil {
			t.Fatal("NewClient returned nil")
		}
		if c.apiBase != defaultOpenAlexAPIBase {
			t.Errorf("apiBase: got %q, want %q", c.apiBase, defaultOpenAlexAPIBase)
		}
		if c.httpClient == nil {
			t.Error("httpClient is nil")
		}
	})
}

func TestFetchAchievements_DelegatestoFetchWorks(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(mockWorksPage(t, nil, nil))
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), apiBase: srv.URL}
	result, err := c.FetchAchievements(context.Background(), "A12345678")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(result) != 0 {
		t.Errorf("expected empty result, got %d", len(result))
	}
}
