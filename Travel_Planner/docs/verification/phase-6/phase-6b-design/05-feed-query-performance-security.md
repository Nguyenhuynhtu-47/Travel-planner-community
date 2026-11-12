# PHASE 6B.0 — DELIVERABLE 05: FEED QUERY, PERFORMANCE & SECURITY (SESSION 71 PATCH)

**Project:** Travel Planner  
**Date:** 2026-11-12  
**Status:** FINAL REVISED SPECIFICATION — MULTI-QUERY, SKIP LOCKED BATCH CLAIMS & GROUNDED SECURITY BOUNDARIES  
**Git Policy Compliance:** STRICTLY NO COMMIT, NO PUSH

---

## 1. Feed Pagination Strategy & Concurrency Analysis

### 1.1. Deterministic Stable Ordering
All feed queries MUST enforce a deterministic tie-breaker:
`ORDER BY p.created_at DESC, p.post_id DESC`
Sorting by `created_at` alone allows non-deterministic row ordering when multiple posts share the same millisecond timestamp.

### 1.2. Offset Pagination Architecture (Design Decision)
- **Configuration:** Default page size: **10 posts**; Maximum page size: **50 posts**.
- **Edge Cases & Concurrency Handling:**
  - *New Posts Inserted During Paging:* When a new post is inserted at the top of the feed while a user is reading page 0, elements shift down by 1. When the client requests page 1, the last element of page 0 may appear as the first element of page 1.
    - *Resolution:* Client-side deduplication set in `CommunityFeedNotifier`:
      ```dart
      final existingIds = _posts.map((p) => p.postId).toSet();
      final newItems = response.content.where((p) => !existingIds.contains(p.postId)).toList();
      _posts.addAll(newItems);
      ```
  - *Posts Deleted or Moderated During Paging:* When a post on page 0 is deleted, elements shift up by 1, potentially causing an item to be skipped on page 1. In social feed UX, this is an acceptable standard tradeoff for offset pagination. Pull-to-refresh realigns the feed completely.
  - *Expected Benefit:* Native compatibility with Spring Data `Pageable` and existing mobile pagination notifiers without adding complex keyset state management.

---

## 2. Multi-Query Feed Retrieval Strategy (Architecture Review)

### 2.1. Prevention of Hibernate Collection Memory Warnings
Executing `JOIN FETCH p.mediaList` with `Pageable` causes Hibernate warning `HHH000104: firstResult/maxResults specified with collection fetch; applying in memory!`. Hibernate would fetch all matching rows from MySQL and perform pagination in JVM memory, creating a severe memory leak risk.

### 2.2. Specified Multi-Query Strategy (Option B Aligned)
The feed service executes a coordinated multi-query strategy:

1. **Query 1 — Paginated Posts with Single-Valued Associations:**
   ```sql
   SELECT p FROM Post p
   JOIN FETCH p.author a
   LEFT JOIN FETCH p.itinerary i
   LEFT JOIN FETCH i.user iu
   WHERE p.status = 'ACTIVE' AND p.visibility = 'PUBLIC' AND a.status = 'ACTIVE'
   ORDER BY p.createdAt DESC, p.postId DESC
   ```
   - *Design Decision:* `author` and `itinerary` are `@ManyToOne` (single-valued) associations. Fetching them in SQL does not multiply root rows. MySQL executes `LIMIT` and `OFFSET` natively and safely.
2. **Query 2 — Batch Fetch Media for Page Posts (Option B):**
   ```sql
   SELECT pm.post.postId, ma.secureUrl 
   FROM PostMedia pm 
   JOIN pm.mediaAsset ma 
   WHERE pm.post.postId IN (:pagePostIds) 
   ORDER BY pm.post.postId ASC, pm.displayOrder ASC
   ```
   - *Empty Media Handling:* Posts with no photos simply have no rows returned by Query 2. The assembler sets `mediaUrls = Collections.emptyList()`.
3. **Query 3 — Viewer Like State Resolution:**
   - If viewer is unauthenticated (guest): `isLikedByMe = false` for all posts without querying the database.
   - If viewer is authenticated:
     ```sql
     SELECT l.post.postId FROM PostLike l WHERE l.post.postId IN (:pagePostIds) AND l.user.userId = :viewerId
     ```
     Returns `Set<Long> likedPostIds`. In-memory mapping assigns `isLikedByMe = likedPostIds.contains(post.getPostId())`.
4. **Counters Resolution (Zero N+1):**
   - `like_count` and `comment_count` are denormalized columns on `posts` and fetched directly in Query 1. Zero additional `COUNT(*)` queries are executed.

---

## 3. Database Indexes & Redundancy Review

### 3.1. Verified Index Strategy
1. **`post_likes` Table:**
   - Table definition includes: `CONSTRAINT uk_post_likes UNIQUE (post_id, user_id)`.
   - **Verified Fact:** MySQL InnoDB automatically generates a composite B-Tree index for unique constraints (`VERIFIED IN DATABASE`). Zero redundant secondary index added.
2. **`posts` Table Index:**
   - Index: `idx_posts_feed_public` on `(status, visibility, created_at DESC, post_id DESC)`.
3. **`media_assets` Table Index:**
   - Index: `idx_media_assets_owner_status` on `(uploaded_by, status, created_at DESC)`.
   - Index: `idx_media_assets_cleanup` on `(status, dead_lettered_at, next_retry_at, locked_at)` for high-throughput worker lease sweeps.
4. **`post_media` Table Index:**
   - Index: `idx_post_media_post_order` on `(post_id, display_order ASC)`.
   - Unique constraint: `uk_post_media_asset` on `media_asset_id` (automatically indexed).
5. **`post_comments` Table Index:**
   - Index: `idx_post_comments_post_status` on `(post_id, status, created_at ASC)`.

---

## 4. Technical Claims Grounding & Security Boundaries (Issues 1, 4, 6)

### 4.1. Algorithmic Complexity of Primary Key Lookups (Issue 6.A)
- **Accurate Description:** Clustered primary key lookups in MySQL InnoDB use a balanced B+Tree index structure (typically 3 to 4 tree levels in depth for standard table sizes). The algorithmic search complexity is $O(\log n)$ page inspections in the InnoDB buffer pool/disk.
- **True Technical Value of `mediaAssetIds`:**
  - The value of using `mediaAssetIds: List<Long>` instead of raw URLs is NOT an exaggerated "O(1)" lookup, but rather providing a **compact, immutable numeric identifier**.
  - It enables fast clustered index lookups, robust ownership verification in SQL, and complete architectural separation between domain entity references and external CDN URL strings.

### 4.2. Distinction: Anti-Enumeration vs Authorization vs SQL Injection (Issue 6.B)
- **Anti-Enumeration Measure:** Returning `404 Not Found` when a client requests an unowned or non-existent asset ID is an anti-enumeration measure. It conceals resource existence to mitigate ID harvesting oracles.
- **Authorization Enforcement:** Anti-enumeration does NOT replace authorization. True authorization occurs when the server explicitly checks `ma.uploadedBy.userId == currentUserId`.
- **SQL Injection Defense:** Passing `mediaAssetIds` does NOT automatically prevent SQL injection by itself. SQL injection protection relies strictly on:
  - Spring Data JPA parameter binding (`@Param("mediaAssetIds") List<Long> mediaAssetIds`).
  - Hibernate PreparedStatement placeholder substitution (`?`).
  - Strong typing in Java DTOs (`List<Long>`).

### 4.3. Attached Itinerary Security Barrier & Generic Privacy Reason (Issue 4)
```
                     ┌──────────────────────────┐
                     │    Post (e.g. PUBLIC)    │
                     └─────────────┬────────────┘
                                   │ references
                                   ▼
                     ┌──────────────────────────┐
                     │     Attached Itinerary   │
                     └─────────────┬────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              ▼                                         ▼
   Itinerary is PUBLIC & ACTIVE             Itinerary is PRIVATE / HIDDEN / DELETED
   & Itinerary Owner is ACTIVE              OR Itinerary Owner is INACTIVE / BANNED
              │                                         │
              ▼                                         ▼
    Render Itinerary Card                     Render Safe Fallback Card:
 (Title, Days, Budget, Location)          "Lịch trình ở chế độ riêng tư hoặc
                                                không khả dụng."
                                        (ZERO private data leaked!)
```

1. **Independent Identity Principle:** **Post Author** and **Itinerary Owner** are separate entities. A user owning a Post has ZERO authority to reveal private data of an attached Itinerary owned by someone else (or an itinerary they themselves made private later).
2. **Evaluation Invariant:**
   - The attached itinerary is ONLY rendered when ALL of the following conditions hold simultaneously:
     `itinerary.visibility == 'PUBLIC' AND itinerary.status == 'ACTIVE' AND itinerary.user.status == 'ACTIVE'`.
   - If ANY condition fails:
     - The Post continues to display normally if the Post itself is valid.
     - The DTO strictly returns `itinerary = null`, `itineraryUnavailable = true`, and generic `itineraryUnavailableReason = "UNAVAILABLE"`.
     - Zero private metadata (title, cover, duration, budget, activities) is returned in the API response.
     - Detailed operational causes are recorded exclusively in server-side logs.

### 4.4. Worker Batch Claim Token & Stale Worker Protection (Issue 1 & 2)
1. **The Stale Worker Problem:** If Worker A claims an asset batch, hangs or experiences network delay, its 10-minute lease expires. Worker B reclaims the batch and begins deletion. If Worker A wakes up and updates the database without token validation, Worker A could overwrite state or undo Worker B's work.
2. **Batch Claim Token Architecture:**
   - Every claim transaction assigns a unique batch UUID: `claim_token = UUID.randomUUID().toString()`.
   - The worker selects up to 50 eligible asset IDs via `SELECT ... FOR UPDATE SKIP LOCKED` and updates them with the batch token in a short claim transaction (< 50ms), then commits immediately.
   - The worker iterates over the claimed IDs in memory (or queries back via `SELECT ... WHERE claim_token = :claimToken`).
   - Remote Cloudinary calls execute strictly outside database transactions.
   - Result updates require matching token: `WHERE media_asset_id = :id AND claim_token = :token AND status = 'DELETING'`.
   - If the token does not match (`affectedRows == 0`), Worker A detects it has become stale and silently discards its update.
   - *Token Boundary:* The claim token protects database state update authority; it cannot recall an external HTTP call if already transmitted over the network.
   - *Idempotency:* If Worker A already deleted the file on Cloudinary, Worker B receives `result: "not found"`, treats it as idempotent success, and marks the row `DELETED`. Idempotency is preserved under standard error classification.

### 4.5. Security Reality & Status Distinction
- **Verified in Running Codebase (`VERIFIED IN SOURCE`):**
  - Cloudinary credentials and `ImageUploadService` exist.
  - Endpoint `/api/media/images` requires JWT authentication.
  - `ImageUploadController` currently accepts any authenticated upload, passes zero user identity to the storage layer, and does NOT record ownership in any database table (`VERIFIED IN SOURCE`).
- **Design Specification Pending Implementation (`DESIGN GAP ADDRESSED — IMPLEMENTATION PENDING`):**
  - The Media Asset Ownership Architecture (`media_assets`, `post_media`, `mediaAssetIds` validation) is a **PROPOSED DESIGN SPECIFICATION**.
  - **The running system is NOT yet protected against media URL tampering until Phase 6B.1 is implemented and verified through automated test suites.**
