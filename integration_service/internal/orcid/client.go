package orcid

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
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

type OrcidSummaryResponse struct {
	Group []struct {
		WorkSummary []struct {
			PutCode int64 `json:"put-code"`
		} `json:"work-summary"`
	} `json:"group"`
}

type OrcidDetailResponse struct {
	Bulk []struct {
		Work struct {
			Title struct {
				Title struct {
					Value string `json:"value"`
				} `json:"title"`
			} `json:"title"`
			Type         string `json:"type"`
			JournalTitle struct {
				Value string `json:"value"`
			} `json:"journal-title"`
			ExternalIds struct {
				ExternalId []struct {
					ExternalIdValue string `json:"external-id-value"`
					ExternalIdType  string `json:"external-id-type"`
					ExternalIdUrl   struct {
						Value string `json:"value"`
					} `json:"external-id-url"`
				} `json:"external-id"`
			} `json:"external-ids"`
			PublicationDate struct {
				Year struct {
					Value string `json:"value"`
				} `json:"year"`
			} `json:"publication-date"`
			ShortDescription string `json:"short-description"`
			Contributors     struct {
				Contributor []interface{} `json:"contributor"`
			} `json:"contributors"`
			Source struct {
				SourceName struct {
					Value string `json:"value"`
				} `json:"source-name"`
			} `json:"source"`
		} `json:"work"`
	} `json:"bulk"`
}

func (c *Client) FetchWorks(orcidID string) ([]*pb.Achievement, error) {
	// 1. Get summaries to get put-codes
	summaryUrl := fmt.Sprintf("https://pub.orcid.org/v3.0/%s/works", orcidID)
	req, err := http.NewRequest("GET", summaryUrl, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("orcid summary api returned status %d", resp.StatusCode)
	}

	var summaryResp OrcidSummaryResponse
	if err := json.NewDecoder(resp.Body).Decode(&summaryResp); err != nil {
		return nil, err
	}

	var putCodes []string
	for _, group := range summaryResp.Group {
		for _, s := range group.WorkSummary {
			putCodes = append(putCodes, fmt.Sprintf("%d", s.PutCode))
		}
	}

	if len(putCodes) == 0 {
		return nil, nil
	}

	// Bulk API limit is 50 works per call
	if len(putCodes) > 50 {
		putCodes = putCodes[:50]
	}

	// 2. Get full details in bulk to get contributors
	detailUrl := fmt.Sprintf("https://pub.orcid.org/v3.0/%s/works/%s", orcidID, strings.Join(putCodes, ","))
	req, err = http.NewRequest("GET", detailUrl, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err = c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("orcid detail api returned status %d", resp.StatusCode)
	}

	var detailResp OrcidDetailResponse
	if err := json.NewDecoder(resp.Body).Decode(&detailResp); err != nil {
		return nil, err
	}

	var achievements []*pb.Achievement
	for _, item := range detailResp.Bulk {
		w := item.Work

		description := w.ShortDescription
		if description == "" {
			description = w.Source.SourceName.Value
		}

		achievement := &pb.Achievement{
			Title:        w.Title.Title.Value,
			Type:         w.Type,
			Date:         w.PublicationDate.Year.Value,
			AuthorCount:  int32(len(w.Contributors.Contributor)),
			JournalTitle: w.JournalTitle.Value,
			Description:  description,
		}

		if len(w.ExternalIds.ExternalId) > 0 {
			achievement.ExternalId = w.ExternalIds.ExternalId[0].ExternalIdValue
			achievement.Url = w.ExternalIds.ExternalId[0].ExternalIdUrl.Value
		}

		achievements = append(achievements, achievement)
	}

	return achievements, nil
}
