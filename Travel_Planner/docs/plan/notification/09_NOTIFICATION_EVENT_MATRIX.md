# Notification Event Matrix

**Source-state labels:** “Center” = personal `notifications` row; “Announcement” = one shared row plus read receipt; “Push-only” = FCM without Center row.

**Implementation status (2026-11-26):** C1–C8 Center producers are implemented and focused backend-tested. C4 uses the owner-approved UTC-day grouping/unlike rules. Phase 5 Android FCM token and D1–D3 dispatch policy are implemented; credential/schema/device acceptance remain pending. Existing Admin actions now create `SYSTEM` records with concrete action types. No account/post warning endpoint exists.

| ID | Verified source candidate / transition | Recipient | Center or Push | Center badge | Group | Deep link destination | Skip / idempotency |
|---|---|---|---|---|---|---|---|
| C1 | `FriendshipServiceImpl.sendRequest` new pending friendship | Request target | Center + optional FCM | Yes | No | Friends/request or profile | Ignore self, duplicate existing pending, blocked/inactive; friendship transition key |
| C2 | `FriendshipServiceImpl.accept` PENDING→ACCEPTED | Original requester | Center + optional FCM | Yes | No | Friends/profile | Only actual accept; do not notify accepter; transition key |
| C3 | `PublicUserServiceImpl.follow` new Follow row | Followed account | Center + optional FCM | Yes | No | Follower profile/follow list | No self; only insert transition; DB pair uniqueness |
| C4 | `PostServiceImpl.likePost` new `PostLike` | Post author | Center + optional FCM | Yes | Yes, UTC-day unread group | Post | No self/duplicate; unlike before read removes actor; unlike after read preserves history; see 10 |
| C5 | `PostServiceImpl.addComment` root post comment | Post author | Center + optional FCM | Yes | No | Post + comment ID | No self; actual saved active comment; unique by comment ID |
| C6 | Post reply creation in `PostServiceImpl` | Exact author of parent `PostComment` | Center + optional FCM | Yes | No | Post + reply ID | No self; parent author only, not all thread users; unique by reply ID |
| C7 | `CommentServiceImpl.createComment/createActivityComment` itinerary/activity root | Itinerary owner | Center + optional FCM | Yes | No | Itinerary or Activity/comment | No self; visible target and block policy; unique by comment ID |
| C8 | `CommentServiceImpl.createReply` | Exact parent `Comment` author | Center + optional FCM | Yes | No | Itinerary/activity + reply ID | No self; parent writer only; unique by reply ID |
| A | Admin publishes a shared announcement | Eligible active accounts | Shared Announcement + optional FCM | Yes until read/expired | One shared content row; fixed `SYSTEM` group | Notification Center announcement | Only successful DRAFT→PUBLISHED; dedup publish transition; announcement subtype/category is not modeled |
| D1 | `MessagingServiceImpl.send`, accepted thread | Other participant, if message recipient-visible | Push-only | No | Collapse per conversation candidate | Inbox/chat → authorized REST | No self, block/inactive/invisible excluded; no Center write |
| D2 | Send visible message to pending stranger under EVERYONE | Request recipient | Push-only | No | Collapse/coalesce candidate | Stranger Inbox/chat | No hidden/declined/block; no Center write |
| D3 | New eligible pending request transition | Request recipient | Push-only once per request transition | No | Initial request then collapse | Stranger Inbox/request detail | Subsequent messages are not new request; no Center write |
| Hidden stranger message | FRIENDS_ONLY sender-only path | Recipient gets none | No recipient Push; no Center | No | — | Sender remains in existing chat | Never leak that hidden message exists to recipient |
| F1 | `PostServiceImpl.moderatePost` transition to HIDDEN/DELETED/ACTIVE | Post author | `SYSTEM` Center | Yes | No | Post if still accessible | `POST_HIDDEN`, `POST_REMOVED`, `POST_RESTORED`; only a real state change; moderation reason is public copy |
| F2 | Explicit warning action on post | Post author | Not available | No | No | — | No warning endpoint/model exists; do not infer this from hide/remove |
| F4 | Explicit account-warning action | Account owner | Not available | No | No | — | No warning endpoint/model exists |
| F5 | `AdminUserTransactionalWorker` status ACTIVE→BANNED | Affected user | `SYSTEM` Center | Yes | No | Own account | `ACCOUNT_SUSPENDED`; actor and public status reason retained |
| F6 | `AdminUserTransactionalWorker` status BANNED→ACTIVE | Affected user | `SYSTEM` Center | Yes | No | Own account | `ACCOUNT_RESTORED`; only actual restoration |
| F7 | `PostServiceImpl.resolveReport` PENDING→RESOLVED/DISMISSED | Reporter | `SYSTEM` Center | Yes | No | Safe fallback; report detail route is not supported | `REPORT_RESOLVED`/`REPORT_DISMISSED`; pessimistic row lock and neutral copy |
| — | Admin role update | Affected user | `SYSTEM` Center | Yes | No | Own account | `ACCOUNT_ROLE_CHANGED`; only actual role change |
| — | Admin session revoke with one or more active sessions | Affected user | `SYSTEM` Center | Yes | No | Own account after sign-in | `ACCOUNT_SESSIONS_REVOKED`; no internal audit reason in user copy |
| — | Admin hard purge of a post | Post author | `SYSTEM` Center | Yes | No | Post may no longer exist | `POST_PURGED`; notification persists transactionally with purge |

## Read/recipient invariants

- `C6/C8` recipient must be the writer of the exact parent being replied to, including nested reply; not all participants and not necessarily root author.
- C7 target has `Activity` but owner is itinerary's user; check CommentService visibility/block checks on implementation.
- Admin action notifications are user-facing rows in the same `notifications` table; existing immutable/admin-only `AuditLog` remains the operator audit source.
- A content is one shared announcement; user receipt is separate. Notification badge counts active unread personal Center rows + active unread announcements only.
- D1/D2/D3 are never stored in Center and do not affect Center badge, request count or current Messaging unread contract.
- Target resolution always re-checks current authorization, deletion, visibility and block.
