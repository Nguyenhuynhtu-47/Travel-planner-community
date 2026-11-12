# PHASE 5 — BACKEND API INTEGRATION VERIFICATION

**Project:** Travel Planner  
**Phase:** 5 — Clone Itinerary  
**Target Snapshot Date:** 2026-09-20  
**Git Branch:** `develop`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  

---

## 1. ENDPOINT SPECIFICATION: `POST /api/itineraries/{id}/clone`

- **HTTP Method:** `POST`
- **Path:** `/api/itineraries/{id:[0-9]+}/clone`
- **Authentication:** Required (`Authorization: Bearer <JWT>`)
- **Path Variable:** `id` (Integer) — ID of the itinerary to clone.
- **Request Body:** None required (empty JSON `{}` or omitted).

### Success Response (`201 Created`)
```json
{
  "itineraryId": 260,
  "originalItineraryId": 259,
  "title": "Trekking Sa Pa - Chinh Phục Đỉnh Fansipan 3N2Đ (Bản sao)",
  "description": "Hành trình trekking Fansipan...",
  "location": "Sa Pa, Lào Cai",
  "coverImage": "https://example.com/sapa.jpg",
  "totalDays": 3,
  "budget": 3500000.00,
  "theme": "Trekking",
  "visibility": "PRIVATE",
  "status": "ACTIVE",
  "viewCount": 0,
  "favoriteCount": 0,
  "ratingCount": 0,
  "commentCount": 0,
  "reuseCount": 0,
  "averageRating": 0.0,
  "isFavorited": false,
  "isSaved": false,
  "userRating": null,
  "createdAt": "2026-11-12T06:15:28.123",
  "updatedAt": "2026-11-12T06:15:28.123",
  "creator": {
    "userId": 2,
    "username": "cloner_user",
    "handle": "@cloner_user",
    "fullName": "Người Dùng Nhân Bản",
    "avatar": null
  },
  "days": [
    {
      "dayId": 105,
      "dayNumber": 1,
      "title": "Ngày 1: Chạm ngõ Sa Pa",
      "date": "2026-12-01",
      "activities": [
        {
          "activityId": 401,
          "name": "Khởi hành từ Trạm Tôn",
          "description": "Bắt đầu hành trình leo núi",
          "locationName": "Trạm Tôn",
          "locationAddress": "Xã San Sả Hồ, Sa Pa",
          "canonicalPlaceId": 15,
          "latitude": 22.3500000,
          "longitude": 103.7800000,
          "startTime": "08:00:00",
          "endTime": "11:30:00",
          "cost": 250000.00,
          "displayOrder": 1
        }
      ]
    }
  ]
}
```

---

## 2. AUTOMATED BACKEND INTEGRATION TEST SUITE

The dedicated test class `Travel_Planner.Travel_Planner.ItineraryCloneTest` executed 11 comprehensive integration test cases against MySQL `travel_planner_test`:

```
[INFO] Running Travel_Planner.Travel_Planner.ItineraryCloneTest
[INFO] Tests run: 11, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 24.71 s
[INFO] BUILD SUCCESS
```

### Test Case Breakdown
1. `testClonePublicItinerary_Success`: Validates 201 Created, owner assigned to cloner, title appended with `(Bản sao)`, status `ACTIVE`, visibility `PRIVATE`, original `reuseCount` incremented, `originalItineraryId` set, zero Place rows duplicated.
2. `testCloneAnonymous_ReturnsUnauthorized`: Calling without token returns 401 Unauthorized.
3. `testClonePrivateItinerary_OtherUser_ReturnsForbidden`: Other user attempting to clone private itinerary returns 403 Forbidden.
4. `testClonePrivateItinerary_Owner_Success`: Owner cloning their own private itinerary succeeds (201 Created).
5. `testCloneNonExistent_ReturnsNotFound`: Cloning non-existent ID returns 404 Not Found.
6. `testCloneDeleted_ReturnsNotFound`: Cloning deleted itinerary returns 404 Not Found.
7. `testCloneBannedUser_ReturnsUnauthorized`: Banned user account is locked by Spring Security (401 Unauthorized).
8. `testCloneDaysAndActivities_DeepCopy`: Verifies days and activities are cloned with unique IDs and identical metadata.
9. `testCloneItineraryPlaces_PreservedWithoutDuplicatingPlaces`: Verifies `itinerary_places` entries are duplicated for new itinerary pointing to same canonical places.
10. `testModifyClone_DoesNotAffectOriginal`: Verifies deleting or updating clone does not impact original itinerary.
11. `testCloneMultipleTimes_IncrementsReuseCount`: Verifies multiple clones create distinct entities and increment `reuseCount` monotonically.

