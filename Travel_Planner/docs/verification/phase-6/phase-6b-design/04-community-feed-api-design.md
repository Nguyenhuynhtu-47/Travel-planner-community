# PHASE 6B.0 — DELIVERABLE 04: COMMUNITY FEED API DESIGN (SESSION 71 PATCH)

**Project:** Travel Planner  
**Date:** 2026-11-12  
**Status:** FINAL REVISED SPECIFICATION — CONCURRENCY, PRIVACY & STRICT AUTHORIZATION  
**Git Policy Compliance:** STRICTLY NO COMMIT, NO PUSH

---

## 1. REST Endpoint Summary

| HTTP Method | URL Path | Auth | Purpose |
| :--- | :--- | :---: | :--- |
| **GET** | `/api/community/feed` | Optional | Public feed (Latest chronological stream). |
| **GET** | `/api/community/feed/following` | Mandatory | Following feed (posts from followed creators and mutual friends). |
| **POST** | `/api/community/posts` | Mandatory | Create a post using validated internal `mediaAssetIds` and optional public itinerary. |
| **GET** | `/api/community/posts/{id}` | Optional | Detailed post view (enforces post visibility, author status, and itinerary privacy). |
| **PATCH** | `/api/community/posts/{id}` | Mandatory | Update post content or visibility (Author only, requires `ACTIVE` account). |
| **DELETE** | `/api/community/posts/{id}` | Mandatory | Soft delete post (Author or Admin). |
| **POST** | `/api/community/posts/{id}/likes` | Mandatory | Like a post (Idempotent, requires `ACTIVE` account). |
| **DELETE** | `/api/community/posts/{id}/likes` | Mandatory | Unlike a post (Idempotent, requires `ACTIVE` account). |
| **GET** | `/api/community/posts/{id}/comments` | Optional | Paginated flat comments list. |
| **POST** | `/api/community/posts/{id}/comments` | Mandatory | Add flat comment (No reply threads, requires `ACTIVE` account). |
| **PATCH** | `/api/community/posts/{id}/comments/{commentId}` | Mandatory | Edit comment (Author only). |
| **DELETE** | `/api/community/posts/{id}/comments/{commentId}` | Mandatory | Soft delete comment (Comment author, Post author, Admin). |
| **POST** | `/api/community/posts/{id}/report` | Mandatory | Report inappropriate content (Requires `ACTIVE` account). |
| **POST** | `/api/media/images` | Mandatory | Upload image to Cloudinary and return `mediaAssetId` + `secureUrl` (with compensating action). |
| **GET** | `/api/conversations/unread-total` | Mandatory | Aggregate unread message count for AppBar navigation badge (Scheduled for Phase 6B.2). |

---

## 2. Media Upload & Ownership API

### 2.1. `POST /api/media/images` (Compensating Deletion Architecture)
Uploads an image file to Cloudinary and persists ownership in `media_assets`.

- **Authentication:** Mandatory (`Bearer <token>`).
- **Request:** `MultipartFile file` (Form-Data).
- **Validation:** Max 5MB; magic-byte verified JPEG, PNG, WebP.
- **Backend Action & Compensating Action (Issue 2):**
  1. Truncates and extracts authenticated `userId` from `@AuthenticationPrincipal`.
  2. Uploads binary to Cloudinary, obtaining `public_id` and `secure_url`.
  3. Attempts to insert row into `media_assets` with `status = 'UNATTACHED'`.
  4. **Compensating Rollback:** If the database insert throws an exception (connection failure, disk full), the service immediately calls `cloudinary.uploader().destroy(publicId)` to delete the uploaded remote object.
  5. If the compensating deletion fails, an ERROR log event is written to the dead-letter log for scheduled reconciliation in Phase 6B.6.
- **Response Structure (201 Created):**
  ```json
  {
    "mediaAssetId": 1001,
    "secureUrl": "https://res.cloudinary.com/.../cloud_1.jpg"
  }
  ```

---

## 3. Feed Endpoints

### 3.1. `GET /api/community/feed`
Retrieves the paginated public community feed with stable deterministic ordering.

- **Authentication:** Optional. If authenticated, `isLikedByMe` is populated for the current viewer.
- **Query Parameters:** `page` (int, default 0), `size` (int, default 10, max 50).
- **Ordering:** Stable chronological: `created_at DESC, post_id DESC`.
- **Filtering:** Strictly filters `WHERE p.status = 'ACTIVE' AND p.visibility = 'PUBLIC' AND p.author.status = 'ACTIVE'`.
- **Response Structure (200 OK):**
  ```json
  {
    "content": [
      {
        "postId": 101,
        "content": "Hoàng hôn trên đỉnh Tà Xùa thật sự kỳ vĩ! Chia sẻ lại lịch trình cho cả nhà.",
        "author": {
          "userId": 5,
          "handle": "wanderer_linh",
          "fullName": "Nguyễn Linh",
          "avatar": "https://res.cloudinary.com/.../avatar.jpg"
        },
        "mediaUrls": [
          "https://res.cloudinary.com/.../cloud_1.jpg",
          "https://res.cloudinary.com/.../cloud_2.jpg"
        ],
        "itinerary": {
          "itineraryId": 42,
          "title": "Săn mây Tà Xùa 2N1Đ",
          "coverImage": "https://res.cloudinary.com/.../cover.jpg",
          "totalDays": 2,
          "budget": 1800000.0,
          "location": "Sơn La",
          "averageRating": 4.8,
          "owner": {
            "userId": 9,
            "handle": "hiker_duy",
            "fullName": "Trần Duy",
            "avatar": "https://res.cloudinary.com/.../duy.jpg"
          }
        },
        "itineraryUnavailable": false,
        "itineraryUnavailableReason": null,
        "likeCount": 24,
        "commentCount": 5,
        "isLikedByMe": true,
        "isOwner": false,
        "createdAt": "2026-11-12T09:30:00Z",
        "updatedAt": "2026-11-12T09:30:00Z"
      }
    ],
    "pageNumber": 0,
    "pageSize": 10,
    "totalElements": 1,
    "totalPages": 1,
    "last": true
  }
  ```
- **Fallback Payload When Linked Itinerary is Unavailable (Issue 4):**
  ```json
  {
    "itinerary": null,
    "itineraryUnavailable": true,
    "itineraryUnavailableReason": "UNAVAILABLE"
  }
  ```
  - **Airtight Privacy Rule:** For all external clients, the API returns strictly `itineraryUnavailableReason = "UNAVAILABLE"`. It does NOT expose whether the itinerary is PRIVATE, DELETED, or HIDDEN, nor whether the owner is INACTIVE or BANNED.
  - Detailed internal causes (`ITINERARY_PRIVATE`, `CREATOR_BANNED`, etc.) are recorded exclusively in backend server logs.
  - **Zero leak:** `itinerary` is `null`. Title, cover, duration, budget, and activities are completely omitted.

---

### 3.2. `GET /api/community/feed/following`
- **Authentication:** Mandatory (`Bearer <token>`).
- **Stream Rules:**
  - `PUBLIC` posts authored by users whom the current viewer follows (`follows`), where author `status = 'ACTIVE'`.
  - `FRIENDS` posts authored by users whom the current viewer follows **AND** has an active bidirectional friendship with (`friendships.status = 'ACCEPTED'`), where author `status = 'ACTIVE'`.
  - Current viewer's own posts (if viewer `status = 'ACTIVE'`).

---

## 4. Post CRUD Endpoints

### 4.1. `POST /api/community/posts` (Unified Error Policy & Concurrency Defense)
Creates a post using validated internal `mediaAssetIds`.

- **Authentication:** Mandatory. Author extracted strictly from JWT principal (`currentUserId`). Author account MUST be `status == 'ACTIVE'`, otherwise returns `403 Forbidden` (*"Tài khoản của bạn đang tạm khóa hoặc chưa được kích hoạt"*).
- **Request Body (`CreatePostRequest`):**
  ```json
  {
    "content": "Một buổi chiều bình yên tại Hội An...",
    "visibility": "PUBLIC",
    "itineraryId": 12,
    "mediaAssetIds": [1001, 1002]
  }
  ```

#### Detailed Validation & HTTP Error Response Specification (Issue 1 & 6):

| Case / Condition | HTTP Status | Error Message / Semantic Response |
| :--- | :---: | :--- |
| **Request contains duplicate IDs** | **`400 Bad Request`** | *"Danh sách ảnh chứa định danh trùng lặp"* |
| **Request exceeds limit (> 5 IDs)** | **`400 Bad Request`** | *"Vượt quá giới hạn tối đa 5 ảnh"* |
| **One or more IDs do not exist in DB** | **`404 Not Found`** | *"Tệp phương tiện không tồn tại"* |
| **Asset belongs to another user** | **`404 Not Found`** | *"Tệp phương tiện không tồn tại hoặc bạn không có quyền truy cập"* *(Anti-Enumeration Policy)* |
| **Asset already has status `ATTACHED`** | **`409 Conflict`** | *"Tệp phương tiện đã được sử dụng trong bài viết khác"* |
| **Asset has status `DELETING` or `DELETED`** | **`409 Conflict`** | *"Tệp phương tiện đang được xóa hoặc không còn khả dụng"* |
| **All assets `UNATTACHED` & owned by user** | **`201 Created`** | Post created, `media_assets` updated to `ATTACHED`, rows inserted into `post_media`. |

> **Anti-Enumeration Policy vs Authorization (Issue 6):**  
> Returning `404 Not Found` for unowned assets is an anti-enumeration measure to prevent attackers from probing whether asset IDs exist on the server (ID harvesting oracle).  
> It does NOT replace authorization. True authorization is enforced when the server verifies `ma.uploadedBy.userId == currentUserId`. Anti-enumeration is purely a resource concealment policy.

#### Concurrency & TOCTOU Defense:
1. To prevent Time-of-Check to Time-of-Use (TOCTOU) race conditions, validation and attachment execute inside a single `@Transactional` method.
2. The service sorts IDs (`sortedIds`) as a mitigation to reduce lock ordering inversion risk and executes pessimistic write locking:
   `@Lock(LockModeType.PESSIMISTIC_WRITE)` on `MediaAssetRepository.findByIdsForUpdate(sortedIds)`.
   *Deadlock Handling:* Because SQL `IN (:ids)` is an unordered set predicate in relational database standards, sorting in Java reduces deadlock probability but cannot guarantee the database engine's internal lock order. The service must catch transient deadlock exceptions (`CannotAcquireLockException`) and apply a bounded retry policy (`@Retryable(maxAttempts = 3)`).
3. If any validation fails (duplicate, unowned, deleting, already attached), the transaction rolls back immediately: zero posts created, zero assets attached.
4. Schema level guarantee: `CONSTRAINT uk_post_media_asset UNIQUE (media_asset_id)` provides engine-level enforcement against double attachments.

---

## 5. Post Authorization & Account Status Semantics Matrix (Issue 4 & 5)

Authorization rules are uniformly enforced across all post-related endpoints:

| Endpoint | `PUBLIC` Post | `FRIENDS` Post | `PRIVATE` Post | Post `DELETED` / `HIDDEN` | Author `INACTIVE` | Author `BANNED` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`GET /feed`** | Included (if author `ACTIVE`). | Excluded. | Excluded. | Excluded. | **Excluded**. | **Excluded**. |
| **`GET /feed/following`** | Included (if followed & author `ACTIVE`). | Included (if mutual friend & author `ACTIVE`). | Excluded. | Excluded. | **Excluded**. | **Excluded**. |
| **`GET /posts/{id}`** | Allowed (200 OK). | Friend: 200 OK.<br>Non-friend: **403 Forbidden**. | Author: 200 OK.<br>Others: **404 Not Found**. | **404 Not Found**. | Others: **404 Not Found**.<br>Author: 404 (or auth banner). | **404 Not Found** (all non-admins). |
| **`GET /posts/{id}/comments`** | Allowed (200 OK). | Friend: 200 OK.<br>Non-friend: **403 Forbidden**. | Author: 200 OK.<br>Others: **404 Not Found**. | **404 Not Found**. | **404 Not Found**. | **404 Not Found**. |
| **`POST /posts/{id}/comments`** | Active user: 201 Created.<br>Inactive: **403 Forbidden**. | Friend: 201 Created.<br>Non-friend: **403 Forbidden**. | Author: 201 Created.<br>Others: **404 Not Found**. | **404 Not Found**. | **404 Not Found**. | **404 Not Found**. |
| **`POST /posts/{id}/likes`** | Active user: 200 OK.<br>Inactive: **403 Forbidden**. | Friend: 200 OK.<br>Non-friend: **403 Forbidden**. | Author: 200 OK.<br>Others: **404 Not Found**. | **404 Not Found**. | **404 Not Found**. | **404 Not Found**. |
| **`DELETE /posts/{id}/likes`** | Active user: 200 OK.<br>Inactive: **403 Forbidden**. | Friend: 200 OK.<br>Non-friend: **403 Forbidden**. | Author: 200 OK.<br>Others: **404 Not Found**. | **404 Not Found**. | **404 Not Found**. | **404 Not Found**. |
| **`POST /posts/{id}/report`** | Active user: 201 Created.<br>Inactive: **403 Forbidden**. | Friend: 201 Created.<br>Non-friend: **403 Forbidden**. | Author: 400 Bad Request.<br>Others: **404 Not Found**. | **404 Not Found**. | **404 Not Found**. | **404 Not Found**. |

### 5.1. HTTP Status Code Semantic Distinction
- **`401 Unauthorized`:** Missing or expired JWT. Client must authenticate.
- **`403 Forbidden`:** Authenticated, but lacks authority. Used for:
  - Non-friend attempting to view/interact with a `FRIENDS` post.
  - User with `status == 'INACTIVE'` attempting write operations (comment, like, report, create post).
  - Non-author attempting to modify or delete a post.
- **`404 Not Found`:** Resource does not exist, has been soft-deleted (`DELETED`), moderated (`HIDDEN`), belongs to a `BANNED` or `INACTIVE` author, is an unowned/non-existent asset in post creation, or is a `PRIVATE` post accessed by a non-author (concealing existence to prevent enumeration).

---

## 6. Flat Comments Endpoints (ADR-6B-05)

### 6.1. `GET /api/community/posts/{postId}/comments`
- **Query Parameters:** `page` (default 0), `size` (default 20).
- **Ordering:** `created_at ASC` (Chronological flat discussion).
- **Response Structure (No Parent Comment Hierarchy):**
  ```json
  {
    "content": [
      {
        "commentId": 501,
        "postId": 101,
        "content": "Ảnh đẹp quá bạn ơi!",
        "author": {
          "userId": 8,
          "handle": "foodie_khoa",
          "fullName": "Đăng Khoa",
          "avatar": "https://..."
        },
        "isOwner": false,
        "createdAt": "2026-11-12T10:00:00Z"
      }
    ],
    "pageNumber": 0,
    "pageSize": 20,
    "totalElements": 1,
    "totalPages": 1,
    "last": true
  }
  ```

### 6.2. `POST /api/community/posts/{postId}/comments`
- **Request Body:**
  ```json
  {
    "content": "Lịch trình này đi vào tháng mấy là đẹp nhất vậy bạn?"
  }
  ```
  *(Zero parentCommentId field).*

---

## 7. Navigation Badges Support API (ADR-6B-02 & Phase 6B.2 Roadmap)

### 7.1. Friend Requests Badge (Existing Verified Endpoint)
- **Endpoint:** `GET /api/users/me/friend-requests?direction=received`
- **Status:** Already implemented in backend (`FriendshipController.java`).
- **Response:** Spring Data `Page<FriendRequestResponse>` returning `totalElements`.
- **Usage:** Mobile AppBar "Bạn bè" shortcut directly uses `totalElements` to render numerical badge.

### 7.2. Unread Conversations Total (Committed Addition: Option B)
- **Endpoint:** `GET /api/conversations/unread-total`
- **Status:** **Scheduled for backend implementation in Phase 6B.2**.
- **Authentication:** Mandatory (`Bearer <token>`).
- **Backend Query:**
  ```sql
  SELECT COALESCE(SUM(cm.unread_count), 0)
  FROM conversation_members cm
  WHERE cm.user_id = :currentUserId;
  ```
- **Response Structure (200 OK):**
  ```json
  {
    "totalUnread": 4
  }
  ```

### 7.3. Phasing & Interim Navigation Badge Policy (Issue 6)
- **Verified Fact:** The current backend has **NO** global unread total endpoint.
- **Interim Mobile Recommendation (Phase 6B MVP):**  
  **HIDE the unread badge on the Chat AppBar icon entirely** until `GET /api/conversations/unread-total` is delivered in Phase 6B.2.
- **Strict Rule:** Do NOT attempt to calculate the global unread count from local conversation caches or the first page of the conversation list. Doing so presents inaccurate, partial data and creates a degraded user experience. Once the Phase 6B.2 endpoint is delivered, the numerical badge will be connected cleanly.
