package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/Shine-Up/backend/internal/models"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PartnerService struct {
	db       *gorm.DB
	notifSvc *NotificationService
}

func NewPartnerService(db *gorm.DB, notifSvc *NotificationService) *PartnerService {
	return &PartnerService{db: db, notifSvc: notifSvc}
}

// ─── Profile ─────────────────────────────────────────────

func (s *PartnerService) GetProfile(ctx context.Context, userID uuid.UUID) (*models.Partner, error) {
	var partner models.Partner
	if err := s.db.Preload("User").Preload("Hub").Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner profile not found")
	}
	return &partner, nil
}

func (s *PartnerService) UpdateProfile(ctx context.Context, userID uuid.UUID, name, docURL string) (*models.Partner, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	if name != "" {
		partner.Name = name
	}
	if docURL != "" {
		partner.DocURL = docURL
		// Reset KYC status when new documents are submitted
		partner.KYCStatus = "PENDING"
	}

	if err := s.db.Save(&partner).Error; err != nil {
		return nil, err
	}
	return &partner, nil
}

// ─── KYC ─────────────────────────────────────────────────

type KYCUpdateRequest struct {
	AadhaarFront   string `json:"aadhaar_front"`
	AadhaarBack    string `json:"aadhaar_back"`
	PanURL         string `json:"pan_url"`
	DrivingLicense string `json:"driving_license"`
	HomePhotoURL   string `json:"home_photo_url"`
	Name           string `json:"name"`
	City           string `json:"city"`
	Category       string `json:"category"`
}

func (s *PartnerService) UpdateKYC(ctx context.Context, userID uuid.UUID, req KYCUpdateRequest) (*models.Partner, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	if req.AadhaarFront != "" {
		partner.AadhaarFront = req.AadhaarFront
	}
	if req.AadhaarBack != "" {
		partner.AadhaarBack = req.AadhaarBack
	}
	if req.PanURL != "" {
		partner.PanURL = req.PanURL
	}
	if req.DrivingLicense != "" {
		partner.DrivingLicense = req.DrivingLicense
	}
	if req.HomePhotoURL != "" {
		partner.HomePhotoURL = req.HomePhotoURL
	}
	if req.Name != "" {
		partner.Name = req.Name
	}
	if req.City != "" {
		partner.City = req.City
	}
	if req.Category != "" {
		partner.Category = req.Category
	}

	// Set KYC status to PENDING for admin review
	partner.KYCStatus = "PENDING"

	if err := s.db.Save(&partner).Error; err != nil {
		return nil, err
	}

	return &partner, nil
}

// ─── Online Toggle ───────────────────────────────────────

func (s *PartnerService) ToggleOnline(ctx context.Context, userID uuid.UUID, online bool) error {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return errors.New("partner not found")
	}

	// Only approved partners can go online
	if online && partner.KYCStatus != "APPROVED" {
		return errors.New("KYC not approved — you cannot go online yet")
	}

	partner.IsOnline = online
	return s.db.Save(&partner).Error
}

// ─── Slots ───────────────────────────────────────────────

func (s *PartnerService) GetSlots(ctx context.Context, userID uuid.UUID, date string) ([]models.PartnerSlot, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var slots []models.PartnerSlot
	s.db.Where("partner_id = ? AND date = ?", partner.ID, date).Order("hour ASC").Find(&slots)

	// Auto-create 16 default slots if none exist for this date
	if len(slots) == 0 {
		for hour := 6; hour <= 21; hour++ {
			slot := models.PartnerSlot{
				PartnerID:   partner.ID,
				Date:        date,
				Hour:        hour,
				IsAvailable: true,
			}
			s.db.Create(&slot)
			slots = append(slots, slot)
		}
	}

	return slots, nil
}

func (s *PartnerService) ToggleSlot(ctx context.Context, userID uuid.UUID, slotID uuid.UUID) (*models.PartnerSlot, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var slot models.PartnerSlot
	if err := s.db.Where("id = ? AND partner_id = ?", slotID, partner.ID).First(&slot).Error; err != nil {
		return nil, errors.New("slot not found")
	}

	// Can't toggle if slot has a booking
	if slot.BookingID != nil {
		return nil, errors.New("cannot toggle a slot that has a booking")
	}

	slot.IsAvailable = !slot.IsAvailable
	if err := s.db.Save(&slot).Error; err != nil {
		return nil, err
	}

	return &slot, nil
}

// ─── Leaves ──────────────────────────────────────────────

func (s *PartnerService) RequestLeave(ctx context.Context, userID uuid.UUID, date string, reason string) (*models.PartnerLeave, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	// Check for duplicate leave request
	var existing models.PartnerLeave
	if err := s.db.Where("partner_id = ? AND date = ? AND status != ?", partner.ID, date, "REJECTED").First(&existing).Error; err == nil {
		return nil, errors.New("leave already requested for this date")
	}

	leave := models.PartnerLeave{
		PartnerID: partner.ID,
		Date:      date,
		Reason:    reason,
		Status:    models.LeavePending,
	}

	if err := s.db.Create(&leave).Error; err != nil {
		return nil, err
	}

	// Mark all slots as unavailable for the leave date
	s.db.Model(&models.PartnerSlot{}).
		Where("partner_id = ? AND date = ? AND booking_id IS NULL", partner.ID, date).
		Update("is_available", false)

	return &leave, nil
}

func (s *PartnerService) ListLeaves(ctx context.Context, userID uuid.UUID) ([]models.PartnerLeave, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var leaves []models.PartnerLeave
	s.db.Where("partner_id = ?", partner.ID).Order("date DESC").Find(&leaves)
	return leaves, nil
}

func (s *PartnerService) CancelLeave(ctx context.Context, userID uuid.UUID, leaveID uuid.UUID) error {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return errors.New("partner not found")
	}

	var leave models.PartnerLeave
	if err := s.db.Where("id = ? AND partner_id = ? AND status = ?", leaveID, partner.ID, "PENDING").First(&leave).Error; err != nil {
		return errors.New("leave not found or not cancellable")
	}

	// Restore availability for slots on that date
	s.db.Model(&models.PartnerSlot{}).
		Where("partner_id = ? AND date = ? AND booking_id IS NULL", partner.ID, leave.Date).
		Update("is_available", true)

	return s.db.Delete(&leave).Error
}

// ─── Jobs ────────────────────────────────────────────────

func (s *PartnerService) ListJobs(ctx context.Context, userID uuid.UUID) ([]models.Booking, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var bookings []models.Booking
	if err := s.db.Preload("SKU").Preload("Customer").Preload("Customer.User").
		Preload("Vehicle").Preload("Address").
		Where("partner_id = ?", partner.ID).
		Order("created_at DESC").
		Find(&bookings).Error; err != nil {
		return nil, err
	}
	return bookings, nil
}

func (s *PartnerService) AcceptJob(ctx context.Context, userID uuid.UUID, bookingID uuid.UUID) error {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return errors.New("partner not found")
	}

	var booking models.Booking
	if err := s.db.Where("id = ? AND partner_id = ?", bookingID, partner.ID).First(&booking).Error; err != nil {
		return errors.New("booking not found or not assigned to you")
	}

	if booking.Status != models.BookingAssigned {
		return errors.New("booking is not in ASSIGNED status")
	}

	// Move to CONFIRMED — partner has accepted
	booking.Status = models.BookingConfirmed
	if err := s.db.Save(&booking).Error; err != nil {
		return err
	}

	// Push real-time notification
	if s.notifSvc != nil {
		s.notifSvc.NotifyJobAccepted(booking)
	}

	return nil
}

func (s *PartnerService) StartJob(ctx context.Context, userID uuid.UUID, bookingID uuid.UUID, otp string) error {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return errors.New("partner not found")
	}

	var booking models.Booking
	if err := s.db.Where("id = ? AND partner_id = ?", bookingID, partner.ID).First(&booking).Error; err != nil {
		return errors.New("booking not found or not assigned to you")
	}

	if booking.Status != models.BookingAssigned && booking.Status != models.BookingConfirmed {
		return errors.New("booking must be ASSIGNED or CONFIRMED to start")
	}

	// Verify OTP from customer
	if booking.OTP != otp {
		return errors.New("invalid OTP — ask the customer for the correct code")
	}

	booking.Status = models.BookingInProgress
	if err := s.db.Save(&booking).Error; err != nil {
		return err
	}

	// Push real-time notification
	if s.notifSvc != nil {
		s.notifSvc.NotifyJobStarted(booking)
	}

	return nil
}

func (s *PartnerService) CompleteJob(ctx context.Context, userID uuid.UUID, bookingID uuid.UUID) error {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return errors.New("partner not found")
	}

	var booking models.Booking
	if err := s.db.Where("id = ? AND partner_id = ?", bookingID, partner.ID).First(&booking).Error; err != nil {
		return errors.New("booking not found or not assigned to you")
	}

	if booking.Status != models.BookingInProgress {
		return errors.New("job must be IN_PROGRESS to complete")
	}

	booking.Status = models.BookingCompleted

	// Create a payment record (stub — Razorpay to be wired later)
	payment := models.Payment{
		BookingID: booking.ID,
		Amount:    booking.TotalAmount,
		Status:    "SUCCESS",
		Method:    "COD",
	}

	// 70% Commission for the partner
	partnerCredit := booking.TotalAmount * 0.70

	err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(&booking).Error; err != nil {
			return err
		}
		if err := tx.Create(&payment).Error; err != nil {
			return err
		}
		// Add to partner wallet
		if err := tx.Model(&partner).Update("wallet_balance", gorm.Expr("wallet_balance + ?", partnerCredit)).Error; err != nil {
			return err
		}
		// Create wallet transaction
		wt := models.WalletTransaction{
			PartnerID: &partner.ID,
			Amount:    partnerCredit,
			Type:      "JOB_CREDIT",
			Reference: fmt.Sprintf("Booking %s", booking.ID.String()[:8]),
		}
		if err := tx.Create(&wt).Error; err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return err
	}

	// Push real-time notification
	if s.notifSvc != nil {
		s.notifSvc.NotifyJobCompleted(booking)
	}

	return nil
}

// ─── Service Photos ──────────────────────────────────────

func (s *PartnerService) UploadServicePhoto(ctx context.Context, userID uuid.UUID, bookingID uuid.UUID, photoType string, photoURL string) (*models.ServicePhoto, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	// Verify booking belongs to partner
	var booking models.Booking
	if err := s.db.Where("id = ? AND partner_id = ?", bookingID, partner.ID).First(&booking).Error; err != nil {
		return nil, errors.New("booking not found or not assigned to you")
	}

	// Validate photo type
	if photoType != models.PhotoSelfie && photoType != models.PhotoBefore && photoType != models.PhotoAfter {
		return nil, errors.New("invalid photo type — must be SELFIE, BEFORE, or AFTER")
	}

	photo := models.ServicePhoto{
		BookingID: bookingID,
		PartnerID: partner.ID,
		PhotoType: photoType,
		PhotoURL:  photoURL,
	}

	if err := s.db.Create(&photo).Error; err != nil {
		return nil, err
	}

	return &photo, nil
}

func (s *PartnerService) GetServicePhotos(ctx context.Context, bookingID uuid.UUID) ([]models.ServicePhoto, error) {
	var photos []models.ServicePhoto
	s.db.Where("booking_id = ?", bookingID).Order("created_at ASC").Find(&photos)
	return photos, nil
}

// ─── Bank Account ────────────────────────────────────────

type BankAccountRequest struct {
	AccountHolder string `json:"account_holder"`
	AccountNumber string `json:"account_number"`
	IFSCCode      string `json:"ifsc_code"`
	BankName      string `json:"bank_name"`
}

func (s *PartnerService) GetBankDetails(ctx context.Context, userID uuid.UUID) (*models.PartnerBankAccount, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var bank models.PartnerBankAccount
	if err := s.db.Where("partner_id = ?", partner.ID).First(&bank).Error; err != nil {
		return nil, nil // No bank account yet, return nil
	}
	return &bank, nil
}

func (s *PartnerService) SubmitBankDetails(ctx context.Context, userID uuid.UUID, req BankAccountRequest) (*models.PartnerBankAccount, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var bank models.PartnerBankAccount
	err := s.db.Where("partner_id = ?", partner.ID).First(&bank).Error

	if err != nil {
		// Create new
		bank = models.PartnerBankAccount{
			PartnerID:     partner.ID,
			AccountHolder: req.AccountHolder,
			AccountNumber: req.AccountNumber,
			IFSCCode:      req.IFSCCode,
			BankName:      req.BankName,
			IsVerified:    false,
		}
		if err := s.db.Create(&bank).Error; err != nil {
			return nil, err
		}
	} else {
		// Update existing
		bank.AccountHolder = req.AccountHolder
		bank.AccountNumber = req.AccountNumber
		bank.IFSCCode = req.IFSCCode
		bank.BankName = req.BankName
		bank.IsVerified = false // Reset verification on update
		if err := s.db.Save(&bank).Error; err != nil {
			return nil, err
		}
	}

	return &bank, nil
}

func (s *PartnerService) MockVerifyBank(ctx context.Context, userID uuid.UUID) (*models.PartnerBankAccount, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var bank models.PartnerBankAccount
	if err := s.db.Where("partner_id = ?", partner.ID).First(&bank).Error; err != nil {
		return nil, errors.New("no bank account found — please submit bank details first")
	}

	// Mock: Just mark as verified (₹1 test simulation)
	bank.IsVerified = true
	partner.BankVerified = true

	if err := s.db.Save(&bank).Error; err != nil {
		return nil, err
	}
	s.db.Save(&partner)

	return &bank, nil
}

// ─── Earnings ────────────────────────────────────────────

type EarningsSummary struct {
	TotalEarnings    float64 `json:"total_earnings"`
	CompletedJobs    int64   `json:"completed_jobs"`
	PendingJobs      int64   `json:"pending_jobs"`
	AverageRating    float64 `json:"average_rating"`
	AcceptanceRate   float64 `json:"acceptance_rate"`
	TotalJobs        int64   `json:"total_jobs"`
}

func (s *PartnerService) GetEarnings(ctx context.Context, userID uuid.UUID) (*EarningsSummary, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var totalEarnings float64
	s.db.Model(&models.Booking{}).
		Where("partner_id = ? AND status = ?", partner.ID, "COMPLETED").
		Select("COALESCE(SUM(total_amount), 0)").Scan(&totalEarnings)

	var completedJobs int64
	s.db.Model(&models.Booking{}).Where("partner_id = ? AND status = ?", partner.ID, "COMPLETED").Count(&completedJobs)

	var pendingJobs int64
	s.db.Model(&models.Booking{}).Where("partner_id = ? AND status IN ?", partner.ID, []string{"ASSIGNED", "CONFIRMED", "IN_PROGRESS"}).Count(&pendingJobs)

	var totalJobs int64
	s.db.Model(&models.Booking{}).Where("partner_id = ?", partner.ID).Count(&totalJobs)

	return &EarningsSummary{
		TotalEarnings:  totalEarnings,
		CompletedJobs:  completedJobs,
		PendingJobs:    pendingJobs,
		AverageRating:  partner.Rating,
		AcceptanceRate: partner.AcceptanceRate,
		TotalJobs:      totalJobs,
	}, nil
}

// ─── Admin: Partner Detail ───────────────────────────────

type PartnerDetailResponse struct {
	Partner        models.Partner             `json:"partner"`
	BankAccount    *models.PartnerBankAccount `json:"bank_account"`
	CompletedJobs  int64                      `json:"completed_jobs"`
	TotalJobs      int64                      `json:"total_jobs"`
	TotalEarnings  float64                    `json:"total_earnings"`
	PendingLeaves  int64                      `json:"pending_leaves"`
}

func (s *PartnerService) GetPartnerDetail(ctx context.Context, partnerID uuid.UUID) (*PartnerDetailResponse, error) {
	var partner models.Partner
	if err := s.db.Preload("User").Preload("Hub").Where("id = ?", partnerID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	var bank models.PartnerBankAccount
	bankPtr := &bank
	if err := s.db.Where("partner_id = ?", partnerID).First(&bank).Error; err != nil {
		bankPtr = nil
	}

	var completedJobs, totalJobs int64
	var totalEarnings float64
	var pendingLeaves int64

	s.db.Model(&models.Booking{}).Where("partner_id = ? AND status = ?", partnerID, "COMPLETED").Count(&completedJobs)
	s.db.Model(&models.Booking{}).Where("partner_id = ?", partnerID).Count(&totalJobs)
	s.db.Model(&models.Booking{}).Where("partner_id = ? AND status = ?", partnerID, "COMPLETED").Select("COALESCE(SUM(total_amount), 0)").Scan(&totalEarnings)
	s.db.Model(&models.PartnerLeave{}).Where("partner_id = ? AND status = ?", partnerID, "PENDING").Count(&pendingLeaves)

	return &PartnerDetailResponse{
		Partner:       partner,
		BankAccount:   bankPtr,
		CompletedJobs: completedJobs,
		TotalJobs:     totalJobs,
		TotalEarnings: totalEarnings,
		PendingLeaves: pendingLeaves,
	}, nil
}

// ─── Admin: Slot View ────────────────────────────────────

func (s *PartnerService) GetPartnerSlots(ctx context.Context, partnerID uuid.UUID, date string) ([]models.PartnerSlot, error) {
	var slots []models.PartnerSlot
	s.db.Where("partner_id = ? AND date = ?", partnerID, date).Order("hour ASC").Find(&slots)

	if len(slots) == 0 {
		for hour := 6; hour <= 21; hour++ {
			slot := models.PartnerSlot{
				PartnerID:   partnerID,
				Date:        date,
				Hour:        hour,
				IsAvailable: true,
			}
			s.db.Create(&slot)
			slots = append(slots, slot)
		}
	}

	return slots, nil
}

// ─── Admin: Leave Management ─────────────────────────────

func (s *PartnerService) ApproveLeave(ctx context.Context, leaveID uuid.UUID) error {
	return s.db.Model(&models.PartnerLeave{}).Where("id = ?", leaveID).Update("status", models.LeaveApproved).Error
}

func (s *PartnerService) RejectLeave(ctx context.Context, leaveID uuid.UUID) error {
	var leave models.PartnerLeave
	if err := s.db.Where("id = ?", leaveID).First(&leave).Error; err != nil {
		return errors.New("leave not found")
	}

	leave.Status = models.LeaveRejected
	if err := s.db.Save(&leave).Error; err != nil {
		return err
	}

	// Restore slot availability
	s.db.Model(&models.PartnerSlot{}).
		Where("partner_id = ? AND date = ? AND booking_id IS NULL", leave.PartnerID, leave.Date).
		Update("is_available", true)

	return nil
}

// ─── Auto-Assignment Helper ──────────────────────────────

func (s *PartnerService) FindBestAvailablePartner(ctx context.Context, slotStart string, hour int) (*models.Partner, error) {
	var partners []models.Partner
	if err := s.db.Where("is_online = ? AND kyc_status = ?", true, "APPROVED").
		Order("rating DESC, acceptance_rate DESC").
		Find(&partners).Error; err != nil {
		return nil, err
	}

	for _, p := range partners {
		// Check if partner has an available slot
		var slot models.PartnerSlot
		err := s.db.Where("partner_id = ? AND date = ? AND hour = ? AND is_available = ? AND booking_id IS NULL",
			p.ID, slotStart, hour, true).First(&slot).Error
		if err == nil {
			return &p, nil
		}

		// If no slot record exists, the partner is assumed available (auto-create later)
		var count int64
		s.db.Model(&models.PartnerSlot{}).Where("partner_id = ? AND date = ?", p.ID, slotStart).Count(&count)
		if count == 0 {
			return &p, nil
		}
	}

	return nil, fmt.Errorf("no available partner found for this time slot")
}

// ─── Wallet & Withdrawals ────────────────────────────────

func (s *PartnerService) GetWallet(ctx context.Context, userID uuid.UUID) (float64, []models.WalletTransaction, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return 0, nil, errors.New("partner not found")
	}

	var txns []models.WalletTransaction
	s.db.Where("partner_id = ?", partner.ID).Order("created_at DESC").Limit(50).Find(&txns)

	return partner.WalletBalance, txns, nil
}

func (s *PartnerService) RequestWithdrawal(ctx context.Context, userID uuid.UUID, amount float64) (*models.WithdrawalRequest, error) {
	var partner models.Partner
	if err := s.db.Where("user_id = ?", userID).First(&partner).Error; err != nil {
		return nil, errors.New("partner not found")
	}

	if partner.WalletBalance < amount {
		return nil, errors.New("insufficient balance")
	}

	if amount < 500 {
		return nil, errors.New("minimum withdrawal amount is ₹500")
	}

	// Enforce 1st or 2nd of the month rule (with bypass)
	day := time.Now().Day()
	if day != 1 && day != 2 {
		// Mock dev bypass if amount is exactly x.99
		if int(amount*100)%100 != 99 {
			return nil, errors.New("withdrawals are only allowed on the 1st and 2nd of the month")
		}
	}

	var req models.WithdrawalRequest
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Deduct from wallet
		if err := tx.Model(&partner).Update("wallet_balance", gorm.Expr("wallet_balance - ?", amount)).Error; err != nil {
			return err
		}

		// Create withdrawal request
		req = models.WithdrawalRequest{
			PartnerID: partner.ID,
			Amount:    amount,
			Status:    "PENDING",
		}
		if err := tx.Create(&req).Error; err != nil {
			return err
		}

		// Create wallet transaction
		wt := models.WalletTransaction{
			PartnerID: &partner.ID,
			Amount:    -amount,
			Type:      "WITHDRAWAL",
			Reference: fmt.Sprintf("Req %s", req.ID.String()[:8]),
		}
		if err := tx.Create(&wt).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	return &req, nil
}
