# PHASE 6B.0 — DELIVERABLE 02: COMMUNITY FEED PRODUCT DESIGN (REMEDIATED)

**Project:** Travel Planner  
**Date:** 2026-11-12  
**Status:** REMEDIATED SPECIFICATION — USER-APPROVED DECISIONS & VERIFIED ARCHITECTURE  
**Git Policy Compliance:** STRICTLY NO COMMIT, NO PUSH

---

## 1. Product Scope & Core Principles

### 1.1. Business Purpose
Community Feed provides a spontaneous, real-time social space for travelers to share micro-stories, photo moments, travel questions, and trip reflections, while maintaining seamless discovery of full travel itineraries.

### 1.2. The Distinction: Explore vs Community Feed

| Dimension | **Explore (Khám phá)** | **Community Feed (Bảng tin Cộng đồng)** |
| :--- | :--- | :--- |
| **Core Entity** | `Itinerary` (Lịch trình du lịch) | `Post` (Bài viết xã hội của người dùng) |
| **User Mindset** | "Tôi muốn tìm một kế hoạch chi tiết để đi du lịch." | "Tôi muốn xem mọi người đang chia sẻ điều gì hôm nay." |
| **Content Nature** | Structured, chronological days, activity budgets, waypoints, route map. | Micro-blog, photo story, review, tips, itinerary showcase. |
| **Discovery Method** | Multi-criteria filters (theme, budget, duration, rating, location search). | Reverse-chronological timeline, following stream. |
| **Lifespan** | Long-term reference (evergreen travel guides). | Real-time social engagement (active discussion for hours/days). |
| **Creation Effort** | High (5–30 minutes to plan days and activities). | Low (30 seconds to write a post, attach 1–5 photos). |

> [!IMPORTANT]
> **Product Principle:** Explore must NOT be converted into a mixed social feed. Injecting short-form status posts into Explore would dilute the utility of itinerary search, break filter logic, and confuse users seeking trip planning templates. Explore remains dedicated to Itineraries; Community Feed is dedicated to User Posts.

---

## 2. Mobile Navigation Architecture: Feed-First (ADR-6B-02)

### 2.1. Approved Structure (Option A)
- **Bottom Navigation Shell:** 5 destinations strictly preserved (`Explore`, `Community`, `Create`, `Collection`, `Profile`). No 6th tab added.
- **Tab 1 ("Cộng đồng"):**
  - **Primary Body:** `CommunityFeedScreen` rendering the reverse-chronological post stream and a quick create-post entry point.
  - **Top AppBar Actions:**
    - Action 1: **Tin nhắn** (`Icons.chat_bubble_outline`) $\rightarrow$ opens `ChatInboxScreen` (`_inbox()` from `community_screen.dart`).
    - Action 2: **Bạn bè & Lời mời** (`Icons.people_outline`) $\rightarrow$ opens `FriendsScreen` (`_friendsTab()` and `_requests()`).
  - *Route Preservation:* Existing screens and navigation flows for Chat and Friends remain 100% intact (`VERIFIED IN SOURCE`).

### 2.2. Navigation Badge Implementation Reality
- **Friend Requests Badge:**
  - *Backend Support:* `GET /api/users/me/friend-requests?direction=received` returns `PageResponse.totalElements` (`VERIFIED IN SOURCE`).
  - *Status:* Supported for rendering a numerical badge.
- **Unread Messages Badge:**
  - *Backend Support:* `ConversationSummaryResponse` has per-conversation `unreadCount`, but **NO global aggregate endpoint** exists (`VERIFIED IN SOURCE`).
  - *Remediation Plan:*
    - Phase 6B.2 introduces `GET /api/conversations/unread-total` (`PROPOSED`).
    - In the interim prior to Phase 6B.2, the unread chat badge is **HIDDEN** on the Chat icon to prevent displaying misleading partial counts from local cache or page 0. Once `GET /api/conversations/unread-total` is delivered in Phase 6B.2, the numerical badge will be enabled cleanly.

---

## 3. Post Content Types & Itinerary Attachment (ADR-6B-04)

### 3.1. MVP Content Scope
1. **Standalone Travel Post:** Text content (1..2000 chars) + 0 to 5 photos uploaded via Cloudinary.
2. **Itinerary-Linked Post:** Text content + 0 to 5 photos + **at most ONE referenced Itinerary**.

### 3.2. Attachment Policy: Owned & Other Users' Public Itineraries
- **User-Approved Rule:** Authors can attach an Itinerary if:
  - `itinerary.visibility == 'PUBLIC'` (`VERIFIED IN SOURCE`)
  - `itinerary.status == 'ACTIVE'` (`VERIFIED IN SOURCE`)
  - Creator account `status == 'ACTIVE'` (`VERIFIED IN SOURCE`)
- **No Ownership Requirement:** The user is NOT required to own, favorite, or save the itinerary.
- **Role Attribution Invariant:**
  - Post Author displayed at top of card (Avatar, `@handle`, `full_name`).
  - Itinerary Owner displayed distinctly inside the embedded Itinerary card (e.g., *"Tác giả lịch trình: @hiker_duy"*). Readers will never confuse the post author with the itinerary creator.

### 3.3. Itinerary & Account Lifecycle Impact Matrix

| Lifecycle Event on Referenced Itinerary | Feed Behavior | Post Detail Behavior | Linked DTO Behavior | Post Visibility | Reappearance Upon Restoration |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **Itinerary becomes `PRIVATE`** | Post rendered; card replaced with fallback | Post rendered; card replaced with fallback | `itinerary = null`<br>`reason = "PRIVATE_OR_UNAVAILABLE"` | Visible | **Yes** (Card reappears if owner switches back to `PUBLIC`) |
| **Itinerary soft-deleted (`status = 'DELETED'`)** | Post rendered; card replaced with fallback | Post rendered; card replaced with fallback | `itinerary = null`<br>`reason = "DELETED_OR_UNAVAILABLE"` | Visible | **Yes** (Card reappears if admin restores to `ACTIVE`) |
| **Itinerary hidden (`status = 'HIDDEN'`)** | Post rendered; card replaced with fallback | Post rendered; card replaced with fallback | `itinerary = null`<br>`reason = "MODERATED_OR_UNAVAILABLE"` | Visible | **Yes** (Card reappears if unhidden by admin) |
| **Itinerary Owner banned (`User.status = 'BANNED'`)** | Post rendered; card replaced with fallback | Post rendered; card replaced with fallback | `itinerary = null`<br>`reason = "CREATOR_UNAVAILABLE"` | Visible | **Yes** (Card reappears if owner account unbanned) |
| **Post Author banned (`User.status = 'BANNED'`)** | **Post completely excluded from feed** | **404 Not Found** | Excluded | **Hidden** | **Yes** (Post re-emerges if author account unbanned) |

> [!IMPORTANT]
> **Privacy Invariant:** Under NO circumstances will an attached itinerary in `PRIVATE`, `DELETED`, or `HIDDEN` state leak its title, budget, duration, activities, or cover image. The API dynamically suppresses all fields.

---

## 4. Post Comments Design: Flat Comments (ADR-6B-05)

- **User-Approved Decision:** Strictly first-level flat comments.
- **Explicit Exclusions:** NO replies, NO nested threads, NO parent comment hierarchy.
- **UI:** Clean chronological vertical comment list under the post with a bottom text field.

---

## 5. Feed Visibility & Access Control Matrix (ADR-6B-06)

| Post Visibility | Viewer Status | Can View in Feed? | Can Open Post Detail? | Can Like / Comment? |
| :--- | :--- | :---: | :---: | :---: |
| **`PUBLIC`** | Guest (Unauthenticated) | ✅ Yes | ✅ Yes | ❌ (Must login) |
| **`PUBLIC`** | Authenticated User | ✅ Yes | ✅ Yes | ✅ Yes |
| **`FRIENDS`** | Author | ✅ Yes | ✅ Yes | ✅ Yes |
| **`FRIENDS`** | Mutual Friend (`friendships.status = ACCEPTED`) | ✅ Yes | ✅ Yes | ✅ Yes |
| **`FRIENDS`** | Follower Only (No mutual Friendship) | ❌ No | ❌ Forbidden (403) | ❌ Forbidden |
| **`FRIENDS`** | Unrelated User / Guest | ❌ No | ❌ Forbidden (403) | ❌ Forbidden |
| **`PRIVATE`** | Author | ✅ Yes | ✅ Yes | ✅ Yes |
| **`PRIVATE`** | Any other user | ❌ No | ❌ Forbidden (403) | ❌ Forbidden |
| **Any Post** | Author Account `BANNED` | ❌ Excluded | ❌ Not Found (404) | ❌ Excluded |
| **Any Post** | Post `status = HIDDEN` or `DELETED` | ❌ Excluded | ❌ Not Found (404) | ❌ Excluded |
