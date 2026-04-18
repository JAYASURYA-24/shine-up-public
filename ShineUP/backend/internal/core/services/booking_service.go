package services

import (
	"context"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/Shine-Up/backend/internal/models"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

type BookingService struct {
	db       *gorm.DB
	redis    *redis.Client
	notifSvc *NotificationService
}

func NewBookingService(db *gorm.DB, redisClient *redis.Client, notifSvc *NotificationService) *BookingService {
	return &BookingService{db: db, redis: redisClient, notifSvc: notifSvc}
}

func (s *BookingService) FetchServices(ctx context.Context) ([]models.Service, error) {
	var services []models.Service
	// Preload the SKUs with the service so client gets categories + variants mapping
	if err := s.db.Preload("SKUs").Find(&services).Error; err != nil {
		return nil, err
	}
	return services, nil
}

// GetAvailableSlots generates available time slots for a given date
// It assumes 16 slots per day, from 06:00 to 21:00 spaced by 1 hour (for simplicity)
func (s *BookingService) GetAvailableSlots(ctx context.Context, dateStr string, skuID uuid.UUID) ([]time.Time, error) {
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		return nil, errors.New("invalid date format, use YYYY-MM-DD")
	}

	var slots []time.Time
	// Generate slots from 06:00 to 21:00
	for hour := 6; hour <= 21; hour++ {
		slotTime := time.Date(date.Year(), date.Month(), date.Day(), hour, 0, 0, 0, time.UTC)
		// Only add slots in the future
		if slotTime.After(time.Now().UTC().Add(2 * time.Hour)) {
			// Check if slot is already fully booked in DB (mock logic: limit 5 bookings per slot for the platform)
			var count int64
			s.db.Model(&models.Booking{}).Where("slot_start = ?", slotTime).Count(&count)
			if count < 5 {
				slots = append(slots, slotTime)
			}
		}
	}
	return slots, nil
}

func (s *BookingService) ReserveSlotAndBook(ctx context.Context, customerID uuid.UUID, skuID uuid.UUID, vehicleID *uuid.UUID, addressID *uuid.UUID, timeSlot time.Time) (*models.Booking, error) {
	// 1. Look up the SKU to get pricing and duration
	var sku models.SKU
	if err := s.db.First(&sku, "id = ?", skuID).Error; err != nil {
		return nil, errors.New("invalid SKU")
	}

	// Calculate end time
	endTime := timeSlot.Add(time.Duration(sku.DurationMins) * time.Minute)

	// --- Redis Distributed Lock implementation ---
	lockKey := fmt.Sprintf("lock:slot:%s:%s", skuID.String(), timeSlot.UTC().Format(time.RFC3339))

	if s.redis != nil {
		acquired, err := s.redis.SetNX(ctx, lockKey, "locked", 30*time.Second).Result()
		if err != nil {
			return nil, fmt.Errorf("redis lock err: %w", err)
		}
		if !acquired {
			return nil, errors.New("this slot is currently being booked by someone else, please try again")
		}
		defer s.redis.Del(ctx, lockKey)
	}

	// 2. Look up the customer record from user ID
	var customer models.Customer
	if err := s.db.Where("user_id = ?", customerID).First(&customer).Error; err != nil {
		// If customerID is already a customer.ID (not user.ID), try that
		if err2 := s.db.Where("id = ?", customerID).First(&customer).Error; err2 != nil {
			return nil, errors.New("customer not found")
		}
	}

	// 2.5 Geofencing Check
	if addressID != nil {
		var address models.Address
		if err := s.db.First(&address, "id = ?", addressID).Error; err == nil {
			var hubs []models.Hub
			s.db.Where("is_active = ?", true).Find(&hubs)
			
			isServiceable := false
			for _, hub := range hubs {
				dist := haversine(address.Latitude, address.Longitude, hub.Latitude, hub.Longitude)
				if dist <= hub.RadiusKm {
					isServiceable = true
					break
				}
			}
			
			// For bypassing in dev if no hubs exist
			if len(hubs) > 0 && !isServiceable {
				return nil, errors.New("selected address is outside our service area")
			}
		}
	}

	// 3. Transaction to create booking safely
	var booking models.Booking
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Prevents double booking for the exact same customer
		var existingCount int64
		tx.Model(&models.Booking{}).Where("customer_id = ? AND slot_start = ?", customer.ID, timeSlot).Count(&existingCount)
		if existingCount > 0 {
			return errors.New("you already have a booking for this time slot")
		}

		// Generate random 4-digit OTP
		otp := fmt.Sprintf("%04d", time.Now().UnixNano()%10000)

		booking = models.Booking{
			CustomerID:  customer.ID,
			SKUID:       skuID,
			VehicleID:   vehicleID,
			AddressID:   addressID,
			Status:      models.BookingScheduled,
			SlotStart:   timeSlot,
			SlotEnd:     endTime,
			TotalAmount: sku.Price,
			OTP:         otp,
		}

		if err := tx.Create(&booking).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	// 4. Notify about new booking
	if s.notifSvc != nil {
		s.notifSvc.NotifyBookingCreated(booking)
	}

	// 5. Try auto-assignment in a goroutine (non-blocking)
	go s.AutoAssignPartner(context.Background(), booking.ID)

	return &booking, nil
}

// ─── Auto-Assignment Engine ──────────────────────────────

func (s *BookingService) AutoAssignPartner(ctx context.Context, bookingID uuid.UUID) {
	var booking models.Booking
	if err := s.db.First(&booking, "id = ?", bookingID).Error; err != nil {
		return
	}

	// Only auto-assign SCHEDULED bookings
	if booking.Status != models.BookingScheduled {
		return
	}

	dateStr := booking.SlotStart.Format("2006-01-02")
	hour := booking.SlotStart.Hour()

	// Find available partners sorted by rating and acceptance rate
	var partners []models.Partner
	s.db.Where("is_online = ? AND kyc_status = ?", true, "APPROVED").
		Order("rating DESC, acceptance_rate DESC").
		Find(&partners)

	for _, partner := range partners {
		// Check if partner has a leave on this date
		var leaveCount int64
		s.db.Model(&models.PartnerLeave{}).
			Where("partner_id = ? AND date = ? AND status IN ?", partner.ID, dateStr, []string{"PENDING", "APPROVED"}).
			Count(&leaveCount)
		if leaveCount > 0 {
			continue
		}

		// Check slot availability
		var slot models.PartnerSlot
		err := s.db.Where("partner_id = ? AND date = ? AND hour = ? AND is_available = ? AND booking_id IS NULL",
			partner.ID, dateStr, hour, true).First(&slot).Error

		available := false
		if err == nil {
			available = true
		} else {
			// No slot record — partner might not have slots created yet, assume available
			var slotCount int64
			s.db.Model(&models.PartnerSlot{}).Where("partner_id = ? AND date = ?", partner.ID, dateStr).Count(&slotCount)
			if slotCount == 0 {
				available = true
				// Auto-create slots for this partner on this date
				for h := 6; h <= 21; h++ {
					newSlot := models.PartnerSlot{
						PartnerID:   partner.ID,
						Date:        dateStr,
						Hour:        h,
						IsAvailable: true,
					}
					s.db.Create(&newSlot)
					if h == hour {
						slot = newSlot
					}
				}
			}
		}

		if !available {
			continue
		}

		// Assign this partner
		partnerID := partner.ID
		booking.PartnerID = &partnerID
		booking.Status = models.BookingAssigned

		if err := s.db.Save(&booking).Error; err != nil {
			continue
		}

		// Mark slot as occupied
		if slot.ID != uuid.Nil {
			slot.BookingID = &booking.ID
			slot.IsAvailable = false
			s.db.Save(&slot)
		}

		// Push real-time notification to both customer & partner
		if s.notifSvc != nil {
			s.notifSvc.NotifyBookingAssigned(booking)
		}

		return // Successfully assigned
	}

	// No partner found — schedule a retry in 30 seconds (mocking 10 mins for local testing)
	go func() {
		time.Sleep(30 * time.Second)
		
		// Check booking status again
		var checkBooking models.Booking
		if err := s.db.First(&checkBooking, "id = ?", bookingID).Error; err != nil {
			return
		}

		if checkBooking.Status == models.BookingScheduled {
			// Still unassigned, transition to UNASSIGNED (SOS state)
			checkBooking.Status = "UNASSIGNED"
			s.db.Save(&checkBooking)

			if s.notifSvc != nil {
				// Send an Admin SOS Notification
				s.notifSvc.NotifyToAdmin("Booking Assignment Timeout", fmt.Sprintf("Booking %s could not be auto-assigned after timeout.", bookingID))
			}
		}
	}()
}

// ─── Helpers ───────────────────────────────────────────────────

func haversine(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371 // Earth radius in km
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0
	lat1Rad := lat1 * math.Pi / 180.0
	lat2Rad := lat2 * math.Pi / 180.0

	a := math.Sin(dLat/2)*math.Sin(dLat/2) + math.Sin(dLon/2)*math.Sin(dLon/2)*math.Cos(lat1Rad)*math.Cos(lat2Rad)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}
