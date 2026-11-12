# PHASE 6B.0 — FINAL DEFECT REMEDIATION REPORT
## Resolution of Remaining Architecture and Security Gaps

**Project:** Travel Planner  
**Date:** 2026-11-12  
**Auditor:** Senior Software Architect / AI Technical Lead  
**Branch:** `develop` | **HEAD Commit:** `f997f34`  
**Git Policy Compliance:** **STRICTLY NO COMMIT, NO PUSH** (100% Compliant)  
**Implementation Policy:** **ZERO SOURCE CODE MODIFICATIONS, ZERO DATABASE MIGRATIONS**

---

## 1. Executive Summary & Remediation Objectives

This report documents the targeted remediation of technical gaps and architectural defects identified during the acceptance review of Phase 6B.0:
1. **Resolution of Blocking Media Ownership Defect:** Elimination of URL whitelisting in favor of an authoritative `media_assets` ownership model.
2. **ADR Status Register Correction:** Strict reclassification distinguishing 6 user-approved decisions from 3 proposed engineering recommendations.
3. **Itinerary & Account Lifecycle Invariants:** Exhaustive specification of the 5 lifecycle cases for referenced itineraries and banned accounts.
4. **Query Strategy & Pagination Hardening:** Detailed specification of the Multi-Query strategy (Queries 1, 2, and 3) avoiding JVM memory pagination warnings and duplicate rows.
5. **Navigation Badge Capabilities Audit:** Verified empirical facts regarding chat unread count and pending friend requests.

---

## 2. Evidence-Based Verification of Remediated Items

### 2.1. Cloudinary Media Ownership Remediation
- **Verified Fact in Source:**
  - `ImageUploadController.java` lines 23–27: Endpoint `POST /api/media/images` accepts `MultipartFile`, returns `ImageUploadResponse(secureUrl)`, but passes zero user identity to `ImageUploadService`. (`VERIFIED IN SOURCE`)
  - `SecurityConfig.java` line 98: `/api/media/images` requires JWT authentication. (`VERIFIED IN SOURCE`)
  - Database schema: Zero media tables exist in MySQL `travel_planner`. (`VERIFIED IN DATABASE`)
- **Remediation Specification (ADR-6B-08):**
  - **Selected Design:** Persistent `media_assets` Table (`media_asset_id`, `uploaded_by`, `cloudinary_public_id`, `secure_url`, `media_type`, `status`, `created_at`, `attached_at`, `post_id`).
  - **Ownership Invariant:** Post creation strictly queries `media_assets` where `secure_url IN (:urls) AND uploaded_by = :currentUserId AND status = 'UNATTACHED'`. Rejects unowned or already-attached images with `403 Forbidden`.
  - **Lifecycle Management:** Unattached media assets older than 24 hours are cleaned up via a daily scheduled batch job dispatching asynchronous Cloudinary deletions.
  - **Phased Implementation:** Table creation, upload tracking, and post creation validation are assigned to **Phase 6B.1**. Background cleanup cron and async Cloudinary reconciliation are scheduled for **Phase 6B.6**.

### 2.2. ADR Status Register Correction
- **User-Approved Decisions (`APPROVED BY USER`):**
  1. `ADR-6B-01`: Content Model — Standalone `Post` Entity.
  2. `ADR-6B-02`: Mobile Community Navigation — Option A (Feed-First with AppBar Action Icons).
  3. `ADR-6B-03`: Interaction Model — Separation of Post Interactions from Itinerary Interactions.
  4. `ADR-6B-04`: Itinerary Attachment — Both Owned and Other Users' Public Itineraries.
  5. `ADR-6B-05`: Post Comments — Flat Comments Only (zero `parent_comment_id`).
  6. `ADR-6B-06`: Visibility — Friendship-based Two-Way `FRIENDS` Access.
- **Proposed Technical Designs (`PROPOSED (ACCEPTED TECHNICAL DESIGN)`):**
  7. `ADR-6B-07`: Moderation Lifecycle & Soft Delete Invariants (Agent recommendation).
  8. `ADR-6B-08`: Media Asset Ownership Model (Design A: Persistent `media_assets` Table).
  9. `ADR-6B-09`: Multi-Query Feed Retrieval Strategy.

### 2.3. Itinerary and Account Lifecycle Specifications
- **Verified Enums in Source:**
  - `ItineraryStatus`: `ACTIVE`, `HIDDEN`, `DELETED` (`ItineraryStatus.java` lines 3–7). (`VERIFIED IN SOURCE`)
  - `Visibility`: `PUBLIC`, `PRIVATE` (`Visibility.java` lines 3–6). (`VERIFIED IN SOURCE`)
  - `UserStatus`: `ACTIVE`, `INACTIVE`, `BANNED` (`UserStatus.java` lines 3–7). (`VERIFIED IN SOURCE`)
- **Lifecycle Matrix:**
  1. *Itinerary becomes `PRIVATE`:* Post remains visible. Embedded card replaced with fallback: *"Lịch trình đính kèm ở chế độ riêng tư hoặc không khả dụng"*. DTO sets `itinerary = null`, `reason = "PRIVATE_OR_UNAVAILABLE"`. Dynamic query ensures card automatically reappears if switched back to `PUBLIC`.
  2. *Itinerary soft-deleted (`status = 'DELETED'`):* Post remains visible. Embedded card replaced with fallback. Card reappears if restored by admin.
  3. *Itinerary hidden (`status = 'HIDDEN'`):* Post remains visible. Embedded card replaced with fallback. Card reappears if unhidden by admin.
  4. *Itinerary Owner banned (`User.status = 'BANNED'`):* Post remains visible. Embedded card replaced with fallback. Card reappears if owner unbanned.
  5. *Post Author banned (`User.status = 'BANNED'`):* Post is completely excluded from all feeds (`WHERE p.author.status = 'ACTIVE'`). Direct URL access returns `404 Not Found`.

### 2.4. Multi-Query Feed Strategy Clarification
- **Design Decision & Expected Benefits:**
  - *Query 1:* Fetches paginated `Post` rows + `@ManyToOne` associations (`author`, `itinerary`, `itinerary.user`). Single-valued joins do not duplicate rows; native SQL `LIMIT/OFFSET` executes safely without Hibernate `HHH000104` in-memory collection warnings.
  - *Query 2:* Batch fetches `PostMedia` by page post IDs (`WHERE post_id IN (:pagePostIds)`). Posts with zero photos are handled gracefully (empty list `[]`).
  - *Query 3:* Batch fetches viewer-specific like status: `SELECT l.post.postId FROM PostLike l WHERE l.post.postId IN (:pagePostIds) AND l.user.userId = :viewerId`.
  - *Counters:* Denormalized `like_count` and `comment_count` on `posts` table are retrieved directly in Query 1 with zero N+1 queries.
- **Classification:** `PROPOSED (ACCEPTED TECHNICAL DESIGN)`. Benchmarks under load will be validated in Phase 6B.6.

### 2.5. Navigation Badges Reality
- **Friend Requests Badge:** `GET /api/users/me/friend-requests?direction=received` provides `totalElements` (`VERIFIED IN SOURCE`). Supported.
- **Unread Messages Badge:** `ConversationSummaryResponse` has per-conversation `unreadCount`, but **NO global aggregate endpoint** exists (`VERIFIED IN SOURCE`).
- **Remediation:** Mobile client will display an unread presence dot indicator on the chat icon, with a lightweight endpoint `GET /api/conversations/unread-total` scheduled for addition in Phase 6B.2.

---

## 3. Consistency Matrix

| Item | Product Design | Data Architecture | API Design | ADR Register | Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Media Ownership** | Reflected | `media_assets` defined | `POST /api/media/images` updated | ADR-6B-08 | ✅ CONSISTENT |
| **Flat Comments** | Reflected | No `parent_comment_id` | Flat DTO list | ADR-6B-05 | ✅ CONSISTENT |
| **Itinerary Attachment** | Reflected | Author vs Owner separated | Dynamic fallback | ADR-6B-04 | ✅ CONSISTENT |
| **Feed-First Nav** | Reflected | Preserves 5 tabs | N/A | ADR-6B-02 | ✅ CONSISTENT |
| **Two-Way Friends** | Reflected | Uses `friendships` | Checked in `/feed/following` | ADR-6B-06 | ✅ CONSISTENT |

---

## 4. Phase 6B.1 Readiness & Final Verdict

### Status Assessment
All architectural and security gaps identified during review have been thoroughly addressed. The media ownership model is completely specified, ADR statuses are accurately represented, lifecycle behaviors are exhaustively cataloged, and empirical technical gaps (such as the unread chat badge) are documented without false claims.

### Final Verdict

# ✅ **ACCEPTED WITH LIMITATIONS**

> **Limitations for Authorization:**
> 1. Implementation of Phase 6B.1 requires creating the `media_assets` table alongside `posts` and `post_media` to enforce media ownership.
> 2. Mobile chat unread count will use a presence indicator until `GET /api/conversations/unread-total` is added in Phase 6B.2.
>
> **Strict Stop Condition:**  
> Phase 6B.0 design remediation is **COMPLETE**. Implementation of Phase 6B.1 is **STRICTLY NOT AUTHORIZED** until explicit user approval is granted.

