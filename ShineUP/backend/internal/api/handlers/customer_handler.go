package handlers

import (
	"net/http"
	"time"

	"github.com/Shine-Up/backend/internal/core/services"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type CustomerHandler struct {
	customerService *services.CustomerService
}

func NewCustomerHandler(cs *services.CustomerService) *CustomerHandler {
	return &CustomerHandler{customerService: cs}
}

// ─── Profile ─────────────────────────────────────────────

func (h *CustomerHandler) GetProfile(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	profile, err := h.customerService.GetProfile(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, profile)
}

func (h *CustomerHandler) UpdateProfile(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req struct {
		Name     string `json:"name"`
		Email    string `json:"email"`
		Location string `json:"location"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload"})
		return
	}

	profile, err := h.customerService.UpdateProfile(c.Request.Context(), userID, req.Name, req.Email, req.Location)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, profile)
}

// ─── Bookings ────────────────────────────────────────────

func (h *CustomerHandler) ListBookings(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookings, err := h.customerService.ListMyBookings(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, bookings)
}

func (h *CustomerHandler) GetBookingDetail(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	booking, err := h.customerService.GetBookingDetail(c.Request.Context(), userID, bookingID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, booking)
}

func (h *CustomerHandler) CancelBooking(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	var req struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&req)

	if err := h.customerService.CancelBooking(c.Request.Context(), userID, bookingID, req.Reason); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "booking cancelled successfully"})
}

func (h *CustomerHandler) RescheduleBooking(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	var req struct {
		NewSlotStart string `json:"new_slot_start" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "new_slot_start is required (RFC3339)"})
		return
	}

	newTime, err := time.Parse(time.RFC3339, req.NewSlotStart)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid time format"})
		return
	}

	if err := h.customerService.RescheduleBooking(c.Request.Context(), userID, bookingID, newTime); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "booking rescheduled successfully"})
}

// ─── Rating ──────────────────────────────────────────────

func (h *CustomerHandler) RateBooking(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	var req struct {
		Stars  int    `json:"stars" binding:"required"`
		Review string `json:"review"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "stars is required (1-5)"})
		return
	}

	if req.Stars < 1 || req.Stars > 5 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "stars must be between 1 and 5"})
		return
	}

	if err := h.customerService.RateBooking(c.Request.Context(), userID, bookingID, req.Stars, req.Review); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "thank you for your rating!"})
}

// ─── Wallet ──────────────────────────────────────────────

func (h *CustomerHandler) GetWallet(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	balance, txns, err := h.customerService.GetWallet(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"balance":      balance,
		"transactions": txns,
	})
}

func (h *CustomerHandler) ApplyReferral(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req struct {
		ReferralCode string `json:"referral_code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "referral_code is required"})
		return
	}

	if err := h.customerService.ApplyReferral(c.Request.Context(), userID, req.ReferralCode); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "referral applied! ₹50 credited to your wallet"})
}

// ─── Notifications ───────────────────────────────────────

func (h *CustomerHandler) ListNotifications(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	notifications, err := h.customerService.ListNotifications(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, notifications)
}
