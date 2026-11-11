# PHASE 4 — 04. ASSOCIATION DELETION SAFETY AUDIT
## Verification of Association-Only Deletion Semantics

**Project:** Travel Planner  
**Focus:** Proving zero side-effects on Place, Activity, and sibling Itineraries  

---

### 1. Invariant Definition

When an itinerary place association is deleted via `DELETE /api/itineraries/{itineraryId}/places/{placeId}`:
1. **Place Entity Safety:** The `places` table row for `placeId` MUST NOT be deleted or modified in any way.
2. **Activity Integrity:** Any `activities` belonging to this itinerary or other itineraries that reference `placeId` MUST retain their foreign key link (`canonical_place_id`) and all activity details.
3. **Cross-Itinerary Isolation:** Other itineraries that have saved the same `placeId` MUST NOT have their associations deleted or modified.

---

### 2. Empirical Test Evidence

Three dedicated tests in `ItineraryPlaceTest.java` mathematically verify these safety guarantees:

#### Test 16: `testDeleteItineraryPlace_DoesNotDeletePlaceEntity`
- Place `activePlace1` is saved to `publicItinerary`.
- Deletion endpoint is executed.
- Assertion: `placeRepository.findById(activePlace1.getPlaceId())` returns `Optional.isPresent() == true` with status `ACTIVE`.
- **Result: PASS.**

#### Test 17: `testDeleteItineraryPlace_DoesNotAlterActivity`
- An `Activity` is created with `place = activePlace1`.
- `activePlace1` is saved to `publicItinerary.savedPlaces`.
- `activePlace1` is then removed from `publicItinerary.savedPlaces`.
- Assertion: `activityRepository.findById(activity.getActivityId())` returns intact activity, with `activity.getPlace().getPlaceId() == activePlace1.getPlaceId()`.
- **Result: PASS.**

#### Test 18: `testDeleteItineraryPlace_DoesNotAffectOtherItineraries`
- Place `activePlace1` is saved in `publicItinerary` (Itinerary A) and `itineraryB`.
- `activePlace1` is removed from Itinerary A.
- Assertion: Association in Itinerary A is removed; association in Itinerary B remains present and unmodified.
- **Result: PASS.**

