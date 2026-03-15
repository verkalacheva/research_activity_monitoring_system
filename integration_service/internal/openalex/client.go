package openalex

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"integration_service/pb"
)

type Client struct {
	httpClient *http.Client
}

func NewClient() *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

// FetchAchievements implements the integrations.Provider interface
func (c *Client) FetchAchievements(ctx context.Context, externalID string) ([]*pb.Achievement, error) {
	return c.FetchWorks(externalID)
}

type OpenAlexWorksResponse struct {
	Results []struct {
		Title       string   `json:"title"`
		Type        string   `json:"type"`
		Ids         struct {
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
	} `json:"results"`
}

func (c *Client) FetchWorks(openAlexID string) ([]*pb.Achievement, error) {
	// OpenAlex ID can be a full URL or just the ID. Ensure we only use the ID part.
	// Example: https://openalex.org/A5023888336 -> A5023888336
	u, err := url.Parse(openAlexID)
	if err == nil && u.Host == "openalex.org" {
		openAlexID = u.Path[1:] // strip leading slash
	}

	apiUrl := fmt.Sprintf("https://api.openalex.org/works?filter=author.id:%s", openAlexID)
	req, err := http.NewRequest("GET", apiUrl, nil)
	if err != nil {
		return nil, err
	}
	
	// OpenAlex best practice: include mailto for faster response
	req.Header.Set("User-Agent", "ResearchActivityMonitoringSystem/1.0 (mailto:admin@example.com)")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("openalex api returned status %d", resp.StatusCode)
	}

	var worksResp OpenAlexWorksResponse
	if err := json.NewDecoder(resp.Body).Decode(&worksResp); err != nil {
		return nil, err
	}

	var achievements []*pb.Achievement
	for _, work := range worksResp.Results {
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

	return achievements, nil
}
