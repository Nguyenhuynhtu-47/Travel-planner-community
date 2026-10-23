# Local Development Test Accounts

> **Development-Only Document**  
> Credentials in this document are strictly for local development and testing environments. They are NOT used in production configurations.

All seeded test accounts share the default local password:
```text
Password123!
```

---

## 1. Test User Accounts & Personas

| Username | Email | Role | Status | Full Name | Persona / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`admin_master`** | `admin@travelplanner.local` | `ADMIN` | `ACTIVE` | Nguyễn Hoàng Nam (Admin) | System admin account for moderation, dashboard, and management testing. |
| **`traveler_viet`** | `viet.nguyen@travelplanner.local` | `USER` | `ACTIVE` | Nguyễn Quốc Việt | Travel blogger & trekker. Author of Hà Nội & Cần Thơ itineraries. |
| **`wanderer_linh`** | `linh.dan@travelplanner.local` | `USER` | `ACTIVE` | Đặng Thùy Linh | Landscape & cultural photographer. Author of Đà Nẵng - Hội An & Huế itineraries. |
| **`foodie_khoa`** | `khoa.tran@travelplanner.local` | `USER` | `ACTIVE` | Trần Đăng Khoa | Saigon food reviewer. Author of Saigon 1-Day & derived Fansipan itineraries. |
| **`nature_an`** | `an.le@travelplanner.local` | `USER` | `ACTIVE` | Lê Hoài An | Nature & camping enthusiast. Author of Đà Lạt clouds & Hạ Long cruise itineraries. Also owns a private honeymoon itinerary. |
| **`hiker_duy`** | `duy.pham@travelplanner.local` | `USER` | `ACTIVE` | Phạm Đức Duy | Mountaineer. Author of Fansipan 3N2Đ base itinerary & Đà Lạt camping itinerary. |
| **`island_mai`** | `mai.huynh@travelplanner.local` | `USER` | `ACTIVE` | Huỳnh Ngọc Mai | PADI diver. Author of Phú Quốc resort & coral diving itineraries. |
| **`backpacker_tuan`** | `tuan.vu@travelplanner.local` | `USER` | `ACTIVE` | Vũ Minh Tuấn | Motorbike backpacker. Author of Ninh Bình Tràng An itinerary & private Northwest draft. |
| **`inactive_user`** | `inactive@travelplanner.local` | `USER` | `INACTIVE` | Trần Thị Thanh (Chưa kích hoạt) | Inactive account for testing login rejection (403 Forbidden). |
| **`banned_spammer`** | `spammer@travelplanner.local` | `USER` | `BANNED` | Nguyễn Vi Phạm (Bị khóa) | Banned account for testing login blocking and content exclusion from public Explore feed. |

---

## 2. Seed Data Characteristics

- **Total Users:** 10 seeded users (+ preserves pre-existing developer accounts such as `minhdanh`).
- **Total Destinations:** 20 verified destinations across Northern, Central, and Southern Vietnam (19 `ACTIVE`, 1 `HIDDEN`).
- **Total Itineraries:** 18 itineraries covering single-day to 5-day trips (13 `PUBLIC` & `ACTIVE`, 2 `PRIVATE`, 1 `HIDDEN`, 1 `DELETED`, 1 created by `BANNED` user).
- **Derived Itinerary:** Itinerary #260 (`sa_pa_derived`) is derived from Itinerary #259 (`sa_pa_trekking`) using `original_itinerary_id` to test reuse and personalization.
- **Itinerary Days:** 47 itinerary days with ordered sequential numbering.
- **Activities:** 111 detailed activities with valid start/end times, realistic costs (VND), display orders, and mandatory foreign-key links to destinations.
- **Social Interactions:**
  - 14 comments (active, hidden, deleted for moderation tests).
  - 24 ratings (1–5 stars; top itineraries have average >= 4.5 and ratingCount >= 2 to trigger the mobile "Yêu thích" badge).
  - 14 favorites.
  - 9 saved itineraries (bookmarks).
  - 11 follows (realistic social graph, strictly no self-following).
  - 5 itinerary shares (including 4 active tokens and 1 expired token).
  - 7 offline downloads.

---

## 3. Seed Execution & Configuration

### Automatic Execution
When running the backend in development:
```powershell
.\mvnw.cmd spring-boot:run
```
The `DataSeeder` automatically runs during startup (`app.seed.enabled=true` by default in `application.properties`).

### Idempotency Guarantee
The seed mechanism is strictly idempotent:
- Checking existing records by username, email, destination name, itinerary title + user, and composite unique keys.
- Running the seeder multiple times does NOT duplicate records or alter primary keys.
- Pre-existing data is preserved.

### Disabling Seed Execution
To start the application without seeding:
```powershell
.\mvnw.cmd spring-boot:run -Dspring-boot.run.arguments="--app.seed.enabled=false"
```
Or via environment variable:
```powershell
$env:APP_SEED_ENABLED="false"
.\mvnw.cmd spring-boot:run
```
