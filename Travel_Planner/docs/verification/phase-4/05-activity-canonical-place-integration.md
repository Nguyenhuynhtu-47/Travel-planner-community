# PHASE 4 — 05. ACTIVITY & CANONICAL PLACE INTEGRATION
## Workflow: From Itinerary Saved Place to Scheduled Activity

**Project:** Travel Planner  
**Layer:** Data Flow + Backend DTO + Mobile Client Form  

---

### 1. Conceptual Workflow

```
+-------------------------------------------------------------------------------+
| User browses Places Catalog or Search                                         |
| -> Taps "Lưu vào Lịch trình"                                                  |
| -> System creates `itinerary_places` row                                      |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
| User edits Itinerary -> Opens Day N -> Opens "Thêm Hoạt Động"                 |
| -> `ActivityFormBottomSheet` queries `/api/itineraries/{id}/places/all`       |
| -> Displays horizontal list of Saved Places Chips                             |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
| User taps a Saved Place Chip                                                  |
| -> Sets `canonicalPlaceId = place.placeId`                                    |
| -> Pre-fills `name`, `address`, `latitude`, `longitude`, `provider = 'SYSTEM'`|
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
| User submits Form                                                             |
| -> POST `/api/itineraries/{id}/days/{dayId}/activities`                       |
| -> Backend sets `activity.canonical_place_id = place_id`                      |
| -> Activity becomes canonically linked to Place POI                           |
+-------------------------------------------------------------------------------+
```

---

### 2. Backward Compatibility Guarantee

- `canonical_place_id` remains nullable on `activities`.
- Custom activities without a canonical place (e.g., custom free-form addresses or coordinates) continue to function without restriction.
- Any existing activity with or without a canonical place is completely unaffected by changes to the itinerary's saved places list.

