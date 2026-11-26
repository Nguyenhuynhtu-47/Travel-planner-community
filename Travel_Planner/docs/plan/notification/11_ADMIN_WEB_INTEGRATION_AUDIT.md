# Audit tích hợp Admin Web

**Kết quả quan trọng:** Trong workspace này Admin Web là **Flutter Web**, không phải Angular. Không tìm thấy `angular.json` hoặc Angular `package.json`. Căn cứ: `frontend/web/pubspec.yaml` khai báo Flutter package `travel_planner_web`; `frontend/web/lib/main.dart`; màn hình và repository viết bằng Dart.

## Khung, xác thực và điều hướng hiện có

- `frontend/web/lib/features/layout/domain/admin_tab.dart`: AdminTab routes/hash paths `/dashboard`, `/posts`, `/reports`, `/users`, `/places`, `/itineraries`, `/media`, `/administrative-areas`, `/audit-logs`, `/settings`, `/profile`; no announcement tab. `violations/` directory không có file Dart được liệt kê trong source inventory và không có AdminTab.
- `features/layout/presentation/screens/admin_shell.dart`: giữ shell và khởi tạo screen/repository theo tab; chọn User/Role từ `AuthNotifier`. `admin_sidebar.dart` nhóm Community, Travel, Content, System; Reports có pending badge riêng.
- `features/auth`: `AuthNotifier`, `AuthStorage`, login; `ApiClient` dùng token. Đây là auth UI enforcement, backend vẫn kiểm tra role.
- Các admin controller khảo sát dùng `@PreAuthorize("hasRole('ADMIN')")`; exact route, DTO và service phải giữ contract hiện tại.
- Admin audit logs có API riêng, read-only; không phải Announcement history và không nên tái sử dụng để lưu nội dung announcement.

## Ma trận chức năng Admin đã có

| Chức năng | Đã có? | Component/route (Flutter Web) | API đang dùng | Backend xử lý/entity | Cần đổi vì Notification? |
|---|---|---|---|---|---|
| Dashboard/analytics | Có | `AdminDashboardScreen`, `/dashboard` | GET `/api/admin/dashboard/summary`, `/analytics` | `AdminDashboardController`, `AdminDashboardService`; aggregate nhiều domain | Không; có thể thêm số liệu sau nếu được yêu cầu, không cần cho MVP |
| Kiểm duyệt post | Có | `AdminPostsScreen`, `/posts` | GET `/api/admin/community/posts`, `/{id}`; PATCH `/{id}/moderate`; DELETE `/{id}/purge` | `AdminCommunityController` → `PostServiceImpl`, `Post` status/moderation fields, `AuditLog` | Cắm F1 khi status thật sự đổi; F2 chỉ nếu có action warning thực tế; không notify purge/no-op nhầm |
| Xử lý report | Có | `AdminReportsScreen`, `/reports` | GET `/api/admin/community/reports`, `/{id}`; PATCH `/{id}/resolve?resolution=` | `AdminCommunityController` → `PostServiceImpl.resolveReport`, `PostReport` status/resolver/time | Resolve/dismiss lưu `SYSTEM` notification cho reporter bằng copy chung; không lộ audit nội bộ |
| Quản lý user | Có | `AdminUsersScreen`, `/users`, detail/action dialogs | GET `/api/admin/users`, `/{id}`; PATCH `/{id}/status`, `/{id}/role`; POST `/{id}/sessions/revoke-all` | `AdminUserController` → `AdminUserOrchestrationServiceImpl` → `AdminUserTransactionalWorker`, User/status/session/AuditLog | Suspend/restore, role change, revoke session có `SYSTEM` notification; chưa có thao tác cảnh cáo |
| Quản lý itinerary | Có | `AdminItinerariesScreen`, `/itineraries` | GET `/api/admin/itineraries`, `/{id}`; PATCH `/{id}/moderate` | `AdminItineraryController` → `AdminItineraryService`, `Itinerary` | Không nằm C1–C8/F1–F7 trừ khi product thêm rule; không tự notify mọi inspection |
| Quản lý Place chuẩn hóa | Có | `AdminPlacesScreen`, `/places` | GET/POST `/api/admin/places`, GET/PUT/DELETE `/{id}` | `AdminPlaceController` → `PlaceService`, `Place` | Không phát Center notification |
| Khu vực hành chính và liên kết Place | Có | `AdminAdministrativeAreasScreen`, `/administrative-areas` | `/api/administrative-areas/**`; `/api/admin/places/administrative-area/**` preview/resolve/link/unlink/stats/batch | `AdministrativeAreaController`, `AdminPlaceAdministrativeAreaController`, place-area services/entities | Không phát Center notification |
| Media moderation/retry | Có | `AdminMediaScreen`, `/media` | GET `/api/admin/media-assets`; POST `/{id}/retry` (alias community path tồn tại) | `AdminCommunityController` → media services/`MediaAsset` | Không phải notification event trong scope |
| Admin audit logs | Có | `AdminAuditLogsScreen`, `/audit-logs` | GET `/api/admin/audit-logs`, `/{id}`, `/action-types` | `AdminAuditLogController` read-only → `AdminAuditLogService`, `AuditLog` | Giữ audit độc lập; không thay bằng notification history |
| System settings | Có | `AdminSettingsScreen`, `/settings` | GET `/api/admin/settings`; PUT `/api/admin/settings/{key}` | `AdminSettingsController` → `SystemSettingService`, `SystemSetting` | Không phải nội dung thông báo hệ thống; update setting không tự phát notification |
| Admin profile | Có | `ProfileScreen`, `/profile` via header | `/api/user/profile` (profile contract) | `ProfileController`/`ProfileService` | Không cần đổi |
| Announcement authoring/history | Đã triển khai sau audit snapshot | `AdminTab.announcements`, `AdminAnnouncementsScreen` | `/api/admin/announcements` | `AdminAnnouncementController`/service, `SystemAnnouncement` | Dùng chung nhóm `SYSTEM`; không có AnnouncementType category enum |
| Angular Admin | **Không tìm thấy** | Không có Angular route/component | Không có Angular API client | — | Chốt với người dùng: dùng Flutter Web hiện hữu hay cung cấp repo Angular riêng |

## Tích hợp đề xuất, không trùng hệ thống

1. Thêm Announcement screen vào `AdminTab` hiện có trong nhóm System (hoặc vị trí người dùng duyệt), dựng trong `AdminShell`, dùng `ApiClient`, `AuthNotifier`, shared `AdminDataTable`, toolbar/dialog/status badge.
2. Giữ `AdminAuditLogsScreen` là nhật ký bất biến. Announcement list là nội dung phát hành/read policy, không phải audit log. Publish/cancel action vẫn nên ghi audit event hiện hữu nếu service support.
3. Moderation tự tạo user notification chỉ sau commit và chỉ với transitions đã xác minh. Reuse current dialogs/actions; không thêm nút “send notification” cho từng moderation action nếu thông báo tự động đã được duyệt.
4. Admin authoring cần draft/preview/confirmation/publish/history/cancel/expiry; functionality mới thực sự. Không thêm FCM logic/credentials phía Flutter Web.
5. Không cần thêm User management, report, lock/unlock hoặc moderation screen; các screens/API đã có và chỉ cần tích hợp event hook hậu commit.

## Kiểm tra còn thiếu trước implementation

- Re-read exact Flutter repository methods/DTO and backend request/response types for each screen.
- Verify roles beyond ADMIN, if any; current controllers show ADMIN role guard.
- Check actual `SystemSetting` maintenance workflow and whether announcement publish should update it (proposal: separate; no coupling).
- Confirm whether F2/F4 warning actions exist in `features/violations` or backend; current AdminTab/source inventory did not establish them.
- Live data/schema, deployed Angular app outside this repo, and admin permission configuration are CHƯA XÁC MINH.
