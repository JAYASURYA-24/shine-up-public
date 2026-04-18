.PHONY: infra stop seed api admin all help

help:
	@echo "Shine-Up Local Development Commands:"
	@echo "  make infra    - Start PostgreSQL & Redis services"
	@echo "  make seed     - Populate initial services & mock data"
	@echo "  make api       - Start the Go Backend (API)"
	@echo "  make admin     - Start the React Admin Panel"
	@echo "  make stop      - Stop the infrastructure services"
	@echo "  make all       - Start infra, seed, and api (ready for mobile)"

infra:
	@echo "🚀 Starting infrastructure (Postgres & Redis)..."
	docker compose up -d

stop:
	@echo "🛑 Stopping infrastructure..."
	docker compose down

seed:
	@echo "🌱 Seeding database..."
	cd backend && go run scripts/seed/main.go

api:
	@echo "📡 Starting Go Backend API..."
	cd backend && go run cmd/api/main.go

admin:
	@echo "💻 Starting React Admin Panel..."
	cd admin-panel && npm install && npm run dev

all:
	@echo "🌟 Setting up entire backend environment..."
	docker compose up -d
	@sleep 3
	cd backend && go run scripts/seed.go
	cd backend && go run cmd/api/main.go
