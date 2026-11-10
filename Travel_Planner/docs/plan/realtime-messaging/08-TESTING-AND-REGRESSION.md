# 08 — Test matrix và nghiệm thu

## Backend

| Area | Type | Cases | Assertions |
|---|---|---|---|
| Friendship service | Unit | self, duplicate, already friend, reverse pending, reject/retry, cancel, unfriend | correct state/no duplicate/no Follow mutation |
| Friendship persistence | MySQL integration | simultaneous opposite requests, concurrent accept/cancel, unique pair | one canonical row, one final state, no uncaught duplicate |
| Settings/block | Unit + controller | own-only GET/PUT, invalid enum, inactive actor, either-direction block | 401/403/400, generic denial, no settings leak |
| Conversation API | MVC/service | create/reopen, self-chat, target inactive, permission matrix, nonmember ID | one pair, owner principal, no IDOR |
| Messages | service/repository | empty/too long, forged sender, blocked, no friendship, NOBODY | reject before persist |
| Idempotency | MySQL integration | same clientMessageId serial/concurrent and timeout retry | one row, same persisted response |
| Pagination | repository integration | beforeSequence cursor, same timestamp, concurrent sends serialized per conversation; sequence follows commit order, rollback leaves no allocated sequence, insertion between pages | deterministic sequence cursor, no skip/dup |
| Read state | service/integration | cross-conversation cursor, backward cursor, other member | reject or monotonic max; unread correct |
| WebSocket auth | integration | CONNECT missing/invalid/expired JWT, active/inactive/banned | reject connect, principal maps correct internal user |
| WebSocket authorization | integration | allowed user queue, arbitrary topic/queue, forged user destination | deny client publish/subscription; no cross-account event |
| Transaction delivery | integration | successful commit, rollback, concurrent sends serialized per conversation; sequence follows commit order; rollback leaves no allocated sequence | only committed message event sent; event after row exists |
| Security | MVC/integration | guest/private/member boundaries, generic errors | no private DTO/body/token leak |
| Load controls | test/manual | rate limit, size, too many sockets, heartbeat timeout | bounded resource use and correct throttling |
| Regression | existing tests | PublicUserServiceTest, AuthControllerTest, JwtTokenProviderTest, community/profile/comment suites | Follow/profile/comment/JWT behavior preserved |

Mock-only concurrency tests are insufficient to prove MySQL unique/locking behavior. Use a disposable MySQL database matching production dialect or approved integration container; never the developer's valuable DB.

## Flutter Mobile

| Area | Type | Cases |
|---|---|---|
| Models | unit | serialization/nulls/timezone/cursor/event envelope |
| MessagingRepository | unit with mock ApiClient | URLs/query/body/token/errors/idempotency key |
| Notifiers | unit | send optimistic → success/fail, retry same key, incoming event before REST response, dedupe, out-of-order sort, paging |
| Realtime client | unit/fake socket | CONNECT headers, reconnect backoff, heartbeat config, connection state, unsubscribe/dispose |
| Auth lifecycle | widget/unit | login opens one socket; logout/401/account switch closes socket and clears private cache; token expires during socket |
| Conversation list/chat | widget | unread badge, loading/empty/error/retry, message own/peer, timestamp, older paging, keyboard composer |
| Friendship/settings | widget | incoming/sent requests, accept/decline/cancel/unfriend, all privacy modes, blocked state |
| Public profile route | widget | guest, own profile, friend, pending request, canMessage false, open/reuse conversation, Follow unchanged |
| Lifecycle | integration/manual | foreground realtime; background interruption; resume sync; airplane/network reconnect |
| Regression | existing widget | public_profile_screen_test.dart, bottom_navigation_test.dart, auth_401_test.dart, social_ui_sync_test.dart, app smoke |

No optimistic UI may claim sent before server response. Duplicate event/response merge must preserve single row.

## Flutter Web

MVP: run existing Web flutter analyze, flutter test, build/regression; no messaging screen yet. Future Web-chat phase needs tests for STOMP CONNECT header behavior in browser, origin/CORS, refresh/logout/tab visibility, keyboard navigation and responsive design. WebSocket package metadata saying browser support is not itself a passing integration test.

## Manual end-to-end

Two test users on two devices/emulators:
1. A opens B public profile from itinerary, sends request.
2. B accepts; A sees accepted state.
3. A opens chat; B online receives event; B replies.
4. Compare DB-backed REST history after app reload and reconnect; verify dedupe.
5. Toggle each privacy mode; test existing conversation send rules.
6. Block either direction; verify send/request denial and no event.
7. Disconnect network before send; retry; prove one row.
8. Logout A and login C on same device; C never sees A's conversations or socket events.
9. Force close app, then reopen; history syncs; do not expect socket push while closed.
10. Follow/unfollow, profile, comments, itinerary, and 5 bottom tabs remain intact.

## Commands (future implementation only)

From backend: .\mvnw.cmd test and targeted integration/profile/security tests. From mobile and web separately: flutter analyze, flutter test, dart format --output=none --set-exit-if-changed ., then applicable build. This plan phase has not run these commands.


