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

	var partners []models.Partner
	db.Preload("User").Find(&partners)

	fmt.Println("\n--- ALL REGISTERED PARTNERS ---")
	for _, p := range partners {
		fmt.Printf("Phone: %s, Name: %s, Status: %s, Online: %v\n", p.User.Phone, p.Name, p.KYCStatus, p.IsOnline)
	}
	fmt.Println("-------------------------------")
}
