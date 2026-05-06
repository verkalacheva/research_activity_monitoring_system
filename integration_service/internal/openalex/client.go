package openalex

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"integration_service/pb"
)

const (
	perPageOpenAlex    = 200
	maxOpenAlexPages   = 5000 // защита от бесконечного cursor
	EnvOpenAlexAPIBase = "OPENALEX_API_BASE"
)

const defaultOpenAlexAPIBase = "https://api.openalex.org"

// APIBaseFromEnv returns OpenAlex REST root without trailing slash (e.g. https://api.openalex.org).
func APIBaseFromEnv() string {
	v := strings.TrimSpace(os.Getenv(EnvOpenAlexAPIBase))
	if v == "" {
		return defaultOpenAlexAPIBase
	}
	return strings.TrimRight(v, "/")
}

type Client struct {
	httpClient *http.Client
	apiBase    string // e.g. https://api.openalex.org
}

func NewClient() *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: 120 * time.Second,
		},
		apiBase: APIBaseFromEnv(),
	}
}

// FetchAchievements implements the integrations.Provider interface
func (c *Client) FetchAchievements(ctx context.Context, externalID string) ([]*pb.Achievement, error) {
	return c.FetchWorks(ctx, externalID)
}

type workEntry struct {
	Title string `json:"title"`
	Type  string `json:"type"`
	Ids   struct {
		Openalex string `json:"openalex"`
		Doi      string `json:"doi"`
	} `json:"ids"`
	PublicationYear int `json:"publication_year"`
	Authorships     []struct {
		Author struct {
			DisplayName string `json:"display_name"`
		} `json:"author"`
	} `json:"authorships"`
	PrimaryLocation struct {
		Source struct {
			DisplayName string `json:"display_name"`
		} `json:"source"`
		LandingPageUrl string `json:"landing_page_url"`
	} `json:"primary_location"`
}

type openAlexWorksPage struct {
	Meta struct {
		NextCursor *string `json:"next_cursor"`
	} `json:"meta"`
	Results []workEntry `json:"results"`
}

func (c *Client) FetchWorks(ctx context.Context, openAlexID string) ([]*pb.Achievement, error) {
	u, err := url.Parse(openAlexID)
	if err == nil && u.Host == "openalex.org" {
		openAlexID = u.Path[1:]
	}

	var cursor string
	var achievements []*pb.Achievement

	for page := 0; page < maxOpenAlexPages; page++ {
		u, err := url.Parse(fmt.Sprintf("%s/works", c.apiBase))
		if err != nil {
			return nil, err
		}
		q := u.Query()
		q.Set("filter", "author.id:"+openAlexID)
		q.Set("per_page", fmt.Sprintf("%d", perPageOpenAlex))
		if cursor != "" {
			q.Set("cursor", cursor)
		}
		u.RawQuery = q.Encode()

		req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("User-Agent", "ResearchActivityMonitoringSystem/1.0 (mailto:openalex@example.org)")

		resp, err := c.httpClient.Do(req)
		if err != nil {
			return nil, err
		}

		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			return nil, fmt.Errorf("openalex api returned status %d", resp.StatusCode)
		}

		var worksPage openAlexWorksPage
		if err := json.NewDecoder(resp.Body).Decode(&worksPage); err != nil {
			resp.Body.Close()
			return nil, err
		}
		resp.Body.Close()

		for _, work := range worksPage.Results {
			achievement := &pb.Achievement{
				Title:        work.Title,
				Type:         work.Type,
				Date:         fmt.Sprintf("%d", work.PublicationYear),
				AuthorCount:  int32(len(work.Authorships)),
				JournalTitle: work.PrimaryLocation.Source.DisplayName,
				ExternalId:   work.Ids.Doi,
				Url:          work.PrimaryLocation.LandingPageUrl,
			}
			if achievement.ExternalId == "" {
				achievement.ExternalId = work.Ids.Openalex
			}
			achievements = append(achievements, achievement)
		}

		if worksPage.Meta.NextCursor == nil || *worksPage.Meta.NextCursor == "" {
			break
		}
		cursor = *worksPage.Meta.NextCursor
	}

	return achievements, nil
}
