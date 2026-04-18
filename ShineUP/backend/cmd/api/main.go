package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/Shine-Up/backend/internal/api/handlers"
	"github.com/Shine-Up/backend/internal/api/middleware"
	"github.com/Shine-Up/backend/internal/config"
	"github.com/Shine-Up/backend/internal/core/services"
	"github.com/Shine-Up/backend/internal/models"
	"github.com/Shine-Up/backend/internal/websocket"
	"github.com/Shine-Up/backend/pkg/database"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func main() {
	// ─── Load Configuration ──────────────────────────────
	cfg := config.LoadConfig()

	// ─── Initialize Database (Auto-fallback to SQLite) ───
	db, err := database.NewDatabaseConnection(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Critical error: Failed to initialize any database: %v", err)
	}

	// Auto-Migrate ALL Database Models
	err = db.AutoMigrate(
		&models.User{},
		&models.Customer{},
		&models.Partner{},
		&models.Vehicle{},
		&models.Address{},
		&models.Hub{},
		&models.Service{},
		&models.SKU{},
		&models.Booking{},
		&models.Payment{},
		&models.Rating{},
		&models.WalletTransaction{},
		&models.Notification{},
		// Phase 3: New models
		&models.PartnerSlot{},
		&models.PartnerLeave{},
		&models.ServicePhoto{},
		&models.PartnerBankAccount{},
		// Phase 4: Chat
		&models.ChatMessage{},
		// Phase 5: Earnings
		&models.WithdrawalRequest{},
	)
	if err != nil {
		log.Printf("⚠️  Migration warning: %v. Database might be inconsistent.", err)
	} else {
		log.Println("✅ Database schema is up-to-date (18 tables)")
	}

	// ─── Initialize Redis ────────────────────────────────
	redisClient, err := database.NewRedisConnection(cfg.RedisURL)
	if err != nil {
		log.Printf("Redis warning: %v. Slot locking disabled.", err)
	} else {
		defer redisClient.Close()
	}

	// ─── Initialize Firebase Auth ────────────────────────
	var firebaseAuth *firebase.App
	firebaseApp, err := firebase.NewApp(context.Background(), nil)
	if err != nil {
		log.Printf("Firebase setup error (ok for local dev): %v", err)
	} else {
		firebaseAuth = firebaseApp
	}

	var authClient *auth.Client
	if firebaseAuth != nil {
		authClient, _ = firebaseAuth.Auth(context.Background())
	}

	// ─── Initialize WebSocket Hub ────────────────────────
	wsHub := websocket.NewHub()
	go wsHub.Run()
	log.Println("🔌 WebSocket Hub started")

	// ─── Setup Services ──────────────────────────────────
	authService := services.NewAuthService(db, authClient, cfg.JWTSecret)
	notifService := services.NewNotificationService(db, wsHub)
	bookingService := services.NewBookingService(db, redisClient, notifService)
	customerService := services.NewCustomerService(db, notifService)
	partnerService := services.NewPartnerService(db, notifService)

	// ─── Setup Handlers ──────────────────────────────────
	authHandler := handlers.NewAuthHandler(authService)
	bookingHandler := handlers.NewBookingHandler(bookingService)
	customerHandler := handlers.NewCustomerHandler(customerService)
	partnerHandler := handlers.NewPartnerHandler(partnerService)
	slotHandler := handlers.NewSlotHandler(partnerService)
	adminHandler := handlers.NewAdminHandler(db, partnerService, notifService, wsHub)
	vehicleHandler := handlers.NewVehicleHandler(db)
	addressHandler := handlers.NewAddressHandler(db)
	chatHandler := handlers.NewChatHandler(db, notifService)
	notifHandler := handlers.NewNotificationHandler(notifService)
	paymentHandler := handlers.NewPaymentHandler(db)
	callHandler := handlers.NewCallHandler()

	// WebSocket handler
	wsHandler := websocket.NewWSHandler(wsHub, cfg.JWTSecret)
	wsHandler.OnChatMessage = func(senderID uuid.UUID, senderRole string, payload json.RawMessage) {
		// Parse chat message from WebSocket
		var chatPayload struct {
			BookingID string `json:"booking_id"`
			Message   string `json:"message"`
		}
		if err := json.Unmarshal(payload, &chatPayload); err != nil {
			return
		}

		bookingID, err := uuid.Parse(chatPayload.BookingID)
		if err != nil {
			return
		}

		// Create and persist the message
		msg := models.ChatMessage{
			BookingID:  bookingID,
			SenderID:   senderID,
			SenderRole: senderRole,
			Message:    chatPayload.Message,
		}
		if err := db.Create(&msg).Error; err != nil {
			return
		}

		// Push via WebSocket to recipient
		notifService.NotifyChatMessage(msg)
	}

	// ─── Setup Gin Router ────────────────────────────────
	router := gin.Default()
	router.Use(middleware.CORSMiddleware())

	// Health Check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":          "up",
			"application":     "Shine-Up API",
			"version":         "3.0.0",
			"ws_connections":  wsHub.GetConnectionCount(),
			"ws_users_online": wsHub.GetUserCount(),
		})
	})

	// ─── WebSocket Upgrade ───────────────────────────────
	router.GET("/ws", wsHandler.HandleWebSocket)

	// ═══════════════════════════════════════════════════════
	// API v1 Routes
	// ═══════════════════════════════════════════════════════
	v1 := router.Group("/api/v1")
	{
		// ─── Auth (Public) ───────────────────────────────
		authGroup := v1.Group("/auth")
		{
			authGroup.POST("/verify-otp", authHandler.VerifyFirebaseToken) // Keep Firebase for future
			authGroup.POST("/send-otp", authHandler.SendOTP)               // New mocked OTP
			authGroup.POST("/verify-otp-demo", authHandler.VerifyOTP)      // New mocked OTP (demo)
			authGroup.POST("/dev-login", authHandler.DevLogin)
		}

		// ─── Catalog (Public) ────────────────────────────
		v1.GET("/services", bookingHandler.GetServices)
		v1.GET("/slots", bookingHandler.GetSlots)

		// ─── Serviceability (Public) ─────────────────────
		v1.GET("/check-serviceability", addressHandler.CheckServiceability)

		// ─── Customer Routes (JWT + CUSTOMER role) ───────
		customer := v1.Group("/customer")
		customer.Use(middleware.AuthMiddleware(cfg.JWTSecret, string(models.RoleCustomer)))
		{
			// Profile
			customer.GET("/profile", customerHandler.GetProfile)
			customer.PUT("/profile", customerHandler.UpdateProfile)

			// Bookings
			customer.GET("/bookings", customerHandler.ListBookings)
			customer.GET("/bookings/:id", customerHandler.GetBookingDetail)
			customer.POST("/bookings/:id/cancel", customerHandler.CancelBooking)
			customer.POST("/bookings/:id/reschedule", customerHandler.RescheduleBooking)
			customer.POST("/bookings/:id/rate", customerHandler.RateBooking)

			// Wallet & Referral
			customer.GET("/wallet", customerHandler.GetWallet)
			customer.POST("/wallet/apply-referral", customerHandler.ApplyReferral)

			// Notifications
			customer.GET("/notifications", notifHandler.ListNotifications)
			customer.PUT("/notifications/:id/read", notifHandler.MarkRead)
			customer.PUT("/notifications/read-all", notifHandler.MarkAllRead)
			customer.GET("/notifications/unread-count", notifHandler.GetUnreadCount)

			// Vehicles
			customer.POST("/vehicles", vehicleHandler.AddVehicle)
			customer.GET("/vehicles", vehicleHandler.ListVehicles)
			customer.DELETE("/vehicles/:id", vehicleHandler.DeleteVehicle)

			// Addresses
			customer.POST("/addresses", addressHandler.AddAddress)
			customer.GET("/addresses", addressHandler.ListAddresses)
		}

		// ─── Booking Creation (JWT, any role) ────────────
		bookings := v1.Group("/bookings")
		bookings.Use(middleware.AuthMiddleware(cfg.JWTSecret))
		{
			bookings.POST("/", bookingHandler.CreateBooking)
		}

		// ─── Chat Routes (JWT, any role) ─────────────────
		chat := v1.Group("/chat")
		chat.Use(middleware.AuthMiddleware(cfg.JWTSecret))
		{
			chat.POST("/:bookingId/send", chatHandler.SendMessage)
			chat.GET("/:bookingId/messages", chatHandler.GetMessages)
			chat.PUT("/:bookingId/read", chatHandler.MarkChatRead)
		}

		// ─── Payment Routes (JWT, any role) ──────────────
		payment := v1.Group("/payment")
		payment.Use(middleware.AuthMiddleware(cfg.JWTSecret))
		{
			payment.POST("/create-order", paymentHandler.CreateOrder)
			payment.POST("/verify", paymentHandler.VerifyPayment)
		}

		// ─── Partner Routes (JWT + PARTNER role) ─────────
		partner := v1.Group("/partner")
		partner.Use(middleware.AuthMiddleware(cfg.JWTSecret, string(models.RolePartner)))
		{
			// Profile
			partner.GET("/profile", partnerHandler.GetProfile)
			partner.PUT("/profile", partnerHandler.UpdateProfile)
			partner.PUT("/profile/kyc", partnerHandler.UpdateKYC)

			// Online toggle
			partner.POST("/toggle-online", partnerHandler.ToggleOnline)

			// Jobs lifecycle
			partner.GET("/jobs", partnerHandler.ListJobs)
			partner.POST("/jobs/:id/accept", partnerHandler.AcceptJob)
			partner.POST("/jobs/:id/start", partnerHandler.StartJob)
			partner.POST("/jobs/:id/complete", partnerHandler.CompleteJob)
			partner.POST("/jobs/:id/photos", partnerHandler.UploadPhoto)
			partner.GET("/jobs/:id/photos", partnerHandler.GetPhotos)

			// Slots & Leave management
			partner.GET("/slots", slotHandler.GetSlots)
			partner.PUT("/slots/:id/toggle", slotHandler.ToggleSlot)
			partner.POST("/leaves", slotHandler.RequestLeave)
			partner.GET("/leaves", slotHandler.ListLeaves)
			partner.DELETE("/leaves/:id", slotHandler.CancelLeave)

			// Bank account
			partner.GET("/bank", partnerHandler.GetBankDetails)
			partner.POST("/bank", partnerHandler.SubmitBankDetails)
			partner.POST("/bank/verify", partnerHandler.VerifyBank)

			// Earnings & Wallet
			partner.GET("/earnings", partnerHandler.GetEarnings)
			partner.GET("/wallet", partnerHandler.GetWallet)
			partner.POST("/wallet/withdraw", partnerHandler.RequestWithdrawal)

			// Notifications (partner-specific)
			partner.GET("/notifications", notifHandler.ListNotifications)
			partner.PUT("/notifications/:id/read", notifHandler.MarkRead)
			partner.PUT("/notifications/read-all", notifHandler.MarkAllRead)
			partner.GET("/notifications/unread-count", notifHandler.GetUnreadCount)
		}

		// ─── Admin Routes (protected with RoleAdmin) ─────
		admin := v1.Group("/admin")
		admin.Use(middleware.AuthMiddleware(cfg.JWTSecret, string(models.RoleAdmin)))
		{
			// Dashboard
			admin.GET("/stats", adminHandler.DashboardStats)

			// Partner management
			admin.GET("/partners", adminHandler.ListPartners)
			admin.GET("/partners/:id/detail", adminHandler.GetPartnerDetail)
			admin.POST("/partners/:id/approve", adminHandler.ApprovePartnerKYC)
			admin.POST("/partners/:id/reject", adminHandler.RejectPartnerKYC)
			admin.GET("/partners/:id/slots", adminHandler.GetPartnerSlots)
			admin.GET("/partners/:id/leaves", adminHandler.ListPartnerLeaves)
			admin.POST("/partners/:id/leaves/:leaveId/approve", adminHandler.ApproveLeave)
			admin.POST("/partners/:id/leaves/:leaveId/reject", adminHandler.RejectLeave)

			// Booking management
			admin.GET("/bookings", adminHandler.ListBookings)
			admin.POST("/bookings/:id/assign", adminHandler.AssignPartnerToBooking)
			admin.POST("/bookings/:id/cancel", adminHandler.CancelBooking)

			// Customer management
			admin.GET("/customers", adminHandler.ListCustomers)

			// Service & SKU CRUD
			admin.GET("/services", adminHandler.ListServices)
			admin.POST("/services", adminHandler.CreateService)
			admin.DELETE("/services/:id", adminHandler.DeleteService)
			admin.POST("/services/:id/skus", adminHandler.AddSKU)

			// Hub management
			admin.GET("/hubs", adminHandler.ListHubs)
			admin.POST("/hubs", adminHandler.CreateHub)
			admin.PUT("/hubs/:id", adminHandler.UpdateHub)

			// Notifications (admin platform view)
			admin.GET("/notifications", notifHandler.AdminListNotifications)

			// Withdrawals
			admin.GET("/withdrawals", adminHandler.ListWithdrawals)
			admin.POST("/withdrawals/:id/process", adminHandler.ProcessWithdrawal)

			// Announcements
			admin.POST("/announcements", adminHandler.BroadcastAnnouncement)

			// Call recordings
			admin.GET("/calls", callHandler.GetMockCallRecordings)
		}
	}

	// ─── Start Server ────────────────────────────────────
	log.Printf("🚀 Shine-Up API starting on port %s", cfg.Port)
	log.Printf("📋 Routes: Auth(4) + Customer(20) + Booking(1) + Chat(3) + Partner(21) + Admin(18) + WS(1) = 68 endpoints")
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to run server: %v", err)
	}
}
