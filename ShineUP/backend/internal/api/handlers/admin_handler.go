package handlers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/Shine-Up/backend/internal/core/services"
	"github.com/Shine-Up/backend/internal/models"
	"github.com/Shine-Up/backend/internal/websocket"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AdminHandler struct {
	db             *gorm.DB
	partnerService *services.PartnerService
	notifSvc       *services.NotificationService
	wsHub          *websocket.Hub
}

func NewAdminHandler(db *gorm.DB, ps *services.PartnerService, ns *services.NotificationService, hub *websocket.Hub) *AdminHandler {
	return &AdminHandler{db: db, partnerService: ps, notifSvc: ns, wsHub: hub}
}

// ─── Dashboard Stats ─────────────────────────────────────

func (h *AdminHandler) DashboardStats(c *gin.Context) {
	var customerCount, partnerCount, bookingCount, completedCount, cancelledCount int64
	var totalRevenue float64

	h.db.Model(&models.Customer{}).Count(&customerCount)
	h.db.Model(&models.Partner{}).Count(&partnerCount)
	h.db.Model(&models.Booking{}).Count(&bookingCount)
	h.db.Model(&models.Booking{}).Where("status = ?", "COMPLETED").Count(&completedCount)
	h.db.Model(&models.Booking{}).Where("status = ?", "CANCELLED").Count(&cancelledCount)
	h.db.Model(&models.Booking{}).Where("status = ?", "COMPLETED").Select("COALESCE(SUM(total_amount), 0)").Scan(&totalRevenue)

	var onlinePartners int64
	h.db.Model(&models.Partner{}).Where("is_online = ?", true).Count(&onlinePartners)

	var pendingKYC int64
	h.db.Model(&models.Partner{}).Where("kyc_status = ?", "PENDING").Count(&pendingKYC)

	var avgRating float64
	h.db.Model(&models.Partner{}).Where("kyc_status = ?", "APPROVED").Select("COALESCE(AVG(rating), 0)").Scan(&avgRating)

	// WebSocket live stats
	wsConnections := 0
	wsUsersOnline := 0
	if h.wsHub != nil {
		wsConnections = h.wsHub.GetConnectionCount()
		wsUsersOnline = h.wsHub.GetUserCount()
	}

	c.JSON(http.StatusOK, gin.H{
		"total_customers":    customerCount,
		"total_partners":     partnerCount,
		"online_partners":    onlinePartners,
		"total_bookings":     bookingCount,
		"completed_bookings": completedCount,
		"cancelled_bookings": cancelledCount,
		"total_revenue":      totalRevenue,
		"pending_kyc":        pendingKYC,
		"avg_partner_rating": avgRating,
		"ws_connections":     wsConnections,
		"ws_users_online":    wsUsersOnline,

		// Funnel stats
		"funnel": map[string]interface{}{
			"signups":   customerCount,
			"placed":    bookingCount,
			"completed": completedCount,
		},
	})
}

// ─── Partner Management ──────────────────────────────────

func (h *AdminHandler) ListPartners(c *gin.Context) {
	var partners []models.Partner
	if err := h.db.Preload("User").Find(&partners).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch partners"})
		return
	}

	type PartnerResponse struct {
		ID             string  `json:"id"`
		Name           string  `json:"name"`
		Phone          string  `json:"phone"`
		DocURL         string  `json:"doc_url"`
		KYCStatus      string  `json:"kyc_status"`
		IsOnline       bool    `json:"is_online"`
		Rating         float64 `json:"rating"`
		AcceptanceRate float64 `json:"acceptance_rate"`
	}

	var response []PartnerResponse
	for _, p := range partners {
		response = append(response, PartnerResponse{
			ID:             p.ID.String(),
			Name:           p.Name,
			Phone:          p.User.Phone,
			DocURL:         p.DocURL,
			KYCStatus:      p.KYCStatus,
			IsOnline:       p.IsOnline,
			Rating:         p.Rating,
			AcceptanceRate: p.AcceptanceRate,
		})
	}

	c.JSON(http.StatusOK, response)
}

func (h *AdminHandler) ApprovePartnerKYC(c *gin.Context) {
	partnerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid partner ID"})
		return
	}

	result := h.db.Model(&models.Partner{}).Where("id = ?", partnerID).Update("kyc_status", "APPROVED")
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "partner not found"})
		return
	}

	// Notify the partner
	var partner models.Partner
	if err := h.db.First(&partner, "id = ?", partnerID).Error; err == nil {
		h.db.Create(&models.Notification{
			UserID: partner.UserID,
			Title:  "KYC Approved! 🎉",
			Body:   "Your documents have been verified. You can now go online and start accepting jobs.",
		})
	}

	c.JSON(http.StatusOK, gin.H{"message": "partner KYC approved"})
}

func (h *AdminHandler) RejectPartnerKYC(c *gin.Context) {
	partnerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid partner ID"})
		return
	}

	result := h.db.Model(&models.Partner{}).Where("id = ?", partnerID).Update("kyc_status", "REJECTED")
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "partner not found"})
		return
	}

	var partner models.Partner
	if err := h.db.First(&partner, "id = ?", partnerID).Error; err == nil {
		h.db.Create(&models.Notification{
			UserID: partner.UserID,
			Title:  "KYC Rejected",
			Body:   "Your documents could not be verified. Please re-upload valid documents.",
		})
	}

	c.JSON(http.StatusOK, gin.H{"message": "partner KYC rejected"})
}

// ─── Booking Management ──────────────────────────────────

func (h *AdminHandler) ListBookings(c *gin.Context) {
	var bookings []models.Booking
	if err := h.db.Preload("SKU").Preload("Customer").Preload("Customer.User").Preload("Partner").Preload("Partner.User").
		Order("created_at DESC").Find(&bookings).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch bookings"})
		return
	}

	type BookingResponse struct {
		ID            string  `json:"id"`
		ServiceName   string  `json:"service_name"`
		Customer      string  `json:"customer"`
		Partner       string  `json:"partner"`
		Amount        float64 `json:"amount"`
		Status        string  `json:"status"`
		SlotStart     string  `json:"slot_start"`
		CanBeAssigned bool    `json:"can_be_assigned"`
	}

	var response []BookingResponse
	for _, b := range bookings {
		customerName := b.Customer.Name
		if customerName == "" {
			customerName = b.Customer.User.Phone
		}
		partnerName := "Unassigned"
		if b.Partner != nil {
			partnerName = b.Partner.Name
			if partnerName == "" {
				partnerName = b.Partner.User.Phone
			}
		}

		response = append(response, BookingResponse{
			ID:            b.ID.String(),
			ServiceName:   b.SKU.Title,
			Customer:      customerName,
			Partner:       partnerName,
			Amount:        b.TotalAmount,
			Status:        b.Status,
			SlotStart:     b.SlotStart.Format("2006-01-02 15:04"),
			CanBeAssigned: b.Status == "CREATED",
		})
	}

	c.JSON(http.StatusOK, response)
}

func (h *AdminHandler) CancelBooking(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	var booking models.Booking
	if err := h.db.First(&booking, "id = ?", bookingID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "booking not found"})
		return
	}

	if booking.Status == "COMPLETED" || booking.Status == "CANCELLED" {
		c.JSON(http.StatusConflict, gin.H{"error": "cannot cancel a finished booking"})
		return
	}

	booking.Status = "CANCELLED"
	if err := h.db.Save(&booking).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to cancel booking"})
		return
	}

	// Push real-time notifications
	if h.notifSvc != nil {
		h.notifSvc.NotifyBookingCancelled(booking)
	}

	c.JSON(http.StatusOK, gin.H{"message": "booking cancelled by admin"})
}

func (h *AdminHandler) AssignPartnerToBooking(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid booking ID"})
		return
	}

	var req struct {
		PartnerID string `json:"partner_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "partner_id is required"})
		return
	}

	partnerUUID, err := uuid.Parse(req.PartnerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid partner ID format"})
		return
	}

	// Verify partner exists and is approved
	var partner models.Partner
	if err := h.db.First(&partner, "id = ?", partnerUUID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "partner not found"})
		return
	}
	if partner.KYCStatus != "APPROVED" {
		c.JSON(http.StatusConflict, gin.H{"error": "partner KYC not approved"})
		return
	}

	// Update booking
	var booking models.Booking
	if err := h.db.First(&booking, "id = ?", bookingID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "booking not found"})
		return
	}

	if booking.Status != "CREATED" && booking.Status != models.BookingScheduled {
		c.JSON(http.StatusConflict, gin.H{"error": "booking is not in a state that allows assignment"})
		return
	}

	booking.PartnerID = &partnerUUID
	booking.Status = "ASSIGNED"

	if err := h.db.Save(&booking).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to assign partner"})
		return
	}

	// Push real-time notifications to both customer & partner
	if h.notifSvc != nil {
		h.notifSvc.NotifyBookingAssigned(booking)
	}

	c.JSON(http.StatusOK, gin.H{"message": "partner assigned to booking"})
}

// ─── Customer Management ─────────────────────────────────

func (h *AdminHandler) ListCustomers(c *gin.Context) {
	var customers []models.Customer
	if err := h.db.Preload("User").Find(&customers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch customers"})
		return
	}

	type CustomerResponse struct {
		ID            string  `json:"id"`
		Name          string  `json:"name"`
		Phone         string  `json:"phone"`
		Email         string  `json:"email"`
		WalletBalance float64 `json:"wallet_balance"`
		ReferralCode  string  `json:"referral_code"`
	}

	var response []CustomerResponse
	for _, cu := range customers {
		response = append(response, CustomerResponse{
			ID:            cu.ID.String(),
			Name:          cu.Name,
			Phone:         cu.User.Phone,
			Email:         cu.Email,
			WalletBalance: cu.WalletBalance,
			ReferralCode:  cu.ReferralCode,
		})
	}

	c.JSON(http.StatusOK, response)
}

// ─── Service & SKU CRUD ──────────────────────────────────

func (h *AdminHandler) CreateService(c *gin.Context) {
	var req struct {
		Name        string `json:"name" binding:"required"`
		Description string `json:"description"`
		Category    string `json:"category" binding:"required"`
		ImageURL    string `json:"image_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name and category are required"})
		return
	}

	service := models.Service{
		Name:        req.Name,
		Description: req.Description,
		Category:    req.Category,
		ImageURL:    req.ImageURL,
		IsActive:    true,
	}

	if err := h.db.Create(&service).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create service"})
		return
	}

	c.JSON(http.StatusCreated, service)
}

func (h *AdminHandler) AddSKU(c *gin.Context) {
	serviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid service ID"})
		return
	}

	// Verify service exists
	var service models.Service
	if err := h.db.First(&service, "id = ?", serviceID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "service not found"})
		return
	}

	var req struct {
		Title        string  `json:"title" binding:"required"`
		Price        float64 `json:"price" binding:"required"`
		DurationMins int     `json:"duration_mins" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "title, price, and duration_mins are required"})
		return
	}

	sku := models.SKU{
		ServiceID:    serviceID,
		Title:        req.Title,
		Price:        req.Price,
		DurationMins: req.DurationMins,
	}

	if err := h.db.Create(&sku).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create SKU"})
		return
	}

	c.JSON(http.StatusCreated, sku)
}

func (h *AdminHandler) DeleteService(c *gin.Context) {
	serviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid service ID"})
		return
	}

	// Delete service and its SKUs
	err = h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Delete(&models.SKU{}, "service_id = ?", serviceID).Error; err != nil {
			return err
		}
		if err := tx.Delete(&models.Service{}, "id = ?", serviceID).Error; err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete service"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "service deleted successfully"})
}

func (h *AdminHandler) ListServices(c *gin.Context) {
	category := c.Query("category")
	query := h.db.Preload("SKUs").Order("sort_order ASC")
	if category != "" {
		query = query.Where("category = ?", category)
	}

	var services []models.Service
	if err := query.Find(&services).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch services"})
		return
	}
	c.JSON(http.StatusOK, services)
}

// ─── Hub Management ──────────────────────────────────────

func (h *AdminHandler) ListHubs(c *gin.Context) {
	city := c.Query("city")
	query := h.db.Order("city ASC, name ASC")
	if city != "" {
		query = query.Where("city = ?", city)
	}

	var hubs []models.Hub
	if err := query.Find(&hubs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch hubs"})
		return
	}
	c.JSON(http.StatusOK, hubs)
}

func (h *AdminHandler) CreateHub(c *gin.Context) {
	var req struct {
		Name      string  `json:"name" binding:"required"`
		City      string  `json:"city" binding:"required"`
		Latitude  float64 `json:"latitude" binding:"required"`
		Longitude float64 `json:"longitude" binding:"required"`
		RadiusKm  float64 `json:"radius_km"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	radius := req.RadiusKm
	if radius == 0 {
		radius = 10
	}

	hub := models.Hub{
		Name:      req.Name,
		City:      req.City,
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		RadiusKm:  radius,
		IsActive:  true,
	}

	if err := h.db.Create(&hub).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create hub"})
		return
	}

	c.JSON(http.StatusCreated, hub)
}

func (h *AdminHandler) UpdateHub(c *gin.Context) {
	hubID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid hub ID"})
		return
	}

	var hub models.Hub
	if err := h.db.First(&hub, "id = ?", hubID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "hub not found"})
		return
	}

	var req struct {
		Name      string  `json:"name"`
		City      string  `json:"city"`
		Latitude  float64 `json:"latitude"`
		Longitude float64 `json:"longitude"`
		RadiusKm  float64 `json:"radius_km"`
		IsActive  *bool   `json:"is_active"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Name != "" {
		hub.Name = req.Name
	}
	if req.City != "" {
		hub.City = req.City
	}
	if req.Latitude != 0 {
		hub.Latitude = req.Latitude
	}
	if req.Longitude != 0 {
		hub.Longitude = req.Longitude
	}
	if req.RadiusKm != 0 {
		hub.RadiusKm = req.RadiusKm
	}
	if req.IsActive != nil {
		hub.IsActive = *req.IsActive
	}

	if err := h.db.Save(&hub).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update hub"})
		return
	}

	c.JSON(http.StatusOK, hub)
}

// ─── Partner Detail (Admin) ──────────────────────────────

func (h *AdminHandler) GetPartnerDetail(c *gin.Context) {
	partnerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid partner ID"})
		return
	}

	detail, err := h.partnerService.GetPartnerDetail(c.Request.Context(), partnerID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, detail)
}

// ─── Partner Slots (Admin) ───────────────────────────────

func (h *AdminHandler) GetPartnerSlots(c *gin.Context) {
	partnerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid partner ID"})
		return
	}

	date := c.Query("date")
	if date == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "date query parameter required"})
		return
	}

	slots, err := h.partnerService.GetPartnerSlots(c.Request.Context(), partnerID, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, slots)
}

// ─── Leave Management (Admin) ────────────────────────────

func (h *AdminHandler) ListPartnerLeaves(c *gin.Context) {
	partnerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid partner ID"})
		return
	}

	var leaves []models.PartnerLeave
	h.db.Where("partner_id = ?", partnerID).Order("date DESC").Find(&leaves)
	c.JSON(http.StatusOK, leaves)
}

func (h *AdminHandler) ApproveLeave(c *gin.Context) {
	leaveID, err := uuid.Parse(c.Param("leaveId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid leave ID"})
		return
	}

	if err := h.partnerService.ApproveLeave(c.Request.Context(), leaveID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "leave approved"})
}

func (h *AdminHandler) RejectLeave(c *gin.Context) {
	leaveID, err := uuid.Parse(c.Param("leaveId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid leave ID"})
		return
	}

	if err := h.partnerService.RejectLeave(c.Request.Context(), leaveID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "leave rejected — slots restored"})
}

// ─── Withdrawals (Admin) ─────────────────────────────────

func (h *AdminHandler) ListWithdrawals(c *gin.Context) {
	var requests []models.WithdrawalRequest
	if err := h.db.Preload("Partner").Preload("Partner.User").Order("created_at DESC").Find(&requests).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch withdrawals"})
		return
	}
	
	type WithdrawalResponse struct {
		ID            string  `json:"id"`
		PartnerName   string  `json:"partner_name"`
		PartnerPhone  string  `json:"partner_phone"`
		Amount        float64 `json:"amount"`
		Status        string  `json:"status"`
		BankReference string  `json:"bank_reference"`
		CreatedAt     string  `json:"created_at"`
	}

	var response []WithdrawalResponse
	for _, r := range requests {
		name := r.Partner.Name
		if name == "" && r.Partner.User.Phone != "" {
			name = r.Partner.User.Phone
		}
		response = append(response, WithdrawalResponse{
			ID:            r.ID.String(),
			PartnerName:   name,
			PartnerPhone:  r.Partner.User.Phone,
			Amount:        r.Amount,
			Status:        r.Status,
			BankReference: r.BankReference,
			CreatedAt:     r.CreatedAt.Format("2006-01-02 15:04"),
		})
	}

	c.JSON(http.StatusOK, response)
}

func (h *AdminHandler) ProcessWithdrawal(c *gin.Context) {
	reqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request ID"})
		return
	}

	var payload struct {
		Action        string `json:"action" binding:"required"` // APPROVE, REJECT
		BankReference string `json:"bank_reference"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var req models.WithdrawalRequest
	if err := h.db.First(&req, "id = ?", reqID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "withdrawal request not found"})
		return
	}

	if req.Status != "PENDING" {
		c.JSON(http.StatusConflict, gin.H{"error": "request is already processed"})
		return
	}

	err = h.db.Transaction(func(tx *gorm.DB) error {
		if payload.Action == "APPROVE" {
			req.Status = "APPROVED"
			req.BankReference = payload.BankReference
			if err := tx.Save(&req).Error; err != nil {
				return err
			}
			// Notification to Partner
			if h.notifSvc != nil {
				var p models.Partner
				if err := tx.First(&p, "id = ?", req.PartnerID).Error; err == nil {
					// We ideally should push this async but adding to DB triggers the WS flow inside notifSvc if we wired it, but for admin we simply write to DB.
					// Actually notifSvc.db.Create is better handled via a method, but creating directly handles offline push.
					h.db.Create(&models.Notification{
						UserID: p.UserID,
						Title:  "Withdrawal Processed",
						Body:   "Your withdrawal of ₹" + fmt.Sprintf("%.2f", req.Amount) + " has been processed.",
					})
				}
			}
		} else if payload.Action == "REJECT" {
			req.Status = "REJECTED"
			if err := tx.Save(&req).Error; err != nil {
				return err
			}
			// Refund wallet
			var p models.Partner
			if err := tx.First(&p, "id = ?", req.PartnerID).Error; err != nil {
				return err
			}
			if err := tx.Model(&p).Update("wallet_balance", gorm.Expr("wallet_balance + ?", req.Amount)).Error; err != nil {
				return err
			}
			
			// Refund WalletTransaction
			wt := models.WalletTransaction{
				PartnerID: &p.ID,
				Amount:    req.Amount,
				Type:      "WITHDRAWAL_REJECTED",
				Reference: "Refund for Req " + req.ID.String()[:8],
			}
			if err := tx.Create(&wt).Error; err != nil {
				return err
			}

			// Notification
			if h.notifSvc != nil {
				h.db.Create(&models.Notification{
					UserID: p.UserID,
					Title:  "Withdrawal Rejected",
					Body:   "Your withdrawal of ₹" + fmt.Sprintf("%.2f", req.Amount) + " was rejected and refunded.",
				})
			}
		} else {
			return fmt.Errorf("invalid action")
		}
		return nil
	})

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "withdrawal processed successfully"})
}

// ─── Announcements (Admin) ───────────────────────────────

func (h *AdminHandler) BroadcastAnnouncement(c *gin.Context) {
	var req struct {
		Title   string `json:"title" binding:"required"`
		Message string `json:"message" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if h.notifSvc != nil {
		h.notifSvc.NotifyToAdmin("Announcement Sent", req.Title+": "+req.Message)
		// We could use an all-users broadcast here, but for now we simulate by pushing to all
		if h.wsHub != nil {
			msg := websocket.WSMessage{
				Type: models.WSTypeNewNotification,
				Payload: map[string]interface{}{
					"title":   "Announcement",
					"message": req.Title + " - " + req.Message,
				},
				Time: time.Now(),
			}
			h.wsHub.BroadcastToRole("CUSTOMER", msg)
			h.wsHub.BroadcastToRole("PARTNER", msg)
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Announcement broadcast successfully"})
}
