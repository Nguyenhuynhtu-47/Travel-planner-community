# PHASE 6B.0 — DELIVERABLE 01: CURRENT ARCHITECTURE AUDIT (REMEDIATED)

**Project:** Travel Planner  
**Date:** 2026-11-12  
**Status:** REMEDIATED ARCHITECTURE AUDIT — EVIDENCE-BASED & VERIFIED  
**Git Policy Compliance:** STRICTLY NO COMMIT, NO PUSH. Working tree preserved.

---

## 1. Executive Summary & Verification Evidence

An exhaustive architecture audit across Backend (Spring Boot 3.x), Database (MySQL 8.x), Mobile (Flutter), and Web Admin (Flutter Web) was conducted. Every technical assertion below is classified with verifiable evidence from source files and runtime schemas.

### Key Findings & Classification Matrix

| Layer / Component | Existing Capability | Classification | Audit Finding / Technical Gap |
| :--- | :--- | :---: | :--- |
| **Backend Data Model** | 22 MySQL tables, 24 JPA entities. Full Itinerary, Activity, Place, Rating, Favorite, Comment, Friendship, Message, Follow models. | `VERIFIED IN SOURCE`<br>`VERIFIED IN DATABASE` | No `Post`, `MediaAsset`, `PostMedia`, `PostLike`, `PostComment`, or `PostReport` entities exist. |
| **Media Service & Ownership** | Cloudinary integration (`CloudinaryImageUploadService`), 5MB limit, SHA-1 signatures, JPEG/PNG/WebP magic-byte validation. Authenticated endpoint `POST /api/media/images`. | `VERIFIED IN SOURCE`<br>**`BLOCKING GAP`** | **Critical Security Gap:** Upload endpoint accepts `MultipartFile`, returns bare `secureUrl`, and records **NO ownership metadata** in MySQL. The server cannot verify if an authenticated user owns a submitted URL. |
| **Navigation Badges** | Chat conversations and friend requests. | `VERIFIED IN SOURCE`<br>**`TECHNICAL GAP`** | `GET /api/users/me/friend-requests?direction=received` provides `totalElements` for pending friend requests. However, **NO global aggregate endpoint** exists for total unread messages (only per-conversation `unreadCount` in paginated list). |
| **Itinerary & Account Lifecycle** | Enums `ItineraryStatus` (`ACTIVE`, `HIDDEN`, `DELETED`), `Visibility` (`PUBLIC`, `PRIVATE`), `UserStatus` (`ACTIVE`, `INACTIVE`, `BANNED`). | `VERIFIED IN SOURCE` | Moderation hides itineraries by setting `status = 'HIDDEN'`. No separate moderation table exists for itineraries. |
| **Mobile Navigation Shell** | 5 Bottom Navigation destinations: Explore (0), Community (1), Create Itinerary (2), Collections (3), Profile (4). | `VERIFIED IN SOURCE` | Tab 1 ("Cộng đồng") currently hosts Private Chat, Friends, and Friend Requests, NOT a Community Feed. |
| **Flutter Web Admin** | Place Catalog Management (`AdminPlacesScreen`), Auth, Profile. | `VERIFIED IN SOURCE` | Subsystems `moderation/`, `itineraries/`, `comments/`, `users/`, `violations/` contain only `.gitkeep`. |

---

## 2. Media Upload & Ownership Audit (Cloudinary)

### 2.1. Codebase Reality
Direct source inspection of `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/`:
- **Controller (`ImageUploadController.java` lines 23–27):**
  ```java
  @PostMapping(path = "/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public ResponseEntity<ImageUploadResponse> uploadImage(@RequestPart("file") MultipartFile file) {
      String secureUrl = imageUploadService.uploadImage(file);
      return ResponseEntity.status(HttpStatus.CREATED).body(new ImageUploadResponse(secureUrl));
  }
  ```
  - **Evidence:** Method signature does NOT take `@AuthenticationPrincipal UserDetails`.
  - **Security Filter (`SecurityConfig.java` line 98):** Endpoint `/api/media/images` falls under `.anyRequest().authenticated()`, requiring a valid JWT.
  - **DTO (`ImageUploadResponse.java` line 3):** Record contains only `String secureUrl`.
  - **Service (`CloudinaryImageUploadService.java` lines 98–108):** Calls Cloudinary upload API, reads `secure_url` from JSON, and discards Cloudinary `public_id`, `created_at`, `bytes`, and `format`.
- **Database Reality:** Zero media-related tables exist in MySQL `travel_planner`. Images are stored only as string columns (`users.avatar`, `itineraries.cover_image`).

### 2.2. The Blocking Security Defect
- **Problem Statement:** A client submitting `CreatePostRequest` with an array of `imageUrls` cannot be authenticated as the legitimate owner of those images simply because the URLs match Cloudinary domain or folder rules. Anyone with a Cloudinary URL from the shared folder could reuse or hotlink images uploaded by another user.
- **Classification:** **`BLOCKING GAP`** (Requires dedicated Media Asset ownership model in Phase 6B.1).

---

## 3. Navigation Badge Counts Audit

### 3.1. Friend Requests Badge
- **Endpoint:** `GET /api/users/me/friend-requests?direction=received` in `FriendshipController.java`.
- **Response:** Returns `PageResponse<FriendRequestResponse>`.
- **Capability:** `PageResponse.totalElements` provides the exact count of pending incoming friend requests.
- **Status:** **`VERIFIED IN SOURCE`** — Supported for friend request badge.

### 3.2. Unread Messages Badge
- **Endpoints:** `ConversationController.java` provides `GET /api/conversations`, returning `PageResponse<ConversationSummaryResponse>`.
- **Per-Conversation Count:** `ConversationSummaryResponse.unreadCount` is populated per conversation.
- **Global Count:** There is **NO endpoint** (such as `GET /api/conversations/unread-total`) to retrieve total unread messages across all conversations.
- **Status:** **`TECHNICAL GAP`** — Mobile client cannot display an accurate unread message badge without either paginating all conversations or requiring a new lightweight aggregate endpoint in Phase 6B.2.

---

## 4. Itinerary & Account Lifecycle Audit

### 4.1. Verified Enums and Storage
- **`ItineraryStatus` (`Travel_Planner/Travel_Planner/model/enums/ItineraryStatus.java`):**
  - Values: `ACTIVE`, `HIDDEN`, `DELETED`. (`VERIFIED IN SOURCE`)
- **`Visibility` (`Travel_Planner/Travel_Planner/model/enums/Visibility.java`):**
  - Values: `PUBLIC`, `PRIVATE`. (`VERIFIED IN SOURCE`)
- **`UserStatus` (`Travel_Planner/Travel_Planner/model/enums/UserStatus.java`):**
  - Values: `ACTIVE`, `INACTIVE`, `BANNED`. (`VERIFIED IN SOURCE`)

### 4.2. Separation of Status Concepts
1. **Lifecycle Status (`itineraries.status`):** `ACTIVE` (normal) vs `DELETED` (soft-deleted by author/admin).
2. **Visibility Setting (`itineraries.visibility`):** `PUBLIC` (discoverable) vs `PRIVATE` (author only).
3. **Moderation Status (`itineraries.status = 'HIDDEN'`):** When flagged for violation, the itinerary is set to `HIDDEN`. No separate moderation table exists.
4. **Author Account Status (`users.status`):** `ACTIVE` vs `BANNED`. If banned, all itineraries are excluded from public discovery.

---

## 5. Architectural Invariants to Preserve

1. **Place & Activity Decoupling (`VERIFIED IN SOURCE`):** Activities store authoritative location snapshots (`location_name`, `latitude`, `longitude`, `location_address`). Activity coordinates and titles remain valid regardless of Place catalog status.
2. **Pure Associative Saved Places (`VERIFIED IN SOURCE`):** `itinerary_places` connects an Itinerary to a `Place`. Deleting an association never deletes the Place or Activity.
3. **Privacy Decoupling (`VERIFIED IN SOURCE`):** Login `username` is NEVER exposed as a public display name. Only `full_name` or `@handle` is rendered.
4. **Clone Independence (`VERIFIED IN SOURCE`):** Cloned itineraries are completely independent rows.
5. **Phase 6A Invariants (`VERIFIED IN SOURCE`):** Flow A (Save Place to Itinerary) and Flow B (Schedule as Activity) operate independently.
6. **Attached Itinerary Privacy Barrier (`PROPOSED MANDATORY INVARIANT`):** A public post must NEVER leak private itinerary metadata. When an attached itinerary is `PRIVATE`, `HIDDEN`, `DELETED`, or its owner is `BANNED`, the post renders a safe placeholder card with zero private data.
