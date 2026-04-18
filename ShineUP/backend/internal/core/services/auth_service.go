package services

import (
	"context"
	"errors"
	"log"
	"strings"

	"firebase.google.com/go/v4/auth"
	"github.com/Shine-Up/backend/internal/models"
	pkigAuth "github.com/Shine-Up/backend/pkg/auth"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AuthService struct {
	db           *gorm.DB
	firebaseAuth *auth.Client
	jwtSecret    string
}

func NewAuthService(db *gorm.DB, firebaseAuth *auth.Client, jwtSecret string) *AuthService {
	return &AuthService{
		db:           db,
		firebaseAuth: firebaseAuth,
		jwtSecret:    jwtSecret,
	}
}

// LoginWithFirebaseToken takes the ID Token from Flutter Firebase Auth, verifies it,
// upserts the user into our Database, and issues our own system JWT.
func (s *AuthService) LoginWithFirebaseToken(ctx context.Context, idToken string, appRole models.Role) (string, error) {
	var phoneNumber string

	if s.firebaseAuth != nil {
		token, err := s.firebaseAuth.VerifyIDToken(ctx, idToken)
		if err != nil {
			log.Printf("Firebase token verification failed: %v", err)
			return "", errors.New("invalid firebase token")
		}

		// Get phone number from token claims
		if phone, ok := token.Claims["phone_number"].(string); ok {
			phoneNumber = phone
		} else {
			return "", errors.New("phone number missing from firebase token")
		}
	} else {
		// Mock logic for local testing without firebase credentials configured
		log.Println("WARNING: Firebase not initialized. Using mocked token logic.")
		if idToken == "" || len(idToken) < 10 {
			return "", errors.New("invalid mocked token (send phone number)")
		}
		phoneNumber = idToken
	}

	// Find or Create User
	var user models.User
	result := s.db.Where("phone = ?", phoneNumber).First(&user)

	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			// First time login - register
			user = models.User{
				Phone: phoneNumber,
				Role:  appRole,
			}
			if err := s.db.Create(&user).Error; err != nil {
				return "", err
			}

			// Create associated specific role record
			if appRole == models.RoleCustomer {
				if err := s.db.Create(&models.Customer{
					UserID:       user.ID,
					ReferralCode: s.generateReferralCode(),
				}).Error; err != nil {
					return "", err
				}
			} else if appRole == models.RolePartner {
				if err := s.db.Create(&models.Partner{UserID: user.ID}).Error; err != nil {
					return "", err
				}
			}
		} else {
			return "", result.Error
		}
	} else if user.Role != appRole {
		// Basic security check: Customer trying to login to Partner app
		return "", errors.New("user role mismatch with application")
	}

	// Generate System JWT
	jwtToken, err := pkigAuth.GenerateJWT(user.ID, string(user.Role), s.jwtSecret)
	if err != nil {
		return "", err
	}

	return jwtToken, nil
}

// DevLogin directly issues a JWT for a phone number (For local development only)
func (s *AuthService) DevLogin(ctx context.Context, phoneNumber string, appRole models.Role) (string, error) {
	log.Printf("DevLogin Request - Phone: %s, Role: %s", phoneNumber, appRole)
	var user models.User
	result := s.db.Where("phone = ?", phoneNumber).First(&user)

	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			// Register as a new user if they don't exist
			user = models.User{
				Phone: phoneNumber,
				Role:  appRole,
			}
			if err := s.db.Create(&user).Error; err != nil {
				return "", err
			}
			// Create specific role record
			if appRole == models.RoleCustomer {
				s.db.Create(&models.Customer{
					UserID:       user.ID,
					ReferralCode: s.generateReferralCode(),
				})
			} else {
				s.db.Create(&models.Partner{UserID: user.ID})
			}
		} else {
			return "", result.Error
		}
	}

	return pkigAuth.GenerateJWT(user.ID, string(user.Role), s.jwtSecret)
}

// LoginWithOTP handles mock OTP login and registration with additional fields
func (s *AuthService) LoginWithOTP(ctx context.Context, phone, name, email, location string, lat, lng float64, appRole models.Role) (string, error) {
	log.Printf("LoginWithOTP Request - Phone: %s, Name: %s, Lat: %f, Lng: %f", phone, name, lat, lng)

	var user models.User
	result := s.db.Where("phone = ?", phone).First(&user)

	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			// Register new user
			user = models.User{
				Phone: phone,
				Role:  appRole,
			}
			if err := s.db.Create(&user).Error; err != nil {
				return "", err
			}

			// ─── Create Profile & Default Address ──────────
			if appRole == models.RoleCustomer {
				customer := models.Customer{
					UserID:       user.ID,
					Name:         name,
					Email:        email,
					Location:     location,
					ReferralCode: s.generateReferralCode(),
				}
				s.db.Create(&customer)

				// Automatically add the first address
				if location != "" {
					addr := models.Address{
						CustomerID:  customer.ID,
						Label:       "Home",
						AddressLine: location,
						Latitude:    lat,
						Longitude:   lng,
						IsDefault:   true,
					}
					s.db.Create(&addr)
					log.Printf("✅ Created default address for customer %s", customer.ID)
				}
			} else if appRole == models.RolePartner {
				partner := models.Partner{
					UserID:   user.ID,
					Name:     name,
					Email:    email,
					Location: location,
				}
				s.db.Create(&partner)
			}
		} else {
			return "", result.Error
		}
	} else {
		// Update existing user/profile if needed
		if appRole == models.RoleCustomer {
			s.db.Model(&models.Customer{}).Where("user_id = ?", user.ID).Updates(map[string]interface{}{
				"name":     name,
				"email":    email,
				"location": location,
			})
			
			// Ensure address exists for existing customer
			var customer models.Customer
			if err := s.db.Where("user_id = ?", user.ID).First(&customer).Error; err == nil {
				var addrCount int64
				s.db.Model(&models.Address{}).Where("customer_id = ?", customer.ID).Count(&addrCount)
				if addrCount == 0 && (lat != 0 || lng != 0 || location != "") {
					addr := models.Address{
						CustomerID:  customer.ID,
						Label:       "Home",
						AddressLine: location,
						Latitude:    lat,
						Longitude:   lng,
						IsDefault:   true,
					}
					s.db.Create(&addr)
				}
			}
		} else if appRole == models.RolePartner {
			s.db.Model(&models.Partner{}).Where("user_id = ?", user.ID).Updates(map[string]interface{}{
				"name":     name,
				"email":    email,
				"location": location,
			})
		}
	}

	return pkigAuth.GenerateJWT(user.ID, string(user.Role), s.jwtSecret)
}

func (s *AuthService) generateReferralCode() string {
	return "SHINE" + strings.ToUpper(uuid.New().String()[:5])
}
