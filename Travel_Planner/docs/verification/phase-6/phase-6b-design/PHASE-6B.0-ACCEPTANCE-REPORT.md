# PHASE 6B.0 — ACCEPTANCE REPORT: ARCHITECTURE AUDIT & TECHNICAL DESIGN (SESSION 71 PATCH)

**Project:** Travel Planner  
**Phase:** 6B.0 — Community Feed / Discovery  
**Audit Date:** 2026-11-12  
**Auditor:** Senior Software Architect / AI Technical Lead  
**Branch:** `develop` | **HEAD Commit:** `f997f34`  
**Verdict:** **ACCEPTED WITH LIMITATIONS (DESIGN SPECIFICATION COMPLETE — AWAITING USER AUTHORIZATION FOR PHASE 6B.1)**  
**Git Policy Compliance:** **STRICTLY NO COMMIT, NO PUSH** (100% Compliant)  
**Implementation Policy:** **ZERO SOURCE CODE MODIFICATIONS, ZERO DATABASE MIGRATIONS**

---

## 1. ADR Register & Status Classification

| ADR Reference | Topic | Classification | Summary of Decision |
| :--- | :--- | :---: | :--- |
| **ADR-6B-01** | Content Model | **`APPROVED BY USER`** | Dedicated `posts` table as independent entity. |
| **ADR-6B-02** | Mobile Navigation | **`APPROVED BY USER`** | Option A (Feed-First with AppBar Action Icons). 5 tabs preserved. Chat badge hidden until 6B.2. |
| **ADR-6B-03** | Interaction Model | **`APPROVED BY USER`** | Separate `post_likes` and `post_comments` tables. |
| **ADR-6B-04** | Itinerary Attachment | **`APPROVED BY USER`** | Both owned & other users' public itineraries. Distinct author/owner attribution. Generic `"UNAVAILABLE"` reason code. |
| **ADR-6B-05** | Post Comments | **`APPROVED BY USER`** | Flat comments only (zero `parent_comment_id`). |
| **ADR-6B-06** | FRIENDS Visibility | **`APPROVED BY USER`** | Strictly gated on bidirectional active `Friendship` (`status = ACCEPTED`). |
| **ADR-6B-07** | Moderation Lifecycle | **`PROPOSED (ACCEPTED TECHNICAL DESIGN)`** | Three-state lifecycle (`ACTIVE`, `HIDDEN`, `DELETED`) with audit columns. Retention window duration is `OPEN QUESTION`. |
| **ADR-6B-08** | Media Asset Ownership | **`PROPOSED (ACCEPTED TECHNICAL DESIGN)`** | Option B: Association table `post_media` + internal `mediaAssetIds` validation + `@Lock(PESSIMISTIC_WRITE)` with sorted IDs & retry + compensating delete + MySQL 8 `SKIP LOCKED` batch claim tokens + error classification. |
| **ADR-6B-09** | Query Strategy | **`PROPOSED (ACCEPTED TECHNICAL DESIGN)`** | Multi-query feed retrieval (Option B aligned) preventing JVM memory pagination warnings. |

---

## 2. Architecture Consistency & Verification Checklist

| Verification Item | Design Alignment | Evidence Classification | Status | Notes |
| :--- | :--- | :---: | :---: | :--- |
| **Product Design vs ADRs** | Option A Feed-First navigation and Flat Comments reflected in UX. | `VERIFIED IN SOURCE` | **MATCH** | AppBar shortcuts for Chat/Friends; flat vertical comments list. |
| **ERD vs ADRs** | `post_comments` has NO `parent_comment_id`. `posts.itinerary_id` is nullable. | `PROPOSED` | **MATCH** | Schema strictly enforces flat comments. |
| **API vs Visibility Matrix** | `GET /api/community/posts/{id}` checks `FRIENDS` against bidirectional friendship. | `PROPOSED` | **MATCH** | 403 Forbidden returned if only following without friendship. |
| **Following Feed vs Social Graph** | Following feed includes `PUBLIC` posts from followed creators, and `FRIENDS` posts only if mutual friends. | `PROPOSED` | **MATCH** | Does not confuse 1-way follow with 2-way friendship. |
| **Post Author vs Itinerary Owner** | DTO returns `author` and `itinerary.owner` as distinct objects. | `PROPOSED` | **MATCH** | Eliminates author confusion in UI. |
| **Itinerary Privacy Barrier** | Private or deleted attached itinerary returns `itinerary = null` + `itineraryUnavailableReason = "UNAVAILABLE"`. | `PROPOSED` | **MATCH** | Zero private metadata leaked. Generic reason code prevents probing. |
| **Media Ownership Model** | Table `media_assets` + `post_media` (Option B), `mediaAssetIds` validation. | `PROPOSED (DESIGN)` | **DESIGN GAP ADDRESSED — IMPLEMENTATION PENDING** | Replaces URL whitelisting with internal IDs. Codebase does NOT currently enforce this until 6B.1. |
| **Locking & Deadlock Semantics** | Ascending ID sorting as deadlock mitigation; service-level deadlock catch and retry; JPA `@Lock(PESSIMISTIC_WRITE)`. | `PROPOSED (DESIGN)` | **SPECIFIED (REMEDIATED)** | Acknowledges SQL `IN (:ids)` is unordered; runtime MySQL 8 verification required. |
| **MySQL 8 SKIP LOCKED Claim Flow** | Batch claim via `SELECT ... FOR UPDATE SKIP LOCKED` + batch update inside short transaction (< 50ms), in-memory ID iteration, stale worker protection, idempotent Cloudinary delete. | `PROPOSED (DESIGN)` | **SPECIFIED (SKIP LOCKED)** | Token protects DB update rights; does not recall in-flight HTTP calls. |
| **Attachment / Cleanup Race** | Single-winner transition (`UNATTACHED -> ATTACHED` vs `UNATTACHED -> DELETING`), multi-asset atomicity, 10-scenario race matrix. | `PROPOSED (DESIGN)` | **SPECIFIED (10 SCENARIOS)** | Prohibits `ATTACHED -> DELETING` based on age; rollback on partial failure. |
| **Cloudinary Error Classification** | Idempotent success vs transient vs systemic configuration failure (circuit breaker/pause worker) vs permanent data error. | `PROPOSED (DESIGN)` | **SPECIFIED** | Systemic credential failure does NOT increment asset retry count or cause false dead-lettering. |
| **Post Deletion & Purge Lifecycle** | Soft-delete retains media `ATTACHED`; hard purge transitions media to `DELETING` before cascade; exact retention window is `OPEN QUESTION`. | `PROPOSED (DESIGN)` | **SPECIFIED (WITH OPEN QUESTION)** | Prevents losing photos on soft-delete restoration; purge ordering invariant verified. |
| **Account Status Policy** | `UserStatus` matrix covers `ACTIVE`, `INACTIVE`, and `BANNED`. | `VERIFIED IN SOURCE` / `PROPOSED` | **SPECIFIED (WITH OPEN QUESTION)** | `AuthServiceImpl` blocks `INACTIVE` with 403. Reactivation is registered as an `OPEN QUESTION`. |
| **Database Indexing** | Verified `uk_post_likes` provides composite index; no redundant index created. | `VERIFIED IN DATABASE` | **MATCH** | Prevents wasted storage and slow writes. |
| **Safe Query Strategy** | Multi-Query strategy specified for feed retrieval. | `PROPOSED` | **MATCH** | Avoids Hibernate collection pagination memory warnings. |
| **Navigation Badges Reality** | Friend request count supported; unread conversation endpoint added to Phase 6B.2 roadmap. | `VERIFIED IN SOURCE` / `PROPOSED` | **COMMITTED (Option B)** | Option B chosen: `GET /api/conversations/unread-total` scheduled for 6B.2. Chat badge hidden in MVP. |
| **Phase 6A Invariants** | Flow A (Save Place) and Flow B (Schedule Activity) untouched. | `VERIFIED IN SOURCE` | **PRESERVED** | Zero schema or logic pollution from posts. |
| **Git Policy Compliance** | STRICTLY NO COMMIT, NO PUSH. Zero code modified. | `VERIFIED IN SOURCE` | **PRESERVED** | Working tree 100% intact. |

---

## 3. Synchronized Documentation Suite

All detailed architectural deliverables reside in:
`Travel_Planner/docs/verification/phase-6/phase-6b-design/`
1. [`01-current-architecture-audit.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/01-current-architecture-audit.md)
2. [`02-community-feed-product-design.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/02-community-feed-product-design.md)
3. [`03-community-feed-data-architecture.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/03-community-feed-data-architecture.md)
4. [`04-community-feed-api-design.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/04-community-feed-api-design.md)
5. [`05-feed-query-performance-security.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/05-feed-query-performance-security.md)
6. [`06-phase-6b-implementation-roadmap.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/06-phase-6b-implementation-roadmap.md)
7. [`07-phase-6b-architecture-decision-record.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/07-phase-6b-architecture-decision-record.md)
8. [`PHASE-6B.0-FINAL-DEFECT-REMEDIATION-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/PHASE-6B.0-FINAL-DEFECT-REMEDIATION-REPORT.md)
9. [`PHASE-6B.0-FINAL-ARCHITECTURE-CONSISTENCY-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-CONSISTENCY-REPORT.md)
10. [`PHASE-6B.0-FINAL-ARCHITECTURE-ACCEPTANCE-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-ACCEPTANCE-REPORT.md)
11. [`PHASE-6B.0-SESSION-69-FINAL-LIFECYCLE-PRIVACY-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-69-FINAL-LIFECYCLE-PRIVACY-REPORT.md)
12. [`PHASE-6B.0-SESSION-70-CONCURRENCY-LIFECYCLE-CONSISTENCY-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-70-CONCURRENCY-LIFECYCLE-CONSISTENCY-REPORT.md)
13. [`PHASE-6B.0-SESSION-71-FINAL-TECHNICAL-CLARIFICATION-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-71-FINAL-TECHNICAL-CLARIFICATION-REPORT.md)

---

## 4. Final Recommendation & Readiness

Phase 6B.0 Technical Design, Concurrency and Lifecycle Consistency is **DESIGN SPECIFICATION COMPLETE & CONSISTENT ACROSS SCOPE**. The media architecture is unified under Option B (`post_media`), client payloads use internal `mediaAssetIds`, all 6 user decisions are strictly respected, MySQL 8 `SKIP LOCKED` batch claim semantics and 10-scenario race condition matrix are thoroughly specified, Cloudinary errors and systemic failures are clearly categorized, post restore and hard-purge cascading invariants are formalized, and empirical technical facts are transparently documented.

**Verdict: ACCEPTED WITH LIMITATIONS (Awaiting user review, product resolution on INACTIVE reactivation and Post retention window, and authorization to proceed to Phase 6B.1).**  
**Implementation of Phase 6B.1 is STRICTLY NOT AUTHORIZED until explicit user go-ahead is granted.**
