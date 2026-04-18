package handlers

import (
	"net/http"

	"github.com/Shine-Up/backend/internal/core/services"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type PartnerHandler struct {
	partnerService *services.PartnerService
}

func NewPartnerHandler(ps *services.PartnerService) *PartnerHandler {
	return &PartnerHandler{partnerService: ps}
}

// ─── Profile ─────────────────────────────────────────────

func (h *PartnerHandler) GetProfile(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	profile, err := h.partnerService.GetProfile(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, profile)
}

func (h *PartnerHandler) UpdateProfile(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req struct {
		Name   string `json:"name"`
		DocURL string `json:"doc_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload"})
		return
	}

	profile, err := h.partnerService.UpdateProfile(c.Request.Context(), userID, req.Name, req.DocURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, profile)
}

// ─── KYC ─────────────────────────────────────────────────

func (h *PartnerHandler) UpdateKYC(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req services.KYCUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload"})
		return
	}

	profile, err := h.partnerService.UpdateKYC(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "KYC documents submitted for review",
		"partner": profile,
	})
}

// ─── Online Toggle ───────────────────────────────────────

func (h *PartnerHandler) ToggleOnline(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req struct {
		Online bool `json:"online"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "online (bool) is required"})
		return
	}

	if err := h.partnerService.ToggleOnline(c.Request.Context(), userID, req.Online); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}

	status := "offline"
	if req.Online {
		status = "online"
	}
	c.JSON(http.StatusOK, gin.H{"message": "you are now " + status})
}

// ─── Jobs ────────────────────────────────────────────────

func (h *PartnerHandler) ListJobs(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	jobs, err := h.partnerService.ListJobs(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, jobs)
}

func (h *PartnerHandler) AcceptJob(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	if err := h.partnerService.AcceptJob(c.Request.Context(), userID, bookingID); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "job accepted and confirmed"})
}

func (h *PartnerHandler) StartJob(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	var req struct {
		OTP string `json:"otp" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "otp is required"})
		return
	}

	if err := h.partnerService.StartJob(c.Request.Context(), userID, bookingID, req.OTP); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "job started — work in progress"})
}

func (h *PartnerHandler) CompleteJob(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	if err := h.partnerService.CompleteJob(c.Request.Context(), userID, bookingID); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "job completed! Payment recorded."})
}

// ─── Service Photos ──────────────────────────────────────

func (h *PartnerHandler) UploadPhoto(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	var req struct {
		PhotoType string `json:"photo_type" binding:"required"` // SELFIE, BEFORE, AFTER
		PhotoURL  string `json:"photo_url" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "photo_type and photo_url are required"})
		return
	}

	photo, err := h.partnerService.UploadServicePhoto(c.Request.Context(), userID, bookingID, req.PhotoType, req.PhotoURL)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, photo)
}

func (h *PartnerHandler) GetPhotos(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	photos, err := h.partnerService.GetServicePhotos(c.Request.Context(), bookingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, photos)
}

// ─── Earnings ────────────────────────────────────────────

func (h *PartnerHandler) GetEarnings(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	earnings, err := h.partnerService.GetEarnings(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, earnings)
}

// ─── Bank Account ────────────────────────────────────────

func (h *PartnerHandler) GetBankDetails(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	bank, err := h.partnerService.GetBankDetails(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if bank == nil {
		c.JSON(http.StatusOK, gin.H{"message": "no bank account added yet"})
		return
	}
	c.JSON(http.StatusOK, bank)
}

func (h *PartnerHandler) SubmitBankDetails(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req services.BankAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "all bank fields are required"})
		return
	}

	bank, err := h.partnerService.SubmitBankDetails(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "bank details saved",
		"bank_account": bank,
	})
}

func (h *PartnerHandler) VerifyBank(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	bank, err := h.partnerService.MockVerifyBank(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "₹1 test successful — bank verified!",
		"bank_account": bank,
	})
}

// ─── Wallet ──────────────────────────────────────────────

func (h *PartnerHandler) GetWallet(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	balance, txns, err := h.partnerService.GetWallet(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"wallet_balance": balance,
		"transactions":   txns,
	})
}

func (h *PartnerHandler) RequestWithdrawal(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req struct {
		Amount float64 `json:"amount" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "withdrawal amount is required"})
		return
	}

	withdrawalReq, err := h.partnerService.RequestWithdrawal(c.Request.Context(), userID, req.Amount)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "withdrawal request submitted successfully",
		"request": withdrawalReq,
	})
}
