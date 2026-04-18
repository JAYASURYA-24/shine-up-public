package handlers

import (
	"fmt"
	"net/http"

	"github.com/Shine-Up/backend/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PaymentHandler struct {
	db *gorm.DB
}

func NewPaymentHandler(db *gorm.DB) *PaymentHandler {
	return &PaymentHandler{db: db}
}

// ─── Create Mock Order ───────────────────────────────────

func (h *PaymentHandler) CreateOrder(c *gin.Context) {
	var req struct {
		BookingID string `json:"booking_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "booking_id is required"})
		return
	}

	bookingUUID, err := uuid.Parse(req.BookingID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking format"})
		return
	}

	var booking models.Booking
	if err := h.db.First(&booking, "id = ?", bookingUUID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "booking not found"})
		return
	}

	// Mocking Razorpay order creation
	mockOrderID := fmt.Sprintf("order_mock_%s", uuid.New().String()[:8])

	c.JSON(http.StatusOK, gin.H{
		"order_id": mockOrderID,
		"amount":   booking.TotalAmount,
		"currency": "INR",
	})
}

// ─── Verify Mock Payment ─────────────────────────────────

func (h *PaymentHandler) VerifyPayment(c *gin.Context) {
	var req struct {
		BookingID     string `json:"booking_id" binding:"required"`
		RazorpayOrder string `json:"razorpay_order_id" binding:"required"`
		RazorpayPayID string `json:"razorpay_payment_id" binding:"required"`
		Method        string `json:"method"` // WALLET, CREDIT_CARD, UPI
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing required fields"})
		return
	}

	bookingUUID, err := uuid.Parse(req.BookingID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking format"})
		return
	}

	var booking models.Booking
	if err := h.db.First(&booking, "id = ?", bookingUUID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "booking not found"})
		return
	}

	method := req.Method
	if method == "" {
		method = "UPI"
	}

	// Create payment record
	payment := models.Payment{
		BookingID:   booking.ID,
		Amount:      booking.TotalAmount,
		RPOrderID:   req.RazorpayOrder,
		RPPaymentID: req.RazorpayPayID,
		Status:      "SUCCESS",
		Method:      method,
	}

	err = h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&payment).Error; err != nil {
			return err
		}
		
		// Update Booking PaidAmount to mark it fully paid online (optional/mock behaviour)
		booking.PaidAmount = booking.TotalAmount
		if err := tx.Save(&booking).Error; err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to process payment verification"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "payment successful",
		"payment_id": payment.ID,
	})
}
