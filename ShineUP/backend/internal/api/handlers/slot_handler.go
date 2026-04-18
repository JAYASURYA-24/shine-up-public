package handlers

import (
	"net/http"

	"github.com/Shine-Up/backend/internal/core/services"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type SlotHandler struct {
	partnerService *services.PartnerService
}

func NewSlotHandler(ps *services.PartnerService) *SlotHandler {
	return &SlotHandler{partnerService: ps}
}

// ─── Slots ───────────────────────────────────────────────

func (h *SlotHandler) GetSlots(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	date := c.Query("date")
	if date == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "date query parameter is required (YYYY-MM-DD)"})
		return
	}

	slots, err := h.partnerService.GetSlots(c.Request.Context(), userID, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, slots)
}

func (h *SlotHandler) ToggleSlot(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	slotID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid slot ID"})
		return
	}

	slot, err := h.partnerService.ToggleSlot(c.Request.Context(), userID, slotID)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, slot)
}

// ─── Leaves ──────────────────────────────────────────────

func (h *SlotHandler) RequestLeave(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req struct {
		Date   string `json:"date" binding:"required"`
		Reason string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "date is required (YYYY-MM-DD)"})
		return
	}

	leave, err := h.partnerService.RequestLeave(c.Request.Context(), userID, req.Date, req.Reason)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, leave)
}

func (h *SlotHandler) ListLeaves(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	leaves, err := h.partnerService.ListLeaves(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, leaves)
}

func (h *SlotHandler) CancelLeave(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	leaveID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid leave ID"})
		return
	}

	if err := h.partnerService.CancelLeave(c.Request.Context(), userID, leaveID); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "leave request cancelled"})
}
