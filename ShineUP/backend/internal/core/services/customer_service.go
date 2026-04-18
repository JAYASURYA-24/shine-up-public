package services

import (
	"context"
	"errors"
	"fmt"
	"math/rand"
	"strings"
	"time"

	"github.com/Shine-Up/backend/internal/models"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type CustomerService struct {
	db       *gorm.DB
	notifSvc *NotificationService
}

func NewCustomerService(db *gorm.DB, notifSvc *NotificationService) *CustomerService {
	return &CustomerService{db: db, notifSvc: notifSvc}
}

// ─── Profile ─────────────────────────────────────────────

func (s *CustomerService) GetProfile(ctx context.Context, userID uuid.UUID) (*models.Customer, error) {
	var customer models.Customer
	if err := s.db.Preload("User").Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return nil, errors.New("customer profile not found")
	}

	// Auto-generate referral code if missing
	if customer.ReferralCode == "" {
		code := generateReferralCode()
		customer.ReferralCode = code
		s.db.Save(&customer)
	}

	return &customer, nil
}

func (s *CustomerService) UpdateProfile(ctx context.Context, userID uuid.UUID, name, email, location string) (*models.Customer, error) {
	var customer models.Customer
	if err := s.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return nil, errors.New("customer not found")
	}

	if name != "" {
		customer.Name = name
	}
	if email != "" {
		customer.Email = email
	}
	if location != "" {
		customer.Location = location
	}

	if err := s.db.Save(&customer).Error; err != nil {
		return nil, err
	}

	return &customer, nil
}

// ─── Bookings ────────────────────────────────────────────

func (s *CustomerService) ListMyBookings(ctx context.Context, userID uuid.UUID) ([]models.Booking, error) {
	// First get customer ID from user ID
	var customer models.Customer
	if err := s.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return nil, errors.New("customer not found")
	}

	var bookings []models.Booking
	if err := s.db.Preload("SKU").Preload("Partner").Preload("Partner.User").
		Where("customer_id = ?", customer.ID).
		Order("created_at DESC").
		Find(&bookings).Error; err != nil {
		return nil, err
	}
	return bookings, nil
}

func (s *CustomerService) GetBookingDetail(ctx context.Context, userID uuid.UUID, bookingID uuid.UUID) (*models.Booking, error) {
	var customer models.Customer
	if err := s.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return nil, errors.New("customer not found")
	}

	var booking models.Booking
	if err := s.db.Preload("SKU").Preload("Partner").Preload("Partner.User").
		Where("id = ? AND customer_id = ?", bookingID, customer.ID).
		First(&booking).Error; err != nil {
		return nil, errors.New("booking not found")
	}
	return &booking, nil
}

func (s *CustomerService) CancelBooking(ctx context.Context, userID uuid.UUID, bookingID uuid.UUID, reason string) error {
	var customer models.Customer
	if err := s.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return errors.New("customer not found")
	}

	var booking models.Booking
	if err := s.db.Where("id = ? AND customer_id = ?", bookingID, customer.ID).First(&booking).Error; err != nil {
		return errors.New("booking not found")
	}

	// Only CREATED or ASSIGNED bookings can be cancelled
	if booking.Status != "CREATED" && booking.Status != "ASSIGNED" {
		return errors.New("booking cannot be cancelled in current status")
	}

	booking.Status = "CANCELLED"
	booking.CancelNote = reason
	if err := s.db.Save(&booking).Error; err != nil {
		return err
	}

	// Push real-time notification
	if s.notifSvc != nil {
		s.notifSvc.NotifyBookingCancelled(booking)
	}

	return nil
}

func (s *CustomerService) RescheduleBooking(ctx context.Context, userID uuid.UUID, bookingID uuid.UUID, newSlotStart time.Time) error {
	var customer models.Customer
	if err := s.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return errors.New("customer not found")
	}

	var booking models.Booking
	if err := s.db.Preload("SKU").Where("id = ? AND customer_id = ?", bookingID, customer.ID).First(&booking).Error; err != nil {
		return errors.New("booking not found")
	}

	if booking.Status != "CREATED" && booking.Status != "ASSIGNED" {
		return errors.New("booking cannot be rescheduled in current status")
	}

	duration := booking.SlotEnd.Sub(booking.SlotStart)
	booking.SlotStart = newSlotStart
	booking.SlotEnd = newSlotStart.Add(duration)

	if err := s.db.Save(&booking).Error; err != nil {
		return err
	}

	// Push real-time notification
	if s.notifSvc != nil {
		s.notifSvc.NotifyBookingRescheduled(booking)
	}

	return nil
}

// ─── Rating ──────────────────────────────────────────────

func (s *CustomerService) RateBooking(ctx context.Context, userID uuid.UUID, bookingID uuid.UUID, stars int, review string) error {
	var customer models.Customer
	if err := s.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return errors.New("customer not found")
	}

	var booking models.Booking
	if err := s.db.Where("id = ? AND customer_id = ?", bookingID, customer.ID).First(&booking).Error; err != nil {
		return errors.New("booking not found")
	}

	if booking.Status != "COMPLETED" {
		return errors.New("can only rate completed bookings")
	}

	if booking.PartnerID == nil {
		return errors.New("no partner assigned to this booking")
	}

	// Check if already rated
	var existing models.Rating
	if err := s.db.Where("booking_id = ?", bookingID).First(&existing).Error; err == nil {
		return errors.New("booking already rated")
	}

	rating := models.Rating{
		BookingID:  bookingID,
		CustomerID: customer.ID,
		PartnerID:  *booking.PartnerID,
		Stars:      stars,
		Review:     review,
	}

	if err := s.db.Create(&rating).Error; err != nil {
		return err
	}

	// Update partner's average rating
	var avgRating float64
	s.db.Model(&models.Rating{}).Where("partner_id = ?", *booking.PartnerID).Select("COALESCE(AVG(stars), 5.0)").Scan(&avgRating)
	s.db.Model(&models.Partner{}).Where("id = ?", *booking.PartnerID).Update("rating", avgRating)

	return nil
}

// ─── Wallet ──────────────────────────────────────────────

func (s *CustomerService) GetWallet(ctx context.Context, userID uuid.UUID) (float64, []models.WalletTransaction, error) {
	var customer models.Customer
	if err := s.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return 0, nil, errors.New("customer not found")
	}

	var txns []models.WalletTransaction
	s.db.Where("customer_id = ?", customer.ID).Order("created_at DESC").Limit(50).Find(&txns)

	return customer.WalletBalance, txns, nil
}

func (s *CustomerService) ApplyReferral(ctx context.Context, userID uuid.UUID, referralCode string) error {
	var customer models.Customer
	if err := s.db.Where("user_id = ?", userID).First(&customer).Error; err != nil {
		return errors.New("customer not found")
	}

	// Can't use own code
	if customer.ReferralCode == referralCode {
		return errors.New("cannot use your own referral code")
	}

	// Check if already used a referral
	var existingTxn models.WalletTransaction
	if err := s.db.Where("customer_id = ? AND type = ?", customer.ID, "REFERRAL_BONUS").First(&existingTxn).Error; err == nil {
		return errors.New("you have already used a referral code")
	}

	// Find referrer
	var referrer models.Customer
	if err := s.db.Where("referral_code = ?", referralCode).First(&referrer).Error; err != nil {
		return errors.New("invalid referral code")
	}

	bonusAmount := 50.0 // ₹50 bonus

	// Credit to new user
	s.db.Model(&customer).Update("wallet_balance", gorm.Expr("wallet_balance + ?", bonusAmount))
	s.db.Create(&models.WalletTransaction{
		CustomerID: &customer.ID,
		Amount:     bonusAmount,
		Type:       "REFERRAL_BONUS",
		Reference:  fmt.Sprintf("Referred by %s", referralCode),
	})

	// Credit to referrer
	s.db.Model(&referrer).Update("wallet_balance", gorm.Expr("wallet_balance + ?", bonusAmount))
	s.db.Create(&models.WalletTransaction{
		CustomerID: &referrer.ID,
		Amount:     bonusAmount,
		Type:       "REFERRAL_BONUS",
		Reference:  fmt.Sprintf("Referral used by user %s", customer.ID.String()[:8]),
	})

	return nil
}

// ─── Notifications ───────────────────────────────────────

func (s *CustomerService) ListNotifications(ctx context.Context, userID uuid.UUID) ([]models.Notification, error) {
	var notifications []models.Notification
	if err := s.db.Where("user_id = ?", userID).Order("created_at DESC").Limit(50).Find(&notifications).Error; err != nil {
		return nil, err
	}
	return notifications, nil
}

// ─── Helpers ─────────────────────────────────────────────

func generateReferralCode() string {
	const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var sb strings.Builder
	sb.WriteString("SHINE")
	for i := 0; i < 5; i++ {
		sb.WriteByte(chars[rand.Intn(len(chars))])
	}
	return sb.String()
}
