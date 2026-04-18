package main

import (
	"log"

	"github.com/Shine-Up/backend/internal/config"
	"github.com/Shine-Up/backend/internal/models"
	"github.com/Shine-Up/backend/pkg/database"
	"github.com/google/uuid"
)

func main() {
	cfg := config.LoadConfig()
	db, err := database.NewDatabaseConnection(cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}

	log.Println("🌱 Seeding database...")

	// 0. Auto-Migrate schema
	db.AutoMigrate(
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
	)

	// ═══════════════════════════════════════════════════════
	// 1. HUBS (Serviceability Zones)
	// ═══════════════════════════════════════════════════════
	hubs := []models.Hub{
		{Name: "Chennai Central", City: "Chennai", Latitude: 13.0827, Longitude: 80.2707, RadiusKm: 15, IsActive: true},
		{Name: "Bangalore Central", City: "Bangalore", Latitude: 12.9716, Longitude: 77.5946, RadiusKm: 15, IsActive: true},
		{Name: "Trichy Central", City: "Trichy", Latitude: 10.7905, Longitude: 78.7047, RadiusKm: 12, IsActive: true},
	}
	for i := range hubs {
		db.FirstOrCreate(&hubs[i], "name = ?", hubs[i].Name)
	}
	log.Println("✅ Hubs seeded (3 cities)")

	// ═══════════════════════════════════════════════════════
	// 2. SERVICES & SKUs
	// ═══════════════════════════════════════════════════════

	// ─── Category 1: Vehicle Wash (One-Time) ─────────────
	svcCarWash := models.Service{
		ID:          uuid.New(),
		Name:        "Vehicle Wash (One-Time)",
		Description: "Professional doorstep vehicle cleaning service",
		Category:    models.CategoryVehicleWash,
		VideoURL:    "https://example.com/videos/car-wash.mp4",
		SOPSteps: models.JSONField{
			"Pre-rinse to remove loose dirt",
			"Apply pH-neutral shampoo with microfiber mitt",
			"Scrub wheels and tires with dedicated brush",
			"Rinse thoroughly with clean water",
			"Dry with premium microfiber towels",
			"Apply tire shine and dashboard polish",
			"Final inspection and quality check",
		},
		CustomerRequirements: models.JSONField{
			"Vehicle should be accessible (not in tight parking)",
			"Water supply within 20 meters",
			"Electricity for pressure washer (Premium/Elite only)",
		},
		Inclusions: models.JSONField{
			"Exterior body wash",
			"Wheel and tire cleaning",
			"Dashboard wipe",
			"Door jamb cleaning",
		},
		Exclusions: models.JSONField{
			"Engine bay cleaning",
			"Paint correction / polishing",
			"Ceramic coating",
			"Dent or scratch removal",
		},
		BestUseCases: models.JSONField{
			"Weekly maintenance wash",
			"Post-rain cleaning",
			"Before a road trip",
			"Pre-sale vehicle prep",
		},
		IsActive:  true,
		SortOrder: 1,
	}
	db.FirstOrCreate(&svcCarWash, "name = ?", svcCarWash.Name)

	carWashSKUs := []models.SKU{
		{ServiceID: svcCarWash.ID, Title: "Basic Manual Wash - 2W", Price: 149, DurationMins: 20, VehicleType: "2W", IsPopular: false},
		{ServiceID: svcCarWash.ID, Title: "Basic Manual Wash - 4W", Price: 299, DurationMins: 30, VehicleType: "4W", IsPopular: false},
		{ServiceID: svcCarWash.ID, Title: "Premium Pressure Wash - 2W", Price: 249, DurationMins: 30, VehicleType: "2W", IsPopular: true},
		{ServiceID: svcCarWash.ID, Title: "Premium Pressure Wash - 4W", Price: 499, DurationMins: 45, VehicleType: "4W", IsPopular: true},
		{ServiceID: svcCarWash.ID, Title: "Elite Deep Cleaning - 2W", Price: 499, DurationMins: 45, VehicleType: "2W", IsPopular: false},
		{ServiceID: svcCarWash.ID, Title: "Elite Deep Cleaning - 4W", Price: 999, DurationMins: 90, VehicleType: "4W", IsPopular: false},
	}
	for i := range carWashSKUs {
		db.FirstOrCreate(&carWashSKUs[i], "title = ? AND service_id = ?", carWashSKUs[i].Title, carWashSKUs[i].ServiceID)
	}

	// ─── Category 2: Monthly Wash Packages ───────────────
	svcMonthly := models.Service{
		ID:          uuid.New(),
		Name:        "Monthly Wash Package",
		Description: "Regular doorstep wash subscription with flexible frequency",
		Category:    models.CategoryMonthlyPackage,
		VideoURL:    "https://example.com/videos/monthly-wash.mp4",
		SOPSteps: models.JSONField{
			"Daily scheduled wash at preferred time",
			"Mix of water wash + dry dusting as per plan",
			"Monthly deep cleaning included",
			"Quality check card maintained",
		},
		CustomerRequirements: models.JSONField{
			"Vehicle parked at accessible spot daily",
			"Water supply available",
			"Inform for schedule changes 12hrs in advance",
		},
		Inclusions: models.JSONField{
			"Exterior wash as per frequency",
			"Tire and wheel wipe",
			"Dashboard dusting",
			"Monthly interior vacuum (Premium plans)",
		},
		Exclusions: models.JSONField{
			"Engine cleaning",
			"Paint protection",
			"Interior deep shampooing",
		},
		BestUseCases: models.JSONField{
			"Daily commuters",
			"Apartment residents",
			"Fleet owners",
		},
		IsActive:  true,
		SortOrder: 2,
	}
	db.FirstOrCreate(&svcMonthly, "name = ?", svcMonthly.Name)

	monthlySKUs := []models.SKU{
		{ServiceID: svcMonthly.ID, Title: "2x/week - 2W", Price: 499, DurationMins: 20, VehicleType: "2W"},
		{ServiceID: svcMonthly.ID, Title: "2x/week - 4W", Price: 899, DurationMins: 30, VehicleType: "4W"},
		{ServiceID: svcMonthly.ID, Title: "3x/week - 2W", Price: 699, DurationMins: 20, VehicleType: "2W", IsPopular: true},
		{ServiceID: svcMonthly.ID, Title: "3x/week - 4W", Price: 1299, DurationMins: 30, VehicleType: "4W", IsPopular: true},
		{ServiceID: svcMonthly.ID, Title: "Daily (7x/week) - 2W", Price: 1499, DurationMins: 20, VehicleType: "2W"},
		{ServiceID: svcMonthly.ID, Title: "Daily (7x/week) - 4W", Price: 2499, DurationMins: 30, VehicleType: "4W"},
	}
	for i := range monthlySKUs {
		db.FirstOrCreate(&monthlySKUs[i], "title = ? AND service_id = ?", monthlySKUs[i].Title, monthlySKUs[i].ServiceID)
	}

	// ─── Category 3: Doorstep PUC Certificate ────────────
	svcPUC := models.Service{
		ID:          uuid.New(),
		Name:        "Doorstep PUC Certificate",
		Description: "Get your Pollution Under Control certificate at your doorstep",
		Category:    models.CategoryPUC,
		VideoURL:    "https://example.com/videos/puc-service.mp4",
		SOPSteps: models.JSONField{
			"Verify vehicle registration (RC) details",
			"Connect emission testing equipment",
			"Run engine at idle and record readings",
			"Generate PUC certificate with QR code",
			"Provide digital + physical copy",
			"OTP verification for authenticity",
		},
		CustomerRequirements: models.JSONField{
			"Valid Registration Certificate (RC)",
			"Vehicle in running condition with fuel",
			"Owner's Aadhaar/ID for verification",
		},
		Inclusions: models.JSONField{
			"Emission testing",
			"Digital PUC certificate",
			"Physical certificate copy",
			"SMS/email confirmation",
		},
		Exclusions: models.JSONField{
			"Vehicle repair if emission fails",
			"RC renewal or transfer",
			"Insurance documentation",
		},
		BestUseCases: models.JSONField{
			"PUC renewal (every 6 months)",
			"Before vehicle inspection",
			"Fleet compliance",
		},
		IsActive:  true,
		SortOrder: 3,
	}
	db.FirstOrCreate(&svcPUC, "name = ?", svcPUC.Name)

	pucSKUs := []models.SKU{
		{ServiceID: svcPUC.ID, Title: "PUC - Two Wheeler", Price: 99, DurationMins: 15, VehicleType: "2W"},
		{ServiceID: svcPUC.ID, Title: "PUC - Four Wheeler (Petrol)", Price: 149, DurationMins: 20, VehicleType: "4W"},
		{ServiceID: svcPUC.ID, Title: "PUC - Four Wheeler (Diesel)", Price: 199, DurationMins: 20, VehicleType: "4W"},
	}
	for i := range pucSKUs {
		db.FirstOrCreate(&pucSKUs[i], "title = ? AND service_id = ?", pucSKUs[i].Title, pucSKUs[i].ServiceID)
	}

	// ─── Category 4: Home Cleaning ───────────────────────

	// 4a. Full Home Cleaning
	svcFullHome := models.Service{
		ID:          uuid.New(),
		Name:        "Full Home Deep Cleaning",
		Description: "Complete home cleaning service with professional equipment",
		Category:    models.CategoryHomeCleaning,
		SubCategory: "FULL_HOME",
		VideoURL:    "https://example.com/videos/home-cleaning.mp4",
		SOPSteps: models.JSONField{
			"Initial walkthrough and assessment",
			"Dust all surfaces, fans, and fixtures",
			"Mop all floors with disinfectant",
			"Clean kitchen counters, sink, and appliances",
			"Scrub bathrooms (toilet, tiles, fixtures)",
			"Clean windows and glass surfaces",
			"Vacuum upholstery and carpets",
			"Final walkthrough with customer",
		},
		CustomerRequirements: models.JSONField{
			"Clear clutter from surfaces",
			"Provide access to all rooms",
			"Ensure water and electricity available",
		},
		Inclusions: models.JSONField{
			"All rooms dusting and mopping",
			"Kitchen deep clean",
			"Bathroom scrubbing",
			"Window cleaning",
			"Balcony sweeping",
		},
		Exclusions: models.JSONField{
			"Ceiling painting",
			"Pest control",
			"Plumbing repairs",
			"Electrical work",
			"Heavy furniture moving",
		},
		BestUseCases: models.JSONField{
			"Moving in/out",
			"Post-renovation",
			"Festival preparation",
			"Quarterly deep clean",
		},
		IsActive:  true,
		SortOrder: 4,
	}
	db.FirstOrCreate(&svcFullHome, "name = ?", svcFullHome.Name)

	fullHomeSKUs := []models.SKU{
		{ServiceID: svcFullHome.ID, Title: "1 BHK - Unfurnished", Price: 1999, DurationMins: 180, SizeType: "1BHK"},
		{ServiceID: svcFullHome.ID, Title: "1 BHK - Furnished", Price: 2499, DurationMins: 240, SizeType: "1BHK", IsPopular: true},
		{ServiceID: svcFullHome.ID, Title: "2 BHK - Unfurnished", Price: 2999, DurationMins: 240, SizeType: "2BHK"},
		{ServiceID: svcFullHome.ID, Title: "2 BHK - Furnished", Price: 3499, DurationMins: 300, SizeType: "2BHK", IsPopular: true},
		{ServiceID: svcFullHome.ID, Title: "3 BHK - Unfurnished", Price: 3999, DurationMins: 300, SizeType: "3BHK"},
		{ServiceID: svcFullHome.ID, Title: "3 BHK - Furnished", Price: 4999, DurationMins: 360, SizeType: "3BHK"},
		{ServiceID: svcFullHome.ID, Title: "Villa / Independent House", Price: 6999, DurationMins: 480, SizeType: "VILLA"},
	}
	for i := range fullHomeSKUs {
		db.FirstOrCreate(&fullHomeSKUs[i], "title = ? AND service_id = ?", fullHomeSKUs[i].Title, fullHomeSKUs[i].ServiceID)
	}

	// 4b. Sofa Cleaning
	svcSofa := models.Service{
		ID:          uuid.New(),
		Name:        "Sofa Cleaning",
		Description: "Professional sofa shampooing and steam cleaning",
		Category:    models.CategoryHomeCleaning,
		SubCategory: "SOFA",
		SOPSteps: models.JSONField{
			"Vacuum loose dust and debris",
			"Pre-treat stains with enzyme cleaner",
			"Apply foam shampoo to all surfaces",
			"Scrub with soft brush",
			"Steam extraction cleaning",
			"Deodorize and sanitize",
			"Air dry (2-3 hours)",
		},
		Inclusions: models.JSONField{
			"Deep vacuuming",
			"Stain treatment",
			"Shampooing",
			"Deodorizing",
		},
		Exclusions: models.JSONField{
			"Leather conditioning (separate service)",
			"Structural repair",
			"Color restoration",
		},
		IsActive:  true,
		SortOrder: 5,
	}
	db.FirstOrCreate(&svcSofa, "name = ?", svcSofa.Name)

	sofaSKUs := []models.SKU{
		{ServiceID: svcSofa.ID, Title: "3-Seater Fabric Sofa", Price: 799, DurationMins: 60, SizeType: "3-SEAT"},
		{ServiceID: svcSofa.ID, Title: "5-Seater Fabric Sofa", Price: 1199, DurationMins: 90, SizeType: "5-SEAT", IsPopular: true},
		{ServiceID: svcSofa.ID, Title: "7-Seater Fabric Sofa", Price: 1599, DurationMins: 120, SizeType: "7-SEAT"},
		{ServiceID: svcSofa.ID, Title: "3-Seater Leather Sofa", Price: 999, DurationMins: 60, SizeType: "3-SEAT"},
		{ServiceID: svcSofa.ID, Title: "5-Seater Leather Sofa", Price: 1499, DurationMins: 90, SizeType: "5-SEAT"},
	}
	for i := range sofaSKUs {
		db.FirstOrCreate(&sofaSKUs[i], "title = ? AND service_id = ?", sofaSKUs[i].Title, sofaSKUs[i].ServiceID)
	}

	// 4c. Bathroom Deep Cleaning
	svcBathroom := models.Service{
		ID:          uuid.New(),
		Name:        "Bathroom Deep Cleaning",
		Description: "Thorough bathroom scrubbing and sanitization",
		Category:    models.CategoryHomeCleaning,
		SubCategory: "BATHROOM",
		SOPSteps: models.JSONField{
			"Apply descaling agent to tiles and fixtures",
			"Scrub toilet bowl inside/outside",
			"Clean shower area and glass",
			"Scrub floor tiles and grout",
			"Clean mirror and cabinets",
			"Sanitize all surfaces",
		},
		Inclusions: models.JSONField{
			"Tile scrubbing",
			"Toilet deep clean",
			"Mirror cleaning",
			"Fixture polishing",
		},
		Exclusions: models.JSONField{
			"Plumbing repair",
			"Tile replacement",
			"Painting",
		},
		IsActive:  true,
		SortOrder: 6,
	}
	db.FirstOrCreate(&svcBathroom, "name = ?", svcBathroom.Name)

	bathroomSKUs := []models.SKU{
		{ServiceID: svcBathroom.ID, Title: "1 Bathroom", Price: 499, DurationMins: 45},
		{ServiceID: svcBathroom.ID, Title: "2 Bathrooms", Price: 899, DurationMins: 90, IsPopular: true},
		{ServiceID: svcBathroom.ID, Title: "3 Bathrooms", Price: 1299, DurationMins: 120},
	}
	for i := range bathroomSKUs {
		db.FirstOrCreate(&bathroomSKUs[i], "title = ? AND service_id = ?", bathroomSKUs[i].Title, bathroomSKUs[i].ServiceID)
	}

	// 4d. Tank/Sump Cleaning
	svcTank := models.Service{
		ID:          uuid.New(),
		Name:        "Water Tank / Sump Cleaning",
		Description: "Professional water storage cleaning and sanitization",
		Category:    models.CategoryHomeCleaning,
		SubCategory: "TANK_SUMP",
		SOPSteps: models.JSONField{
			"Drain existing water",
			"Remove sludge and sediment",
			"Scrub walls with cleaning solution",
			"High-pressure rinse",
			"Anti-bacterial treatment",
			"Refill and test water quality",
		},
		Inclusions: models.JSONField{
			"Complete draining",
			"Sludge removal",
			"Wall scrubbing",
			"Sanitization",
		},
		Exclusions: models.JSONField{
			"Tank repair or waterproofing",
			"Plumbing modifications",
			"Water purifier servicing",
		},
		IsActive:  true,
		SortOrder: 7,
	}
	db.FirstOrCreate(&svcTank, "name = ?", svcTank.Name)

	tankSKUs := []models.SKU{
		{ServiceID: svcTank.ID, Title: "Up to 500L Tank", Price: 699, DurationMins: 60},
		{ServiceID: svcTank.ID, Title: "500L - 1000L Tank", Price: 999, DurationMins: 90, IsPopular: true},
		{ServiceID: svcTank.ID, Title: "1000L - 2000L Sump", Price: 1499, DurationMins: 120},
		{ServiceID: svcTank.ID, Title: "Above 2000L Sump", Price: 1999, DurationMins: 180},
	}
	for i := range tankSKUs {
		db.FirstOrCreate(&tankSKUs[i], "title = ? AND service_id = ?", tankSKUs[i].Title, tankSKUs[i].ServiceID)
	}

	// ─── Category 5: Accessories Store ───────────────────
	svcAccessories := models.Service{
		ID:          uuid.New(),
		Name:        "Accessories Store",
		Description: "Coming soon — Premium car and bike accessories delivered to your doorstep",
		Category:    models.CategoryAccessories,
		SOPSteps:    models.JSONField{},
		Inclusions:  models.JSONField{},
		Exclusions:  models.JSONField{},
		IsActive:    false, // Not yet launched
		SortOrder:   10,
	}
	db.FirstOrCreate(&svcAccessories, "name = ?", svcAccessories.Name)

	log.Println("✅ Services seeded (5 categories, 8 services)")

	// ═══════════════════════════════════════════════════════
	// 3. Mock Admin User
	// ═══════════════════════════════════════════════════════
	adminUser := models.User{
		Phone: "+10000000000",
		Role:  models.RoleAdmin,
	}
	db.FirstOrCreate(&adminUser, "phone = ?", adminUser.Phone)

	log.Println("✅ Database seeded successfully!")
}
