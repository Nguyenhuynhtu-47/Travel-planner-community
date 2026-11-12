# PHASE 5 — CLONE BUSINESS LOGIC VERIFICATION

**Project:** Travel Planner  
**Phase:** 5 — Clone Itinerary  
**Target Snapshot Date:** 2026-09-20  
**Git Branch:** `develop`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  

---

## 1. IMPLEMENTATION DETAILS: `ItineraryServiceImpl.cloneItinerary`

The business logic is implemented inside `Travel_Planner.Travel_Planner.service.impl.ItineraryServiceImpl`:

```java
@Override
@Transactional
public ItineraryDetailResponse cloneItinerary(Integer id, String currentUsername)
```

### Step 1: Input & User Authentication Validation
1. If `id == null` -> throw `BadRequestException("Mã lịch trình không hợp lệ")`.
2. If `currentUsername == null || currentUsername.isBlank()` -> throw `UnauthorizedException("Vui lòng đăng nhập để sao chép lịch trình")`.
3. Lookup user in `userRepository`. If not found -> throw `UnauthorizedException("Người dùng không tồn tại")`.
4. Validate `currentUser.getStatus() == UserStatus.ACTIVE`. If account is BANNED or INACTIVE -> throw `ForbiddenException("Tài khoản của bạn đã bị khóa hoặc không hoạt động")`.

### Step 2: Source Itinerary Retrieval & Accessibility Verification
1. Lookup source itinerary by `id`. If missing -> throw `ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa")`.
2. Check `source.getStatus() == ItineraryStatus.DELETED` or source creator is not ACTIVE -> throw `ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa")`.
3. Check visibility:
   - If `source.getVisibility() == Visibility.PUBLIC` -> accessible to all authenticated users.
   - If `source.getVisibility() == Visibility.PRIVATE` -> accessible ONLY if `currentUsername.equals(source.getUser().getUsername())` (owner cloning own itinerary).
   - If other user tries to clone a PRIVATE itinerary -> throw `ForbiddenException("Bạn không có quyền sao chép lịch trình riêng tư này")` (HTTP 403 Forbidden).

### Step 3: Lineage & Metric Accounting
1. Increment ancestor `reuseCount`:
   ```java
   source.setReuseCount((source.getReuseCount() != null ? source.getReuseCount() : 0) + 1);
   itineraryRepository.save(source);
   ```
2. Build cloned `Itinerary` entity:
   - `title`: `source.getTitle() + " (Bản sao)"` (truncated to max 150 characters to comply with column width).
   - `user`: `currentUser`.
   - `originalItinerary`: `source`.
   - `description`, `location`, `coverImage`, `totalDays`, `budget`, `theme`: exact copies from source.
   - `visibility`: `Visibility.PRIVATE` (safely defaulted to private so user can personalize before sharing).
   - `status`: `ItineraryStatus.ACTIVE`.
   - Reset social metrics: `viewCount = 0`, `favoriteCount = 0`, `ratingCount = 0`, `commentCount = 0`, `reuseCount = 0`.
   - `itineraryRepository.save(clonedItinerary)`.

### Step 4: Deep Copying Days & Activities
1. Query source days ordered by `dayNumber ASC`:
   `itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(id)`.
2. For each `sourceDay`:
   - Create new `ItineraryDay` with `clonedItinerary`, same `dayNumber`, `title`, and `date`.
   - Save new day to database to generate distinct `day_id`.
   - Query source activities for that day ordered by `displayOrder ASC`:
     `activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(sourceDay.getDayId())`.
   - For each `sourceAct`:
     - Create new `Activity` pointing to `clonedDay`.
     - Point `canonical_place_id` (`place`) to `sourceAct.getPlace()`.
     - Copy all location snapshot fields: `name`, `description`, `locationName`, `locationAddress`, `customLocationName`, `customAddress`, `latitude`, `longitude`, `placeId`, `locationProvider`, `imageUrl`, `startTime`, `endTime`, `cost`, and `displayOrder`.
     - Save new activity entity to database.

### Step 5: Deep Copying Itinerary-Scoped Saved Places
1. Query source saved places:
   `itineraryPlaceRepository.findAllByItineraryIdWithPlace(id)`.
2. For each `sourcePlace`:
   - Create new `ItineraryPlace` entity linking `clonedItinerary` and `sourcePlace.getPlace()`.
   - Sets fresh `savedAt = LocalDateTime.now()`.
   - Save via `itineraryPlaceRepository.save(clonedPlace)`.
3. Zero new rows are created in `places` table.

### Step 6: Detail Response Mapping
1. Return `getItineraryDetail(clonedItinerary.getItineraryId(), currentUsername)`.
2. Maps `originalItineraryId = source.getItineraryId()`, `reuseCount = 0`, `days`, `activities`, and `creator = currentUser`.

