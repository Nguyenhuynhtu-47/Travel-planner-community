# PHASE 6B.0 — BÁO CÁO NGHIỆM THU KIẾN TRÚC CUỐI CÙNG
## FINAL ARCHITECTURE ACCEPTANCE REPORT (SESSION 68 PATCH)

**Dự án:** Travel Planner  
**Phân hệ:** Phase 6B.0 — Community Feed / Discovery (Architecture Audit & Technical Design)  
**Ngày thực hiện:** 2026-11-12  
**Kiến trúc sư / Trưởng nhóm Kỹ thuật:** AI Senior Software Architect  
**Nhánh:** `develop` | **HEAD Commit:** `f997f34`  
**Tuân thủ Git Policy:** **STRICTLY NO COMMIT, NO PUSH** (100% Tuân thủ)  
**Chính sách Triển khai:** **ZERO SOURCE CODE MODIFICATIONS, ZERO DATABASE MIGRATIONS**  
**Kết luận Thẩm định (Final Verdict):** **ACCEPTED WITH LIMITATIONS**

---

## 1. TỔNG QUAN VÀ MỤC TIÊU PHIÊN 68 (EXECUTIVE SUMMARY)

Báo cáo này đánh dấu bước hoàn tất tuyệt đối và đóng băng (freeze) toàn bộ hồ sơ thiết kế kỹ thuật của **Phase 6B.0 — Community Feed / Discovery Architecture Design**. Sau các vòng rà soát trước, Session 68 đã giải quyết dứt điểm đúng 6 vấn đề kỹ thuật chuyên sâu:

1. **Thống nhất Mã lỗi HTTP & Triệt tiêu TOCTOU khi Attach Media:**
   - Phân định rõ ràng giữa các lỗi: Trùng ID / vượt quá 5 ảnh (`400 Bad Request`), không tồn tại hoặc thuộc user khác (`404 Not Found` theo Chính sách Chống dò quét ID), đã attach hoặc đang xóa (`409 Conflict`).
   - Khóa bản ghi bằng `SELECT ... FOR UPDATE` trong transaction nguyên tử; schema MySQL có `UNIQUE (media_asset_id)` bảo vệ tuyệt đối ở tầng storage engine.
2. **Quy trình Bù trừ (Compensating Action) khi Cloudinary Upload Thành công nhưng Database Thất bại:**
   - Xử lý kịch bản mất kết nối hoặc lỗi insert MySQL bằng lệnh xóa tức thời `cloudinary.uploader().destroy(publicId)`.
   - Phân tích ranh giới sự cố mạng, ghi log dead-letter và thiết lập script quét đối soát thư mục Cloudinary định kỳ (Phase 6B.6).
3. **Hoàn thiện Retry, Lease Claim Lock và Phục hồi sau Crash:**
   - Bổ sung các cột theo dõi vào `media_assets`: `retry_count`, `next_retry_at`, `last_error`, `locked_at`, `locked_by`.
   - Giữ nguyên 4 trạng thái (`UNATTACHED`, `ATTACHED`, `DELETING`, `DELETED`).
   - Cơ chế claim/lease khóa 10 phút chống đa worker tranh chấp và tự phục hồi khi node crash.
   - Xử lý idempotent (kết quả Cloudinary trả về "not found" vẫn coi là thành công chuyển `DELETED`).
4. **Đồng bộ Toàn diện Chính sách `UserStatus` (`ACTIVE`, `INACTIVE`, `BANNED`):**
   - Loại trừ tài khoản `INACTIVE` khỏi Feed; người khác truy cập Post Detail nhận `404 Not Found`.
   - Chặn quyền ghi (comment, like, post) của user `INACTIVE` bằng `403 Forbidden`.
   - Phân biệt rõ `INACTIVE` (tự kích hoạt lại qua login/auth) vs `BANNED` (chỉ Admin unban).
   - Tách rời hoàn toàn: Mở Post Detail KHÔNG THỂ và KHÔNG ĐƯỢC PHÉP kích hoạt tài khoản.
   - Tự động xuất hiện lại trên feed khi tài khoản trở về `ACTIVE`.
5. **Hoàn thiện Bất biến Hiển thị Lịch trình Đính kèm Bài viết:**
   - Post Author $\ne$ Itinerary Owner (hai danh tính độc lập). Quyền xem Post không suy ra quyền xem Lịch trình.
   - Đánh giá độc lập: Nếu Lịch trình không thỏa mãn (`PUBLIC` + `ACTIVE` + Owner `ACTIVE`), DTO trả về `itinerary: null` kèm reason code (`CREATOR_UNAVAILABLE`, `PRIVATE_OR_UNAVAILABLE`, v.v.).
   - Tuyệt đối không để lộ tiêu đề, chi phí, ngày đi, ảnh bìa hay hoạt động của lịch trình ẩn.
6. **Hiệu chỉnh Tuyên bố Kỹ thuật & Thực tế Navigation Badge:**
   - Chỉnh sửa độ phức tạp tra cứu khóa chính clustered InnoDB từ nhận định chủ quan $O(1)$ thành mô tả chuẩn xác: tra cứu cây B+Tree với độ sâu 3–4 tầng ($O(\log n)$ disk/buffer pool inspections).
   - Phân biệt rành mạch giữa URL tampering, phân quyền tài nguyên và SQL injection.
   - Quyết định rõ ràng về huy hiệu tin nhắn: **ẨN huy hiệu unread trên icon Chat** trong Phase 6B MVP cho đến khi endpoint `GET /api/conversations/unread-total` được hoàn thành ở Phase 6B.2, tránh dùng cache gây sai lệch số liệu.

---

## 2. KẾT QUẢ XỬ LÝ CHI TIẾT SÁU VẤN ĐỀ (ISSUES RESOLUTION)

### ISSUE 1: Thống nhất HTTP Error khi Attach Media Asset
- **Vấn đề đã xử lý:** Loại bỏ sự nhập nhằng giữa `403 Forbidden` và `409 Conflict` do câu lệnh `UPDATE ... WHERE uploaded_by = :userId` gây ra.
- **Quy trình Validation & Mã lỗi Thống nhất:**
  1. `mediaAssetIds` có phần tử trùng lặp $\rightarrow$ `400 Bad Request` (*"Danh sách ảnh chứa định danh trùng lặp"*).
  2. `mediaAssetIds.size() > 5` $\rightarrow$ `400 Bad Request` (*"Vượt quá giới hạn tối đa 5 ảnh"*).
  3. Sắp xếp danh sách ID (`sortedIds`) để tránh Deadlock trong MySQL.
  4. Thực thi truy vấn khóa dòng bi quan (Pessimistic Write Lock):  
     `SELECT ma FROM MediaAsset ma WHERE ma.mediaAssetId IN (:sortedIds) FOR UPDATE`
  5. Nếu `foundAssets.size() != sortedIds.size()` (ID không tồn tại) $\rightarrow$ `404 Not Found` (*"Tệp phương tiện không tồn tại"*).
  6. Nếu có bất kỳ asset nào có `uploaded_by != currentUserId` $\rightarrow$ **`404 Not Found`** (*"Tệp phương tiện không tồn tại hoặc bạn không có quyền truy cập"*).  
     *Lý giải Trade-off Bảo mật:* Chọn trả về `404 Not Found` thay vì `403 Forbidden` để ngăn chặn kẻ tấn công dò quét (ID enumeration oracle) sự tồn tại của các asset ID thuộc về người dùng khác, tuân thủ chặt chẽ khuyến nghị OWASP BOLA.
  7. Nếu có asset có `status == 'ATTACHED'` $\rightarrow$ `409 Conflict` (*"Tệp phương tiện đã được sử dụng trong bài viết khác"*).
  8. Nếu có asset có `status IN ('DELETING', 'DELETED')` $\rightarrow$ `409 Conflict` (*"Tệp phương tiện đang được xóa hoặc không còn khả dụng"*).
  9. Nếu tất cả hợp lệ: Chuyển `status = 'ATTACHED'`, insert các dòng vào `post_media` kèm `display_order`.
- **Bảo toàn Tính nguyên tử & Triệt tiêu TOCTOU:**
  - Nhờ `SELECT ... FOR UPDATE`, không có tiến trình nào khác có thể thay đổi trạng thái hoặc chiếm dụng asset giữa bước kiểm tra và bước ghi.
  - Nếu bất kỳ asset nào lỗi, Spring `@Transactional` lập tức rollback: không có post nào được tạo, không có asset nào bị gắn dở dang.
  - Ràng buộc `uk_post_media_asset UNIQUE (media_asset_id)` là chốt chặn vật lý cuối cùng ở tầng MySQL InnoDB ngăn chặn triệt để việc 1 ảnh bị gắn vào 2 post.

---

### ISSUE 2: Orphan Cloudinary khi Upload Thành công nhưng Database Thất bại
- **Vấn đề đã xử lý:** Trường hợp Cloudinary đã tạo ảnh nhưng bước lưu `media_assets` vào MySQL bị fail (mất mạng DB, crash) khiến Cloudinary có ảnh mồ côi mà MySQL không có bản ghi.
- **Giải pháp Bù trừ (Compensating Action):**
  - Trong `ImageUploadService`, bao bọc lệnh `save` MySQL bằng khối `try-catch`.
  - Nếu MySQL lưu thất bại, lập tức gọi `cloudinary.uploader().destroy(publicId)` để xóa ngay file vừa upload trên Cloudinary.
  - Nếu lệnh xóa bù trừ cũng thất bại (mạng đứt), ghi sự kiện log lỗi cấu trúc `EVENT=CLOUDINARY_ORPHAN_COMPENSATION_FAILED`.
- **Xử lý Giới hạn Thực tế (Crash / Network Partition):**
  - Vì không tồn tại 2-Phase Commit giữa Cloudinary REST API và MySQL, ứng dụng áp dụng quy ước đặt tên thư mục: `travel_planner/assets/{userId}/` kèm metadata tags.
  - Trong Phase 6B.6, một script bảo trì định kỳ sẽ gọi Cloudinary Admin API quét thư mục này và đối soát với MySQL `media_assets.cloudinary_public_id`. Bất kỳ ảnh nào trên Cloudinary quá 7 ngày mà không có dòng tương ứng trong database sẽ được tự động dọn sạch.
  - **Giữ nguyên Option B:** Bảng `media_assets` và `post_media` không bị thay đổi cấu trúc cốt lõi.

---

### ISSUE 3: Hoàn thiện Retry, Lease Claim Lock và Phục hồi sau Crash
- **Vấn đề đã xử lý:** Đảm bảo hệ thống tự phục hồi khi app restart hoặc worker crash, không để asset kẹt ở `DELETING`.
- **Cấu trúc Bảng `media_assets` bổ sung:**
  - `retry_count INT NOT NULL DEFAULT 0`
  - `next_retry_at DATETIME(6) NULL`
  - `last_error VARCHAR(500) NULL`
  - `locked_at DATETIME(6) NULL`
  - `locked_by VARCHAR(100) NULL`
  - Index: `idx_media_assets_cleanup (status, next_retry_at, locked_at, retry_count)`.
- **Quy trình Claim / Lease Lock:**
  ```sql
  UPDATE media_assets 
  SET status = 'DELETING', locked_at = NOW(), locked_by = :workerId, updated_at = NOW()
  WHERE (
      (status = 'UNATTACHED' AND created_at < NOW() - INTERVAL 24 HOUR)
      OR 
      (status = 'DELETING' AND (locked_at IS NULL OR locked_at < NOW() - INTERVAL 10 MINUTE) AND (next_retry_at IS NULL OR next_retry_at <= NOW()))
  )
  AND retry_count < 5
  LIMIT 50;
  ```
- **Khả năng Phục hồi sau Crash:**
  - Nếu worker bị crash giữa chừng, khóa `locked_at` sẽ hết hạn sau 10 phút. Worker khác hoặc chính worker đó sau khi khởi động lại sẽ tự động nhận diện và tiếp tục xử lý.
- **Tính Idempotent & Phân loại Lỗi:**
  - Nếu Cloudinary trả về `result: "ok"` HOẶC `result: "not found"`, hệ thống đều coi là **THÀNH CÔNG** (vì file thực tế không còn trên Cloudinary) và chuyển trạng thái sang `DELETED`.
  - *Lỗi tạm thời (Network timeout, 429, 500, 503):* Tăng `retry_count`, tính exponential backoff `next_retry_at = NOW() + (2^retry * 15s)` + jitter, mở khóa `locked_at = NULL`.
  - *Lỗi vĩnh viễn (400 Bad Request, sai auth):* Đặt `retry_count = 999` (Dead-letter), lưu `last_error` để admin kiểm tra.
- **Ranh giới Transaction:** Lệnh gọi Cloudinary tuyệt đối chỉ thực hiện **SAU KHI** commit database.

---

### ISSUE 4: Đồng bộ Toàn diện Chính sách `UserStatus`
- **Vấn đề đã xử lý:** Đồng bộ hành vi của cả ba trạng thái `ACTIVE`, `INACTIVE`, `BANNED` trên toàn bộ 8 endpoint và thẻ lịch trình nhúng.
- **Quy tắc Thống nhất:**
  1. *Hiển thị trên Feed:* Tác giả `INACTIVE` hoặc `BANNED` bị **LOẠI TRỪ HOÀN TOÀN** khỏi Public Feed và Following Feed (`WHERE p.author.status = 'ACTIVE'`).
  2. *Truy cập Chi tiết Bài viết (`/posts/{id}`):*
     - Nếu tác giả `INACTIVE`: Người khác truy cập nhận **`404 Not Found`**.
     - Nếu tác giả `BANNED`: Người khác truy cập nhận **`404 Not Found`** (không trả `403` để che giấu hoàn toàn tài nguyên vi phạm).
  3. *Quyền Thao tác Ghi:* Người dùng đang `INACTIVE` hoặc `BANNED` bị chặn thực hiện mọi thao tác ghi (tạo bài viết, bình luận, like, báo cáo) bằng mã **`403 Forbidden`** (*"Tài khoản của bạn đang tạm khóa hoặc chưa được kích hoạt"*).
  4. *Khác biệt cốt lõi giữa `INACTIVE` và `BANNED`:*
     - `INACTIVE`: Tự nguyện tạm khóa hoặc chưa xác thực email. Người dùng **CÓ THỂ** tự kích hoạt lại qua luồng đăng nhập / xác thực (`/api/auth/reactivate`).
     - `BANNED`: Cưỡng chế bởi hệ thống do vi phạm chính sách. Người dùng **KHÔNG THỂ** tự mở khóa. Chỉ Quản trị viên (`ADMIN`) mới có quyền unban.
  5. *Tự động Xuất hiện lại:* Khi tài khoản trở lại `ACTIVE`, toàn bộ bài viết hợp lệ (`status = 'ACTIVE'`) và thẻ lịch trình của họ **TỰ ĐỘNG XUẤT HIỆN LẠI** trên Feed và các màn hình liên quan mà không cần can thiệp thủ công.
  6. *Ngắt kết nối với Post Detail:* Việc truy cập `GET /api/community/posts/{id}` là thao tác đọc, **TUYỆT ĐỐI KHÔNG LIÊN QUAN** và **KHÔNG THỂ KÍCH HOẠT LẠI** tài khoản.

---

### ISSUE 5: Hoàn thiện Bất biến Hiển thị Lịch trình Đính kèm Bài viết
- **Vấn đề đã xử lý:** Bảo vệ quyền riêng tư tuyệt đối cho Lịch trình được đính kèm vào Post.
- **Quy tắc Độc lập Danh tính:** **Post Author** và **Itinerary Owner** là hai danh tính tách biệt hoàn toàn. Quyền tác giả của Post không bao giờ được dùng làm căn cứ suy ra quyền xem Lịch trình.
- **Bất biến Hiển thị:**
  - Thẻ Lịch trình đầy đủ CHỈ ĐƯỢC PHÉP hiển thị khi và chỉ khi:  
    `itinerary.visibility == 'PUBLIC' AND itinerary.status == 'ACTIVE' AND itinerary.owner.status == 'ACTIVE'`.
  - Nếu bất kỳ điều kiện nào không thỏa mãn (Lịch trình `PRIVATE`, `HIDDEN`, `DELETED`, hoặc Owner `INACTIVE`, `BANNED`):
    - Bài viết vẫn hiển thị bình thường (nếu bài viết hợp lệ).
    - DTO trả về `itinerary: null` kèm lý do cụ thể (`CREATOR_UNAVAILABLE`, `PRIVATE_OR_UNAVAILABLE`, `MODERATED_OR_UNAVAILABLE`, `DELETED_OR_UNAVAILABLE`).
    - **Triệt tiêu rò rỉ dữ liệu (Zero Leakage):** Tuyệt đối không trả về `title`, `coverImage`, `budget`, `totalDays`, hoặc danh sách hoạt động.
    - Giao diện người dùng hiển thị thẻ placeholder an toàn: *"Lịch trình đính kèm ở chế độ riêng tư hoặc không khả dụng"*.

---

### ISSUE 6: Sửa Tuyên bố Kỹ thuật & Thực tế Navigation Badge
- **Độ phức tạp Primary Key Lookup (Issue 6.A):**
  - Đã loại bỏ hoàn toàn nhận định sai lệch "$O(1)$ PK lookup".
  - Hiệu chỉnh chuẩn xác: Tra cứu theo `media_asset_id` trên MySQL InnoDB là tra cứu cây chỉ mục B+Tree với độ sâu điển hình 3–4 tầng, tương ứng độ phức tạp $O(\log n)$ phép kiểm tra trang nhớ.
  - Khẳng định giá trị thực sự của `mediaAssetIds` là định danh số nguyên nội bộ nhỏ gọn, ổn định, xác thực quyền sở hữu authoritatively và tách rời logic ứng dụng khỏi CDN URL.
- **Phân biệt SQL Injection (Issue 6.B):**
  - Làm rõ rằng việc dùng `mediaAssetIds` không tự nó chống SQL Injection.
  - Phân định rõ: `mediaAssetIds` giải quyết bài toán chống URL tampering và phân quyền tài nguyên (BOLA). Phòng chống SQL Injection thuộc về tầng parameter binding (`PreparedStatement`, Spring Data `@Param`) và strong typing (`List<Long>`).
- **Thực tế Navigation Badge (Issue 6.C):**
  - Huy hiệu Yêu cầu kết bạn: Được hỗ trợ từ `totalElements` của `GET /api/users/me/friend-requests?direction=received` (`VERIFIED IN SOURCE`).
  - Huy hiệu Tin nhắn chưa đọc: Backend hiện tại **CHƯA CÓ** endpoint trả về tổng số tin nhắn chưa đọc toàn cục (`VERIFIED IN SOURCE`).
  - **Quyết định Dứt khoát:** Trong Phase 6B MVP, **ẨN HOÀN TOÀN huy hiệu unread trên icon Chat**. Tuyệt đối không dùng cache danh sách hội thoại hay trang đầu để tính tổng, tránh hiển thị số liệu sai lệch gây ức chế cho người dùng. Khi Phase 6B.2 bổ sung endpoint `GET /api/conversations/unread-total`, huy hiệu số sẽ được kết nối chính thức.

---

## 3. DANH SÁCH CÁC TÀI LIỆU ĐÃ CẬP NHẬT ĐỒNG BỘ

Toàn bộ các tài liệu thiết kế liên quan đã được chỉnh sửa và đồng bộ hóa 100%:

| Đường dẫn Tài liệu | Trạng thái | Nội dung Đồng bộ chính |
| :--- | :---: | :--- |
| [`02-community-feed-product-design.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/02-community-feed-product-design.md) | **ĐÃ CẬP NHẬT** | Ẩn unread chat badge trong MVP; làm rõ luồng Feed-First. |
| [`03-community-feed-data-architecture.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/03-community-feed-data-architecture.md) | **ĐÃ CẬP NHẬT** | Bổ sung cột retry/lease claim vào `media_assets`, DDL Option B, `SELECT ... FOR UPDATE`, compensating deletion, `UserStatus` matrix, Itinerary privacy invariants. |
| [`04-community-feed-api-design.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/04-community-feed-api-design.md) | **ĐÃ CẬP NHẬT** | Bảng mã lỗi HTTP attach media (400, 404 anti-enumeration, 409), ma trận phân quyền 8 endpoint bao gồm `INACTIVE`, ẩn chat badge MVP. |
| [`05-feed-query-performance-security.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/05-feed-query-performance-security.md) | **ĐÃ CẬP NHẬT** | Sửa độ phức tạp $O(\log n)$ B+Tree, phân biệt URL tampering vs SQL injection, rào chắn bảo mật Itinerary. |
| [`06-phase-6b-implementation-roadmap.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/06-phase-6b-implementation-roadmap.md) | **ĐÃ CẬP NHẬT** | Cập nhật phạm vi Phase 6B.1 (compensating upload, write lock), 6B.2 (ẩn badge MVP, endpoint unread), 6B.6 (lease claims, đối soát Cloudinary). |
| [`07-phase-6b-architecture-decision-record.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/07-phase-6b-architecture-decision-record.md) | **ĐÃ CẬP NHẬT** | Cập nhật ADR-6B-02 (chính sách badge) và ADR-6B-08 (Option B, DDL, write lock, anti-enumeration). |
| [`PHASE-6B.0-ACCEPTANCE-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-ACCEPTANCE-REPORT.md) | **ĐÃ CẬP NHẬT** | Đồng bộ toàn bộ checklist nghiệm thu (cả 2 bản sao). |
| [`PHASE-6B.0-FINAL-ARCHITECTURE-ACCEPTANCE-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-ACCEPTANCE-REPORT.md) | **MỚI TẠO** | Báo cáo nghiệm thu kiến trúc toàn diện Session 68. |
| [`09-development-log.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/09-development-log.md) | **ĐÃ CẬP NHẬT** | Ghi nhận Session 68 (DOCUMENTATION ONLY, English). |

---

## 4. KIỂM TRA ĐỐI CHIẾU NHẤT QUÁN (CROSS-DOCUMENT VERIFICATION)

1. **Đối chiếu DDL Option B giữa Data Architecture và ADR:**
   - Cả `03-community-feed-data-architecture.md` và `07-phase-6b-architecture-decision-record.md` (ADR-6B-08) đều mô tả bảng `media_assets` gồm đầy đủ các cột: `media_asset_id`, `uploaded_by`, `cloudinary_public_id`, `secure_url`, `media_type`, `status`, `retry_count`, `next_retry_at`, `last_error`, `locked_at`, `locked_by`, `created_at`, `updated_at`.
   - Bảng `post_media` có `CONSTRAINT uk_post_media_asset UNIQUE (media_asset_id)`.
   - Không tồn tại cột `post_id` trong `media_assets`. $\rightarrow$ **100% MATCH**.
2. **Đối chiếu Vòng đời Phương tiện & Ranh giới Side-Effect:**
   - Cả Data Architecture, API Design và Roadmap đều quy định 4 trạng thái duy nhất: `UNATTACHED`, `ATTACHED`, `DELETING`, `DELETED`.
   - Lệnh gọi Cloudinary xóa ảnh tuyệt đối thực hiện SAU KHI commit database. $\rightarrow$ **100% MATCH**.
3. **Đối chiếu Chính sách Mã lỗi HTTP:**
   - API Design và Data Architecture đều thống nhất: Duplicate/Vượt giới hạn $\rightarrow$ `400 Bad Request`; Không tồn tại hoặc thuộc user khác $\rightarrow$ `404 Not Found` (Anti-Enumeration); Đã gắn hoặc đang xóa $\rightarrow$ `409 Conflict`. $\rightarrow$ **100% MATCH**.
4. **Đối chiếu `UserStatus` Matrix:**
   - Tất cả tài liệu đều thống nhất: `INACTIVE` và `BANNED` bị loại trừ khỏi Feed; Post Detail trả về `404 Not Found`; User `INACTIVE` bị chặn quyền ghi bằng `403 Forbidden`; Post tự động xuất hiện lại khi tài khoản `ACTIVE`. $\rightarrow$ **100% MATCH**.
5. **Đối chiếu Quyền riêng tư Lịch trình Đính kèm:**
   - Tất cả tài liệu đều khẳng định Post Author $\ne$ Itinerary Owner; khi Lịch trình không hợp lệ, DTO trả về `itinerary: null` kèm reason code, rò rỉ metadata bằng 0. $\rightarrow$ **100% MATCH**.
6. **Đối chiếu Navigation Badge:**
   - Product Design, API Design, Roadmap và ADR đều thống nhất: Ẩn chat badge trong Phase 6B MVP; bổ sung `GET /api/conversations/unread-total` ở Phase 6B.2. $\rightarrow$ **100% MATCH**.

---

## 5. XÁC MINH GIT STATUS VÀ BẢO TOÀN DỮ LIỆU

### 5.1. Git Status Trước khi Thực hiện Session 68:
- Branch: `develop` | HEAD: `f997f34`
- Trạng thái: Các file modified và untracked từ Phase 6A và Mobile Baseline Remediation được ghi nhận đầy đủ.

### 5.2. Git Status Sau khi Hoàn thành Session 68:
- Toàn bộ các file source code (`.java`, `.dart`), cấu hình môi trường, dependencies hoàn toàn nguyên vẹn.
- Không có commit nào được tạo (`git log -1` vẫn là `f997f34`).
- Không có push nào được thực hiện.
- Không có migration database nào được tạo hoặc chạy.

---

## 6. NHỮNG ĐIỂM HẠN CHẾ & CÂU HỎI MỞ (REMAINING LIMITATIONS / OPEN QUESTIONS)

Mặc dù toàn bộ thiết kế kiến trúc đã hoàn chỉnh và nhất quán 100%, hệ thống ghi nhận các giới hạn kỹ thuật cần kiểm chứng trong quá trình triển khai thực tế:

1. **Hiệu năng Đo lường Thực tế dưới Tải (Phase 6B.6):**
   - Chiến lược Multi-Query (Query 1, Query 2, Query 3) loại bỏ cảnh báo bộ nhớ Hibernate JVM nhưng cần được benchmark với dữ liệu mẫu lớn (> 100.000 posts, > 300.000 photos) để tinh chỉnh tham số `LIMIT` / `OFFSET`.
2. **Tần suất Đối soát Thư mục Cloudinary (Phase 6B.6):**
   - Cloudinary Admin API áp dụng rate-limit nghiêm ngặt theo gói tài khoản. Script đối soát thư mục hàng tuần cần sử dụng con trỏ phân trang `next_cursor` và thực thi vào khung giờ thấp điểm (3 AM Chủ nhật).
3. **Phụ thuộc Triển khai Phía Mobile (Phase 6B.2):**
   - Việc ẩn huy hiệu tin nhắn chưa đọc trong MVP là giải pháp an toàn về UX, nhưng cần thông báo cho đội ngũ kiểm thử mobile để tránh tạo bug report nhầm lẫn về việc "thiếu badge tin nhắn".

---

## 7. KẾT LUẬN THẨM ĐỊNH (FINAL VERDICT)

### Kết luận Nghiệm thu:
# ✅ **ACCEPTED WITH LIMITATIONS**

> **Tóm tắt Giới hạn Chờ nghiệm thu Thực tế:**
> 1. Thiết kế kiến trúc và mô hình dữ liệu Phase 6B.0 đã đạt mức độ hoàn thiện, bảo mật và nhất quán tối đa.
> 2. Các cơ chế bảo mật (chống URL injection, khóa bi quan `SELECT ... FOR UPDATE`, compensating deletion, lease claims) hiện tại là **ĐẶC TẢ THIẾT KẾ KỸ THUẬT (DESIGN SPECIFICATION)**, chưa có trong mã nguồn đang chạy. Chúng sẽ được hiện thực hóa tại Phase 6B.1 và kiểm chứng bằng test tự động.
> 3. Huy hiệu tin nhắn chưa đọc sẽ được kích hoạt sau khi Phase 6B.2 cung cấp endpoint tổng hợp.

---

## 8. ĐIỀU KIỆN DỪNG BẮT BUỘC (STRICT STOP CONDITION)

> [!CAUTION]
> **NHIỆM VỤ PHASE 6B.0 ĐÃ HOÀN TẤT VÀ KHÓA CHẶT (SEALED).**
> - **TUYỆT ĐỐI KHÔNG TỰ ĐỘNG BẮT ĐẦU PHASE 6B.1.**
> - **KHÔNG TẠO MIGRATION, KHÔNG SỬA CODE JAVA / FLUTTER.**
> - **KHÔNG COMMIT, KHÔNG PUSH.**
> 
> Hệ thống dừng lại tại đây và chờ đợi quyết định phê duyệt chính thức từ người dùng để mở Phase 6B.1.

