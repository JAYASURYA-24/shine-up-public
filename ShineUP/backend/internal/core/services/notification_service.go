package services

import (
	"log"
	"time"

	"github.com/Shine-Up/backend/internal/models"
	"github.com/Shine-Up/backend/internal/websocket"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// NotificationService handles creating, persisting, and pushing notifications
type NotificationService struct {
	db  *gorm.DB
	hub *websocket.Hub
}

// NewNotificationService creates a NotificationService
func NewNotificationService(db *gorm.DB, hub *websocket.Hub) *NotificationService {
	return &NotificationService{db: db, hub: hub}
}

// ─── Core Methods ────────────────────────────────────────

// CreateAndPush persists a notification to DB and pushes it via WebSocket
func (s *NotificationService) CreateAndPush(userID uuid.UUID, title, body string) error {
	notif := models.Notification{
		UserID: userID,
		Title:  title,
		Body:   body,
	}
	if err := s.db.Create(&notif).Error; err != nil {
		log.Printf("Error creating notification for user %s: %v", userID, err)
		return err
	}

	// Push via WebSocket
	if s.hub != nil {
		s.hub.BroadcastToUser(userID, websocket.WSMessage{
			Type: models.WSTypeNewNotification,
			Payload: map[string]interface{}{
				"id":    notif.ID.String(),
				"title": title,
				"body":  body,
			},
			Time: time.Now(),
		})
	}

	return nil
}

// MarkAsRead marks a single notification as read
func (s *NotificationService) MarkAsRead(notificationID uuid.UUID) error {
	return s.db.Model(&models.Notification{}).Where("id = ?", notificationID).Update("is_read", true).Error
}

// MarkAllRead marks all notifications for a user as read
func (s *NotificationService) MarkAllRead(userID uuid.UUID) error {
	return s.db.Model(&models.Notification{}).Where("user_id = ? AND is_read = ?", userID, false).Update("is_read", true).Error
}

// GetUnreadCount returns the count of unread notifications for a user
func (s *NotificationService) GetUnreadCount(userID uuid.UUID) (int64, error) {
	var count int64
	err := s.db.Model(&models.Notification{}).Where("user_id = ? AND is_read = ?", userID, false).Count(&count).Error
	return count, err
}

// ListNotifications returns notifications for a user (paginated)
func (s *NotificationService) ListNotifications(userID uuid.UUID, limit, offset int) ([]models.Notification, error) {
	var notifications []models.Notification
	err := s.db.Where("user_id = ?", userID).
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&notifications).Error
	return notifications, err
}

// ListAllNotifications returns all platform notifications (admin view)
func (s *NotificationService) ListAllNotifications(limit, offset int) ([]models.Notification, error) {
	var notifications []models.Notification
	err := s.db.Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&notifications).Error
	return notifications, err
}

// ─── Booking Lifecycle Notifications ─────────────────────

// NotifyBookingCreated notifies admins about a new booking
func (s *NotificationService) NotifyBookingCreated(booking models.Booking) {
	// Push live feed to all admins
	if s.hub != nil {
		s.hub.BroadcastToRole("ADMIN", websocket.WSMessage{
			Type: models.WSTypeLiveFeed,
			Payload: map[string]interface{}{
				"event":      "BOOKING_CREATED",
				"booking_id": booking.ID.String(),
				"status":     booking.Status,
				"amount":     booking.TotalAmount,
			},
			Time: time.Now(),
		})
	}
}

// NotifyBookingAssigned notifies customer and partner when a booking is assigned
func (s *NotificationService) NotifyBookingAssigned(booking models.Booking) {
	// Notify customer
	s.CreateAndPush(booking.CustomerID,
		"Partner Assigned! 🎉",
		"A service partner has been assigned to your booking. They'll be there on time!")

	// Notify partner (new job)
	if booking.PartnerID != nil {
		s.CreateAndPush(*booking.PartnerID,
			"New Job Assigned! 📋",
			"You have a new job assignment. Please review and accept it.")

		// Also send NEW_JOB event for Partner App to show instant alert
		if s.hub != nil {
			s.hub.BroadcastToUser(*booking.PartnerID, websocket.WSMessage{
				Type: models.WSTypeNewJob,
				Payload: map[string]interface{}{
					"booking_id": booking.ID.String(),
					"status":     booking.Status,
					"amount":     booking.TotalAmount,
				},
				Time: time.Now(),
			})
		}
	}

	// Admin live feed
	s.broadcastAdminFeed("BOOKING_ASSIGNED", booking)
}

// NotifyJobAccepted notifies customer when partner accepts a job
func (s *NotificationService) NotifyJobAccepted(booking models.Booking) {
	s.CreateAndPush(booking.CustomerID,
		"Partner Confirmed! ✅",
		"Your service partner has confirmed the booking. See you soon!")

	s.broadcastBookingUpdate(booking)
	s.broadcastAdminFeed("JOB_ACCEPTED", booking)
}

// NotifyJobStarted notifies customer when the job starts
func (s *NotificationService) NotifyJobStarted(booking models.Booking) {
	s.CreateAndPush(booking.CustomerID,
		"Service Started! 🔧",
		"Your service is now in progress. Sit back and relax!")

	s.broadcastBookingUpdate(booking)
	s.broadcastAdminFeed("JOB_STARTED", booking)
}

// NotifyJobCompleted notifies customer and admin when the job is done
func (s *NotificationService) NotifyJobCompleted(booking models.Booking) {
	s.CreateAndPush(booking.CustomerID,
		"Service Completed! ⭐",
		"Your service has been completed. Please rate your experience!")

	if booking.PartnerID != nil {
		s.CreateAndPush(*booking.PartnerID,
			"Job Done! 💰",
			"Great work! Your earnings have been updated.")
	}

	s.broadcastBookingUpdate(booking)
	s.broadcastAdminFeed("JOB_COMPLETED", booking)
}

// NotifyBookingCancelled notifies both customer and partner
func (s *NotificationService) NotifyBookingCancelled(booking models.Booking) {
	s.CreateAndPush(booking.CustomerID,
		"Booking Cancelled",
		"Your booking has been cancelled.")

	if booking.PartnerID != nil {
		s.CreateAndPush(*booking.PartnerID,
			"Job Cancelled",
			"A job has been cancelled by the customer or admin.")
	}

	s.broadcastBookingUpdate(booking)
	s.broadcastAdminFeed("BOOKING_CANCELLED", booking)
}

// NotifyBookingRescheduled notifies partner about rescheduled booking
func (s *NotificationService) NotifyBookingRescheduled(booking models.Booking) {
	if booking.PartnerID != nil {
		s.CreateAndPush(*booking.PartnerID,
			"Job Rescheduled 📅",
			"A booking has been rescheduled to a new time. Please check your schedule.")
	}

	s.broadcastBookingUpdate(booking)
	s.broadcastAdminFeed("BOOKING_RESCHEDULED", booking)
}

// NotifyChatMessage pushes a chat message to the recipient in real-time
func (s *NotificationService) NotifyChatMessage(msg models.ChatMessage) {
	if s.hub == nil {
		return
	}

	// Determine recipient: get booking and figure out who should receive
	var booking models.Booking
	if err := s.db.First(&booking, "id = ?", msg.BookingID).Error; err != nil {
		return
	}

	var recipientID uuid.UUID
	if msg.SenderRole == "CUSTOMER" && booking.PartnerID != nil {
		recipientID = *booking.PartnerID
	} else {
		recipientID = booking.CustomerID
	}

	s.hub.BroadcastToUser(recipientID, websocket.WSMessage{
		Type: models.WSTypeChatMessage,
		Payload: map[string]interface{}{
			"id":          msg.ID.String(),
			"booking_id":  msg.BookingID.String(),
			"sender_id":   msg.SenderID.String(),
			"sender_role": msg.SenderRole,
			"message":     msg.Message,
			"created_at":  msg.CreatedAt,
		},
		Time: time.Now(),
	})
}

// ─── Helper Methods ──────────────────────────────────────

func (s *NotificationService) broadcastBookingUpdate(booking models.Booking) {
	if s.hub == nil {
		return
	}

	msg := websocket.WSMessage{
		Type: models.WSTypeBookingUpdate,
		Payload: map[string]interface{}{
			"booking_id": booking.ID.String(),
			"status":     booking.Status,
		},
		Time: time.Now(),
	}

	// Send to customer
	s.hub.BroadcastToUser(booking.CustomerID, msg)

	// Send to partner
	if booking.PartnerID != nil {
		s.hub.BroadcastToUser(*booking.PartnerID, msg)
	}
}

func (s *NotificationService) broadcastAdminFeed(event string, booking models.Booking) {
	if s.hub == nil {
		return
	}

	s.hub.BroadcastToRole("ADMIN", websocket.WSMessage{
		Type: models.WSTypeLiveFeed,
		Payload: map[string]interface{}{
			"event":      event,
			"booking_id": booking.ID.String(),
			"status":     booking.Status,
			"amount":     booking.TotalAmount,
		},
		Time: time.Now(),
	})
}

// NotifyToAdmin sends a generic SOS/Alert to Admin live feed
func (s *NotificationService) NotifyToAdmin(title, message string) {
	if s.hub == nil {
		return
	}

	s.hub.BroadcastToRole("ADMIN", websocket.WSMessage{
		Type: models.WSTypeLiveFeed,
		Payload: map[string]interface{}{
			"event":   "ADMIN_ALERT",
			"title":   title,
			"message": message,
		},
		Time: time.Now(),
	})
}
