# Phase 6 — Moderation Notifications F1/F2/F4/F5/F6/F7

**Trạng thái:** Đã nối Notification vào các thao tác Admin hiện có và kiểm thử tập trung. Không tạo nghiệp vụ cảnh cáo mới. Report resolve/dismiss gửi thông báo trung tính cho người gửi report.

## 1. Mục tiêu
Gửi thông báo user-facing sau moderation transition thành công, giữ audit trace riêng và không lộ admin-only data.

## 2. Phạm vi
Account status/role/session transitions, post hide/remove/restore/purge, report resolve/dismiss, Center record and client rendering.

## 3. Những chức năng sẽ thực hiện
Map actual status transition to one event and correct recipient; stable safe user wording; persist after successful transition; notification route/fallback; tests for duplicate/status no-op.

## 4. Những chức năng không được thay đổi
Không tạo moderation actions mới chỉ để khớp F codes; không đổi reports state, block/account authorization, audit log, warning policy hoặc admin dialogs. Không gửi internal note.

## 5. Phân tích trạng thái code hiện tại
`AdminCommunityController` exposes post moderation, report resolve, purge and media retry. `PostServiceImpl.moderatePost/resolveReport/purgePost` persist existing actions. `AdminUserController` exposes status/role/session revocation via `AdminUserOrchestrationServiceImpl` and transactional worker. The code has no explicit account/post warning endpoint.

## 6. Những file/class/component cần đọc
AdminCommunityController, PostServiceImpl methods/status enums, report entity/audit snapshot; AdminUserController, AdminUserOrchestrationServiceImpl, AdminUserTransactionalWorker, account status enum/status request; Flutter Web admin post/report/user dialogs; report policy specification.

## 7. Những file dự kiến cần tạo/chỉnh sửa
`NotificationActionType`, `Notification`/`NotificationResponse`, `NotificationService`/`SocialNotificationService`, `AdminUserTransactionalWorker`, `PostServiceImpl`, report row locking, focused tests and the existing Flutter Notification Center model/admin announcement form.

## 8. Database changes
Reuse core `notifications`; nullable `action_type` identifies the concrete Admin action. Existing actor, target, title/body, event key and read state carry the rest. AuditLog remains separate; no additional history table is created. `system_announcements.type` is an opaque compatibility string normalized to `SYSTEM` on writes; the category enum is removed.

## 9. Backend implementation
Emit only after effective old→new state change in the transaction that commits. For retrying `AdminUserTransactionalWorker`, create the notice inside its definitive transaction. Report resolution uses a pessimistic row lock, rejects already-final reports, and sends generic outcome copy to the reporter. Account/post moderation reasons are user-facing fields; audit-only/session notes are not copied.

## 10. Flutter implementation
Center displays title/body with the existing list/badge. Existing guarded targets remain; report details use the safe fallback. Locked accounts may not open the Center until restored, but the record remains stored.

## 11. Flutter Web Admin scope
N/A in repo; Admin tools are Flutter Web. No direct notification composition in moderation UI unless a future explicit warning action is approved. Reuse current admin dialogs.

## 12. API contract
Reuse existing admin action APIs: `/api/admin/community/posts/{id}/moderate`, `/api/admin/community/reports/{id}/resolve`, `/api/admin/users/{id}/status`; no new notification mutation endpoint for user. Center DTO exposes sanitized copy and safe target. `GET /api/admin/notification-actions` is a read-only, ADMIN-only, paginated view over notification rows with non-null `action_type`; it reuses the existing table and does not replace operational AuditLog. Exact status/body contract checked in existing request/response DTO.

## 13. Luồng end-to-end
Admin authenticated action → existing authorization/validation/audit → persisted moderation transition → within same transaction create notification for affected user/reporter → optional post-commit generic push → user Center fetch; target API checks latest access/status.

## 14. Business rules
Post status maps to `POST_HIDDEN`, `POST_REMOVED` or `POST_RESTORED`; hard purge maps to `POST_PURGED`. Account status maps to `ACCOUNT_SUSPENDED`/`ACCOUNT_RESTORED`; role changes and successful session revocations are recorded. Reports map to `REPORT_RESOLVED`/`REPORT_DISMISSED` for the reporter with neutral copy. No warning action exists, so none is fabricated.

## 15. Validation và error handling
Validate allowed transition and recipient status. Transaction rollback emits none. Duplicate retry is idempotent. Missing recipient/deleted account handled by retention policy. Push errors post-commit do not undo action. No raw internal reason copied to body.

## 16. Security và authorization
Admin uses server `hasRole('ADMIN')`; end-user reads own notification only. Sanitized copy must not reveal reporter/other targets/internal evidence. Target links never override account lock/block/privacy rules.

## 17. Realtime và Push behavior
Center invalidation after commit; optional push generic and private-safe. FCM success is not read. Admin Audit Log stays authoritative for operator activity; notification is separate user-facing record.

## 18. Test plan
F1 hidden/remove vs no-op; F2/F4 explicit warning availability; F5/F6 transition; F7 report resolved/dismissed; wrong recipient; rollback; retried transaction; internal-note exclusion; locked user restoration; FCM fail; inaccessible target.

## 19. Acceptance criteria
Only committed Admin operations create a user-facing row; audit is preserved; internal/session notes are not leaked; access remains recipient-scoped; no-op and duplicate final report transitions do not emit a second row.

## 20. Dependencies
Phase 0 map/wording and policy; Phase 1 core; Phase 2 Center; current Admin source tests. Phase 3 announcement unrelated except shared Center rendering.

## 21. Risks and mitigation
F2/F4 may not have actual actions; F7 reporter feedback privacy needs product approval. User status may prevent immediate app access. Transaction retry creates duplicate events unless generated only in successful worker transaction.

## 22. Completion checklist
- [x] Account status and post state transitions save system notifications with action type, Admin actor, target and user-facing copy.
- [x] Admin role changes and successful session revocations reuse the same notifications table and transaction.
- [x] Post purge and report resolve/dismiss are recorded; reports are locked and repeat final transitions are rejected.
- [x] `NotificationActionType` and `notifications.action_type` retain each action as a separate history row.
- [x] Admin-only paginated action history can be filtered by target type/id and is tested for role authorization.
- [x] Shared announcements no longer use A1/A2/A3/A5; Center API returns group type `SYSTEM`.
- [ ] Account/post warning actions remain unavailable because no source operation exists.
- [ ] Production schema provisioning, locked-account access and device-level target behavior remain unverified.
