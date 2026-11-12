# PHASE 5 — MOBILE CLIENT INTEGRATION VERIFICATION

**Project:** Travel Planner  
**Phase:** 5 — Clone Itinerary  
**Target Snapshot Date:** 2026-09-20  
**Framework:** Flutter (Mobile)  
**Git Branch:** `develop`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  

---

## 1. MOBILE CLIENT IMPLEMENTATION SUMMARY

### 1.1 `ItineraryDetail` Model Extension
File: `lib/features/itinerary/data/models/itinerary_detail.dart`
- Added `final int reuseCount;` (default 0).
- Added `final int? originalItineraryId;` (nullable).
- Updated `fromJson` to parse integer numbers or strings safely.
- Updated `copyWith` to support updating `reuseCount` and `originalItineraryId`.

### 1.2 `ItineraryCrudRepository` Method
File: `lib/features/itinerary/data/itinerary_crud_repository.dart`
```dart
Future<ItineraryDetail> cloneItinerary(int itineraryId, {String? token}) async {
  final response = await _apiClient.post(
    '${ApiConstants.itinerariesEndpoint}/$itineraryId/clone',
    body: const {},
    token: token,
  );
  if (response is Map) {
    return ItineraryDetail.fromJson(Map<String, dynamic>.from(response));
  }
  throw ApiException(statusCode: 0, message: 'Phản hồi từ máy chủ không hợp lệ.');
}
```

### 1.3 `ItineraryDetailScreen` UI & Actions
File: `lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart`
1. **AppBar Clone Action:**
   - Adds `IconButton(icon: const Icon(Icons.copy_all_outlined), tooltip: 'Sao chép lịch trình', onPressed: ...)` to `AppBar.actions`.
   - Replaced by a `CircularProgressIndicator` during in-flight cloning to prevent double-tap race conditions.
2. **Confirmation Dialog:**
   - Displays confirmation modal clearly stating that an independent personal copy will be created.
   - User must tap "Sao chép" to initiate the request.
3. **Post-Clone Navigation:**
   - Upon receiving 201 Created from backend, displays success SnackBar.
   - Pushes `ItineraryDetailScreen` with the newly created itinerary ID and `isOwner = true`, allowing the user to immediately personalize their trip.
4. **Metadata Badge:**
   - In `_buildOverview`, renders `${itinerary.reuseCount} lượt sao chép` badge when `reuseCount > 0`.

---

## 2. MOBILE TEST SUITE VERIFICATION

### 2.1 Dedicated Clone Test Suite
File: `test/itinerary_clone_test.dart`
```
00:00 +0: Phase 5 - Itinerary Clone Model & Serialization Tests ItineraryDetail parses reuseCount and originalItineraryId correctly
00:00 +1: Phase 5 - Itinerary Clone Model & Serialization Tests ItineraryDetail defaults reuseCount to 0 and originalItineraryId to null when omitted
00:00 +2: Phase 5 - Itinerary Clone Model & Serialization Tests ItineraryDetail.copyWith preserves and updates reuseCount and originalItineraryId
00:00 +3: Phase 5 - ItineraryCrudRepository.cloneItinerary Tests sends POST to /api/itineraries/{id}/clone with Bearer token and parses response
00:00 +4: Phase 5 - ItineraryCrudRepository.cloneItinerary Tests propagates ApiException when backend rejects with 403 Forbidden
00:00 +5: Phase 5 - ItineraryDetailScreen Clone UI Widget Tests displays clone action button in AppBar
00:00 +6: Phase 5 - ItineraryDetailScreen Clone UI Widget Tests displays reuseCount in metadata badge when reuseCount > 0
00:01 +7: Phase 5 - ItineraryDetailScreen Clone UI Widget Tests unauthenticated user tapping clone button prompts to login
00:01 +8: All tests passed!
```
- **Result:** **8/8 PASS (100%)**.

### 2.2 Full Mobile Regression Suite
- Total Tests Executed: **377**
- Passed: **374**
- Failed: **3** (pre-existing baseline mock failures documented in prior phases: `CreatorSummary falls back to username`, `Rating Dialog layout overflow`, `CommentsSection precedes RatingSection`).
- Regressions: **0** (Zero regressions).

