# ✨ Shine-Up: Service-at-Home Platform

Shine-Up is a full-stack service booking ecosystem with dedicated applications for Customers, Partners, and Admin.

## 🚀 Quick-Start (Local Development)

Follow these 3 steps to get the entire backend and admin environment running.

### 1. Start Infrastructure
Ensure you have Docker installed, then run:
```bash
make infra
```
*This starts PostgreSQL and Redis.*

### 2. Seed & Start Backend
Once the database is ready, run:
```bash
make seed
make api
```
*The API will be live at `http://localhost:8080`.*

### 3. Start Admin Panel
In a new terminal:
```bash
make admin
```
*Access the dashboard at `http://localhost:5173`.*

---

## 📱 Mobile App Testing (Flutter)

1. Open the `app-customer` or `app-partner` directory.
2. Run `flutter pub get`.
3. Start your Android Emulator or iOS Simulator.
4. Run `flutter run`.

> [!TIP]
> **Android Emulator Connection**: The apps are already configured to connect to `10.0.2.2:8080` so they "just work" with the backend on your host machine.

---

## 🛠 Project Components
- **Backend**: Go (Gin, GORM, Redis)
- **Customer App**: Flutter (Riverpod v3)
- **Partner App**: Flutter (Riverpod v3)
- **Admin Panel**: React (Vite, Lucide)

## 🧪 Verified Flows
- **Auth**: Firebase OTP token exchange for JWT.
- **Booking**: Distributed locking via Redis for conflict-free slot management.
- **Lifecycle**: Create → Assign (Admin) → Start (OTP) → Success.
