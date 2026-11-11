# PHASE 4 — 06. BACKEND UNIT & INTEGRATION TEST REPORT
## Comprehensive Automated Test Suite Results

**Project:** Travel Planner  
**Backend Framework:** Spring Boot 4.1.1 + JUnit 5 + MockMvc  
**Execution Timestamp:** 2026-11-12T01:15:24+07:00  

---

### 1. Test Suite Summary

- **Total Backend Tests Run:** 440
- **Total Failures:** 0
- **Total Errors:** 0
- **Total Skipped:** 0
- **Execution Time:** 01:44 min
- **Dedicated Phase 4 Tests (`ItineraryPlaceTest.java`):** 19 tests, 19 PASS (100%)

---

### 2. Breakdown of Phase 4 Test Cases (`ItineraryPlaceTest.java`)

| # | Test Method Name | Scenario Description | HTTP Status / Assert | Result |
|---|---|---|---|---|
| 1 | `testSavePlace_Success` | Owner saves valid active place | 201 Created | **PASS** |
| 2 | `testGetSavedPlaces_Success` | Paginated retrieval of saved places | 200 OK | **PASS** |
| 3 | `testGetAllSavedPlaces_Success` | Unpaginated retrieval for activity picker | 200 OK | **PASS** |
| 4 | `testRemovePlace_Success` | Owner removes saved place | 200 OK | **PASS** |
| 5 | `testSavePlace_DuplicateConflict_Throws409` | Prevent duplicate save of same place | 409 Conflict | **PASS** |
| 6 | `testSamePlaceInMultipleItineraries` | Same place saved in Itin A and Itin B | 201 Created | **PASS** |
| 7 | `testItineraryMultiplePlaces` | Multiple places saved in one itinerary | Count == 2 | **PASS** |
| 8 | `testSavePlace_Unauthorized_NonOwner_Throws403`| Non-owner cannot save place | 403 Forbidden | **PASS** |
| 9 | `testRemovePlace_Unauthorized_NonOwner_Throws403`| Non-owner cannot remove place | 403 Forbidden | **PASS** |
| 10 | `testSavePlace_Anonymous_Throws401` | Unauthenticated user cannot save place | 401 Unauthorized | **PASS** |
| 11 | `testRemovePlace_Anonymous_Throws401` | Unauthenticated user cannot remove place| 401 Unauthorized | **PASS** |
| 12 | `testSavePlace_ItineraryNotFound_Throws404` | Save to non-existent itinerary | 404 Not Found | **PASS** |
| 13 | `testSavePlace_PlaceNotFound_Throws404` | Save non-existent place | 404 Not Found | **PASS** |
| 14 | `testSavePlace_PlaceInactiveOrHidden_Throws400`| Reject saving HIDDEN place | 400 Bad Request | **PASS** |
| 15 | `testRemovePlace_NotSaved_Throws404` | Remove place not in itinerary | 404 Not Found | **PASS** |
| 16 | `testDeleteItineraryPlace_DoesNotDeletePlaceEntity` | Place entity survives association deletion | Exists in DB | **PASS** |
| 17 | `testDeleteItineraryPlace_DoesNotAlterActivity` | Activity canonical_place_id survives deletion | Exists & Intact | **PASS** |
| 18 | `testDeleteItineraryPlace_DoesNotAffectOtherItineraries`| Itinerary B survives Itinerary A deletion | Intact in B | **PASS** |
| 19 | `testGetSavedPlaces_PrivateItineraryAccessControl` | Private itinerary hidden from non-owner/anon | 403 Forbidden | **PASS** |

