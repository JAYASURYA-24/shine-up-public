package database

import (
	"context"
	"github.com/redis/go-redis/v9"
	"log"
)

func NewRedisConnection(url string) (*redis.Client, error) {
	// If URL is empty, default to local redis for development ease
	if url == "" {
		url = "redis://localhost:6379/0"
	}
	
	opts, err := redis.ParseURL(url)
	if err != nil {
		return nil, err
	}

	client := redis.NewClient(opts)

	// Create context to test connection
	ctx := context.Background()
	_, err = client.Ping(ctx).Result()
	if err != nil {
		return nil, err
	}

	log.Println("Connected to Redis successfully")
	return client, nil
}
