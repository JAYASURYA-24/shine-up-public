package main

import (
	"fmt"
	"log"

	"github.com/Shine-Up/backend/internal/config"
	"github.com/Shine-Up/backend/internal/models"
	"github.com/Shine-Up/backend/pkg/database"
)

func main() {
	cfg := config.LoadConfig()
	db, err := database.NewDatabaseConnection(cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}

	var bookings []models.Booking
	db.Preload("Partner").Preload("Partner.User").Find(&bookings)

	fmt.Println("\n--- ALL BOOKINGS ---")
	for _, b := range bookings {
		partnerPhone := "N/A"
		if b.Partner != nil {
			partnerPhone = b.Partner.User.Phone
		}
		fmt.Printf("ID: %s, Status: %s, Partner: %s\n", b.ID, b.Status, partnerPhone)
	}
	fmt.Println("--------------------")
}
