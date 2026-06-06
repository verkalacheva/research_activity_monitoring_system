//go:build go1.21

package main

import (
	"context"
	"database/sql"
	"errors"
	"net"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"integration_service/internal/github"
	"integration_service/internal/integrations"
	"integration_service/internal/repository"
	"integration_service/internal/testdb"
	"integration_service/pb"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestDeduplicate(t *testing.T) {
	t.Run("empty slice returns empty", func(t *testing.T) {
		got := deduplicate(nil)
		if len(got) != 0 {
			t.Errorf("expected empty, got %d items", len(got))
		}
	})

	t.Run("no duplicates — all kept", func(t *testing.T) {
		in := []*pb.Achievement{
			{Title: "Paper A", ExternalId: "doi:1"},
			{Title: "Paper B", ExternalId: "doi:2"},
		}
		got := deduplicate(in)
		if len(got) != 2 {
			t.Errorf("expected 2, got %d", len(got))
		}
	})

	t.Run("duplicate by ExternalId removed", func(t *testing.T) {
		in := []*pb.Achievement{
			{Title: "Paper", ExternalId: "doi:1"},
			{Title: "Paper (duplicate)", ExternalId: "doi:1"},
		}
		got := deduplicate(in)
		if len(got) != 1 {
			t.Errorf("expected 1, got %d", len(got))
		}
		if got[0].Title != "Paper" {
			t.Errorf("expected first occurrence kept, got %q", got[0].Title)
		}
	})

	t.Run("duplicate by Title (no ExternalId) removed", func(t *testing.T) {
		in := []*pb.Achievement{
			{Title: "Same Title"},
			{Title: "Same Title"},
		}
		got := deduplicate(in)
		if len(got) != 1 {
			t.Errorf("expected 1, got %d", len(got))
		}
	})

	t.Run("deduplication is case-insensitive", func(t *testing.T) {
		in := []*pb.Achievement{
			{Title: "Paper Title"},
			{Title: "PAPER TITLE"},
		}
		got := deduplicate(in)
		if len(got) != 1 {
			t.Errorf("expected 1 (case-insensitive dedup), got %d", len(got))
		}
	})

	t.Run("ExternalId takes priority over Title for key", func(t *testing.T) {
		in := []*pb.Achievement{
			{Title: "Same Title", ExternalId: "doi:A"},
			{Title: "Same Title", ExternalId: "doi:B"},
		}
		got := deduplicate(in)
		if len(got) != 2 {
			t.Errorf("expected 2 (different external ids), got %d", len(got))
		}
	})

	t.Run("whitespace trimmed for key comparison", func(t *testing.T) {
		in := []*pb.Achievement{
			{Title: "  paper  "},
			{Title: "paper"},
		}
		got := deduplicate(in)
		if len(got) != 1 {
			t.Errorf("expected 1 after trimming whitespace, got %d", len(got))
		}
	})
}

func TestDatabaseURLFromEnv_UsesEnv(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://custom/db")
	if got := databaseURLFromEnv(); got != "postgres://custom/db" {
		t.Errorf("got %q", got)
	}
}

func TestDatabaseURLFromEnv_DefaultWhenWhitespace(t *testing.T) {
	t.Setenv("DATABASE_URL", "   ")
	got := databaseURLFromEnv()
	if !strings.Contains(got, "research_activity_monitoring_system_development") {
		t.Errorf("expected default dev DB in URL, got %q", got)
	}
}

func TestStartHealthHTTPServer_LiveAndReady(t *testing.T) {
	db := testdb.Open(t)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	addr := ln.Addr().String()
	if err := ln.Close(); err != nil {
		t.Fatalf("close: %v", err)
	}

	srv := startHealthHTTPServer(db, addr)
	t.Cleanup(func() {
		_ = srv.Shutdown(context.Background())
	})

	waitHealthLive(t, "http://"+addr)

	resp, err := http.Get("http://" + addr + "/health/ready")
	if err != nil {
		t.Fatalf("ready: %v", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("ready status: %d", resp.StatusCode)
	}
}

func TestStartHealthHTTPServer_ReadyFailsWhenDBUnreachable(t *testing.T) {
	// No real server on this port; PingContext should fail quickly.
	db, err := sql.Open("postgres", "postgres://n:n@127.0.0.1:65432/none?sslmode=disable&connect_timeout=1")
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	defer func() { _ = db.Close() }()

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	addr := ln.Addr().String()
	if err := ln.Close(); err != nil {
		t.Fatalf("close: %v", err)
	}

	srv := startHealthHTTPServer(db, addr)
	t.Cleanup(func() {
		_ = srv.Shutdown(context.Background())
	})

	waitHealthLive(t, "http://"+addr)

	resp, err := http.Get("http://" + addr + "/health/ready")
	if err != nil {
		t.Fatalf("ready: %v", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("ready status: want %d got %d", http.StatusServiceUnavailable, resp.StatusCode)
	}
}

func waitHealthLive(t *testing.T, base string) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		resp, err := http.Get(base + "/health/live")
		if err == nil && resp.StatusCode == http.StatusOK {
			_ = resp.Body.Close()
			return
		}
		if resp != nil {
			_ = resp.Body.Close()
		}
		time.Sleep(25 * time.Millisecond)
	}
	t.Fatal("/health/live never returned 200")
}

func TestFetchOrcidAchievements_InvalidOrcidNoDB(t *testing.T) {
	s := &server{
		registry:             integrations.NewRegistry(),
		researcherRepository: nil,
		githubClient:         nil,
	}
	_, err := s.FetchOrcidAchievements(context.Background(), &pb.OrcidRequest{OrcidId: "not-a-valid-orcid"})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestCrawlDevActivity_EmptyUsername(t *testing.T) {
	s := &server{githubClient: github.NewClient(nil)}
	resp, err := s.CrawlDevActivity(context.Background(), &pb.DevActivityRequest{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("nil response")
	}
	if len(resp.Activities) != 0 || len(resp.ActivityDetails) != 0 || len(resp.ProjectCriteriaMet) != 0 {
		t.Fatalf("expected empty slices, got activities=%d details=%d criteria=%d",
			len(resp.Activities), len(resp.ActivityDetails), len(resp.ProjectCriteriaMet))
	}
}

type stubGithubDevActivity struct {
	userActs     []*pb.DevActivity
	userDetails  []*pb.ActivityDetail
	userCriteria []string
	userErr      error

	repoActs     []*pb.DevActivity
	repoDetails  []*pb.ActivityDetail
	repoCriteria []string
	repoErr      error

	lastUser string
	lastRepo string
}

func (s *stubGithubDevActivity) GetUserActivity(ctx context.Context, username string) ([]*pb.DevActivity, []*pb.ActivityDetail, []string, error) {
	s.lastUser = username
	return s.userActs, s.userDetails, s.userCriteria, s.userErr
}

func (s *stubGithubDevActivity) GetRepoActivity(ctx context.Context, repoURL string) ([]*pb.DevActivity, []*pb.ActivityDetail, []string, error) {
	s.lastRepo = repoURL
	return s.repoActs, s.repoDetails, s.repoCriteria, s.repoErr
}

func TestCrawlDevActivity_UserBranch(t *testing.T) {
	stub := &stubGithubDevActivity{
		userActs: []*pb.DevActivity{{ActivityType: "commits", Count: 3}},
		userCriteria: []string{"c1"},
	}
	s := &server{githubClient: stub}
	resp, err := s.CrawlDevActivity(context.Background(), &pb.DevActivityRequest{GithubUsername: "alice"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if stub.lastUser != "alice" || stub.lastRepo != "" {
		t.Fatalf("stub calls: user=%q repo=%q", stub.lastUser, stub.lastRepo)
	}
	if len(resp.Activities) != 1 || resp.Activities[0].Count != 3 {
		t.Fatalf("activities: %+v", resp.Activities)
	}
	if len(resp.ProjectCriteriaMet) != 1 || resp.ProjectCriteriaMet[0] != "c1" {
		t.Fatalf("criteria: %v", resp.ProjectCriteriaMet)
	}
}

func TestCrawlDevActivity_RepoBranch(t *testing.T) {
	stub := &stubGithubDevActivity{
		repoActs: []*pb.DevActivity{{ActivityType: "prs", Count: 1}},
		repoCriteria: []string{"r1"},
	}
	s := &server{githubClient: stub}
	req := &pb.DevActivityRequest{GithubUsername: "org/repo"}
	resp, err := s.CrawlDevActivity(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if stub.lastRepo != "org/repo" || stub.lastUser != "" {
		t.Fatalf("stub calls: user=%q repo=%q", stub.lastUser, stub.lastRepo)
	}
	if len(resp.Activities) != 1 {
		t.Fatalf("activities: %+v", resp.Activities)
	}
	if len(resp.ProjectCriteriaMet) != 1 {
		t.Fatalf("criteria: %v", resp.ProjectCriteriaMet)
	}
}

func TestCrawlDevActivity_HttpPrefixUsesRepoPath(t *testing.T) {
	stub := &stubGithubDevActivity{repoActs: []*pb.DevActivity{{Count: 2}}}
	s := &server{githubClient: stub}
	u := "https://github.com/foo/bar"
	_, err := s.CrawlDevActivity(context.Background(), &pb.DevActivityRequest{GithubUsername: u})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if stub.lastRepo != u {
		t.Fatalf("expected repo URL %q, got %q", u, stub.lastRepo)
	}
}

func TestCrawlDevActivity_GithubError(t *testing.T) {
	want := errors.New("github down")
	s := &server{githubClient: &stubGithubDevActivity{userErr: want}}
	_, err := s.CrawlDevActivity(context.Background(), &pb.DevActivityRequest{GithubUsername: "bob"})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.Internal {
		t.Fatalf("code: %v", status.Code(err))
	}
}

// stubOrcidProvider — без сети ORCID; только для SyncAllAchievements.
type stubOrcidProvider struct {
	out []*pb.Achievement
	err error
}

func (s stubOrcidProvider) FetchAchievements(ctx context.Context, externalID string) ([]*pb.Achievement, error) {
	if s.err != nil {
		return nil, s.err
	}
	if len(s.out) > 0 {
		return s.out, nil
	}
	return []*pb.Achievement{{Title: "Synced", ExternalId: "doi:stub-" + externalID}}, nil
}

type stubOpenAlexProvider struct {
	out []*pb.Achievement
	err error
}

func (s stubOpenAlexProvider) FetchAchievements(ctx context.Context, externalID string) ([]*pb.Achievement, error) {
	if s.err != nil {
		return nil, s.err
	}
	if len(s.out) > 0 {
		return s.out, nil
	}
	return []*pb.Achievement{{Title: "OA", ExternalId: "oa:" + externalID}}, nil
}

func newTestServer(t *testing.T, db *sql.DB) *server {
	t.Helper()
	reg := integrations.NewRegistry()
	reg.Register("orcid", stubOrcidProvider{})
	reg.Register("openalex", stubOpenAlexProvider{})
	return &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
}

func insertResearcherORCID(t *testing.T, db *sql.DB, orcid string) int64 {
	t.Helper()
	adminID := testdb.InsertAdmin(t, db, "orcid-"+orcid+"@test")
	testdb.InsertResearcherORCID(t, db, adminID, orcid)
	return adminID
}

func insertResearcherBothIDs(t *testing.T, db *sql.DB, orcid, openalex string) int64 {
	t.Helper()
	adminID := testdb.InsertAdmin(t, db, "both-"+orcid+"@test")
	_, err := db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES ($1, $2, $3, NULL, NOW(), NOW())`,
		orcid, openalex, adminID,
	)
	if err != nil {
		t.Fatalf("insert researcher: %v", err)
	}
	return adminID
}

func TestSyncAllAchievements_RequiresAdminID(t *testing.T) {
	db := testdb.Open(t)
	srv := newTestServer(t, db)
	_, err := srv.SyncAllAchievements(context.Background(), &pb.SyncRequest{Provider: "orcid"})
	if err == nil {
		t.Fatal("expected error when admin_id is missing")
	}
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("expected InvalidArgument, got %v", status.Code(err))
	}
}

func TestSyncAllAchievements_OrcidProvider(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	const orcid = "0000-0001-5555-5555"
	adminID := insertResearcherORCID(t, db, orcid)

	srv := newTestServer(t, db)
	resp, err := srv.SyncAllAchievements(context.Background(), &pb.SyncRequest{Provider: "orcid", AdminId: adminID})
	if err != nil {
		t.Fatalf("SyncAllAchievements: %v", err)
	}
	if len(resp.Results) != 1 {
		t.Fatalf("expected 1 researcher result, got %d", len(resp.Results))
	}
	if len(resp.Results[0].Achievements) != 1 {
		t.Fatalf("achievements: %d", len(resp.Results[0].Achievements))
	}
}

func TestSyncAllAchievements_AllMergesBothProviders(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := insertResearcherBothIDs(t, db, "0000-0001-6666-6666", "W1234567890")

	reg := integrations.NewRegistry()
	reg.Register("orcid", stubOrcidProvider{out: []*pb.Achievement{{Title: "A", ExternalId: "doi:a"}}})
	reg.Register("openalex", stubOpenAlexProvider{out: []*pb.Achievement{{Title: "B", ExternalId: "doi:b"}}})

	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	resp, err := srv.SyncAllAchievements(context.Background(), &pb.SyncRequest{Provider: "all", AdminId: adminID})
	if err != nil {
		t.Fatalf("SyncAllAchievements: %v", err)
	}
	if len(resp.Results) != 1 {
		t.Fatalf("results: %d", len(resp.Results))
	}
	if len(resp.Results[0].Achievements) != 2 {
		t.Fatalf("expected merged achievements, got %d", len(resp.Results[0].Achievements))
	}
}

func TestSyncAllAchievements_InvalidProviderRegistry(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := insertResearcherORCID(t, db, "0000-0001-8888-8888")

	reg := integrations.NewRegistry()
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	_, err := srv.SyncAllAchievements(context.Background(), &pb.SyncRequest{Provider: "orcid", AdminId: adminID})
	if err == nil {
		t.Fatal("expected error: registry has no orcid provider")
	}
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("expected InvalidArgument, got %v", status.Code(err))
	}
}

func TestSyncAllAchievements_EmptyResearchers(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)

	srv := newTestServer(t, db)
	adminID := testdb.InsertAdmin(t, db, "empty-sync@test")
	resp, err := srv.SyncAllAchievements(context.Background(), &pb.SyncRequest{Provider: "orcid", AdminId: adminID})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Results) != 0 {
		t.Fatalf("expected no results, got %d", len(resp.Results))
	}
}

func TestSyncAllAchievements_FetchErrorSkipsResearcher(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := insertResearcherORCID(t, db, "0000-0001-7777-7777")

	reg := integrations.NewRegistry()
	reg.Register("orcid", stubOrcidProvider{err: status.Error(codes.Unavailable, "stub fail")})

	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	resp, err := srv.SyncAllAchievements(context.Background(), &pb.SyncRequest{Provider: "orcid", AdminId: adminID})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Results) != 0 {
		t.Fatalf("expected no results when fetch fails, got %d", len(resp.Results))
	}
}

func TestSyncAllAchievements_DBError(t *testing.T) {
	testdb.SkipIfNoDSN(t)
	dsn := os.Getenv("TEST_DATABASE_URL")
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		t.Fatalf("ping: %v", err)
	}
	_ = db.Close()

	reg := integrations.NewRegistry()
	reg.Register("orcid", stubOrcidProvider{})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(nil),
	}
	_, err = srv.SyncAllAchievements(context.Background(), &pb.SyncRequest{Provider: "orcid", AdminId: 1})
	if err == nil {
		t.Fatal("expected error from closed DB")
	}
	if status.Code(err) != codes.Internal {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func insertResearcherOpenAlexOnly(t *testing.T, db *sql.DB, openalexID string) int64 {
	t.Helper()
	adminID := testdb.InsertAdmin(t, db, "openalex-"+openalexID+"@test")
	_, err := db.Exec(
		`INSERT INTO researchers (orcid_id, openalex_id, admin_id, deleted_at, created_at, updated_at)
		 VALUES (NULL, $1, $2, NULL, NOW(), NOW())`,
		openalexID, adminID,
	)
	if err != nil {
		t.Fatalf("insert researcher openalex: %v", err)
	}
	return adminID
}

func TestFetchOrcidAchievements_NotFound(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)

	reg := integrations.NewRegistry()
	reg.Register("orcid", stubOrcidProvider{})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	_, err := srv.FetchOrcidAchievements(context.Background(), &pb.OrcidRequest{OrcidId: "0000-0001-2345-6789"})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.NotFound {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestFetchOrcidAchievements_Success(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	const orcid = "0000-0001-2345-6789"
	insertResearcherORCID(t, db, orcid)

	reg := integrations.NewRegistry()
	reg.Register("orcid", stubOrcidProvider{out: []*pb.Achievement{{Title: "Paper", ExternalId: "doi:ok"}}})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	resp, err := srv.FetchOrcidAchievements(context.Background(), &pb.OrcidRequest{OrcidId: orcid})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Achievements) != 1 || resp.Achievements[0].Title != "Paper" {
		t.Fatalf("achievements: %+v", resp.Achievements)
	}
}

func TestFetchOrcidAchievements_Unavailable(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	const orcid = "0000-0002-3456-7890"
	insertResearcherORCID(t, db, orcid)

	reg := integrations.NewRegistry()
	reg.Register("orcid", stubOrcidProvider{err: status.Error(codes.Unavailable, "upstream")})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	_, err := srv.FetchOrcidAchievements(context.Background(), &pb.OrcidRequest{OrcidId: orcid})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.Unavailable {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestFetchOrcidAchievements_InternalMissingProvider(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	insertResearcherORCID(t, db, "0000-0001-1111-1111")

	srv := &server{
		registry:             integrations.NewRegistry(),
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	_, err := srv.FetchOrcidAchievements(context.Background(), &pb.OrcidRequest{OrcidId: "0000-0001-1111-1111"})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.Internal {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestFetchOrcidAchievements_InternalDB(t *testing.T) {
	testdb.SkipIfNoDSN(t)
	dsn := os.Getenv("TEST_DATABASE_URL")
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		t.Fatalf("ping: %v", err)
	}
	_ = db.Close()

	reg := integrations.NewRegistry()
	reg.Register("orcid", stubOrcidProvider{})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(nil),
	}
	_, err = srv.FetchOrcidAchievements(context.Background(), &pb.OrcidRequest{OrcidId: "0000-0001-0000-0002"})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.Internal {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestFetchOpenAlexAchievements_NotFound(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)

	reg := integrations.NewRegistry()
	reg.Register("openalex", stubOpenAlexProvider{})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	_, err := srv.FetchOpenAlexAchievements(context.Background(), &pb.OpenAlexRequest{OpenalexId: "W9999999999"})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.NotFound {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestFetchOpenAlexAchievements_Success(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	const oa = "W1234567891"
	insertResearcherOpenAlexOnly(t, db, oa)

	reg := integrations.NewRegistry()
	reg.Register("openalex", stubOpenAlexProvider{out: []*pb.Achievement{{Title: "Work", ExternalId: "id:1"}}})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	resp, err := srv.FetchOpenAlexAchievements(context.Background(), &pb.OpenAlexRequest{OpenalexId: oa})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Achievements) != 1 || resp.Achievements[0].Title != "Work" {
		t.Fatalf("achievements: %+v", resp.Achievements)
	}
}

func TestFetchOpenAlexAchievements_Unavailable(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	const oa = "W1234567892"
	insertResearcherOpenAlexOnly(t, db, oa)

	reg := integrations.NewRegistry()
	reg.Register("openalex", stubOpenAlexProvider{err: status.Error(codes.Unavailable, "oa fail")})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	_, err := srv.FetchOpenAlexAchievements(context.Background(), &pb.OpenAlexRequest{OpenalexId: oa})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.Unavailable {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestFetchOpenAlexAchievements_InternalMissingProvider(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	insertResearcherOpenAlexOnly(t, db, "W1234567893")

	srv := &server{
		registry:             integrations.NewRegistry(),
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	_, err := srv.FetchOpenAlexAchievements(context.Background(), &pb.OpenAlexRequest{OpenalexId: "W1234567893"})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.Internal {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestFetchOpenAlexAchievements_InternalDB(t *testing.T) {
	testdb.SkipIfNoDSN(t)
	dsn := os.Getenv("TEST_DATABASE_URL")
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		t.Fatalf("ping: %v", err)
	}
	_ = db.Close()

	reg := integrations.NewRegistry()
	reg.Register("openalex", stubOpenAlexProvider{})
	srv := &server{
		registry:             reg,
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(nil),
	}
	_, err = srv.FetchOpenAlexAchievements(context.Background(), &pb.OpenAlexRequest{OpenalexId: "W1"})
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Code(err) != codes.Internal {
		t.Fatalf("code: %v", status.Code(err))
	}
}

func TestSyncAllAchievements_All_EmptyProvidersMap(t *testing.T) {
	db := testdb.Open(t)
	testdb.EnsureResearchersTable(t, db)
	testdb.TruncateResearchers(t, db)
	adminID := insertResearcherBothIDs(t, db, "0000-0003-3333-3333", "W4444444444")

	srv := &server{
		registry:             integrations.NewRegistry(),
		researcherRepository: repository.NewResearcherRepository(db),
		githubClient:         github.NewClient(db),
	}
	resp, err := srv.SyncAllAchievements(context.Background(), &pb.SyncRequest{Provider: "all", AdminId: adminID})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Results) != 0 {
		t.Fatalf("expected no sync rows when no providers registered, got %d", len(resp.Results))
	}
}
