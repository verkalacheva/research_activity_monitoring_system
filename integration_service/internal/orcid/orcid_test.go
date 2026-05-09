//go:build go1.21

package orcid

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNormalizeOrcidID(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			name:  "canonical bare id",
			input: "0000-0001-2345-6789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "uppercase X check digit",
			input: "0000-0001-2345-678X",
			want:  "0000-0001-2345-678x",
		},
		{
			name:  "https orcid.org prefix stripped",
			input: "https://orcid.org/0000-0001-2345-6789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "http orcid.org prefix stripped",
			input: "http://orcid.org/0000-0001-2345-6789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "https www.orcid.org prefix stripped",
			input: "https://www.orcid.org/0000-0001-2345-6789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "sandbox prefix stripped",
			input: "https://sandbox.orcid.org/0000-0001-2345-6789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "trailing slash stripped",
			input: "0000-0001-2345-6789/",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "em dash replaced",
			input: "0000\u20130001\u20132345\u20136789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "unicode minus replaced",
			input: "0000\u22120001\u22122345\u22126789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "BOM prefix stripped",
			input: "\uFEFF0000-0001-2345-6789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "spaces inside removed",
			input: "0000 0001 2345 6789",
			want:  "0000-0001-2345-6789",
		},
		{
			name:  "empty string returns empty",
			input: "",
			want:  "",
		},
		{
			name:  "invalid format returns empty",
			input: "not-an-orcid",
			want:  "",
		},
		{
			name:  "too short returns empty",
			input: "0000-0001-2345",
			want:  "",
		},
		{
			name:  "ORCID embedded in longer text",
			input: "Author: 0000-0001-2345-6789, work",
			want:  "0000-0001-2345-6789",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := NormalizeOrcidID(tc.input)
			if got != tc.want {
				t.Errorf("NormalizeOrcidID(%q) = %q, want %q", tc.input, got, tc.want)
			}
		})
	}
}

func TestPubAPIBaseFromEnv(t *testing.T) {
	t.Run("default when env unset", func(t *testing.T) {
		t.Setenv(EnvOrcidPubAPIBase, "")
		got := PubAPIBaseFromEnv()
		if got != defaultOrcidPubAPIBase {
			t.Errorf("got %q, want %q", got, defaultOrcidPubAPIBase)
		}
	})

	t.Run("custom value without trailing slash", func(t *testing.T) {
		t.Setenv(EnvOrcidPubAPIBase, "https://pub.sandbox.orcid.org/v3.0/")
		got := PubAPIBaseFromEnv()
		if got != "https://pub.sandbox.orcid.org/v3.0" {
			t.Errorf("got %q, want trailing slash stripped", got)
		}
	})

	t.Run("custom value without slash kept as-is", func(t *testing.T) {
		t.Setenv(EnvOrcidPubAPIBase, "https://pub.sandbox.orcid.org/v3.0")
		got := PubAPIBaseFromEnv()
		if got != "https://pub.sandbox.orcid.org/v3.0" {
			t.Errorf("got %q", got)
		}
	})
}

func TestNewClient(t *testing.T) {
	c := NewClient()
	if c == nil {
		t.Fatal("expected non-nil client")
	}
	if c.httpClient == nil {
		t.Fatal("expected non-nil httpClient")
	}
	if c.pubAPIBase == "" {
		t.Fatal("expected non-empty pubAPIBase")
	}
}

// mockOrcidSummary builds a minimal ORCID summary JSON response.
func mockOrcidSummary(t *testing.T, putCodes []int64) []byte {
	t.Helper()
	type workSummary struct {
		PutCode int64 `json:"put-code"`
	}
	type group struct {
		WorkSummary []workSummary `json:"work-summary"`
	}
	type response struct {
		Group []group `json:"group"`
	}
	var groups []group
	for _, pc := range putCodes {
		groups = append(groups, group{WorkSummary: []workSummary{{PutCode: pc}}})
	}
	b, err := json.Marshal(response{Group: groups})
	if err != nil {
		t.Fatalf("marshal summary: %v", err)
	}
	return b
}

// mockOrcidDetail builds a minimal ORCID bulk detail JSON response.
func mockOrcidDetail(t *testing.T, titles []string) []byte {
	t.Helper()
	type titleInner struct {
		Value string `json:"value"`
	}
	type titleOuter struct {
		Title titleInner `json:"title"`
	}
	type work struct {
		Title            titleOuter  `json:"title"`
		Type             string      `json:"type"`
		ShortDescription string      `json:"short-description"`
	}
	type item struct {
		Work work `json:"work"`
	}
	type response struct {
		Bulk []item `json:"bulk"`
	}
	var items []item
	for _, title := range titles {
		items = append(items, item{Work: work{
			Title: titleOuter{Title: titleInner{Value: title}},
			Type:  "journal-article",
		}})
	}
	b, err := json.Marshal(response{Bulk: items})
	if err != nil {
		t.Fatalf("marshal detail: %v", err)
	}
	return b
}

func TestFetchWorks_InvalidOrcid(t *testing.T) {
	c := &Client{httpClient: http.DefaultClient, pubAPIBase: "https://pub.orcid.org/v3.0"}
	_, err := c.FetchWorks("not-valid-orcid")
	if err == nil {
		t.Fatal("expected error for invalid ORCID, got nil")
	}
}

func TestFetchWorks_SingleWork(t *testing.T) {
	callCount := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if callCount == 0 {
			w.Write(mockOrcidSummary(t, []int64{123}))
		} else {
			w.Write(mockOrcidDetail(t, []string{"Test Paper"}))
		}
		callCount++
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), pubAPIBase: srv.URL}
	achievements, err := c.FetchWorks("0000-0001-2345-6789")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(achievements) != 1 {
		t.Fatalf("expected 1 achievement, got %d", len(achievements))
	}
	if achievements[0].Title != "Test Paper" {
		t.Errorf("title: got %q, want %q", achievements[0].Title, "Test Paper")
	}
}

func TestFetchWorks_EmptyPutCodes(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		// Return empty groups → no put codes
		w.Write(mockOrcidSummary(t, nil))
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), pubAPIBase: srv.URL}
	achievements, err := c.FetchWorks("0000-0001-2345-6789")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if achievements != nil {
		t.Errorf("expected nil achievements for empty put codes, got %v", achievements)
	}
}

func TestFetchWorks_404Response(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), pubAPIBase: srv.URL}
	achievements, err := c.FetchWorks("0000-0001-2345-6789")
	if err != nil {
		t.Fatalf("unexpected error on 404 (should return empty): %v", err)
	}
	if len(achievements) != 0 {
		t.Errorf("expected 0 achievements on 404, got %d", len(achievements))
	}
}

func TestFetchWorks_SummaryHTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), pubAPIBase: srv.URL}
	_, err := c.FetchWorks("0000-0001-2345-6789")
	if err == nil {
		t.Fatal("expected error on 500, got nil")
	}
}

func TestFetchWorks_DetailHTTPError(t *testing.T) {
	callCount := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if callCount == 0 {
			w.Write(mockOrcidSummary(t, []int64{1}))
		} else {
			w.WriteHeader(http.StatusInternalServerError)
		}
		callCount++
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), pubAPIBase: srv.URL}
	_, err := c.FetchWorks("0000-0001-2345-6789")
	if err == nil {
		t.Fatal("expected error on detail 500, got nil")
	}
}

func TestFetchAchievements_DelegatesToFetchWorks(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(mockOrcidSummary(t, nil))
	}))
	defer srv.Close()

	c := &Client{httpClient: srv.Client(), pubAPIBase: srv.URL}
	// FetchAchievements delegates to FetchWorks
	achievements, err := c.FetchAchievements(context.Background(), "0000-0001-2345-6789")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if achievements != nil {
		t.Errorf("expected nil for empty put codes, got %v", achievements)
	}
}
