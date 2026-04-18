#!/bin/bash

# Shine-Up Multi-Component Runner
# This script opens separate terminals for each component.

echo "🚀 Starting Shine-Up Development Environment..."

# Ask if user wants to seed
read -p "🌱 Do you want to seed the database first? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Seeding database..."
    cd backend && go run scripts/seed.go
    cd ..
fi

# 1. Backend (Go) - Start in a new terminal tab
echo "📡 Starting Backend API..."
gnome-terminal --tab --title="Backend API" -- bash -c "cd backend && go run cmd/api/main.go; exec bash"

# 2. Admin Panel (React) - Start in a new terminal tab
echo "💻 Starting Admin Panel..."
gnome-terminal --tab --title="Admin Panel" -- bash -c "cd admin-panel && npm run dev; exec bash"

echo "✅ Commands sent to separate tabs."
echo "Note: For Flutter apps, run 'flutter run' in app-customer and app-partner directories manually."
