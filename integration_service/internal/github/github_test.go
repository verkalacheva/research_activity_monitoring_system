//go:build go1.21

package github

import (
	"context"
	"fmt"
	"testing"

	gogithub "github.com/google/go-github/v60/github"

	"integration_service/internal/testdb"
)

// ---------------------------------------------------------------------------
// repoFromURL
// ---------------------------------------------------------------------------

func TestRepoFromURL(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"full html url", "https://github.com/owner/repo", "owner/repo"},
		{"with trailing path", "https://github.com/owner/repo/pull/42", "owner/repo"},
		{"already owner/repo", "owner/repo", "owner/repo"},
		{"single segment", "owner", "owner"},
		{"empty string", "", ""},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := repoFromURL(tc.input)
			if got != tc.want {
				t.Errorf("repoFromURL(%q) = %q, want %q", tc.input, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// firstLine
// ---------------------------------------------------------------------------

func TestFirstLine(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"single line", "Hello World", "Hello World"},
		{"multi line", "First\nSecond\nThird", "First"},
		{"starts with newline", "\nSecond", ""},
		{"empty string", "", ""},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := firstLine(tc.input)
			if got != tc.want {
				t.Errorf("firstLine(%q) = %q, want %q", tc.input, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// isRateLimitError
// ---------------------------------------------------------------------------

func TestIsRateLimitError(t *testing.T) {
	t.Run("nil error", func(t *testing.T) {
		if isRateLimitError(nil) {
			t.Error("nil should not be a rate limit error")
		}
	})
	t.Run("rate limit error", func(t *testing.T) {
		err := &gogithub.RateLimitError{}
		if !isRateLimitError(err) {
			t.Error("RateLimitError should be detected")
		}
	})
	t.Run("abuse rate limit error", func(t *testing.T) {
		err := &gogithub.AbuseRateLimitError{}
		if !isRateLimitError(err) {
			t.Error("AbuseRateLimitError should be detected")
		}
	})
	t.Run("generic error", func(t *testing.T) {
		if isRateLimitError(fmt.Errorf("some error")) {
			t.Error("generic error should not be a rate limit error")
		}
	})
}

// ---------------------------------------------------------------------------
// setCriterion
// ---------------------------------------------------------------------------

func TestSetCriterion(t *testing.T) {
	t.Run("sets known key to true", func(t *testing.T) {
		m := map[string]bool{"has_readme": false}
		setCriterion(m, "has_readme")
		if !m["has_readme"] {
			t.Error("expected true after setCriterion")
		}
	})
	t.Run("ignores unknown key", func(t *testing.T) {
		m := map[string]bool{"has_readme": false}
		setCriterion(m, "unknown_key")
		if _, ok := m["unknown_key"]; ok {
			t.Error("unknown key should not be added to map")
		}
	})
	t.Run("already true stays true", func(t *testing.T) {
		m := map[string]bool{"has_tests": true}
		setCriterion(m, "has_tests")
		if !m["has_tests"] {
			t.Error("should remain true")
		}
	})
}

// ---------------------------------------------------------------------------
// setActivity
// ---------------------------------------------------------------------------

func TestSetActivity(t *testing.T) {
	t.Run("increments existing date entry", func(t *testing.T) {
		acts := map[string]map[string]int32{
			"commits": {"2024-01-01": 3},
		}
		setActivity(acts, "commits", "2024-01-01", 2)
		if acts["commits"]["2024-01-01"] != 5 {
			t.Errorf("expected 5, got %d", acts["commits"]["2024-01-01"])
		}
	})
	t.Run("creates new date entry", func(t *testing.T) {
		acts := map[string]map[string]int32{
			"commits": {},
		}
		setActivity(acts, "commits", "2024-02-01", 7)
		if acts["commits"]["2024-02-01"] != 7 {
			t.Errorf("expected 7, got %d", acts["commits"]["2024-02-01"])
		}
	})
	t.Run("ignores unknown check key", func(t *testing.T) {
		acts := map[string]map[string]int32{}
		setActivity(acts, "pull_requests", "2024-01-01", 1)
		if _, ok := acts["pull_requests"]; ok {
			t.Error("unknown key should not be added")
		}
	})
}

// ---------------------------------------------------------------------------
// checkRepoThresholds
// ---------------------------------------------------------------------------

func TestCheckRepoThresholds(t *testing.T) {
	allKeys := []string{"popular_stars_10", "popular_stars_50", "popular_stars_100",
		"active_forks_5", "active_forks_20", "many_watchers_10"}
	newSet := func() map[string]bool {
		m := make(map[string]bool)
		for _, k := range allKeys {
			m[k] = false
		}
		return m
	}

	t.Run("11 stars sets popular_stars_10", func(t *testing.T) {
		m := newSet()
		checkRepoThresholds(11, 0, 0, m)
		if !m["popular_stars_10"] {
			t.Error("expected popular_stars_10 to be true")
		}
		if m["popular_stars_50"] || m["popular_stars_100"] {
			t.Error("higher thresholds should not be set for only 11 stars")
		}
	})
	t.Run("51 stars sets 10 and 50", func(t *testing.T) {
		m := newSet()
		checkRepoThresholds(51, 0, 0, m)
		if !m["popular_stars_10"] || !m["popular_stars_50"] {
			t.Error("expected popular_stars_10 and popular_stars_50")
		}
		if m["popular_stars_100"] {
			t.Error("popular_stars_100 should not be set")
		}
	})
	t.Run("101 stars sets all", func(t *testing.T) {
		m := newSet()
		checkRepoThresholds(101, 0, 0, m)
		if !m["popular_stars_10"] || !m["popular_stars_50"] || !m["popular_stars_100"] {
			t.Error("all star criteria should be set")
		}
	})
	t.Run("6 forks sets active_forks_5", func(t *testing.T) {
		m := newSet()
		checkRepoThresholds(0, 6, 0, m)
		if !m["active_forks_5"] {
			t.Error("expected active_forks_5")
		}
		if m["active_forks_20"] {
			t.Error("active_forks_20 should not be set")
		}
	})
	t.Run("11 watchers sets many_watchers_10", func(t *testing.T) {
		m := newSet()
		checkRepoThresholds(0, 0, 11, m)
		if !m["many_watchers_10"] {
			t.Error("expected many_watchers_10")
		}
	})
	t.Run("zero stats — no criteria set", func(t *testing.T) {
		m := newSet()
		checkRepoThresholds(0, 0, 0, m)
		for k, v := range m {
			if v {
				t.Errorf("criterion %q should be false for zero stats", k)
			}
		}
	})
}

// ---------------------------------------------------------------------------
// checkContributorsThreshold
// ---------------------------------------------------------------------------

func TestCheckContributorsThreshold(t *testing.T) {
	keys := []string{"multi_contributor", "many_contributors_3", "many_contributors_10"}
	newSet := func() map[string]bool {
		m := make(map[string]bool)
		for _, k := range keys {
			m[k] = false
		}
		return m
	}

	tests := []struct {
		count  int
		multi  bool
		many3  bool
		many10 bool
	}{
		{1, false, false, false},
		{2, true, false, false},
		{4, true, true, false},
		{11, true, true, true},
	}
	for _, tc := range tests {
		t.Run(fmt.Sprintf("count=%d", tc.count), func(t *testing.T) {
			m := newSet()
			checkContributorsThreshold(tc.count, m)
			if m["multi_contributor"] != tc.multi {
				t.Errorf("multi_contributor: got %v, want %v", m["multi_contributor"], tc.multi)
			}
			if m["many_contributors_3"] != tc.many3 {
				t.Errorf("many_contributors_3: got %v, want %v", m["many_contributors_3"], tc.many3)
			}
			if m["many_contributors_10"] != tc.many10 {
				t.Errorf("many_contributors_10: got %v, want %v", m["many_contributors_10"], tc.many10)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// checkReleasesThreshold
// ---------------------------------------------------------------------------

func TestCheckReleasesThreshold(t *testing.T) {
	t.Run("6 releases sets many_releases_5", func(t *testing.T) {
		m := map[string]bool{"many_releases_5": false}
		checkReleasesThreshold(6, m)
		if !m["many_releases_5"] {
			t.Error("expected many_releases_5 to be set")
		}
	})
	t.Run("5 releases does not set threshold", func(t *testing.T) {
		m := map[string]bool{"many_releases_5": false}
		checkReleasesThreshold(5, m)
		if m["many_releases_5"] {
			t.Error("5 releases should not trigger > 5 threshold")
		}
	})
}

// ---------------------------------------------------------------------------
// checkTreeEntries
// ---------------------------------------------------------------------------

func TestCheckTreeEntries(t *testing.T) {
	entry := func(path, entryType string) *gogithub.TreeEntry {
		return &gogithub.TreeEntry{
			Path: &path,
			Type: &entryType,
		}
	}

	tests := []struct {
		name      string
		path      string
		entryType string
		key       string
	}{
		{"readme detected", "README.md", "blob", "has_readme"},
		{"readme lowercase", "readme", "blob", "has_readme"},
		{"license detected", "LICENSE", "blob", "has_license"},
		{"contributing detected", "CONTRIBUTING.md", "blob", "has_contributing"},
		{"test file detected", "test/unit_test.go", "blob", "has_tests"},
		{"spec file detected", "spec/helper_spec.rb", "blob", "has_tests"},
		{"github workflow detected", ".github/workflows/ci.yml", "blob", "has_cicd"},
		{"dockerfile detected", "dockerfile", "blob", "has_dockerfile"},
		{"changelog detected", "CHANGELOG.md", "blob", "has_changelog"},
		{"dependabot detected", ".github/dependabot.yml", "blob", "has_dependabot"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			m := map[string]bool{tc.key: false}
			entries := []*gogithub.TreeEntry{entry(tc.path, tc.entryType)}
			checkTreeEntries(entries, 1000, m)
			if !m[tc.key] {
				t.Errorf("expected %q to be true for path %q", tc.key, tc.path)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// buildResults
// ---------------------------------------------------------------------------

func TestBuildResults(t *testing.T) {
	t.Run("empty maps return empty slices", func(t *testing.T) {
		acts, criteria, err := buildResults(
			map[string]map[string]int32{},
			map[string]string{},
			map[string]bool{},
			map[string]string{},
		)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(acts) != 0 {
			t.Errorf("expected 0 activities, got %d", len(acts))
		}
		if len(criteria) != 0 {
			t.Errorf("expected 0 criteria, got %d", len(criteria))
		}
	})

	t.Run("zero-count activities are excluded", func(t *testing.T) {
		activities := map[string]map[string]int32{
			"commits": {"2024-01-01": 0},
		}
		titleMap := map[string]string{"commits": "Commits"}
		acts, _, _ := buildResults(activities, titleMap, map[string]bool{}, map[string]string{})
		if len(acts) != 0 {
			t.Errorf("zero count should be excluded; got %d activities", len(acts))
		}
	})

	t.Run("positive activity included with correct title", func(t *testing.T) {
		activities := map[string]map[string]int32{
			"commits": {"2024-03-01": 5},
		}
		titleMap := map[string]string{"commits": "Коммиты"}
		acts, _, _ := buildResults(activities, titleMap, map[string]bool{}, map[string]string{})
		if len(acts) != 1 {
			t.Fatalf("expected 1 activity, got %d", len(acts))
		}
		if acts[0].ActivityType != "Коммиты" {
			t.Errorf("activity type: got %q, want %q", acts[0].ActivityType, "Коммиты")
		}
		if acts[0].Count != 5 {
			t.Errorf("count: got %d, want 5", acts[0].Count)
		}
	})

	t.Run("met criteria included in result", func(t *testing.T) {
		criteriaSet := map[string]bool{"has_readme": true, "has_tests": false}
		criteriaTitles := map[string]string{"has_readme": "Readme присутствует", "has_tests": "Тесты"}
		_, criteria, _ := buildResults(
			map[string]map[string]int32{},
			map[string]string{},
			criteriaSet, criteriaTitles,
		)
		if len(criteria) != 1 {
			t.Fatalf("expected 1 criterion, got %d", len(criteria))
		}
		if criteria[0] != "Readme присутствует" {
			t.Errorf("criterion: got %q", criteria[0])
		}
	})

	t.Run("activity without title is excluded", func(t *testing.T) {
		activities := map[string]map[string]int32{
			"unknown_key": {"2024-01-01": 10},
		}
		acts, _, _ := buildResults(activities, map[string]string{}, map[string]bool{}, map[string]string{})
		if len(acts) != 0 {
			t.Errorf("activity without matching title should be excluded")
		}
	})
}

// ---------------------------------------------------------------------------
// fetchActivityTypes / fetchCriteria — реальная PostgreSQL (см. TEST_DATABASE_URL).
// ---------------------------------------------------------------------------

func TestFetchActivityTypes_FromDB(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureDevCatalogTables(t, db)
	testdb.TruncateDevCatalog(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)

	_, err := db.Exec(
		`INSERT INTO dev_employee_activity_types (title, check_key, admin_id, created_at, updated_at)
		 VALUES ($1, $2, $5, NOW(), NOW()), ($3, $4, $5, NOW(), NOW())`,
		"Commits", "commits",
		"Pull Requests", "pull_requests",
		adminID,
	)
	if err != nil {
		t.Fatalf("insert activity types: %v", err)
	}

	c := &Client{db: db}
	types, err := c.fetchActivityTypes(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(types) != 2 {
		t.Fatalf("expected 2 types, got %d", len(types))
	}
	byKey := map[string]string{}
	for _, x := range types {
		byKey[x.CheckKey] = x.Title
	}
	if byKey["commits"] != "Commits" || byKey["pull_requests"] != "Pull Requests" {
		t.Errorf("unexpected rows: %+v", byKey)
	}
}

func TestFetchCriteria_FromDB(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureDevCatalogTables(t, db)
	testdb.TruncateDevCatalog(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)

	_, err := db.Exec(
		`INSERT INTO dev_project_criteria (title, check_key, admin_id, created_at, updated_at)
		 VALUES ($1, $2, $5, NOW(), NOW()), ($3, $4, $5, NOW(), NOW())`,
		"Has README", "has_readme",
		"Has Tests", "has_tests",
		adminID,
	)
	if err != nil {
		t.Fatalf("insert criteria: %v", err)
	}

	c := &Client{db: db}
	criteria, err := c.fetchCriteria(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(criteria) != 2 {
		t.Fatalf("expected 2 criteria, got %d", len(criteria))
	}
	byKey := map[string]string{}
	for _, x := range criteria {
		byKey[x.CheckKey] = x.Title
	}
	if byKey["has_readme"] != "Has README" || byKey["has_tests"] != "Has Tests" {
		t.Errorf("unexpected rows: %+v", byKey)
	}
}

func TestFetchActivityTypes_FiltersNullCheckKey(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureDevCatalogTables(t, db)
	testdb.TruncateDevCatalog(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)

	_, err := db.Exec(
		`INSERT INTO dev_employee_activity_types (title, check_key, admin_id, created_at, updated_at)
		 VALUES ($1, NULL, $4, NOW(), NOW()), ($2, $3, $4, NOW(), NOW())`,
		"No key row",
		"Valid", "valid_key",
		adminID,
	)
	if err != nil {
		t.Fatalf("insert: %v", err)
	}

	c := &Client{db: db}
	types, err := c.fetchActivityTypes(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(types) != 1 {
		t.Fatalf("expected 1 row (NULL check_key excluded by query), got %d", len(types))
	}
	if types[0].CheckKey != "valid_key" {
		t.Errorf("check_key: got %q", types[0].CheckKey)
	}
}

func TestFetchCriteria_FiltersNullCheckKey(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureDevCatalogTables(t, db)
	testdb.TruncateDevCatalog(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)

	_, err := db.Exec(
		`INSERT INTO dev_project_criteria (title, check_key, admin_id, created_at, updated_at)
		 VALUES ($1, NULL, $4, NOW(), NOW()), ($2, $3, $4, NOW(), NOW())`,
		"No key criterion",
		"Has CI", "cr_valid_ci",
		adminID,
	)
	if err != nil {
		t.Fatalf("insert: %v", err)
	}

	c := &Client{db: db}
	criteria, err := c.fetchCriteria(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(criteria) != 1 {
		t.Fatalf("expected 1 row (NULL check_key excluded), got %d", len(criteria))
	}
	if criteria[0].CheckKey != "cr_valid_ci" {
		t.Errorf("check_key: got %q", criteria[0].CheckKey)
	}
}

// ---------------------------------------------------------------------------
// resolveToken (app_settings.github_token)
// ---------------------------------------------------------------------------

func TestResolveToken_NilDB(t *testing.T) {
	if got := resolveToken(nil); got != "" {
		t.Errorf("resolveToken(nil) = %q, want empty", got)
	}
}

func TestResolveToken_WithSecret(t *testing.T) {
	db := testdb.Open(t)
	testdb.StashGitHubToken(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)

	const want = "ghp_integration_test_dummy_token"
	if _, err := db.Exec(
		`INSERT INTO app_settings (key, value, admin_id, created_at, updated_at) VALUES ('github_token', $1, $2, NOW(), NOW())`,
		want, adminID,
	); err != nil {
		t.Fatalf("insert: %v", err)
	}
	if got := resolveToken(db); got != want {
		t.Errorf("resolveToken = %q, want %q", got, want)
	}
}

func TestResolveToken_IgnoresNullValue(t *testing.T) {
	db := testdb.Open(t)
	testdb.StashGitHubToken(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)

	if _, err := db.Exec(
		`INSERT INTO app_settings (key, value, admin_id, created_at, updated_at) VALUES ('github_token', NULL, $1, NOW(), NOW())`,
		adminID,
	); err != nil {
		t.Fatalf("insert: %v", err)
	}
	if got := resolveToken(db); got != "" {
		t.Errorf("resolveToken = %q, want empty for NULL value", got)
	}
}

func TestResolveToken_IgnoresEmptyString(t *testing.T) {
	db := testdb.Open(t)
	testdb.StashGitHubToken(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)

	if _, err := db.Exec(
		`INSERT INTO app_settings (key, value, admin_id, created_at, updated_at) VALUES ('github_token', '', $1, NOW(), NOW())`,
		adminID,
	); err != nil {
		t.Fatalf("insert: %v", err)
	}
	if got := resolveToken(db); got != "" {
		t.Errorf("resolveToken = %q, want empty for empty value", got)
	}
}
