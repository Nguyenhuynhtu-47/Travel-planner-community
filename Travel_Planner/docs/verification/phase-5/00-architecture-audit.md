# PHASE 5 — ARCHITECTURE & SUBSYSTEM AUDIT: CLONE ITINERARY

**Project:** Travel Planner  
**Phase:** 5 — Clone Itinerary  
**Target Snapshot Date:** 2026-09-20  
**Git Branch:** `develop`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  

---

## 1. ARCHITECTURAL OVERVIEW

Phase 5 introduces the itinerary cloning mechanism to the Travel Planner ecosystem. It allows authenticated users to fork or duplicate an existing accessible travel itinerary (public trips or personal private trips) into an independent, personalized draft copy.

```
+--------------------------------------------------------------------------------------------------+
|                                    TRAVEL PLANNER CLONE ARCHITECTURE                              |
+--------------------------------------------------------------------------------------------------+
|                                                                                                  |
|   [ Mobile / Web Client ]                                                                        |
|             |                                                                                    |
|             | POST /api/itineraries/{id}/clone  (Bearer JWT)                                     |
|             v                                                                                    |
|   [ Security Filter Chain ] ───(Validate JWT & Active Account) ───► [ 401 Unauthorized / Locked ]|
|             |                                                                                    |
|             v                                                                                    |
|   [ ItineraryController.cloneItinerary ]                                                         |
|             |                                                                                    |
|             v                                                                                    |
|   [ ItineraryServiceImpl.cloneItinerary ] (@Transactional)                                       |
|             |                                                                                    |
|             +── 1. Validate Access (Source PUBLIC or Owned? Inactive/Deleted?)                     |
|             |      └── If PRIVATE & not owner ──► 403 Forbidden                                  |
|             |      └── If DELETED or Not Found ─► 404 Not Found                                  |
|             |                                                                                    |
|             +── 2. Increment Original: source.reuseCount += 1                                    |
|             |                                                                                    |
|             +── 3. Create Clone Entity:                                                          |
|             |      - title: source.title + " (Bản sao)" (max 150 chars)                          |
|             |      - user: currentUser                                                           |
|             |      - originalItinerary: source (Lineage pointer)                                 |
|             |      - visibility: PRIVATE (User workspace draft)                                  |
|             |      - status: ACTIVE                                                              |
|             |      - metrics reset: viewCount=0, favoriteCount=0, ratingCount=0, reuseCount=0    |
|             |                                                                                    |
|             +── 4. Deep Copy Days & Activities:                                                  |
|             |      - ItineraryDay: duplicate order, title, date                                  |
|             |      - Activity: duplicate snapshot, times, costs, canonical_place_id pointer      |
|             |                                                                                    |
|             +── 5. Deep Copy Itinerary Places:                                                   |
|             |      - ItineraryPlace: duplicate association pointing to same canonical Place      |
|             |      - ZERO duplicate rows created in `places` table                               |
|             |                                                                                    |
|             v                                                                                    |
|   [ Return ItineraryDetailResponse ] ──► (201 Created)                                           |
+--------------------------------------------------------------------------------------------------+
```

---

## 2. LINEAGE TRACKING & COMMUNITY METRICS

1. **Lineage Reference (`original_itinerary_id`):**
   - Maintained via `@ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "original_itinerary_id") private Itinerary originalItinerary;`.
   - Links the cloned copy back to its historical ancestor.
   - Exposed in the API DTO `ItineraryDetailResponse.originalItineraryId` for client lineage display and analytics.

2. **Reuse Accounting (`reuse_count`):**
   - Every time an itinerary is cloned, the ancestor's `reuseCount` is incremented by 1.
   - The cloned itinerary initializes with `reuseCount = 0`.
   - Social metrics (`viewCount`, `favoriteCount`, `ratingCount`, `commentCount`) are reset to 0 to prevent artificial inflation.

---

## 3. ENTITY RELATIONSHIP & ISOLATION GRAPH

```
[Source Itinerary #259] (reuse_count = 5) ────────┐ (original_itinerary_id)
        │                                         │
        ├── [Day 1 #101]                          ▼
        │     └── [Act 1 #201] ───► [Place 1] ◄── [Act 1' #203] 
        │                                 ▲                 │
        └── [ItineraryPlace #51] ─────────┘                 ├── [Day 1' #103]
                                                            │         │
                                              [Cloned Itinerary #260] (reuse_count = 0)
                                                            │
                                              [ItineraryPlace #53] ───► [Place 1]
```

- Modifying or deleting any element of `Cloned Itinerary #260` (its days, activities, or saved places) has zero impact on `Source Itinerary #259`.
- The shared entity is the immutable/authoritative catalog `Place`, ensuring normalized POI management without redundant duplicates.

