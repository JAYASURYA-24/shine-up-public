package handlers

import (
	"log"
	"net/http"

	"github.com/Shine-Up/backend/internal/core/services"
	"github.com/Shine-Up/backend/internal/models"
	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authService *services.AuthService
}

func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

type OTPRequest struct {
	Phone string `json:"phone" binding:"required"`
}

type OTPVerifyRequest struct {
	Phone     string      `json:"phone" binding:"required"`
	OTP       string      `json:"otp" binding:"required"`
	Name      string      `json:"name"`
	Email     string      `json:"email"`
	Location  string      `json:"location"`
	Latitude  float64     `json:"latitude"`
	Longitude float64     `json:"longitude"`
	Role      models.Role `json:"role" binding:"required"`
}

type LoginRequest struct {
	IDToken string      `json:"id_token" binding:"required"`
	Role    models.Role `json:"role" binding:"required"`
}

// VerifyFirebaseToken handles login for both Customer and Partner apps.
func (h *AuthHandler) VerifyFirebaseToken(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request payload"})
		return
	}

	// Make sure the role is one of the allowed ones
	if req.Role != models.RoleCustomer && req.Role != models.RolePartner {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid application role specified"})
		return
	}

	jwtToken, err := h.authService.LoginWithFirebaseToken(c.Request.Context(), req.IDToken, req.Role)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": jwtToken,
	})
}

// SendOTP handles the first step of login (DEMO MOCK)
func (h *AuthHandler) SendOTP(c *gin.Context) {
	var req OTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request payload"})
		return
	}

	// MOCK: Always succeed for demo
	c.JSON(http.StatusOK, gin.H{"message": "OTP sent successfully (Demo: 123456)"})
}

// VerifyOTP handles OTP verification and login/registration
func (h *AuthHandler) VerifyOTP(c *gin.Context) {
	var req OTPVerifyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("VerifyOTP Bind Error: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request payload format"})
		return
	}
	log.Printf("DEBUG: VerifyOTP Received - Phone: %s, OTP: %s, Role: %s", req.Phone, req.OTP, req.Role)

	// MOCK OTP Check
	if req.OTP != "123456" && req.Phone != "+1234567890" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid OTP"})
		return
	}

	jwtToken, err := h.authService.LoginWithOTP(c.Request.Context(), req.Phone, req.Name, req.Email, req.Location, req.Latitude, req.Longitude, req.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": jwtToken})
}

// DevLoginRequest schema for bypass
type DevLoginRequest struct {
	Phone string      `json:"phone" binding:"required"`
	Role  models.Role `json:"role" binding:"required"`
}

// DevLogin allows bypassing Firebase for local testing
func (h *AuthHandler) DevLogin(c *gin.Context) {
	var req DevLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request payload"})
		return
	}

	jwtToken, err := h.authService.DevLogin(c.Request.Context(), req.Phone, req.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": jwtToken})
}
