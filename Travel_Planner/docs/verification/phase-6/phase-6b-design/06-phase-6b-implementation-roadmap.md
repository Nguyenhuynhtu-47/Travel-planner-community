# PHASE 6B.0 — DELIVERABLE 06: PHASE 6B IMPLEMENTATION ROADMAP (SESSION 71 PATCH)

**Project:** Travel Planner  
**Date:** 2026-11-12  
**Status:** FINAL REVISED ROADMAP SPECIFICATION — DETAILED PHASING & DELIVERABLES  
**Git Policy Compliance:** STRICTLY NO COMMIT, NO PUSH

---

## 1. Sub-Phase Breakdown & Phased Scope

```
Phase 6B.0: Architecture Audit & Technical Design (DESIGN ONLY - COMPLETED)
    │
    ▼
Phase 6B.1: Backend Post Core & Media Asset Ownership
    │   (media_assets, posts, post_media, ownership validation, CRUD APIs)
    │
    ├─────────────────────────────────────────┐
    ▼                                         ▼
Phase 6B.2: Mobile Feed-First Navigation      Phase 6B.5: Admin Moderation
  & Post Creation (AppBar shortcuts for Chat)    & Reporting (Web Admin UI)
    │                                         │
    ▼                                         │
Phase 6B.3: Post Likes & Flat Comments        │
  (No nested threads, atomic counters)        │
    │                                         │
    ▼                                         │
Phase 6B.4: Sharing Itinerary to Community    │
  (Owned/Other public, Author vs Owner)       │
    │                                         │
    └──────────────────┬──────────────────────┘
                       ▼
Phase 6B.6: Integration, Security & Performance Hardening
  (Scheduled media cleanup cron, Cloudinary async deletion, benchmark validation)
```

---

## 2. Detailed Sub-Phase Specifications

### Phase 6B.0 — Architecture Audit & Technical Design (CURRENT PHASE)
- **Status:** COMPLETED — DESIGN REMEDIATION ACCEPTED.
- **Deliverables:** Synchronized architectural documents under `docs/verification/phase-6/phase-6b-design/`.
- **Constraint:** Strictly NO source code changes, NO schema migrations, NO commit/push.

---

### Phase 6B.1 — Backend Post Core & Media Asset Ownership (Option B Aligned)
- **Scope:**
  - Create database tables:
    - `media_assets` (`media_asset_id`, `uploaded_by`, `cloudinary_public_id`, `secure_url`, `media_type`, `status`, `claim_token`, `locked_at`, `locked_by`, `retry_count`, `next_retry_at`, `dead_lettered_at`, `last_error`, `created_at`, `updated_at`).
    - `posts` (`post_id`, `author_id`, `itinerary_id`, `content`, `visibility`, `status`, `like_count`, `comment_count`, audit columns).
    - `post_media` (`post_media_id`, `post_id`, `media_asset_id`, `display_order`, `created_at`) with `CONSTRAINT uk_post_media_asset UNIQUE (media_asset_id)`.
  - Create JPA entities: `MediaAsset`, `Post`, `PostMedia`, enums (`PostVisibility`, `PostStatus`, `MediaAssetStatus`).
  - Implement repositories: `MediaAssetRepository`, `PostRepository`, `PostMediaRepository`.
  - Update `ImageUploadController` to authenticate user and persist `media_assets` with Cloudinary `public_id`, returning `mediaAssetId` and `secureUrl`, with inline compensating Cloudinary deletion if database save fails.
  - Implement `PostService` & `CommunityPostController` with media ownership validation using `mediaAssetIds: List<Long>`:
    - Pre-validation: deduplication check and max 5 limit (`400 Bad Request`).
    - Pessimistic write lock: `@Lock(LockModeType.PESSIMISTIC_WRITE)` with ascending sorted ID list to mitigate deadlock risk, along with service-level deadlock exception handling and bounded retry policy.
    - Non-existent IDs or IDs belonging to other users: return `404 Not Found` (Anti-Enumeration Policy).
    - IDs already `ATTACHED` or in `DELETING`/`DELETED`: return `409 Conflict`.
    - Atomic attachment and rollback guarantee.
  - Implement Multi-Query strategy for feed pagination (Option B `post_media` join).
  - Enforce uniform authorization matrix across all endpoints with 401/403/404 semantics and explicit `INACTIVE` account blocking (`403 Forbidden`).
  - Enforce attached itinerary generic privacy reason code (`"UNAVAILABLE"`) in client DTO.
  - Endpoints: `POST /api/media/images`, `GET /api/community/feed`, `GET /api/community/feed/following`, `POST /api/community/posts`, `GET /api/community/posts/{id}`, `PATCH /api/community/posts/{id}`, `DELETE /api/community/posts/{id}`.
- **Dependencies:** Phase 6B.0 accepted.
- **Acceptance Criteria:** >= 18 JUnit tests PASS covering Media ownership validation, Post CRUD, visibility rules, soft deletes, and multi-query feed pagination.

---

### Phase 6B.2 — Mobile Feed-First Navigation & Post Creation (ADR-6B-02)
- **Scope:**
  - Restructure Tab 1 of bottom navigation shell:
    - Primary view: `CommunityFeedScreen` rendering post cards.
    - Top AppBar: Title "Cộng đồng du lịch" + Action shortcut `Tin nhắn` (`Icons.chat_bubble_outline`) + Action shortcut `Bạn bè` (`Icons.people_outline`).
    - Backend: Implement `GET /api/conversations/unread-total` returning `{"totalUnread": count}` based on `SUM(unread_count)` from `conversation_members`.
    - Mobile Navigation Badge Policy:
      - Friend requests badge: Connected to existing `GET /api/users/me/friend-requests?direction=received`.
      - Chat unread badge: HIDE badge in MVP until `GET /api/conversations/unread-total` is delivered (do NOT use partial cache or page 0 counts). Once endpoint is delivered, connect numerical badge.
    - Preserves existing `ChatScreen` and `FriendsScreen` routes.
  - Implement `PostCardWidget` supporting text, author header, relative time, and dynamic 1..5 photo grid.
  - Implement `CreatePostScreen` with image picker, authenticated Cloudinary upload, and submission using internal `mediaAssetIds`.
- **Dependencies:** Phase 6B.1 verified.
- **Acceptance Criteria:** >= 14 Flutter widget tests PASS; 0 regressions on existing chat/friend navigation.

---

### Phase 6B.3 — Post Likes & Flat Comments (ADR-6B-03 & ADR-6B-05)
- **Scope:**
  - Backend: Create tables `post_likes`, `post_comments`.
  - Schema rule: `post_comments` is strictly flat (zero `parent_comment_id`).
  - Endpoints: Like/Unlike toggle; Comment list, add, edit, soft delete.
  - Concurrency: Atomic increment/decrement on `posts.like_count` and `comment_count`.
  - Mobile: Like button with optimistic UI; flat comments bottom sheet / screen (no reply button).
- **Dependencies:** Phase 6B.1 and 6B.2 complete.

---

### Phase 6B.4 — Sharing Itinerary to Community (ADR-6B-04)
- **Scope:**
  - Support attaching owned or other users' active public itineraries.
  - UI Card renders: Itinerary title, cover, duration, budget, and clearly displays **Itinerary Owner** distinctly from **Post Author**.
  - Fail-safe privacy fallback card if referenced itinerary becomes private or deleted.
- **Dependencies:** Phase 6B.1, 6B.2, and existing Phase 6A components.

---

### Phase 6B.5 — Admin Moderation & Reporting
- **Scope:**
  - Backend: Create table `post_reports`. Implement report submission and admin resolution endpoints.
  - Web Admin: Implement `AdminReportsScreen` in `frontend/web/lib/features/moderation/` allowing administrators to review reported posts and hide/restore content.
  - Mobile: "Báo cáo bài viết" action dialog.
- **Dependencies:** Phase 6B.1.

---

### Phase 6B.6 — Integration, Security & Performance Hardening
- **Scope:**
  - Scheduled background cron job for cleaning up unattached media assets older than 24h and purged post media (`@Scheduled`), with short claim transactions using MySQL 8 `SELECT ... FOR UPDATE SKIP LOCKED` followed by batch claim update, batch-level UUID `claim_token`, in-memory ID iteration, worker lease claims (`locked_at`, `locked_by`), and stale worker protection.
  - Hard-purge of expired soft-deleted posts based on retention policy (exact retention duration pending Product Owner confirmation under Open Question).
  - Asynchronous Cloudinary remote deletion executed strictly **AFTER** database transaction commit (`TransactionSynchronizationManager`).
  - Idempotent Cloudinary deletion handling (result "ok" or "not found" both transition to `DELETED`).
  - Exponential backoff retry policy, error classification (idempotent, transient, service unavailable, systemic configuration failure with circuit breaker/pause worker, permanent asset data), and dead-letter state tracking (`dead_lettered_at`, max 5 retries, zero magic numbers).
  - Administrative dead-letter recovery endpoint / CLI script (`POST /api/admin/media-assets/{id}/retry`).
  - Scheduled weekly remote Cloudinary folder reconciliation script for orphaned remote files.
  - Compound database index application (`idx_media_assets_cleanup`, etc.) and EXPLAIN query plan validation.
  - Full regression test run: Backend (453+ PASS), Mobile (413+ PASS), Web (33+ PASS).
  - Final documentation and Phase 6B formal closure.
