package models

import (
	"database/sql/driver"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ─── Roles ───────────────────────────────────────────────
type Role string
const (
	RoleCustomer Role = "CUSTOMER"
	RolePartner  Role = "PARTNER"
	RoleAdmin    Role = "ADMIN"
)

// ─── Service Categories ──────────────────────────────────
const (
	CategoryVehicleWash    = "VEHICLE_WASH"
	CategoryMonthlyPackage = "MONTHLY_PACKAGE"
	CategoryPUC            = "PUC_CERTIFICATE"
	CategoryHomeCleaning   = "HOME_CLEANING"
	CategoryAccessories    = "ACCESSORIES"
)

// ─── Vehicle Types ───────────────────────────────────────
const (
	VehicleType2W = "2W"
	VehicleType4W = "4W"
)

// ─── Booking States ──────────────────────────────────────
const (
	BookingScheduled   = "SCHEDULED"
	BookingAssigned    = "ASSIGNED"
	BookingConfirmed   = "CONFIRMED"
	BookingInProgress  = "IN_PROGRESS"
	BookingCompleted   = "COMPLETED"
	BookingCancelled   = "CANCELLED"
	BookingRescheduled = "RESCHEDULED"
	BookingNoResponse  = "NO_RESPONSE"
)

// ─── Leave Status ────────────────────────────────────────
const (
	LeavePending  = "PENDING"
	LeaveApproved = "APPROVED"
	LeaveRejected = "REJECTED"
)

// ─── Photo Types ─────────────────────────────────────────
const (
	PhotoSelfie = "SELFIE"
	PhotoBefore = "BEFORE"
	PhotoAfter  = "AFTER"
)

// ─── JSON Field Helper ──────────────────────────────────
type JSONField []string

func (j JSONField) Value() (driver.Value, error) {
	if j == nil {
		return "[]", nil
	}
	b, err := json.Marshal(j)
	return string(b), err
}

func (j *JSONField) Scan(value interface{}) error {
	if value == nil {
		*j = []string{}
		return nil
	}
	var bytes []byte
	switch v := value.(type) {
	case string:
		bytes = []byte(v)
	case []byte:
		bytes = v
	}
	return json.Unmarshal(bytes, j)
}

// ─── User ────────────────────────────────────────────────
type User struct {
	ID        uuid.UUID `gorm:"primaryKey" json:"id"`
	Phone     string    `gorm:"uniqueIndex;not null" json:"phone"`
	Role      Role      `gorm:"type:varchar(20);not null" json:"role"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ─── Customer ────────────────────────────────────────────
type Customer struct {
	ID            uuid.UUID  `gorm:"primaryKey" json:"id"`
	UserID        uuid.UUID  `gorm:"not null" json:"user_id"`
	Name          string     `json:"name"`
	Email         string     `json:"email"`
	Location      string     `json:"location"`
	WalletBalance float64    `gorm:"default:0" json:"wallet_balance"`
	ReferralCode  string     `gorm:"uniqueIndex" json:"referral_code"`
	User          User       `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Vehicles      []Vehicle  `gorm:"foreignKey:CustomerID" json:"vehicles,omitempty"`
	Addresses     []Address  `gorm:"foreignKey:CustomerID" json:"addresses,omitempty"`
}

// ─── Vehicle ─────────────────────────────────────────────
type Vehicle struct {
	ID           uuid.UUID `gorm:"primaryKey" json:"id"`
	CustomerID   uuid.UUID `gorm:"not null;index" json:"customer_id"`
	VehicleType  string    `gorm:"type:varchar(5);not null" json:"vehicle_type"` // 2W or 4W
	VehicleNumber string   `gorm:"not null" json:"vehicle_number"`
	ModelName    string    `json:"model_name"`
	IsDefault    bool      `gorm:"default:false" json:"is_default"`
	CreatedAt    time.Time `json:"created_at"`
}

// ─── Address ─────────────────────────────────────────────
type Address struct {
	ID           uuid.UUID `gorm:"primaryKey" json:"id"`
	CustomerID   uuid.UUID `gorm:"not null;index" json:"customer_id"`
	Label        string    `json:"label"` // Home, Office, Other
	AddressLine  string    `gorm:"not null" json:"address_line"`
	City         string    `json:"city"`
	Pincode      string    `json:"pincode"`
	Latitude     float64   `json:"latitude"`
	Longitude    float64   `json:"longitude"`
	IsDefault    bool      `gorm:"default:false" json:"is_default"`
	CreatedAt    time.Time `json:"created_at"`
}

// ─── Hub (Serviceability Zone) ───────────────────────────
type Hub struct {
	ID        uuid.UUID `gorm:"primaryKey" json:"id"`
	Name      string    `gorm:"not null" json:"name"`
	City      string    `gorm:"not null;index" json:"city"`
	Latitude  float64   `gorm:"not null" json:"latitude"`
	Longitude float64   `gorm:"not null" json:"longitude"`
	RadiusKm  float64   `gorm:"not null;default:10" json:"radius_km"` // Service radius in km
	IsActive  bool      `gorm:"default:true" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ─── Partner ─────────────────────────────────────────────
type Partner struct {
	ID             uuid.UUID  `gorm:"primaryKey" json:"id"`
	UserID         uuid.UUID  `gorm:"type:uuid;not null" json:"user_id"`
	HubID          *uuid.UUID `json:"hub_id"`
	Name           string     `json:"name"`
	Email          string     `json:"email"`
	Location       string     `json:"location"`
	City           string     `json:"city"`
	Latitude       float64    `json:"latitude"`
	Longitude      float64    `json:"longitude"`
	Category       string     `json:"category"` // Service category specialization
	DocURL         string     `json:"doc_url"`
	AadhaarFront   string     `json:"aadhaar_front"`
	AadhaarBack    string     `json:"aadhaar_back"`
	PanURL         string     `json:"pan_url"`
	DrivingLicense string     `json:"driving_license"`
	HomePhotoURL   string     `json:"home_photo_url"`
	KYCStatus      string     `gorm:"default:'PENDING'" json:"kyc_status"` // PENDING, APPROVED, REJECTED
	IsOnline       bool       `gorm:"default:false" json:"is_online"`
	WalletBalance  float64    `gorm:"default:0" json:"wallet_balance"`
	Rating         float64    `gorm:"default:5.0" json:"rating"`
	AcceptanceRate float64    `gorm:"default:100" json:"acceptance_rate"`
	BankVerified   bool       `gorm:"default:false" json:"bank_verified"`
	User           User       `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Hub            *Hub       `gorm:"foreignKey:HubID" json:"hub,omitempty"`
}

// ─── Service ─────────────────────────────────────────────
type Service struct {
	ID                   uuid.UUID `gorm:"primaryKey" json:"id"`
	Name                 string    `gorm:"not null" json:"name"`
	Description          string    `json:"description"`
	Category             string    `gorm:"not null;index" json:"category"` // VEHICLE_WASH, MONTHLY_PACKAGE, PUC_CERTIFICATE, HOME_CLEANING, ACCESSORIES
	SubCategory          string    `json:"sub_category"`                   // e.g. FULL_HOME, TANK_SUMP, SOFA, BATHROOM, CARPET
	ImageURL             string    `json:"image_url"`
	VideoURL             string    `json:"video_url"`
	SOPSteps             JSONField `gorm:"type:text" json:"sop_steps"`
	CustomerRequirements JSONField `gorm:"type:text" json:"customer_requirements"`
	Inclusions           JSONField `gorm:"type:text" json:"inclusions"`
	Exclusions           JSONField `gorm:"type:text" json:"exclusions"`
	BestUseCases         JSONField `gorm:"type:text" json:"best_use_cases"`
	IsActive             bool      `gorm:"default:true" json:"is_active"`
	SortOrder            int       `gorm:"default:0" json:"sort_order"`
	SKUs                 []SKU     `gorm:"foreignKey:ServiceID" json:"skus,omitempty"`
}

// ─── SKU (Service Variant) ───────────────────────────────
type SKU struct {
	ID           uuid.UUID `gorm:"primaryKey" json:"id"`
	ServiceID    uuid.UUID `gorm:"not null" json:"service_id"`
	Title        string    `gorm:"not null" json:"title"`
	Price        float64   `gorm:"not null" json:"price"`
	DurationMins int       `gorm:"not null" json:"duration_mins"`
	VehicleType  string    `json:"vehicle_type"` // 2W, 4W, or empty (for non-vehicle services)
	SizeType     string    `json:"size_type"`    // For home cleaning: 1BHK, 2BHK, etc.
	IsPopular    bool      `gorm:"default:false" json:"is_popular"`
}

// ─── Booking ─────────────────────────────────────────────
type Booking struct {
	ID          uuid.UUID  `gorm:"primaryKey" json:"id"`
	CustomerID  uuid.UUID  `gorm:"not null" json:"customer_id"`
	PartnerID   *uuid.UUID `json:"partner_id"`
	SKUID       uuid.UUID  `gorm:"not null" json:"sku_id"`
	VehicleID   *uuid.UUID `json:"vehicle_id"`
	AddressID   *uuid.UUID `json:"address_id"`
	Status      string     `gorm:"default:'SCHEDULED'" json:"status"`
	SlotStart   time.Time  `gorm:"not null" json:"slot_start"`
	SlotEnd     time.Time  `gorm:"not null" json:"slot_end"`
	OTP         string     `json:"otp,omitempty"`
	TotalAmount float64    `gorm:"not null" json:"total_amount"`
	PaidAmount  float64    `gorm:"default:0" json:"paid_amount"`
	CancelNote  string     `json:"cancel_note,omitempty"`
	RefundPct   float64    `gorm:"default:0" json:"refund_pct"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`

	Customer Customer  `gorm:"foreignKey:CustomerID" json:"customer,omitempty"`
	Partner  *Partner  `gorm:"foreignKey:PartnerID" json:"partner,omitempty"`
	SKU      SKU       `gorm:"foreignKey:SKUID" json:"sku,omitempty"`
	Vehicle  *Vehicle  `gorm:"foreignKey:VehicleID" json:"vehicle,omitempty"`
	Address  *Address  `gorm:"foreignKey:AddressID" json:"address,omitempty"`
}

// ─── Payment ─────────────────────────────────────────────
type Payment struct {
	ID           uuid.UUID `gorm:"primaryKey" json:"id"`
	BookingID    uuid.UUID `gorm:"not null" json:"booking_id"`
	Amount       float64   `gorm:"not null" json:"amount"`
	RPOrderID    string    `json:"rp_order_id"`
	RPPaymentID  string    `json:"rp_payment_id"`
	Status       string    `gorm:"default:'PENDING'" json:"status"` // PENDING, SUCCESS, FAILED
	Method       string    `json:"method"`                          // RAZORPAY, WALLET, COD, QR
	CreatedAt    time.Time `json:"created_at"`
}

// ─── Rating ──────────────────────────────────────────────
type Rating struct {
	ID        uuid.UUID `gorm:"primaryKey" json:"id"`
	BookingID uuid.UUID `gorm:"uniqueIndex;not null" json:"booking_id"`
	CustomerID uuid.UUID `gorm:"not null" json:"customer_id"`
	PartnerID uuid.UUID `gorm:"not null" json:"partner_id"`
	Stars     int       `gorm:"not null;check:stars >= 1 AND stars <= 5" json:"stars"`
	Review    string    `json:"review"`
	CreatedAt time.Time `json:"created_at"`

	Booking  Booking  `gorm:"foreignKey:BookingID" json:"booking,omitempty"`
	Customer Customer `gorm:"foreignKey:CustomerID" json:"customer,omitempty"`
	Partner  Partner  `gorm:"foreignKey:PartnerID" json:"partner,omitempty"`
}

// ─── WalletTransaction ──────────────────────────────────
type WalletTransaction struct {
	ID         uuid.UUID  `gorm:"primaryKey" json:"id"`
	CustomerID *uuid.UUID `json:"customer_id"`
	PartnerID  *uuid.UUID `json:"partner_id"`
	Amount     float64    `gorm:"not null" json:"amount"` // positive = credit, negative = debit
	Type       string    `gorm:"not null" json:"type"`   // REFERRAL_BONUS, BOOKING_DEBIT, CASHBACK
	Reference  string    `json:"reference"`              // e.g., booking ID or referral code
	CreatedAt  time.Time `json:"created_at"`
}

// ─── Notification ────────────────────────────────────────
type Notification struct {
	ID        uuid.UUID `gorm:"primaryKey" json:"id"`
	UserID    uuid.UUID `gorm:"not null;index" json:"user_id"`
	Title     string    `gorm:"not null" json:"title"`
	Body      string    `gorm:"not null" json:"body"`
	IsRead    bool      `gorm:"default:false" json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

// ─── Partner Slot (16 slots/day, 6AM-9PM) ────────────────
type PartnerSlot struct {
	ID          uuid.UUID `gorm:"primaryKey" json:"id"`
	PartnerID   uuid.UUID `gorm:"not null;index" json:"partner_id"`
	Date        string    `gorm:"not null;index" json:"date"` // YYYY-MM-DD
	Hour        int       `gorm:"not null" json:"hour"`       // 6-21
	IsAvailable bool      `gorm:"default:true" json:"is_available"`
	BookingID   *uuid.UUID `json:"booking_id,omitempty"` // Set when a booking occupies this slot
	CreatedAt   time.Time `json:"created_at"`
}

// ─── Partner Leave ───────────────────────────────────────
type PartnerLeave struct {
	ID        uuid.UUID `gorm:"primaryKey" json:"id"`
	PartnerID uuid.UUID `gorm:"not null;index" json:"partner_id"`
	Date      string    `gorm:"not null" json:"date"`   // YYYY-MM-DD
	Reason    string    `json:"reason"`
	Status    string    `gorm:"default:'PENDING'" json:"status"` // PENDING, APPROVED, REJECTED
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	Partner Partner `gorm:"foreignKey:PartnerID" json:"partner,omitempty"`
}

// ─── Service Photo (Before/After/Selfie) ─────────────────
type ServicePhoto struct {
	ID        uuid.UUID `gorm:"primaryKey" json:"id"`
	BookingID uuid.UUID `gorm:"not null;index" json:"booking_id"`
	PartnerID uuid.UUID `gorm:"not null" json:"partner_id"`
	PhotoType string    `gorm:"not null" json:"photo_type"` // SELFIE, BEFORE, AFTER
	PhotoURL  string    `gorm:"not null" json:"photo_url"`
	CreatedAt time.Time `json:"created_at"`
}

// ─── Partner Bank Account ────────────────────────────────
type PartnerBankAccount struct {
	ID            uuid.UUID `gorm:"primaryKey" json:"id"`
	PartnerID     uuid.UUID `gorm:"uniqueIndex;not null" json:"partner_id"`
	AccountHolder string    `gorm:"not null" json:"account_holder"`
	AccountNumber string    `gorm:"not null" json:"account_number"`
	IFSCCode      string    `gorm:"not null" json:"ifsc_code"`
	BankName      string    `gorm:"not null" json:"bank_name"`
	IsVerified    bool      `gorm:"default:false" json:"is_verified"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`

	Partner Partner `gorm:"foreignKey:PartnerID" json:"partner,omitempty"`
}

// ─── Chat Message ────────────────────────────────────────
type ChatMessage struct {
	ID        uuid.UUID `gorm:"primaryKey" json:"id"`
	BookingID uuid.UUID `gorm:"not null;index" json:"booking_id"`
	SenderID  uuid.UUID `gorm:"not null" json:"sender_id"`
	SenderRole string   `gorm:"not null" json:"sender_role"` // CUSTOMER or PARTNER
	Message   string    `gorm:"not null" json:"message"`
	IsRead    bool      `gorm:"default:false" json:"is_read"`
	CreatedAt time.Time `json:"created_at"`

	Booking Booking `gorm:"foreignKey:BookingID" json:"booking,omitempty"`
}

// ─── Withdrawal Request ──────────────────────────────────
type WithdrawalRequest struct {
	ID            uuid.UUID `gorm:"primaryKey" json:"id"`
	PartnerID     uuid.UUID `gorm:"not null;index" json:"partner_id"`
	Amount        float64   `gorm:"not null" json:"amount"`
	Status        string    `gorm:"default:'PENDING'" json:"status"` // PENDING, APPROVED, REJECTED
	BankReference string    `json:"bank_reference"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`

	Partner Partner `gorm:"foreignKey:PartnerID" json:"partner,omitempty"`
}

// ─── WebSocket Message Types ─────────────────────────────
const (
	WSTypeBookingUpdate   = "BOOKING_UPDATE"
	WSTypeNewNotification = "NEW_NOTIFICATION"
	WSTypeChatMessage     = "CHAT_MESSAGE"
	WSTypeNewJob          = "NEW_JOB"
	WSTypeLiveFeed        = "LIVE_FEED"
)

// ─── GORM Hooks ──────────────────────────────────────────
func (u *User) BeforeCreate(tx *gorm.DB) (err error)              { u.ID = uuid.New(); return }
func (c *Customer) BeforeCreate(tx *gorm.DB) (err error)           { c.ID = uuid.New(); return }
func (p *Partner) BeforeCreate(tx *gorm.DB) (err error)            { p.ID = uuid.New(); return }
func (s *Service) BeforeCreate(tx *gorm.DB) (err error)            { s.ID = uuid.New(); return }
func (s *SKU) BeforeCreate(tx *gorm.DB) (err error)                { s.ID = uuid.New(); return }
func (b *Booking) BeforeCreate(tx *gorm.DB) (err error)            { b.ID = uuid.New(); return }
func (p *Payment) BeforeCreate(tx *gorm.DB) (err error)            { p.ID = uuid.New(); return }
func (r *Rating) BeforeCreate(tx *gorm.DB) (err error)             { r.ID = uuid.New(); return }
func (w *WalletTransaction) BeforeCreate(tx *gorm.DB) (err error)  { w.ID = uuid.New(); return }
func (n *Notification) BeforeCreate(tx *gorm.DB) (err error)       { n.ID = uuid.New(); return }
func (v *Vehicle) BeforeCreate(tx *gorm.DB) (err error)            { v.ID = uuid.New(); return }
func (a *Address) BeforeCreate(tx *gorm.DB) (err error)            { a.ID = uuid.New(); return }
func (h *Hub) BeforeCreate(tx *gorm.DB) (err error)                { h.ID = uuid.New(); return }
func (ps *PartnerSlot) BeforeCreate(tx *gorm.DB) (err error)       { ps.ID = uuid.New(); return }
func (pl *PartnerLeave) BeforeCreate(tx *gorm.DB) (err error)      { pl.ID = uuid.New(); return }
func (sp *ServicePhoto) BeforeCreate(tx *gorm.DB) (err error)      { sp.ID = uuid.New(); return }
func (pb *PartnerBankAccount) BeforeCreate(tx *gorm.DB) (err error) { pb.ID = uuid.New(); return }
func (cm *ChatMessage) BeforeCreate(tx *gorm.DB) (err error)        { cm.ID = uuid.New(); return }
func (wr *WithdrawalRequest) BeforeCreate(tx *gorm.DB) (err error)  { wr.ID = uuid.New(); return }
