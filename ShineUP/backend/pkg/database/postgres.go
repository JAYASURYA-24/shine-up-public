package database

import (
	"log"

	"gorm.io/driver/postgres"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// NewDatabaseConnection tries to connect to Postgres. If it fails, it falls back to
// an in-memory SQLite database for zero-setup local development.
func NewDatabaseConnection(dsn string) (*gorm.DB, error) {
	// 1. Try PostgreSQL
	if dsn != "" {
		db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Warn),
		})
		if err == nil {
			log.Println("✅ Connected to PostgreSQL successfully")
			setupPool(db)
			return db, nil
		}
		log.Printf("⚠️  PostgreSQL connection failed: %v. Falling back to SQLite...", err)
	}

	// 2. Fallback to SQLite (local file)
	db, err := gorm.Open(sqlite.Open("shineup.db"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return nil, err
	}

	log.Println("🚀 RUNNING IN ZERO-SETUP MODE (SQLite)")
	log.Println("💡 This is perfect for local testing! No Docker/Postgres required.")
	
	return db, nil
}

func setupPool(db *gorm.DB) {
	sqlDB, _ := db.DB()
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
}
