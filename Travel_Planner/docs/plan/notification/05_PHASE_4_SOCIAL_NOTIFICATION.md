# Phase 4 — Social Notifications C1–C8

**Trạng thái:** C1–C8 đã triển khai và focused-tested. C4 dùng gom theo ngày UTC; unlike trước đọc gỡ actor khỏi nhóm unread, unlike sau đọc giữ lịch sử. FCM deferred sang Phase 5.

## 1. Mục tiêu
Thông báo đúng recipient khi friendship, follow, like, post comment/reply và itinerary/activity comment/reply đổi thành công.

## 2. Phạm vi
C1–C8, Center records, optional FCM after-commit, deep-link metadata and tests. Notification type/target contract from Phase 1/13.

## 3. Những chức năng sẽ thực hiện
C1 request; C2 acceptance; C3 follow; C4 grouped post like; C5 post root comment; C6 post reply; C7 itinerary/activity root comment; C8 reply. Một comment/reply là một event; actor khác chủ nội dung không bị gộp với comment.

## 4. Những chức năng không được thay đổi
Không đổi friendship state, follow semantics, like count, comment trees, permissions, delete/hidden moderation hoặc API comment hiện tại. Không broadcast tới tất cả người trong thread.

## 5. Phân tích trạng thái code hiện tại
`FriendshipServiceImpl.sendRequest/accept` xử lý pair lock/transition. `PublicUserServiceImpl.follow` insert idempotently qua unique relation. `PostServiceImpl.likePost/unlikePost` insert/delete `PostLike` và cập nhật count. Post comments/replies cũng đi qua PostService; exact methods cần re-trace when wiring. `CommentServiceImpl` handles itinerary/activity roots/replies and resolves parent/root. No notification publisher currently.

## 6. Những file/class/component cần đọc
`FriendshipServiceImpl`, friendship repo/entity/status; `PublicUserServiceImpl`, Follow; `PostServiceImpl` comment and like blocks, `PostLikeRepository`, `PostComment`; `CommentServiceImpl`, `CommentRepository`, `Comment` root/parent; Post/Itinerary/Activity access and block guards; tests for these services and comment API.

## 7. Những file dự kiến cần tạo/chỉnh sửa
Potential producer integrations in those four service implementations; notification service/DTO/target resolver; relevant backend tests; Flutter Center item and target router. Exact post comment method names and target routes must be captured before changes. No changes to unrelated feature UI.

## 8. Database changes
No new social-domain tables beyond approved Notification/optional normalized Like actors. No duplicate comments/likes. Unique source-event key or domain ID prevents retry duplicates. Like aggregation schema in 10.

## 9. Backend implementation
Inject notification writer into existing service transaction. Only emit after confirmed state mutation: new request, actual acceptance, new follow row, new like, saved comment/reply. Define recipient via actor/parent/content owner; insert Center record in same transaction. Push only AFTER_COMMIT. Maintain existing retries/locks/idempotent behavior.

## 10. Flutter implementation
Center decodes event type and routes to existing public post/detail/thread screens. If exact reply target cannot open due current API, additive target resolution must be designed; do not duplicate comment screen/repository.

## 11. Flutter Web Admin scope
N/A: social event production is backend; Admin Web not involved. Admin remains Flutter Web per source.

## 12. API contract
No new producer API expected. Reuse friendship/follow/like/comment APIs; Center API returns type, actor, target and `commentId/parentCommentId` only when needed. Candidate endpoint paths in 13 are proposals, not current routes.

## 13. Luồng end-to-end
Authenticated action → current domain service checks active/block/visibility and commits transition → determine one recipient → create/dedupe Center record within same transaction → post-commit push optional → Mobile fetches record → authorized route loads current target.

## 14. Business rules
No self event. C6/C8 recipients are exact parent comment authors, not root author unless that is the parent. C7 recipient is itinerary owner, including activity comments; confirm current policy if activity-level owner differs. Comment notification per action. Unlike/re-like honors approved group/read window. Hidden/private/blocked target must not leak.

## 15. Validation và error handling
Reject/skip event when domain transition did not occur; parent author missing/deleted, actor=recipient, target inaccessible or inactive. Notification insert failure rolls back producer transaction if same atomic guarantee is accepted; push failure never does. Surface duplicate retry as success/no-op.

## 16. Security và authorization
User actor derives from principal in domain service; recipient never client supplied. All target routes recheck visibility and block. Notification body uses safe snapshot or server template; no private content. Admin cannot use social producer APIs to spoof actor.

## 17. Realtime và Push behavior
Optional push for social center event after commit; mobile websocket invalidation/refetches. Push delivery does not mark read. If websocket and push both arrive, ID/invalidation is idempotent.

## 18. Test plan
Each C1–C8 recipient matrix, self action, duplicate retry, transaction rollback, concurrent like, follow duplicate, reply to nested parent, deleted parent, private itinerary/activity, blocked users, target deleted/hidden, push failure, REST/notification navigation.

## 19. Acceptance criteria
Only intended user gets row; no self duplicates; C6/C8 parent author; each comment/reply distinct; like group contract correct; source transaction and record atomic; no existing count/state regression; all API/mobile tests pass.

## 20. Dependencies
Phase 1 core and Phase 2 item/route; Phase 0 decision on Like group, event IDs, retention. Depends on current social access rules, not Admin Announcement.

## 21. Risks and mitigation
Comment services have different models/routes. Implement shared notification writer, not shared social rewrite. Comments deleted/soft-deleted can make stale links. Parent/root confusion addressed with explicit parent IDs and tests.

## 22. Completion checklist
- [x] Producer methods reverified in source before edits.
- [x] Recipient mapping implemented: target user for request/accept/follow, post owner for root post comment, itinerary owner for root itinerary/activity comment, exact immediate parent author for replies.
- [x] C1–C3 and C5–C8 emit only after the existing domain mutation succeeds; replies route through the parent post/itinerary. Messaging events are not written to Notification Center.
- [x] Focused backend tests: `mvnw.cmd '-Dtest=SocialNotificationServiceImplTest,FriendshipPrivacyServiceTest,PublicUserServiceTest,CommentThreadServiceTest,CommunityPostServiceTest' test` — previous result predates the corrective refactor; rerun before acceptance.
- [x] Existing Mobile resolver supports USER, POST and ITINERARY parent routes; unsupported REPORT shows safe unavailable text. Phase 2 route evidence is recorded in its plan.
- [x] C4 grouped Like semantics approved and implemented: UTC calendar-day grouping; unread membership supports exact unlike; unlike after read preserves history.
- [ ] Full release regression, transaction rollback against MySQL and runtime navigation remain Phase 7 acceptance work.

## 23. Implementation record — 2026-11-26

- Social notification production is exposed by `SocialNotificationService` and implemented in `SocialNotificationServiceImpl`; existing friendship, profile, post and comment service implementations consume the interface without replacing their transition/access logic.
- Producers call the existing `NotificationService.create(...)` inside their domain transaction and use generic safe copy; comment text is not copied into notification bodies. Nested replies notify only the exact immediate parent author. Activity comment notifications target the parent itinerary route.
- Existing PostLike insertion/count behavior is preserved and now publishes C4 only for an actual new like/unlike transition. No mobile native or FCM change was made in this phase.

### C4 implementation record — 2026-11-26

- Added `notification_like_actors` to maintain current actor membership for unread grouped likes. JPA Entity/Repository mappings use the project's existing Hibernate schema configuration; there is no feature-specific SQL or migration framework.
- Groups use `(recipient, post, UTC date)` semantics. The notification row keeps aggregate count and latest actor; unlike before read removes that actor, deletes an empty group, or recomputes the latest actor/count. Read groups are immutable; re-like creates a new unread group if needed.
- Post writes and notification aggregation serialize around the post/recipient rows; mark-read serializes on recipient to avoid unlike/read races.
- Focused test command `mvnw.cmd '-Dtest=NotificationDatabaseIntegrationTest,NotificationServiceImplTest,SocialNotificationServiceImplTest,CommunityPostServiceTest' test` must be rerun after the corrective refactor; prior counts are historical only.
