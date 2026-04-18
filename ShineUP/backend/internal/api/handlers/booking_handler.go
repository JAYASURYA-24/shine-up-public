package handlers

import (
	"net/http"
	"time"

	"github.com/Shine-Up/backend/internal/core/services"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type BookingHandler struct {
	bookingService *services.BookingService
}

func NewBookingHandler(bookingService *services.BookingService) *BookingHandler {
	return &BookingHandler{bookingService: bookingService}
}

func (h *BookingHandler) GetServices(c *gin.Context) {
	servicesList, err := h.bookingService.FetchServices(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch services"})
		return
	}
	c.JSON(http.StatusOK, servicesList)
}

func (h *BookingHandler) GetSlots(c *gin.Context) {
	dateStr := c.Query("date")
	skuIDStr := c.Query("sku_id")

	if dateStr == "" || skuIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "date and sku_id are required"})
		return
	}

	skuUUID, err := uuid.Parse(skuIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid sku_id"})
		return
	}

	slots, err := h.bookingService.GetAvailableSlots(c.Request.Context(), dateStr, skuUUID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, slots)
}


type CreateBookingReq struct {
	SKUID     string `json:"sku_id" binding:"required"`
	SlotStart string `json:"slot_start" binding:"required"` // Using ISO8601 string
	VehicleID string `json:"vehicle_id"`
	AddressID string `json:"address_id"`
}

func (h *BookingHandler) CreateBooking(c *gin.Context) {
	// Retrieve User ID from Auth Middleware context
	userIDRaw, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user ID missing"})
		return
	}
	userID := userIDRaw.(uuid.UUID)

	var req CreateBookingReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload: " + err.Error()})
		return
	}

	skuUUID, err := uuid.Parse(req.SKUID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid sku ID format"})
		return
	}

	slotStart, err := time.Parse(time.RFC3339, req.SlotStart)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid time format, requires RFC3339"})
		return
	}

	var vehicleIDPtr *uuid.UUID
	if req.VehicleID != "" {
		if vid, err := uuid.Parse(req.VehicleID); err == nil {
			vehicleIDPtr = &vid
		}
	}

	var addressIDPtr *uuid.UUID
	if req.AddressID != "" {
		if aid, err := uuid.Parse(req.AddressID); err == nil {
			addressIDPtr = &aid
		}
	}

	// Process booking with Redis concurrency locking inside service
	booking, err := h.bookingService.ReserveSlotAndBook(c.Request.Context(), userID, skuUUID, vehicleIDPtr, addressIDPtr, slotStart)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, booking)
}
