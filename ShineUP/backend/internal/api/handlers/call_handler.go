package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type CallHandler struct{}

func NewCallHandler() *CallHandler {
	return &CallHandler{}
}

// GetMockCallRecordings returns a list of mock VoIP intercepts between SP and Customers
func (h *CallHandler) GetMockCallRecordings(c *gin.Context) {
	// Generate some simulated recordings
	type Recording struct {
		ID        string `json:"id"`
		Customer  string `json:"customer"`
		Partner   string `json:"partner"`
		Duration  int    `json:"duration_seconds"`
		AudioURL  string `json:"audio_url"`
		CreatedAt string `json:"created_at"`
	}

	recordings := []Recording{
		{
			ID:        "REC-1001",
			Customer:  "+91 9876543210",
			Partner:   "+91 8888888888",
			Duration:  45,
			AudioURL:  "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
			CreatedAt: time.Now().Add(-2 * time.Hour).Format(time.RFC3339),
		},
		{
			ID:        "REC-1002",
			Customer:  "+91 9999999999",
			Partner:   "+91 7777777777",
			Duration:  12,
			AudioURL:  "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
			CreatedAt: time.Now().Add(-5 * time.Hour).Format(time.RFC3339),
		},
	}

	c.JSON(http.StatusOK, recordings)
}
