package integrations

import (
	"context"
	"integration_service/pb"
)

type Provider interface {
	FetchAchievements(ctx context.Context, externalID string) ([]*pb.Achievement, error)
}
