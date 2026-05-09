package orcid

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"integration_service/pb"
)

var (
	reOrcidSandboxURL = regexp.MustCompile(`(?i)^https?://sandbox\.orcid\.org/+`)
	reOrcidProdURL    = regexp.MustCompile(`(?i)^https?://(?:www\.)?orcid\.org/+`)
	reOrcidBare       = regexp.MustCompile(`(?i)^(\d{4}-\d{4}-\d{4}-\d{3}[\dX])$`)
	reOrcidFind       = regexp.MustCompile(`(?i)\b(\d{4}-\d{4}-\d{4}-\d{3}[\dX])\b`)
	reOrcidSpaces     = regexp.MustCompile(`\s+`)
)

// NormalizeOrcidID mirrors backend import normalization: canonical lowercase id or empty if invalid.
func NormalizeOrcidID(raw string) string {
	s := strings.TrimPrefix(strings.TrimSpace(raw), "\uFEFF")
	if s == "" {
		return ""
	}
	s = reOrcidSandboxURL.ReplaceAllString(s, "")
	s = reOrcidProdURL.ReplaceAllString(s, "")
	s = strings.NewReplacer(
		"\u2013", "-",
		"\u2014", "-",
		"\u2212", "-",
	).Replace(s)
	s = reOrcidSpaces.ReplaceAllString(s, "-")
	s = strings.TrimRight(s, "/")
	if m := reOrcidBare.FindStringSubmatch(s); len(m) > 1 {
		return strings.ToLower(m[1])
	}
	if m := reOrcidFind.FindStringSubmatch(s); len(m) > 1 {
		return strings.ToLower(m[1])
	}
	return ""
}

// EnvOrcidPubAPIBase is the public ORCID REST root (no trailing slash), e.g. https://pub.orcid.org/v3.0.
// Override via ORCID_PUB_API_BASE (e.g. sandbox: https://pub.sandbox.orcid.org/v3.0).
const EnvOrcidPubAPIBase = "ORCID_PUB_API_BASE"

const defaultOrcidPubAPIBase = "https://pub.orcid.org/v3.0"

func PubAPIBaseFromEnv() string {
	v := strings.TrimSpace(os.Getenv(EnvOrcidPubAPIBase))
	if v == "" {
		return defaultOrcidPubAPIBase
	}
	return strings.TrimRight(v, "/")
}

type Client struct {
	httpClient *http.Client
	pubAPIBase string // e.g. https://pub.orcid.org/v3.0
}

func NewClient() *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
		pubAPIBase: PubAPIBaseFromEnv(),
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
	canonical := NormalizeOrcidID(orcidID)
	if canonical == "" {
		return nil, fmt.Errorf("invalid or empty ORCID after normalization")
	}
	orcidID = canonical

	// 1. Get summaries to get put-codes
	summaryURL := fmt.Sprintf("%s/%s/works", c.pubAPIBase, orcidID)
	req, err := http.NewRequest("GET", summaryURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		log.Printf("[orcid] summary 404 for %s — not in public registry, private, or invalid; skipping", orcidID)
		return []*pb.Achievement{}, nil
	}
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
	detailURL := fmt.Sprintf("%s/%s/works/%s", c.pubAPIBase, orcidID, strings.Join(putCodes, ","))
	req, err = http.NewRequest("GET", detailURL, nil)
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
