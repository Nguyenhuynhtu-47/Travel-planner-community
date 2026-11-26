# API và Navigation Contract — đề xuất để review

**Lưu ý:** Các endpoint trong phần “đề xuất mới” chưa tồn tại. Endpoint dưới đây của domain/Admin đang tồn tại trong source và phải được giữ tương thích. Trước implementation, kiểm tra route/DTO thêm một lần.

## API hiện có được tái sử dụng

| Nghiệp vụ | Endpoint hiện hữu trong source | Controller/service |
|---|---|---|
| Chat send/unread/request | POST `/api/conversations/{id}/messages`; GET `/api/conversations/unread-total`; GET `/api/conversations/message-requests`/count/unread-count; accept/decline | `ConversationController` → `MessagingService`/`MessagingServiceImpl` |
| Friendship request | POST `/api/users/{id}/friend-requests`, POST `/api/friend-requests/{id}/accept` | `FriendshipController`/`FriendshipServiceImpl` (confirm mappings in controller) |
| Follow | follow/unfollow public user endpoints | `PublicUserController` → `PublicUserServiceImpl` |
| Social post comments | post comment/reply routes | `CommunityPostController` → `PostServiceImpl` |
| Itinerary/activity comments | `CommentController`, `ActivityCommentController`, `CommentThreadController` | `CommentServiceImpl` |
| Admin post/reports | GET `/api/admin/community/posts[/{id}]`; PATCH `/{id}/moderate`; DELETE `/{id}/purge`; reports GET/resolve | `AdminCommunityController` → `PostServiceImpl` |
| Admin users | GET `/api/admin/users[/{id}]`; PATCH `/{id}/status`, `/{id}/role`; POST `/{id}/sessions/revoke-all` | `AdminUserController` → orchestration/transactional worker |
| Announcements, Center, FCM token | None found | New contract required |

API prefix descriptions above shorten existing full mappings only; integration must compare Controller annotations with `frontend/web/lib/core/constants/api_constants.dart` and actual tests.

## Proposed User Notification API

All endpoints authenticate with current JWT; recipient comes from principal, never request body.

| Method | Candidate path | Request | Response/side effect |
|---|---|---|---|
| GET | `/api/notifications` | `cursor`, `size` bounded, optional `unreadOnly`, optional business `type` filter (the `SYSTEM` filter includes legacy moderation rows) | Cursor page merges own personal rows and globally active announcements, sorted by `(createdAt,id,source)`; opaque source-aware cursor |
| GET | `/api/notifications/unread-count` | none | `count` aggregate; optionally split personal/announcement for diagnostics, but badge uses total only |
| POST | `/api/notifications/{id}/read` | no recipient ID | Idempotent read timestamp for current user; 404/403 behavior chosen to avoid IDOR |
| POST | `/api/notifications/read-all` | none | Mark only own personal notifications through snapshot; announcement receipts remain explicit-open only |
| POST | `/api/announcements/{id}/read` | none | Insert-if-absent receipt for current user and active publication |
| PUT/DELETE | `/api/users/me/devices/fcm-token` (candidate) | register `{token,platform}` / unregister matching token | no token returned; 204/boolean; exact method/path/security approval required |

## Proposed Admin Announcement API

Role `ADMIN` required server-side. Existing API: GET `/api/admin/announcements` (filters/paging), POST create DRAFT, GET `/{id}`, PUT draft update, POST `/{id}/publish`, POST `/{id}/cancel`. Save request is title/body/expiry with no type; response includes the fixed `SYSTEM` group and lifecycle timestamps. No push credentials are returned.

## Deep-link target contract (đã chốt route fallback)

Notification target is a typed allowlist: `POST`, `POST_COMMENT`, `FRIEND_REQUEST`/`USER`, `ITINERARY`, `ACTIVITY`, `ITINERARY_COMMENT`/`ACTIVITY_COMMENT`, `ANNOUNCEMENT`, `ACCOUNT_STATUS` or `REPORT_RESULT` only if user-safe. Never accept arbitrary route string from DB/client.

Existing Mobile destinations located: `PostDetailScreen` and `PostCommentsSheet`; `ItineraryDetailScreen`; `ActivityDetailScreen`; comments features/screens. Current route navigation generally uses `MaterialPageRoute` and model constructors, not a verified named-route/deep-link registry. Exact ability to open a particular comment/reply or initial tab/scroll anchor is **CHƯA XÁC MINH**; inspect constructor data and loaders before promising route. Add `targetId`/commentId/parentId and route resolver in one feature, then reuse for push taps.

Activity notification producers must encode the parent itinerary as `targetType=ITINERARY`, `targetId=parentItineraryId`; activity comments use their parent post or itinerary target. Comment notification producers likewise encode the source post/itinerary, since a bare comment ID is not a safe resolver. Mobile routes only these allowlisted parent targets and destination REST APIs still authorize access. Report notifications without an approved safe destination stay unrouted and show a safe unavailable message. Missing/hidden/forbidden content never returns private target data.

## Current Mobile navigation/badge evidence

`NotificationsScreen` is reached from the existing Home/Explore bell in `explore_screen.dart`. Repeated shortcuts in Profile, Saved Itineraries, CommunityScreen, CommunityFeed, Collection and MyItineraries were removed so one shared `NotificationBellButton` owns badge refresh and navigation. Messaging and friend-request badges remain on their existing Community entry points and are not folded into notification unread count.

`AppSyncBus` already defines `SyncDomain.notifications`, local invalidation and one-minute TTL. Reuse to refresh mounted screens on same app; it is neither remote persistence nor delivery. Notification websocket event, if added, invalidates the domain and prompts REST refetch. Chat badge/unread state remains owned by Messaging.

## Flow and error contract

Center tap: client POST read → resolves typed target → calls existing authorized target API → route; read API idempotent. If network fails, keep unread until confirmed or reconcile server snapshot. Unknown future notification type renders generic safe item. On logout/account switch, clear notifier cache and token association.

Admin publish: validate preview → explicit confirmation → POST publish → server transition commits → async FCM attempt → Admin screen refreshes history. Provider failure appears as delivery status only if that status is part of approved API; it must not mark audience read.

## Phase 1 API implementation — 2026-11-26

The four personal Notification Core endpoints below are implemented in `NotificationController` and require the normal authenticated Spring Security principal:

| Method and path | Contract | Response |
|---|---|---|
| `GET /api/notifications?cursor=&size=20&unreadOnly=false&type=` | Current principal only. `size` is 1–50. Cursor is URL-safe Base64 of `createdAt|notificationId`; ordering is descending by both fields. | `{content, nextCursor, hasMore}`; item has `id,type,actionType,title,body,targetType,targetId,actor,createdAt,readAt`. `actionType` is present for Admin system actions; announcement group type is `SYSTEM`. |
| `GET /api/notifications/unread-count` | Current principal only; message request/unread counts are excluded. | `{count}` |
| `POST /api/notifications/{id}/read` | Marks only an owned row; repeat is idempotent; foreign and missing IDs both return 404. | `204 No Content` |
| `POST /api/notifications/read-all` | Locks the current user row, snapshots the latest owned ID, and marks only current rows through that watermark. | `204 No Content` |

There is deliberately no client-facing notification-create API. Domain services use `NotificationService.create(...)` inside their transaction in future producer phases. Announcement and FCM contracts in this document remain proposals and have not been implemented.

## Phase 2 Mobile route coverage — 2026-11-26

The Mobile resolver opens `USER`, `POST`, `ITINERARY`, and `ANNOUNCEMENT` using existing authorized screens or announcement detail. Activity/comment producers must map to their parent route as defined above. Report stays safely unavailable. The feed merges personal notifications and active announcements with a source-aware cursor; same numeric IDs are disambiguated by the `announcement` response flag and client stable key. Unread count includes personal items and active unread announcements. Read-all changes only personal items.

## Phase 5 Android messaging push — 2026-11-26

| Method/path | Contract | Response |
|---|---|---|
| `PUT /api/users/me/devices/fcm-token` | Authenticated principal owns the submitted Android Firebase Installation ID (FID); JSON `{ "token": "<fid>", "platform": "ANDROID" }`. Re-registering the same FID transfers it to the current account. Server stores the FID only for provider send and maintains a unique SHA-256 hash; no list/read API exposes it. | `204 No Content` |
| `DELETE /api/users/me/devices/fcm-token` | Authenticated principal may unregister only its own FID using the same JSON body. | `204 No Content` |

The after-commit policy revalidates conversation participants/status, account status, current stranger-message eligibility and block state. Push carries generic OS title/body, event type, opaque conversation ID and collapse metadata; never message content. The first visible message of a new pending request is identified as D3; later visible pending messages are generic D2 pushes with the same request collapse key. Opening a push routes to the existing Messaging inbox; REST remains authoritative. `FCM_ENABLED` defaults false. Delivery needs `FIREBASE_PROJECT_ID=travel-planner-54f53`, backend ADC credentials, enabled FCM HTTP v1 and `user_device_tokens` provisioned through the existing database process.

## Admin action history API — 2026-11-26

`GET /api/admin/notification-actions?targetType=&targetId=&page=0&size=20` requires role `ADMIN`. It returns a bounded page (`size` 1–50) of rows from the existing `notifications` table where `action_type` is not null, ordered newest first. Optional target filters narrow the result. The response uses the existing notification DTO, including action type, Admin actor, target and user-facing body. This is a read-only Admin review API; it introduces no second audit/history table and does not replace the existing operational `AuditLog` API. Authorization, filters and persisted result were verified in `NotificationDatabaseIntegrationTest` against `travel_planner_test`.
