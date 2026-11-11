# PHASE 4 — 03. ACCESS CONTROL & SECURITY MATRIX
## Enforcement Rules and Privilege Boundaries

**Project:** Travel Planner  
**Layer:** Spring Security + Service-Level Validation  

---

### 1. Security Matrix

| Action | Caller Role / State | Public Itinerary | Private Itinerary | Enforced By |
|---|---|---|---|---|
| `POST /places` (Add Place) | Owner | **201 Created** | **201 Created** | Service Ownership Check |
| `POST /places` (Add Place) | Authenticated (Non-Owner) | **403 Forbidden** | **403 Forbidden** | Service Ownership Check |
| `POST /places` (Add Place) | Anonymous | **401 Unauthorized**| **401 Unauthorized**| Spring Security `anyRequest().authenticated()` |
| `GET /places` (View Places)| Owner | **200 OK** | **200 OK** | Service View Check |
| `GET /places` (View Places)| Authenticated (Non-Owner) | **200 OK** | **403 Forbidden** | Service View Check |
| `GET /places` (View Places)| Anonymous | **200 OK** | **403 Forbidden** | Service View Check |
| `DELETE /places/{id}` | Owner | **200 OK** | **200 OK** | Service Ownership Check |
| `DELETE /places/{id}` | Authenticated (Non-Owner) | **403 Forbidden** | **403 Forbidden** | Service Ownership Check |
| `DELETE /places/{id}` | Anonymous | **401 Unauthorized**| **401 Unauthorized**| Spring Security `anyRequest().authenticated()` |

---

### 2. Business Integrity Rules

1. **Place Status Verification:**
   - Only places with `status = ACTIVE` can be saved.
   - Places with `status = HIDDEN` or `DELETED` throw `BadRequestException` (`400 Bad Request`).
2. **Duplicate Conflict Verification:**
   - Attempting to save a place that already exists in the itinerary throws `ConflictException` (`409 Conflict`).
3. **Association Lookup on Delete:**
   - Attempting to delete a place that is not in the itinerary throws `ResourceNotFoundException` (`404 Not Found`).

