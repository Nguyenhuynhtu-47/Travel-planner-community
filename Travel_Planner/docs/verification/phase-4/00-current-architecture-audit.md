# PHASE 4 — 00. CURRENT ARCHITECTURE & SCOPE AUDIT
## Saved Places (Itinerary-Scoped) vs. Other Saved Entities

**Project:** Travel Planner  
**Phase:** 4 — Saved Places: Itinerary-Scoped Place Management  
**Snapshot:** 2026-09-20  
**Baseline Git:** `9902ccd`  

---

### 1. Architectural Distinction of Saved Entities

A fundamental architectural principle in the Travel Planner system is the strict separation between three distinct "save/favorite" features:

```
+--------------------------------------------------------------------------------------------------+
|                                  THREE DISTINCT SAVED ENTITIES                                    |
+--------------------------------------------------------------------------------------------------+
| 1. Saved Places (Itinerary-Scoped)                                                               |
|    - Table: `itinerary_places`                                                                   |
|    - Scope: Scoped to an individual Itinerary (`itinerary_id` + `place_id`).                     |
|    - Purpose: Bookmark candidate POIs/places to visit within the context of a specific trip.     |
|    - Ownership: Owned by the itinerary creator; visible according to itinerary visibility.      |
|    - Deletion Semantics: Deleting row only breaks the association. Place and Activity are intact.|
+--------------------------------------------------------------------------------------------------+
| 2. Saved Itineraries (User Bookmarks)                                                            |
|    - Table: `saved_itineraries`                                                                  |
|    - Scope: Scoped to a User bookmarking whole itineraries created by others (`user_id` + `itin`)|
|    - Purpose: Keep track of community itineraries for inspiration or later cloning.              |
+--------------------------------------------------------------------------------------------------+
| 3. User Favorites (Itinerary Likes/Favorites)                                                    |
|    - Table: `favorites`                                                                          |
|    - Scope: User liking an itinerary (`user_id` + `itinerary_id`).                               |
|    - Purpose: Social engagement and itinerary popularity ranking.                                |
+--------------------------------------------------------------------------------------------------+
```

---

### 2. Place & Activity Linkage Model

- `Place` is a canonical system-wide or user-contributed entity representing a Point of Interest (POI).
- `Activity` represents a concrete scheduled event in an `ItineraryDay` (e.g. "Visit Ben Thanh Market at 09:00 AM").
- `Activity` links directly to `Place` via `canonical_place_id` (`FOREIGN KEY (canonical_place_id) REFERENCES places(place_id) ON DELETE SET NULL`).
- **Critical Architectural Guarantee:** `Activity` has **NO** foreign key to `itinerary_places`. An itinerary's saved places list serves as a pool of candidate locations. Adding or removing a place from the saved pool has **zero effect** on existing activities.

---

### 3. Concurrency and Uniqueness

- Each `(itinerary_id, place_id)` pair is unique via the `uk_itinerary_place` constraint.
- Attempting to add the same place to an itinerary twice results in a `409 Conflict`.
- A single place may be saved across multiple itineraries independently without interference.
- Deleting an association from Itinerary A leaves Itinerary B completely unaffected.

