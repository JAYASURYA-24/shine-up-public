package handlers

import (
	"math"
	"net/http"

	"github.com/Shine-Up/backend/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type VehicleHandler struct {
	db *gorm.DB
}

func NewVehicleHandler(db *gorm.DB) *VehicleHandler {
	return &VehicleHandler{db: db}
}

// AddVehicle adds a new vehicle for the customer
func (h *VehicleHandler) AddVehicle(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	// Find customer by user ID
	var customer models.Customer
	if err := h.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Customer profile not found"})
		return
	}

	var req struct {
		VehicleType   string `json:"vehicle_type" binding:"required"`  // 2W or 4W
		VehicleNumber string `json:"vehicle_number" binding:"required"`
		ModelName     string `json:"model_name"`
		IsDefault     bool   `json:"is_default"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.VehicleType != models.VehicleType2W && req.VehicleType != models.VehicleType4W {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Vehicle type must be 2W or 4W"})
		return
	}

	vehicle := models.Vehicle{
		CustomerID:    customer.ID,
		VehicleType:   req.VehicleType,
		VehicleNumber: req.VehicleNumber,
		ModelName:     req.ModelName,
		IsDefault:     req.IsDefault,
	}

	if req.IsDefault {
		// Unset other defaults
		h.db.Model(&models.Vehicle{}).Where("customer_id = ?", customer.ID).Update("is_default", false)
	}

	if err := h.db.Create(&vehicle).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add vehicle"})
		return
	}

	c.JSON(http.StatusCreated, vehicle)
}

// ListVehicles returns all vehicles for the customer
func (h *VehicleHandler) ListVehicles(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var customer models.Customer
	if err := h.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Customer profile not found"})
		return
	}

	var vehicles []models.Vehicle
	h.db.Where("customer_id = ?", customer.ID).Order("is_default DESC, created_at DESC").Find(&vehicles)

	c.JSON(http.StatusOK, vehicles)
}

// DeleteVehicle removes a vehicle
func (h *VehicleHandler) DeleteVehicle(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	vehicleID := c.Param("id")

	var customer models.Customer
	if err := h.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Customer profile not found"})
		return
	}

	result := h.db.Where("id = ? AND customer_id = ?", vehicleID, customer.ID).Delete(&models.Vehicle{})
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Vehicle not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Vehicle deleted"})
}

// ─── Address Handler ─────────────────────────────────────

type AddressHandler struct {
	db *gorm.DB
}

func NewAddressHandler(db *gorm.DB) *AddressHandler {
	return &AddressHandler{db: db}
}

// AddAddress adds a new address for the customer
func (h *AddressHandler) AddAddress(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var customer models.Customer
	if err := h.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Customer profile not found"})
		return
	}

	var req struct {
		Label       string  `json:"label"`
		AddressLine string  `json:"address_line" binding:"required"`
		City        string  `json:"city"`
		Pincode     string  `json:"pincode"`
		Latitude    float64 `json:"latitude"`
		Longitude   float64 `json:"longitude"`
		IsDefault   bool    `json:"is_default"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	address := models.Address{
		CustomerID:  customer.ID,
		Label:       req.Label,
		AddressLine: req.AddressLine,
		City:        req.City,
		Pincode:     req.Pincode,
		Latitude:    req.Latitude,
		Longitude:   req.Longitude,
		IsDefault:   req.IsDefault,
	}

	if req.IsDefault {
		h.db.Model(&models.Address{}).Where("customer_id = ?", customer.ID).Update("is_default", false)
	}

	if err := h.db.Create(&address).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add address"})
		return
	}

	c.JSON(http.StatusCreated, address)
}

// ListAddresses returns all addresses for the customer
func (h *AddressHandler) ListAddresses(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var customer models.Customer
	if err := h.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Customer profile not found"})
		return
	}

	var addresses []models.Address
	h.db.Where("customer_id = ?", customer.ID).Order("is_default DESC, created_at DESC").Find(&addresses)

	c.JSON(http.StatusOK, addresses)
}

// CheckServiceability checks if a location is within any active hub's radius
func (h *AddressHandler) CheckServiceability(c *gin.Context) {
	var req struct {
		Latitude  float64 `form:"lat" binding:"required"`
		Longitude float64 `form:"lng" binding:"required"`
	}
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "lat and lng are required"})
		return
	}

	var hubs []models.Hub
	h.db.Where("is_active = ?", true).Find(&hubs)

	for _, hub := range hubs {
		distance := haversineDistance(req.Latitude, req.Longitude, hub.Latitude, hub.Longitude)
		if distance <= hub.RadiusKm {
			c.JSON(http.StatusOK, gin.H{
				"serviceable": true,
				"hub_name":    hub.Name,
				"city":        hub.City,
				"distance_km": math.Round(distance*100) / 100,
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"serviceable": false,
		"message":     "Sorry, we don't serve this area yet. We are expanding soon!",
	})
}

// haversineDistance calculates distance in km between two lat/long points
func haversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0 // Earth's radius in km
	dLat := (lat2 - lat1) * math.Pi / 180
	dLon := (lon2 - lon1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}
