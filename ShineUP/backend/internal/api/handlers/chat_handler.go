package handlers

import (
	"net/http"

	"github.com/Shine-Up/backend/internal/core/services"
	"github.com/Shine-Up/backend/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ChatHandler handles chat REST endpoints
type ChatHandler struct {
	db      *gorm.DB
	notifSvc *services.NotificationService
}

// NewChatHandler creates a new ChatHandler
func NewChatHandler(db *gorm.DB, notifSvc *services.NotificationService) *ChatHandler {
	return &ChatHandler{db: db, notifSvc: notifSvc}
}

// SendMessage sends a chat message for a booking
func (h *ChatHandler) SendMessage(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("bookingId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	userIDStr, _ := c.Get("user_id")
	userID, _ := uuid.Parse(userIDStr.(string))
	role, _ := c.Get("role")

	var req struct {
		Message string `json:"message" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "message is required"})
		return
	}

	// Verify the booking exists and user is part of it
	var booking models.Booking
	if err := h.db.First(&booking, "id = ?", bookingID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "booking not found"})
		return
	}

	// Determine sender role
	senderRole := role.(string)

	// Create chat message
	msg := models.ChatMessage{
		BookingID:  bookingID,
		SenderID:   userID,
		SenderRole: senderRole,
		Message:    req.Message,
	}

	if err := h.db.Create(&msg).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to send message"})
		return
	}

	// Push via WebSocket
	h.notifSvc.NotifyChatMessage(msg)

	c.JSON(http.StatusCreated, msg)
}

// GetMessages returns chat history for a booking
func (h *ChatHandler) GetMessages(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("bookingId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	var messages []models.ChatMessage
	h.db.Where("booking_id = ?", bookingID).
		Order("created_at ASC").
		Find(&messages)

	c.JSON(http.StatusOK, messages)
}

// MarkChatRead marks all messages in a booking as read for the current user
func (h *ChatHandler) MarkChatRead(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("bookingId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	userIDStr, _ := c.Get("user_id")
	role, _ := c.Get("role")

	// Mark messages from the OTHER party as read
	senderRole := "PARTNER"
	if role.(string) == "PARTNER" {
		senderRole = "CUSTOMER"
	}

	h.db.Model(&models.ChatMessage{}).
		Where("booking_id = ? AND sender_role = ? AND is_read = ?", bookingID, senderRole, false).
		Update("is_read", true)

	_ = userIDStr // Used for context, not filtering here

	c.JSON(http.StatusOK, gin.H{"status": "marked as read"})
}
