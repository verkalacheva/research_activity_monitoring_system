package github

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"integration_service/pb"

	"github.com/google/go-github/v60/github"
	"golang.org/x/oauth2"
)

const EnvGitHubAPIBase = "GITHUB_API_BASE_URL"
const EnvGitHubUploadURL = "GITHUB_UPLOAD_URL"

// applyGitHubAPIBase overrides go-github URLs for GitHub Enterprise etc.
// Defaults: unset → standard api.github.com (library default left intact when env empty).
func applyGitHubAPIBase(c *github.Client) {
	baseStr := strings.TrimSpace(os.Getenv(EnvGitHubAPIBase))
	if baseStr == "" {
		return
	}
	if !strings.HasSuffix(baseStr, "/") {
		baseStr += "/"
	}
	base, err := url.Parse(baseStr)
	if err != nil {
		log.Printf("invalid %s: %v", EnvGitHubAPIBase, err)
		return
	}
	c.BaseURL = base

	upStr := strings.TrimSpace(os.Getenv(EnvGitHubUploadURL))
	switch {
	case upStr != "":
		if !strings.HasSuffix(upStr, "/") {
			upStr += "/"
		}
		up, err := url.Parse(upStr)
		if err != nil {
			log.Printf("invalid %s: %v", EnvGitHubUploadURL, err)
			return
		}
		c.UploadURL = up
	default:
		if strings.Contains(base.Path, "/api/v3") {
			dup := *base
			dup.Path = strings.Replace(base.Path, "/api/v3", "/api/uploads", 1)
			c.UploadURL = &dup
		} else {
			c.UploadURL = base
		}
	}
}

type activityTypeDef struct {
	CheckKey string
	Title    string
}

type criterionDef struct {
	CheckKey string
	Title    string
}

type Client struct {
	client *github.Client
	db     *sql.DB
}

func NewClient(db *sql.DB) *Client {
	token := resolveToken(db)
	var tc *github.Client
	if token != "" {
		ctx := context.Background()
		ts := oauth2.StaticTokenSource(
			&oauth2.Token{AccessToken: token},
		)
		tc = github.NewClient(oauth2.NewClient(ctx, ts))
	} else {
		tc = github.NewClient(nil)
	}
	applyGitHubAPIBase(tc)
	return &Client{client: tc, db: db}
}

// resolveToken returns the GitHub token from app_settings (UI / API настроек), без process env.
func resolveToken(db *sql.DB) string {
	if db == nil {
		return ""
	}
	var value string
	err := db.QueryRow(
		"SELECT value FROM app_settings WHERE key = 'github_token' AND value IS NOT NULL AND value != '' LIMIT 1",
	).Scan(&value)
	if err == nil && value != "" {
		return value
	}
	return ""
}

// refreshClient re-creates the underlying GitHub API client using the latest token.
// Call this at the start of each request to pick up token changes without restart.
func (c *Client) refreshClient() {
	token := resolveToken(c.db)
	if token != "" {
		ctx := context.Background()
		ts := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: token})
		c.client = github.NewClient(oauth2.NewClient(ctx, ts))
	} else {
		c.client = github.NewClient(nil)
	}
	applyGitHubAPIBase(c.client)
}

// repoFromURL extracts "owner/repo" from a GitHub HTML URL.
func repoFromURL(u string) string {
	u = strings.TrimPrefix(u, "https://github.com/")
	parts := strings.SplitN(u, "/", 3)
	if len(parts) >= 2 {
		return parts[0] + "/" + parts[1]
	}
	return u
}

// firstLine returns the first line of s.
func firstLine(s string) string {
	if idx := strings.IndexByte(s, '\n'); idx != -1 {
		return s[:idx]
	}
	return s
}

// isRateLimitError returns true when the error is a GitHub rate-limit or abuse-rate-limit error.
func isRateLimitError(err error) bool {
	if err == nil {
		return false
	}
	if _, ok := err.(*github.RateLimitError); ok {
		return true
	}
	if _, ok := err.(*github.AbuseRateLimitError); ok {
		return true
	}
	return false
}

// GetUserActivity collects GitHub metrics for a single user account.
func (c *Client) GetUserActivity(ctx context.Context, username string) ([]*pb.DevActivity, []*pb.ActivityDetail, []string, error) {
	c.refreshClient()
	log.Printf("Fetching GitHub activity for user: %s", username)

	activityTypes, err := c.fetchActivityTypes(ctx)
	if err != nil {
		log.Printf("Error fetching activity types: %v", err)
	}
	criteria, err := c.fetchCriteria(ctx)
	if err != nil {
		log.Printf("Error fetching criteria: %v", err)
	}

	activities := make(map[string]map[string]int32) // [checkKey][date] = count
	activityTitle := make(map[string]string)
	for _, t := range activityTypes {
		activities[t.CheckKey] = make(map[string]int32)
		activityTitle[t.CheckKey] = t.Title
	}

	criteriaSet := make(map[string]bool)
	criteriaTitle := make(map[string]string)
	for _, cr := range criteria {
		criteriaSet[cr.CheckKey] = false
		criteriaTitle[cr.CheckKey] = cr.Title
	}

	now := time.Now().Format("2006-01-02")
	var details []*pb.ActivityDetail

	// 1. Basic user info (snapshot metrics, no individual items)
	user, _, err := c.client.Users.Get(ctx, username)
	if err != nil && isRateLimitError(err) {
		return nil, nil, nil, fmt.Errorf("rate_limit: превышен лимит запросов GitHub API. Добавьте или обновите GitHub токен в настройках")
	}
	if err == nil {
		setActivity(activities, "followers", now, int32(user.GetFollowers()))
		setActivity(activities, "public_repos", now, int32(user.GetPublicRepos()))
		setActivity(activities, "gists", now, int32(user.GetPublicGists()))
	}

	// searchAndGroup runs a GitHub issue/PR search, groups by date, and collects individual items.
	searchAndGroup := func(query, activityCheckKey string, criterionCheckKeys ...string) {
		opts := &github.SearchOptions{ListOptions: github.ListOptions{PerPage: 100}}
		results, _, err := c.client.Search.Issues(ctx, query, opts)
		if err != nil || results == nil {
			return
		}
		for _, item := range results.Issues {
			date := item.GetCreatedAt().Time.Format("2006-01-02")
			if _, ok := activities[activityCheckKey]; ok {
				activities[activityCheckKey][date]++
			}
			htmlURL := item.GetHTMLURL()
			details = append(details, &pb.ActivityDetail{
				ActivityType: activityCheckKey,
				ExternalId:   strconv.Itoa(int(item.GetNumber())),
				Title:        item.GetTitle(),
				Repository:   repoFromURL(htmlURL),
				Url:          htmlURL,
				Date:         date,
				State:        item.GetState(),
			})
		}
		if results.GetTotal() > 0 {
			for _, ck := range criterionCheckKeys {
				setCriterion(criteriaSet, ck)
			}
		}
	}

	// 2. PRs / Issues / Code Reviews / Contributions
	searchAndGroup(fmt.Sprintf("author:%s type:pr", username), "pull_requests", "uses_prs")
	searchAndGroup(fmt.Sprintf("author:%s type:pr is:merged", username), "merged_prs")
	searchAndGroup(fmt.Sprintf("author:%s type:issue", username), "issues", "uses_issues")
	searchAndGroup(fmt.Sprintf("commenter:%s type:pr", username), "code_reviews", "has_code_review")
	searchAndGroup(fmt.Sprintf("author:%s is:public", username), "contributions")

	// 3. Repository stats (stars, forks, criteria from tree)
	opts := &github.RepositoryListOptions{
		Sort:        "updated",
		Direction:   "desc",
		ListOptions: github.ListOptions{PerPage: 30},
	}
	repos, _, err := c.client.Repositories.List(ctx, username, opts)
	if err == nil {
		var totalStars, totalForks int
		for _, repo := range repos {
			if repo.GetFork() {
				continue
			}
			totalStars += repo.GetStargazersCount()
			totalForks += repo.GetForksCount()

			checkRepoThresholds(repo.GetStargazersCount(), repo.GetForksCount(),
				repo.GetWatchersCount(), criteriaSet)

			if len(repo.Topics) > 0 {
				setCriterion(criteriaSet, "has_topics")
			}
			if repo.GetHasWiki() {
				setCriterion(criteriaSet, "has_wiki")
			}
			if repo.GetHasPages() {
				setCriterion(criteriaSet, "has_pages")
			}
			if repo.GetHasDiscussions() {
				setCriterion(criteriaSet, "has_discussions")
			}

			tree, _, err := c.client.Git.GetTree(ctx, repo.GetOwner().GetLogin(),
				repo.GetName(), repo.GetDefaultBranch(), false)
			if err == nil {
				checkTreeEntries(tree.Entries, repo.GetSize(), criteriaSet)
				if len(tree.Entries) > 3 {
					setCriterion(criteriaSet, "has_dir_structure")
				}
			}

			// Releases — collect individual items
			rels, _, err := c.client.Repositories.ListReleases(ctx,
				repo.GetOwner().GetLogin(), repo.GetName(),
				&github.ListOptions{PerPage: 10})
			if err == nil && len(rels) > 0 {
				setCriterion(criteriaSet, "has_releases")
				setActivity(activities, "releases", now, int32(len(rels)))
				checkReleasesThreshold(len(rels), criteriaSet)
				for _, rel := range rels {
					date := now
					if t := rel.GetPublishedAt(); !t.Time.IsZero() {
						date = t.Time.Format("2006-01-02")
					}
					details = append(details, &pb.ActivityDetail{
						ActivityType: "releases",
						ExternalId:   rel.GetTagName(),
						Title:        rel.GetName(),
						Repository:   repo.GetFullName(),
						Url:          rel.GetHTMLURL(),
						Date:         date,
					})
				}
			}
		}

		setActivity(activities, "stars", now, int32(totalStars))
		setActivity(activities, "forks", now, int32(totalForks))
	}

	// 4. Commits — collect individual items
	commits, _, err := c.client.Search.Commits(ctx,
		fmt.Sprintf("author:%s", username),
		&github.SearchOptions{ListOptions: github.ListOptions{PerPage: 100}})
	if err == nil && commits != nil {
		for _, commit := range commits.Commits {
			date := commit.GetCommit().GetCommitter().GetDate().Time.Format("2006-01-02")
			setActivity(activities, "commits", date, 1)
			sha := commit.GetSHA()
			details = append(details, &pb.ActivityDetail{
				ActivityType: "commits",
				ExternalId:   sha,
				Title:        firstLine(commit.GetCommit().GetMessage()),
				Repository:   commit.GetRepository().GetFullName(),
				Url:          commit.GetHTMLURL(),
				Date:         date,
			})
		}
	}

	resActivities, resCriteria, err := buildResults(activities, activityTitle, criteriaSet, criteriaTitle)
	return resActivities, details, resCriteria, err
}

// GetRepoActivity collects GitHub metrics for a single repository (team-level).
func (c *Client) GetRepoActivity(ctx context.Context, repoURL string) ([]*pb.DevActivity, []*pb.ActivityDetail, []string, error) {
	c.refreshClient()
	log.Printf("Fetching GitHub activity for repo: %s", repoURL)

	parts := strings.Split(strings.TrimSuffix(strings.TrimPrefix(repoURL, "https://github.com/"), "/"), "/")
	if len(parts) < 2 {
		return nil, nil, nil, fmt.Errorf("invalid github repo url: %s", repoURL)
	}
	owner, repoName := parts[0], parts[1]

	activityTypes, _ := c.fetchActivityTypes(ctx)
	criteria, _ := c.fetchCriteria(ctx)

	activities := make(map[string]map[string]int32)
	activityTitle := make(map[string]string)
	for _, t := range activityTypes {
		activities[t.CheckKey] = make(map[string]int32)
		activityTitle[t.CheckKey] = t.Title
	}

	criteriaSet := make(map[string]bool)
	criteriaTitle := make(map[string]string)
	for _, cr := range criteria {
		criteriaSet[cr.CheckKey] = false
		criteriaTitle[cr.CheckKey] = cr.Title
	}

	now := time.Now().Format("2006-01-02")
	repoFull := fmt.Sprintf("%s/%s", owner, repoName)
	var details []*pb.ActivityDetail

	// 1. Repo object
	repo, _, err := c.client.Repositories.Get(ctx, owner, repoName)
	if err != nil {
		if isRateLimitError(err) {
			return nil, nil, nil, fmt.Errorf("rate_limit: превышен лимит запросов GitHub API. Добавьте или обновите GitHub токен в настройках")
		}
		return nil, nil, nil, fmt.Errorf("failed to get repo: %v", err)
	}

	setActivity(activities, "stars", now, int32(repo.GetStargazersCount()))
	setActivity(activities, "forks", now, int32(repo.GetForksCount()))
	setActivity(activities, "watchers", now, int32(repo.GetWatchersCount()))
	setActivity(activities, "open_issues", now, int32(repo.GetOpenIssuesCount()))
	setActivity(activities, "repo_size", now, int32(repo.GetSize()))

	checkRepoThresholds(repo.GetStargazersCount(), repo.GetForksCount(),
		repo.GetWatchersCount(), criteriaSet)

	if len(repo.Topics) > 0 {
		setCriterion(criteriaSet, "has_topics")
	}
	if repo.GetHasWiki() {
		setCriterion(criteriaSet, "has_wiki")
	}
	if repo.GetHasPages() {
		setCriterion(criteriaSet, "has_pages")
	}
	if repo.GetHasDiscussions() {
		setCriterion(criteriaSet, "has_discussions")
	}

	// 2. Git tree
	tree, _, err := c.client.Git.GetTree(ctx, owner, repoName, repo.GetDefaultBranch(), false)
	if err == nil {
		checkTreeEntries(tree.Entries, repo.GetSize(), criteriaSet)
		if len(tree.Entries) > 3 {
			setCriterion(criteriaSet, "has_dir_structure")
		}
	}

	// 3. Releases
	rels, _, err := c.client.Repositories.ListReleases(ctx, owner, repoName,
		&github.ListOptions{PerPage: 20})
	if err == nil {
		setActivity(activities, "releases", now, int32(len(rels)))
		if len(rels) > 0 {
			setCriterion(criteriaSet, "has_releases")
			checkReleasesThreshold(len(rels), criteriaSet)
			for _, rel := range rels {
				date := now
				if t := rel.GetPublishedAt(); !t.Time.IsZero() {
					date = t.Time.Format("2006-01-02")
				}
				details = append(details, &pb.ActivityDetail{
					ActivityType: "releases",
					ExternalId:   rel.GetTagName(),
					Title:        rel.GetName(),
					Repository:   repoFull,
					Url:          rel.GetHTMLURL(),
					Date:         date,
				})
			}
		}
	}

	// 4. Contributors
	contributors, _, err := c.client.Repositories.ListContributors(ctx, owner, repoName,
		&github.ListContributorsOptions{ListOptions: github.ListOptions{PerPage: 100}})
	if err == nil {
		count := len(contributors)
		setActivity(activities, "contributor_count", now, int32(count))
		checkContributorsThreshold(count, criteriaSet)
	}

	// 5. PRs, Issues, Commits, Code Reviews
	repoFilter := fmt.Sprintf("repo:%s/%s", owner, repoName)

	searchCount := func(query, activityCheckKey string, criterionCheckKeys ...string) {
		opts := &github.SearchOptions{ListOptions: github.ListOptions{PerPage: 100}}
		results, _, err := c.client.Search.Issues(ctx, query, opts)
		if err != nil || results == nil {
			return
		}
		for _, item := range results.Issues {
			date := item.GetCreatedAt().Time.Format("2006-01-02")
			if _, ok := activities[activityCheckKey]; ok {
				activities[activityCheckKey][date]++
			}
			htmlURL := item.GetHTMLURL()
			details = append(details, &pb.ActivityDetail{
				ActivityType: activityCheckKey,
				ExternalId:   strconv.Itoa(int(item.GetNumber())),
				Title:        item.GetTitle(),
				Repository:   repoFull,
				Url:          htmlURL,
				Date:         date,
				State:        item.GetState(),
			})
		}
		if results.GetTotal() > 0 {
			for _, ck := range criterionCheckKeys {
				setCriterion(criteriaSet, ck)
			}
		}
	}

	searchCount(repoFilter+" type:pr", "pull_requests", "uses_prs")
	searchCount(repoFilter+" type:pr is:merged", "merged_prs")
	searchCount(repoFilter+" type:issue", "issues", "uses_issues")
	searchCount(repoFilter+" type:issue is:closed", "closed_issues")
	searchCount(repoFilter+" type:pr is:merged review:approved", "code_reviews", "has_code_review")

	commits, _, err := c.client.Search.Commits(ctx, repoFilter,
		&github.SearchOptions{ListOptions: github.ListOptions{PerPage: 100}})
	if err == nil && commits != nil {
		for _, commit := range commits.Commits {
			date := commit.GetCommit().GetCommitter().GetDate().Time.Format("2006-01-02")
			setActivity(activities, "commits", date, 1)
			sha := commit.GetSHA()
			details = append(details, &pb.ActivityDetail{
				ActivityType: "commits",
				ExternalId:   sha,
				Title:        firstLine(commit.GetCommit().GetMessage()),
				Repository:   repoFull,
				Url:          commit.GetHTMLURL(),
				Date:         date,
			})
		}
	}

	resActivities, resCriteria, err := buildResults(activities, activityTitle, criteriaSet, criteriaTitle)
	return resActivities, details, resCriteria, err
}

// --- Helpers ---

func setCriterion(criteriaSet map[string]bool, checkKey string) {
	if _, ok := criteriaSet[checkKey]; ok {
		criteriaSet[checkKey] = true
	}
}

func setActivity(activities map[string]map[string]int32, checkKey, date string, count int32) {
	if _, ok := activities[checkKey]; ok {
		activities[checkKey][date] += count
	}
}

func checkRepoThresholds(stars, forks, watchers int, criteriaSet map[string]bool) {
	if stars > 10 {
		setCriterion(criteriaSet, "popular_stars_10")
	}
	if stars > 50 {
		setCriterion(criteriaSet, "popular_stars_50")
	}
	if stars > 100 {
		setCriterion(criteriaSet, "popular_stars_100")
	}
	if forks > 5 {
		setCriterion(criteriaSet, "active_forks_5")
	}
	if forks > 20 {
		setCriterion(criteriaSet, "active_forks_20")
	}
	if watchers > 10 {
		setCriterion(criteriaSet, "many_watchers_10")
	}
}

func checkContributorsThreshold(count int, criteriaSet map[string]bool) {
	if count > 1 {
		setCriterion(criteriaSet, "multi_contributor")
	}
	if count > 3 {
		setCriterion(criteriaSet, "many_contributors_3")
	}
	if count > 10 {
		setCriterion(criteriaSet, "many_contributors_10")
	}
}

func checkReleasesThreshold(count int, criteriaSet map[string]bool) {
	if count > 5 {
		setCriterion(criteriaSet, "many_releases_5")
	}
}

func checkTreeEntries(entries []*github.TreeEntry, repoSize int, criteriaSet map[string]bool) {
	for _, entry := range entries {
		path := strings.ToLower(entry.GetPath())

		if entry.GetType() == "blob" && repoSize > 0 {
			setCriterion(criteriaSet, "has_code")
		}
		if strings.HasPrefix(path, "readme") {
			setCriterion(criteriaSet, "has_readme")
		}
		if strings.HasPrefix(path, "license") || strings.HasPrefix(path, "copying") {
			setCriterion(criteriaSet, "has_license")
		}
		if strings.HasPrefix(path, "contributing") {
			setCriterion(criteriaSet, "has_contributing")
		}
		if strings.Contains(path, "test") || strings.Contains(path, "spec") {
			setCriterion(criteriaSet, "has_tests")
		}
		if strings.Contains(path, "example") || strings.Contains(path, "demo") {
			setCriterion(criteriaSet, "has_examples")
		}
		if strings.HasPrefix(path, ".github/workflows") {
			setCriterion(criteriaSet, "has_cicd")
		}
		if strings.HasPrefix(path, "security") || path == ".github/security.md" {
			setCriterion(criteriaSet, "has_security_policy")
		}
		if strings.HasPrefix(path, "changelog") || strings.HasPrefix(path, "changes") || strings.HasPrefix(path, "history") {
			setCriterion(criteriaSet, "has_changelog")
		}
		if path == "dockerfile" || strings.HasPrefix(path, "docker/") {
			setCriterion(criteriaSet, "has_dockerfile")
		}
		if path == ".github/dependabot.yml" || path == ".github/dependabot.yaml" {
			setCriterion(criteriaSet, "has_dependabot")
		}
		if strings.HasPrefix(path, "code_of_conduct") || path == ".github/code_of_conduct.md" {
			setCriterion(criteriaSet, "has_code_of_conduct")
		}
	}
}

func buildResults(
	activities map[string]map[string]int32,
	activityTitle map[string]string,
	criteriaSet map[string]bool,
	criteriaTitle map[string]string,
) ([]*pb.DevActivity, []string, error) {
	resActivities := make([]*pb.DevActivity, 0)
	for checkKey, dates := range activities {
		title, ok := activityTitle[checkKey]
		if !ok {
			continue
		}
		for date, count := range dates {
			if count > 0 {
				resActivities = append(resActivities, &pb.DevActivity{
					ActivityType: title,
					Count:        count,
					Date:         date,
				})
			}
		}
	}

	resCriteria := make([]string, 0)
	for checkKey, met := range criteriaSet {
		if met {
			if title, ok := criteriaTitle[checkKey]; ok {
				resCriteria = append(resCriteria, title)
			}
		}
	}

	return resActivities, resCriteria, nil
}

func (c *Client) fetchActivityTypes(ctx context.Context) ([]activityTypeDef, error) {
	rows, err := c.db.QueryContext(ctx,
		"SELECT check_key, title FROM dev_employee_activity_types WHERE check_key IS NOT NULL AND check_key != ''")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []activityTypeDef
	for rows.Next() {
		var d activityTypeDef
		if err := rows.Scan(&d.CheckKey, &d.Title); err != nil {
			return nil, err
		}
		result = append(result, d)
	}
	return result, nil
}

func (c *Client) fetchCriteria(ctx context.Context) ([]criterionDef, error) {
	rows, err := c.db.QueryContext(ctx,
		"SELECT check_key, title FROM dev_project_criteria WHERE check_key IS NOT NULL AND check_key != ''")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []criterionDef
	for rows.Next() {
		var d criterionDef
		if err := rows.Scan(&d.CheckKey, &d.Title); err != nil {
			return nil, err
		}
		result = append(result, d)
	}
	return result, nil
}
