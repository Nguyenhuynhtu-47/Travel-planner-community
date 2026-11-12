# PHASE 5 — ACCESS CONTROL & SECURITY VERIFICATION

**Project:** Travel Planner  
**Phase:** 5 — Clone Itinerary  
**Target Snapshot Date:** 2026-09-20  
**Git Branch:** `develop`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  

---

## 1. ACCESS CONTROL MATRIX

| Caller Role / State | Target Itinerary Visibility | Target Itinerary Owner | Target Itinerary Status | Result | HTTP Status | Business Reason |
|:---|:---|:---|:---|:---|:---|:---|
| Anonymous (No token) | PUBLIC | Any | ACTIVE | Rejected | 401 Unauthorized | Endpoint requires authenticated session |
| Anonymous (No token) | PRIVATE | Any | ACTIVE | Rejected | 401 Unauthorized | Endpoint requires authenticated session |
| Authenticated User A | PUBLIC | User B | ACTIVE | **Allowed** | 201 Created | Public itineraries are open for community cloning |
| Authenticated User A | PRIVATE | User B | ACTIVE | **Rejected** | 403 Forbidden | Cannot access or clone private itineraries of others |
| Authenticated User A | PRIVATE | User A | ACTIVE | **Allowed** | 201 Created | Owner can clone their own private itinerary (branching/draft) |
| Authenticated User A | PUBLIC | User A | ACTIVE | **Allowed** | 201 Created | Owner can clone their own public itinerary |
| Authenticated User A | PUBLIC / PRIVATE | Any | DELETED | **Rejected** | 404 Not Found | Deleted itineraries are treated as non-existent |
| Authenticated User A | PUBLIC | Banned User | ACTIVE | **Rejected** | 404 Not Found | Content from banned accounts is quarantined from access |
| Banned Account | PUBLIC | Any | ACTIVE | **Rejected** | 401 Unauthorized | Spring Security locks banned accounts at authentication filter |
| Authenticated User A | Non-existent ID | N/A | N/A | **Rejected** | 404 Not Found | Resource not found |

---

## 2. SECURITY FILTER CHAIN AUDIT

In `SecurityConfig.java`:
```java
.authorizeHttpRequests(auth -> auth
    .requestMatchers("/api/health").permitAll()
    .requestMatchers("/ws", "/ws/**").permitAll()
    .requestMatchers("/api/auth/register", "/api/auth/login").permitAll()
    .requestMatchers(HttpMethod.GET, "/api/itineraries", "/api/itineraries/recommendations", "/api/itineraries/{id:[0-9]+}").permitAll()
    ...
    .anyRequest().authenticated()
)
```
- `POST /api/itineraries/{id:[0-9]+}/clone` is strictly matched by `.anyRequest().authenticated()`.
- An invalid or missing token triggers `AuthenticationEntryPoint`, returning standard `401 Unauthorized` JSON.
- Any attempt to clone an unauthorized private itinerary raises `ForbiddenException`, handled by `GlobalExceptionHandler` returning `403 Forbidden`.

---

## 3. DEFENSIVE VERIFICATION EVIDENCE

Integration tests in `ItineraryCloneTest` independently prove:
- `testCloneAnonymous_ReturnsUnauthorized`: PASS (401)
- `testClonePrivateItinerary_OtherUser_ReturnsForbidden`: PASS (403)
- `testClonePrivateItinerary_Owner_Success`: PASS (201)
- `testCloneNonExistent_ReturnsNotFound`: PASS (404)
- `testCloneDeleted_ReturnsNotFound`: PASS (404)
- `testCloneBannedUser_ReturnsUnauthorized`: PASS (401)

