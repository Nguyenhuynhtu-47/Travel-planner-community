# PHASE 6B.0 — DELIVERABLE 07: ARCHITECTURE DECISION RECORDS (ADR) (SESSION 71 PATCH)

**Project:** Travel Planner  
**Date:** 2026-11-12  
**Status:** FINAL REVISED ADR REGISTER — USER APPROVALS, CONCURRENCY & ERROR HANDLING  
**Git Policy Compliance:** STRICTLY NO COMMIT, NO PUSH

---

## 1. User-Approved Architectural Decisions

The following 6 decisions were explicitly approved by the user or established as core project agreements:

### ADR-6B-01: Content Model — Standalone `Post` Entity
- **Status:** **`APPROVED BY USER`**
- **Decision:** Create a dedicated table `posts` as a first-class citizen in the relational schema.
- **Rationale:** Clear separation of concerns between trip planning (`Itinerary`) and social communication (`Post`). Supports standalone posts without requiring dummy itineraries, ensures clean lifecycle decoupling, and avoids complex, high-latency `UNION` queries.

### ADR-6B-02: Mobile Community Navigation — Option A (Feed-First with AppBar Action Icons)
- **Status:** **`APPROVED BY USER`**
- **Decision:**
  - Preserve the 5-tab bottom navigation bar.
  - Tab 1 ("Cộng đồng") transitions to `CommunityFeedScreen` as its primary view.
  - Top AppBar houses action shortcuts:
    - `Icons.chat_bubble_outline` $\rightarrow$ opens Messages list (`ChatInboxScreen`).
      - *Navigation Badge Policy:* Chat unread badge is **HIDDEN** in Phase 6B MVP until `GET /api/conversations/unread-total` is delivered in Phase 6B.2 (preventing inaccurate partial counts from local cache).
    - `Icons.people_outline` (with pending badge from existing `totalElements`) $\rightarrow$ opens Friends & Requests (`FriendsScreen`).
- **Rationale:** Gives maximum screen space to community posts while keeping 1-1 chat and friend management 1 tap away. Avoids cramming a 6th bottom tab on small mobile viewports. Existing chat and friends routes remain 100% operational.

---

### ADR-6B-03: Interaction Model — Separation of Post Interactions from Itinerary Interactions
- **Status:** **`APPROVED BY USER`**
- **Decision:** Create dedicated tables `post_likes` and `post_comments`.
- **Rationale:** Preserves distinct domain semantics: Liking a post is an ephemeral social signal; Favoriting an itinerary saves a travel plan. Itinerary comments critique a trip itinerary; Post comments discuss a social post. Eliminates messy polymorphic tables and protects Phase 4, Phase 5, and Phase 6A invariants from regressions.

### ADR-6B-04: Itinerary Attachment — Both Owned and Other Users' Public Itineraries
- **Status:** **`APPROVED BY USER`**
- **Decision:**
  - Authors may attach at most ONE Itinerary to a Post if: `visibility = 'PUBLIC'` AND `status = 'ACTIVE'` AND author account `status = 'ACTIVE'`.
  - Authors are NOT required to own, favorite, or save the itinerary to reference it.
  - **Attribution Rule:** The post card MUST clearly display the **Itinerary Owner** inside the itinerary preview card, keeping it visually and semantically distinct from the **Post Author**.
  - **Privacy Invariant:** Post access and Itinerary access are evaluated independently. If an attached itinerary becomes `PRIVATE`, `HIDDEN`, or `DELETED`, or its owner becomes `INACTIVE` or `BANNED`, the post renders a safe placeholder card ("Lịch trình không còn khả dụng") without leaking any private itinerary metadata (title, budget, duration, activities). The client DTO strictly returns `itinerary = null`, `itineraryUnavailable = true`, `itineraryUnavailableReason = "UNAVAILABLE"`.

---

### ADR-6B-05: Post Comments — Flat Comments Only
- **Status:** **`APPROVED BY USER`**
- **Decision:** MVP strictly supports **first-level flat comments**.
- **Rationale:**
  - No parent-child hierarchy in `post_comments` (zero `parent_comment_id` column).
  - No replies, no nested threads in UI.
  - Keeps the database model, pagination, and mobile UI simple, fast, and robust.

### ADR-6B-06: Visibility — Friendship-based Two-Way `FRIENDS` Access
- **Status:** **`APPROVED BY USER`**
- **Decision:**
  - Post visibility `FRIENDS` is checked strictly against the bidirectional `friendships` table where `status = 'ACCEPTED'`.
  - Unidirectional `Follow` does NOT grant access to `FRIENDS` posts.
  - Following feed includes `PUBLIC` posts from followed users, plus `FRIENDS` posts if mutual friendship exists.
  - Author can always view own posts.

---

## 2. Proposed Technical Designs (Agent Recommendations — Pending User Approval)

The following decisions are proposed technical solutions by the engineering agent to fulfill system requirements, and are clearly distinguished from user approvals:

### ADR-6B-07: Moderation Lifecycle & Soft Delete Invariants
- **Status:** **`PROPOSED (ACCEPTED TECHNICAL DESIGN)`**
- **Proposal:**
  - Post Status Enum: `ACTIVE`, `HIDDEN` (moderated by admin), `DELETED` (deleted by author or admin).
  - Feed queries strictly filter `WHERE status = 'ACTIVE' AND author.status = 'ACTIVE'`.
  - Posts by banned or inactive users are automatically excluded across all feeds.
  - Audit columns (`deleted_at`, `moderated_at`, `moderated_by_id`, `moderation_reason`) added to `posts` table.
  - Soft-delete retains post with `deleted_at`; media assets remain `ATTACHED` to allow restoration. Exact retention duration before hard-purge is registered as an `OPEN QUESTION`.
- **Rationale:** Reuses the proven three-state lifecycle pattern from `itineraries` and `comments`.

### ADR-6B-08: Media Asset Ownership Model (Option B: Association Table `post_media` & Internal `mediaAssetIds`)
- **Status:** **`PROPOSED (ACCEPTED TECHNICAL DESIGN)`**
- **Proposal:**
  - Commit to **Option B (Association Table)** eliminating duplicate relationship fields:
    - Pure media storage catalog `media_assets` (`media_asset_id`, `uploaded_by`, `cloudinary_public_id`, `secure_url`, `media_type`, `status`, `claim_token`, `locked_at`, `locked_by`, `retry_count`, `next_retry_at`, `dead_lettered_at`, `last_error`, `created_at`, `updated_at`) with **ZERO** post references.
    - Association table `post_media` (`post_media_id`, `post_id`, `media_asset_id`, `display_order`, `created_at`) with `CONSTRAINT uk_post_media_asset UNIQUE (media_asset_id)` enforcing `1 asset = 1 post`.
  - Endpoint `POST /api/media/images` returns `mediaAssetId` and `secureUrl`, with inline compensating Cloudinary deletion on database save failure.
  - Post creation endpoint accepts `mediaAssetIds: List<Long>`:
    - Pre-validation: deduplication check and max 5 limit (`400 Bad Request`).
    - Pessimistic write lock: `@Lock(LockModeType.PESSIMISTIC_WRITE)` with sorted list of IDs to reduce deadlock risk; service-level deadlock handling and bounded retry.
    - Non-existent IDs or unowned IDs: return `404 Not Found` (Anti-Enumeration Policy).
    - Already attached or deleting/deleted IDs: return `409 Conflict`.
  - Post Deletion Lifecycle:
    - Soft-delete post: Media remains `ATTACHED` to enable post restoration.
    - Hard purge: Query attached IDs, transition `media_assets` to `DELETING`, delete `post_media` and `posts` rows, commit, then dispatch async Cloudinary deletion.
  - Worker batch-level claim token mechanism (UUID generated per batch, MySQL 8 `SELECT ... FOR UPDATE SKIP LOCKED` and batch update in short transaction, in-memory ID iteration) with stale worker protection and idempotent Cloudinary deletion handling.
  - Error classification and retry policy (idempotent success, transient with exponential backoff, systemic configuration failure with circuit breaker/pause worker, permanent asset data with dead-letter state tracking, max 5 retries, zero magic numbers).
  - Side-effect boundary: Cloudinary deletions execute strictly **AFTER** database transaction commit.
- **Rationale:** Resolves the blocking security vulnerability of arbitrary URL injection and ID tampering. Internal IDs eliminate URL canonicalization flaws, enable B+Tree clustered index lookups ($O(\log n)$), and cleanly decouple CDN storage URLs from domain logic. Eliminates relational duplication between `media_assets` and `post_media`.

### ADR-6B-09: Multi-Query Feed Retrieval Strategy
- **Status:** **`PROPOSED (ACCEPTED TECHNICAL DESIGN)`**
- **Proposal:**
  - Query 1: Paginated `Post` rows + `@ManyToOne` associations (`author`, `itinerary`, `itinerary.user`).
  - Query 2: Batch fetch `PostMedia` for page post IDs.
  - Query 3: Batch fetch `PostLike` for viewer ID.
- **Rationale:** Prevents Hibernate collection pagination in JVM memory (`HHH000104`) and eliminates N+1 query loops.
