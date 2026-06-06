//go:build go1.21

package github

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	gogithub "github.com/google/go-github/v60/github"

	"integration_service/internal/testdb"
)

func TestApplyGitHubAPIBase_NoEnvLeavesClientUnchanged(t *testing.T) {
	t.Cleanup(func() {
		_ = os.Unsetenv(EnvGitHubAPIBase)
		_ = os.Unsetenv(EnvGitHubUploadURL)
	})
	_ = os.Unsetenv(EnvGitHubAPIBase)
	_ = os.Unsetenv(EnvGitHubUploadURL)

	c := gogithub.NewClient(nil)
	before := c.BaseURL.String()
	applyGitHubAPIBase(c)
	if c.BaseURL.String() != before {
		t.Fatalf("BaseURL changed without env: was %q now %q", before, c.BaseURL.String())
	}
}

func TestApplyGitHubAPIBase_CustomBaseAndUploadURL(t *testing.T) {
	t.Cleanup(func() {
		_ = os.Unsetenv(EnvGitHubAPIBase)
		_ = os.Unsetenv(EnvGitHubUploadURL)
	})

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	t.Cleanup(srv.Close)

	// No trailing slash — applyGitHubAPIBase appends one before parse.
	t.Setenv(EnvGitHubAPIBase, strings.TrimSuffix(srv.URL, "/"))
	up := srv.URL + "/uploads/"
	t.Setenv(EnvGitHubUploadURL, strings.TrimSuffix(up, "/"))

	c := gogithub.NewClient(nil)
	applyGitHubAPIBase(c)
	if c.BaseURL == nil || !strings.HasPrefix(c.BaseURL.String(), srv.URL) {
		t.Fatalf("BaseURL: %v", c.BaseURL)
	}
	if c.UploadURL == nil || !strings.Contains(c.UploadURL.String(), "uploads") {
		t.Fatalf("UploadURL: %v", c.UploadURL)
	}
}

func TestApplyGitHubAPIBase_EnterpriseAPIv3DerivesUploadURL(t *testing.T) {
	t.Cleanup(func() {
		_ = os.Unsetenv(EnvGitHubAPIBase)
		_ = os.Unsetenv(EnvGitHubUploadURL)
	})
	_ = os.Unsetenv(EnvGitHubUploadURL)

	t.Setenv(EnvGitHubAPIBase, "https://github.example.com/api/v3/")
	c := gogithub.NewClient(nil)
	applyGitHubAPIBase(c)
	if c.UploadURL == nil || !strings.Contains(c.UploadURL.Path, "uploads") {
		t.Fatalf("expected uploads path from api/v3 base, got %v", c.UploadURL)
	}
}

func TestApplyGitHubAPIBase_InvalidBaseURLIgnored(t *testing.T) {
	t.Cleanup(func() { _ = os.Unsetenv(EnvGitHubAPIBase) })
	t.Setenv(EnvGitHubAPIBase, "://not-a-url")

	c := gogithub.NewClient(nil)
	before := c.BaseURL.String()
	applyGitHubAPIBase(c)
	if c.BaseURL.String() != before {
		t.Fatal("BaseURL should stay default when env is invalid")
	}
}

func TestGetRepoActivity_InvalidURL_NoDatabase(t *testing.T) {
	t.Cleanup(func() { _ = os.Unsetenv(EnvGitHubAPIBase) })
	_ = os.Unsetenv(EnvGitHubAPIBase)

	c := NewClient(nil)
	_, _, _, err := c.GetRepoActivity(context.Background(), "notownerrepo")
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestGetRepoActivity_RepoNotFound(t *testing.T) {
	testdb.SkipIfNoDSN(t)
	t.Cleanup(func() { _ = os.Unsetenv(EnvGitHubAPIBase) })

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if strings.HasPrefix(r.URL.Path, "/repos/") {
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write([]byte(`{"message":"Not Found"}`))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{}`))
	}))
	t.Cleanup(srv.Close)
	t.Setenv(EnvGitHubAPIBase, srv.URL+"/")

	db := testdb.Open(t)
	testdb.EnsureDevCatalogTables(t, db)
	testdb.TruncateDevCatalog(t, db)

	c := NewClient(db)
	_, _, _, err := c.GetRepoActivity(context.Background(), "owner/missing")
	if err == nil {
		t.Fatal("expected error when repo GET fails")
	}
}

// fakeGitHubREST serves minimal valid JSON for the REST calls made by GetUserActivity / GetRepoActivity.
func fakeGitHubREST(userLogin, owner, repo string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.NotFound(w, r)
			return
		}
		p := r.URL.Path
		w.Header().Set("Content-Type", "application/json")

		switch {
		case strings.HasPrefix(p, "/search/issues"):
			_, _ = w.Write([]byte(`{"total_count":0,"incomplete_results":false,"items":[]}`))
		case strings.HasPrefix(p, "/search/commits"):
			_, _ = w.Write([]byte(`{"total_count":0,"incomplete_results":false,"items":[]}`))
		case strings.HasPrefix(p, "/users/") && strings.HasSuffix(p, "/repos"):
			_, _ = w.Write([]byte(`[]`))
		case strings.HasPrefix(p, "/users/"):
			_, _ = fmt.Fprintf(w, `{"login":%q,"followers":2,"public_repos":0,"public_gists":1}`, userLogin)
		case strings.Contains(p, "/git/trees/"):
			_, _ = w.Write([]byte(`{"sha":"tree1","tree":[{"path":"README.md","type":"blob","mode":"100644","sha":"b1"}],"truncated":false}`))
		case strings.HasSuffix(p, "/releases"):
			_, _ = w.Write([]byte(`[]`))
		case strings.HasSuffix(p, "/contributors"):
			_, _ = w.Write([]byte(`[]`))
		case strings.HasPrefix(p, "/repos/") && strings.Count(p, "/") == 3:
			_, _ = fmt.Fprintf(w,
				`{"id":1,"name":%q,"full_name":%q,"owner":{"login":%q},"default_branch":"main",`+
					`"stargazers_count":3,"forks_count":1,"watchers_count":5,"open_issues_count":0,"size":100,`+
					`"fork":false,"topics":[],"has_wiki":false,"has_pages":false,"has_discussions":false}`,
				repo, owner+"/"+repo, owner)
		default:
			w.WriteHeader(http.StatusNotFound)
			_, _ = fmt.Fprintf(w, `{"message":"unhandled path %s"}`, p)
		}
	}
}

func TestGetUserActivity_WithFakeGitHubREST(t *testing.T) {
	testdb.SkipIfNoDSN(t)
	t.Cleanup(func() { _ = os.Unsetenv(EnvGitHubAPIBase) })

	const login = "ghuser"
	srv := httptest.NewServer(fakeGitHubREST(login, "o", "r"))
	t.Cleanup(srv.Close)
	t.Setenv(EnvGitHubAPIBase, srv.URL+"/")

	db := testdb.Open(t)
	testdb.EnsureDevCatalogTables(t, db)
	testdb.TruncateDevCatalog(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)
	_, err := db.Exec(
		`INSERT INTO dev_employee_activity_types (title, check_key, admin_id, created_at, updated_at)
		 VALUES ('Followers', 'followers', $1, NOW(), NOW())`,
		adminID,
	)
	if err != nil {
		t.Fatalf("insert activity type: %v", err)
	}

	c := NewClient(db)
	acts, details, crit, err := c.GetUserActivity(context.Background(), login)
	if err != nil {
		t.Fatalf("GetUserActivity: %v", err)
	}
	if len(details) != 0 {
		t.Fatalf("expected no details with empty searches, got %d", len(details))
	}
	if len(crit) != 0 {
		t.Fatalf("criteria: %v", crit)
	}
	var followers int
	for _, a := range acts {
		if strings.Contains(strings.ToLower(a.GetActivityType()), "follow") {
			followers += int(a.GetCount())
		}
	}
	if followers < 2 {
		t.Fatalf("expected followers activity from stub user, got acts=%v", acts)
	}
}

func TestGetRepoActivity_WithFakeGitHubREST(t *testing.T) {
	testdb.SkipIfNoDSN(t)
	t.Cleanup(func() { _ = os.Unsetenv(EnvGitHubAPIBase) })

	srv := httptest.NewServer(fakeGitHubREST("x", "owner", "repo"))
	t.Cleanup(srv.Close)
	t.Setenv(EnvGitHubAPIBase, srv.URL+"/")

	db := testdb.Open(t)
	testdb.EnsureDevCatalogTables(t, db)
	testdb.TruncateDevCatalog(t, db)
	adminID := testdb.EnsureTestAdmin(t, db)
	_, err := db.Exec(
		`INSERT INTO dev_employee_activity_types (title, check_key, admin_id, created_at, updated_at)
		 VALUES ('Stars', 'stars', $1, NOW(), NOW())`,
		adminID,
	)
	if err != nil {
		t.Fatalf("insert activity type: %v", err)
	}

	c := NewClient(db)
	acts, _, _, err := c.GetRepoActivity(context.Background(), "owner/repo")
	if err != nil {
		t.Fatalf("GetRepoActivity: %v", err)
	}
	var starPts int32
	for _, a := range acts {
		if strings.EqualFold(a.GetActivityType(), "stars") {
			starPts += a.GetCount()
		}
	}
	if starPts < 3 {
		t.Fatalf("expected stars from stub repo, got %+v", acts)
	}
}
