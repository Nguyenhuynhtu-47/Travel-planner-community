# PHASE 5 — DEEP COPY INTEGRITY VERIFICATION

**Project:** Travel Planner  
**Phase:** 5 — Clone Itinerary  
**Target Snapshot Date:** 2026-09-20  
**Git Branch:** `develop`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  

---

## 1. INDEPENDENT OBJECT GRAPH EVIDENCE

A critical requirement of Phase 5 is ensuring that the cloned itinerary has its own independent entity hierarchy while preserving references to canonical destinations.

```
ENTITY TYPE         SOURCE RECORD          CLONED RECORD          INDEPENDENCE PROOF
──────────────────  ─────────────────────  ─────────────────────  ──────────────────────────────────────────
Itinerary           id = 100               id = 101               Primary keys differ; owner changes to cloner
ItineraryDay        dayId = 201 (day 1)    dayId = 203 (day 1)    New day entity tied to cloned itinerary
ItineraryDay        dayId = 202 (day 2)    dayId = 204 (day 2)    New day entity tied to cloned itinerary
Activity            activityId = 301       activityId = 303       New activity entity tied to day 203
Activity            activityId = 302       activityId = 304       New activity entity tied to day 204
Place               placeId = 1            placeId = 1            SHARED reference; canonical place unchanged
ItineraryPlace      id = 501               id = 502               New association linking itinerary 101 to Place 1
```

---

## 2. PLACE DUPLICATION AUDIT

To ensure the canonical `places` catalog is never polluted or duplicated during cloning:
- Total places in database BEFORE cloning: `N`
- Total places in database AFTER cloning: `N`
- Difference: `0`
- Proven by `ItineraryCloneTest.testCloneItineraryPlaces_PreservedWithoutDuplicatingPlaces`:
  ```java
  long placeCountBefore = placeRepository.count();
  // execute clone
  assertEquals(placeCountBefore, placeRepository.count());
  ```

---

## 3. NON-DESTRUCTIVE SEMANTICS AUDIT

When a user modifies or deletes their cloned copy:
1. Deleting cloned activities does not remove activities from the original itinerary.
2. Deleting cloned days does not delete days from the original itinerary.
3. Unsaving or removing places from the cloned itinerary's `itinerary_places` does not affect the original itinerary's saved places.
4. Soft-deleting the cloned itinerary (`status = DELETED`) leaves the original itinerary in `ACTIVE` status with all days, activities, and metrics intact.
- Proven by `ItineraryCloneTest.testModifyClone_DoesNotAffectOriginal`:
  ```java
  // Delete cloned itinerary
  mockMvc.perform(delete("/api/itineraries/" + clonedItineraryId))
  // Assert original has status ACTIVE, count of days = 2, count of saved places = 2
  ```

