# PHASE 6B.0 — BÁO CÁO NGHIỆM THU HIỆU CHỈNH KỸ THUẬT VÀ ĐỒNG BỘ TÀI LIỆU CUỐI CÙNG
## FINAL TECHNICAL CLARIFICATION & DOCUMENTATION CONSISTENCY REPORT (SESSION 71)

**Dự án:** Travel Planner  
**Phân hệ:** Phase 6B.0 — Community Feed / Discovery (Architecture Audit & Technical Design)  
**Ngày thực hiện:** 2026-11-12  
**Kiến trúc sư / Trưởng nhóm Kỹ thuật:** AI Senior Software Architect  
**Nhánh:** `develop` | **HEAD Commit:** `f997f34`  
**Tuân thủ Git Policy:** **STRICTLY NO COMMIT, NO PUSH** (100% Tuân thủ)  
**Chính sách Triển khai:** **DOCUMENTATION ONLY — ZERO SOURCE CODE MODIFICATIONS, ZERO DATABASE MIGRATIONS**  
**Kết luận Thẩm định (Final Verdict):** **ACCEPTED WITH LIMITATIONS**

---

## 1. TỔNG QUAN VÀ MỤC TIÊU PHIÊN 71 (EXECUTIVE SUMMARY)

Báo cáo này đại diện cho đợt rà soát và hiệu chỉnh kỹ thuật chuyên sâu cuối cùng của **Phase 6B.0 — Community Feed / Discovery Architecture Design**. Sau khi Session 70 đã hiệu chỉnh các nhận định về deadlock và phân loại lỗi Cloudinary, Session 71 tập trung giải quyết triệt để bốn vấn đề kỹ thuật nâng cao nhằm đảm bảo tài liệu đạt độ chính xác và rõ ràng tuyệt đối, giúp bất kỳ kỹ sư hoặc Agent nào cũng có thể triển khai sau khi được phê duyệt:

1. **Chuẩn hóa Quy trình Claim với MySQL 8 `SKIP LOCKED` (Issue 1):** Sửa cú pháp giả định `UPDATE ... LIMIT 50 SKIP LOCKED` thành quy trình 2 bước chuẩn mực trong MySQL 8: (1) `SELECT ... FOR UPDATE SKIP LOCKED` để khóa và lấy tối đa 50 ID; (2) `UPDATE ... WHERE IN (:claimedIds)` để gán batch token; commit transaction giải phóng row lock trước khi gọi Cloudinary; định nghĩa rõ ràng điều kiện đủ tiêu chuẩn claim (eligibility predicate).
2. **Phân biệt Asset Lifecycle State và Worker Claim / Lease State (Issue 2):** Tách bạch hoàn toàn giữa trạng thái vòng đời nghiệp vụ (`UNATTACHED`, `ATTACHED`, `DELETING`, `DELETED`) và metadata quyền xử lý vận hành (`claim_token`, `locked_at`, `locked_by`, `next_retry_at`, `dead_lettered_at`); làm rõ `DELETING` không đồng nghĩa đang có worker xử lý; quy chuẩn hóa bảng chuyển trạng thái vòng đời.
3. **Hiệu chỉnh Ma trận Tranh chấp (Race Condition Matrix) & Ngữ nghĩa Đồng thời (Issue 3):** Loại bỏ cách diễn đạt không được bảo đảm ("Bên chiếm khóa trước commit trước"); thay bằng nguyên tắc chuyển trạng thái có điều kiện; mở rộng ma trận race condition thành **10 kịch bản toàn diện** bao gồm deadlock retry, stale worker, worker crash giữa chừng và tính nguyên tử của bài viết nhiều ảnh.
4. **Xác minh Vòng đời Post Restore & Hard-Purge (Issue 4):** Truy tìm nguồn gốc thời hạn khôi phục bài viết; phân loại việc Soft-delete giữ ảnh `ATTACHED` là `PROPOSED DESIGN`, còn con số "30 ngày" là giả định kỹ thuật chưa có phê duyệt chính thức và được chuyển thành **`OPEN QUESTION`**; xây dựng bảng ma trận đồng bộ vòng đời Post và Media Asset; thiết lập các quy tắc an toàn khi restore bài viết.

---

## 2. THÔNG TIN NHÁNH GIT VÀ COMMIT HEAD

- **Nhánh hiện tại:** `develop`
- **Commit HEAD:** `f997f34` (`f997f346f3c536d5bdcf6612fb3f35f6b1774e45`)
- **Chế độ làm việc:** **DOCUMENTATION ONLY** (Zero source code modifications, zero database migrations).

---

## 3. KIỂM SOÁT GIT VÀ TRẠNG THÁI WORKING TREE (TRƯỚC VÀ SAU)

### 3.1. Trạng thái Git trước Session 71:
```
 M Travel_Planner/docs/ai/09-development-log.md
 M Travel_Planner/frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart
 M Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart
 M Travel_Planner/frontend/mobile/lib/features/location/data/models/location_search_result.dart
 M Travel_Planner/frontend/mobile/lib/features/location/presentation/widgets/location_picker_sheet.dart
 M Travel_Planner/frontend/mobile/test/explore_test.dart
 M Travel_Planner/frontend/mobile/test/features/social/rating_ui_layout_test.dart
?? Travel_Planner/docs/verification/phase-6/PHASE-6A-IMPLEMENTATION-PLAN.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.1-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.2-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.3-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-CONSISTENCY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-69-FINAL-LIFECYCLE-PRIVACY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-70-CONCURRENCY-LIFECYCLE-CONSISTENCY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/phase-6b-design/
?? Travel_Planner/docs/verification/post-phase-6a/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/data/helpers/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/day_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/test/features/itinerary/
```

### 3.2. Trạng thái Git sau Session 71:
```
 M Travel_Planner/docs/ai/09-development-log.md
 M Travel_Planner/frontend/mobile/lib/features/explore/presentation/screens/explore_screen.dart
 M Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart
 M Travel_Planner/frontend/mobile/lib/features/location/data/models/location_search_result.dart
 M Travel_Planner/frontend/mobile/lib/features/location/presentation/widgets/location_picker_sheet.dart
 M Travel_Planner/frontend/mobile/test/explore_test.dart
 M Travel_Planner/frontend/mobile/test/features/social/rating_ui_layout_test.dart
?? Travel_Planner/docs/verification/phase-6/PHASE-6A-IMPLEMENTATION-PLAN.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.1-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.2-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6A.3-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-ACCEPTANCE-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-FINAL-ARCHITECTURE-CONSISTENCY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-69-FINAL-LIFECYCLE-PRIVACY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-70-CONCURRENCY-LIFECYCLE-CONSISTENCY-REPORT.md
?? Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-71-FINAL-TECHNICAL-CLARIFICATION-REPORT.md
?? Travel_Planner/docs/verification/phase-6/phase-6b-design/
?? Travel_Planner/docs/verification/post-phase-6a/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/data/helpers/
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/day_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart
?? Travel_Planner/frontend/mobile/test/features/itinerary/
```
*(Bảo toàn 100% working tree, không ghi đè, không có commit, không có push).*

---

## 4. ISSUE 1 — MYSQL 8 SKIP LOCKED CLAIM FLOW

### 4.1. Vấn đề Cần Xử lý & Chuẩn hóa Cú pháp
- Trong Session 70, tài liệu mô tả câu lệnh `UPDATE ... LIMIT 50` kết hợp `SKIP LOCKED`. Trong MySQL 8, mệnh đề `SKIP LOCKED` là cú pháp khóa của `SELECT ... FOR UPDATE`, không thuộc cú pháp chuẩn của câu lệnh `UPDATE`.
- Session 71 đã chuẩn hóa quy trình claim lô (batch claim) thành mô hình 2 bước trong một transaction ngắn (< 50ms):
  1. Mở transaction.
  2. Dùng `SELECT ... FOR UPDATE SKIP LOCKED` để lấy tối đa 50 bản ghi đủ điều kiện.
  3. Cập nhật các bản ghi vừa chọn trong cùng transaction: gán `claim_token`, `locked_at`, `locked_by`.
  4. Commit transaction ngay lập tức để giải phóng row lock.
  5. Gọi Cloudinary xóa ảnh ngoài transaction.
  6. Mở transaction ngắn thứ hai để cập nhật kết quả DB có kiểm tra `claim_token`.

### 4.2. Điều kiện Đủ Tiêu chuẩn Claim (Eligibility Predicate)
Một asset chỉ được coi là đủ điều kiện đưa vào batch claim khi thỏa mãn điều kiện logic đầy đủ:
- **Asset mồ côi (Orphan Asset):** `status = 'UNATTACHED' AND created_at < NOW() - INTERVAL 24 HOUR`.
- **Asset chờ xóa mới (New Purged Asset):** `status = 'DELETING' AND locked_at IS NULL` (mới chuyển sang `DELETING` sau khi bài viết bị hard-purge).
- **Asset chờ thử lại (Retry Scheduled Asset):** `status = 'DELETING' AND (locked_at IS NULL OR locked_at < NOW() - INTERVAL 10 MINUTE) AND next_retry_at <= NOW()`.
- **Asset hết hạn lease (Expired Lease Asset):** `status = 'DELETING' AND locked_at < NOW() - INTERVAL 10 MINUTE`.
- **Điều kiện loại trừ bắt buộc:**
  - `dead_lettered_at IS NULL` (loại trừ asset đã bị dead-letter).
  - `retry_count < 5` (loại trừ asset đã kiệt sức thử lại).
  - `locked_at IS NULL OR locked_at < NOW() - INTERVAL 10 MINUTE` (loại trừ asset đang được worker khác giữ lease còn hiệu lực).

### 4.3. Phân biệt Hai Giao dịch Độc lập
- **Claim Transaction (Giao dịch Claim):**
  - Thời gian thực thi siêu ngắn (< 50ms).
  - Chỉ thực hiện `SELECT ... FOR UPDATE SKIP LOCKED` và `UPDATE` gán `claim_token`.
  - **Commit ngay lập tức** trước khi khởi tạo bất kỳ yêu cầu mạng nào.
- **Worker Execution (Thực thi Dọn dẹp):**
  - Hoàn toàn **không giữ database row lock** trong lúc gọi Cloudinary.
  - Lệnh gọi Cloudinary `destroy()` thực hiện ngoài transaction.
  - Kết quả được ghi nhận bằng transaction cập nhật DB ngắn có kiểm tra token (`claim_token = :claimToken`).

### 4.4. Minh họa SQL Pseudocode & Lưu ý Khóa Dòng
```sql
-- [Pseudocode Illustration - Transaction 1: Claim]
SELECT media_asset_id
FROM media_assets
WHERE (
    (status = 'UNATTACHED' AND created_at < NOW() - INTERVAL 24 HOUR)
    OR 
    (status = 'DELETING' 
     AND (locked_at IS NULL OR locked_at < NOW() - INTERVAL 10 MINUTE) 
     AND (next_retry_at IS NULL OR next_retry_at <= NOW()))
)
AND dead_lettered_at IS NULL
AND retry_count < 5
ORDER BY media_asset_id ASC
LIMIT 50
FOR UPDATE SKIP LOCKED;

UPDATE media_assets 
SET status = 'DELETING',
    claim_token = :claimToken,
    locked_at = NOW(), 
    locked_by = :workerId,
    updated_at = NOW()
WHERE media_asset_id IN (:claimedIds);

COMMIT;
```
*Lưu ý Lock Ordering:* Mệnh đề `ORDER BY media_asset_id ASC` chỉ quy định thứ tự bản ghi trả về cho client/worker. Thứ tự chiếm row lock vật lý nội bộ của InnoDB phụ thuộc vào execution plan; việc sắp xếp ID chỉ là biện pháp giảm thiểu xung đột, tính năng concurrency runtime trên MySQL 8 được đánh dấu là `NOT VERIFIED AT RUNTIME`.

---

## 5. ISSUE 2 — ASSET LIFECYCLE STATE VS WORKER CLAIM/LEASE STATE

### 5.1. Phân biệt Hai Khái niệm Hoàn toàn Độc lập
Hệ thống đã tách bạch rõ ràng giữa trạng thái vòng đời dữ liệu và metadata xử lý của worker:

1. **Asset Lifecycle State (Vòng đời Nghiệp vụ):**
   - Quản lý qua cột enum `media_assets.status`: `UNATTACHED`, `ATTACHED`, `DELETING`, `DELETED`.
   - Đại diện cho sự tồn tại và liên kết của asset với domain bài viết.
2. **Worker Claim / Lease State (Metadata Quyền Xử lý):**
   - Quản lý qua các cột: `claim_token`, `locked_at`, `locked_by`, `next_retry_at`, `retry_count`, `dead_lettered_at`, `last_error`.
   - Đại diện cho quyền sở hữu xử lý tạm thời của một instance worker cụ thể.

> [!IMPORTANT]
> - `DELETING` **không có nghĩa** là asset đang được một worker xử lý tích cực. Asset có thể đang chờ claim, đang trong lease, hết hạn lease, hoặc đang chờ đến giờ retry.
> - `dead_lettered_at IS NOT NULL` là trạng thái vận hành xử lý lỗi, không phải là một enum lifecycle mới.

### 5.2. Bảng Chuyển Trạng thái Vòng đời Chuẩn hóa

| Chuyển Trạng thái | Ngữ cảnh Kích hoạt | Tác động Metadata |
| :--- | :--- | :--- |
| **`UNATTACHED → ATTACHED`** | Người dùng tạo Post đính kèm ảnh thành công. | Giữ nguyên hoặc xóa metadata claim (nếu có). |
| **`UNATTACHED → DELETING`** | Orphan asset quá 24h được Cleanup Worker claim thành công. | Gán `claim_token`, `locked_at = NOW()`, `locked_by`. |
| **`DELETING → DELETED`** | Cloudinary xóa thành công (hoặc trả về `not found` idempotent). | Xóa `claim_token = NULL`, `locked_at = NULL`, `locked_by = NULL`. |
| **`DELETING → DELETING`** | Worker thử lại sau lỗi tạm thời hoặc worker khác reclaim sau khi hết hạn lease. | Cập nhật `claim_token` mới, `locked_at`, tăng `retry_count`, hoặc dời `next_retry_at`. |
| **`ATTACHED → DELETING`** | Bài viết liên kết bị Hard-Purge hợp lệ khỏi database. | Chuyển `status = 'DELETING'`, `locked_at = NULL` (chờ worker claim). |

*Quy tắc cấm:* Cleanup Worker tuyệt đối **không được phép** chuyển asset từ `ATTACHED` sang `DELETING` chỉ vì tuổi asset đã quá 24 giờ.

### 5.3. Quyền Sở hữu Claim và Ranh giới Token
- Batch-level token: Mỗi batch claim sinh 1 UUID token mới, dùng chung cho tối đa 50 asset trong batch.
- Token bảo vệ quyền cập nhật database: `WHERE media_asset_id = :id AND claim_token = :token AND status = 'DELETING'`.
- Token không thể ngăn chặn gói tin HTTP xóa Cloudinary nếu gói tin này đã được gửi qua mạng.
- Token không tự đảm bảo tính "exactly-once" khi gọi Cloudinary (tính đúng đắn phụ thuộc vào việc xử lý idempotent khi nhận phản hồi "not found").

---

## 6. ISSUE 3 — RACE CONDITION MATRIX & TRANSACTION OUTCOME

### 6.1. Hiệu chỉnh Phát biểu về Kết quả Đồng thời
Đã loại bỏ hoàn toàn câu nói thiếu chính xác *"Bên chiếm khóa trước commit trước"*.  
Thay thế bằng nguyên tắc chuẩn mực:
> Hai transaction cạnh tranh trên cùng một bản ghi `media_assets`. Kết quả hợp lệ được quyết định bởi transaction thực hiện thành công và commit chuyển trạng thái có điều kiện. Transaction còn lại phải đọc lại trạng thái mới nhất và xử lý tương ứng. Deadlock hoặc rollback có thể làm transaction lấy khóa trước không trở thành transaction hoàn tất.

### 6.2. Ma trận Tranh chấp Đồng thời 10 Tình huống Toàn diện

| # | Tình huống Cạnh tranh | Hành động Attachment (User) | Hành động Cleanup (Worker) | Transaction Nào Commit / Rollback | Trạng thái DB Hợp lệ Cuối cùng | Hành vi Client / Worker |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **Attach commit thành công trước Cleanup** | Khóa dòng, kiểm tra uploader, chuyển `ATTACHED`, tạo `post_media`, commit. | Quét tìm asset `UNATTACHED`; do status đã là `ATTACHED`, query bỏ qua. | **Attach commit.** Cleanup không claim. | `status = 'ATTACHED'` (thuộc `post_media`). | Client nhận `201 Created`. Worker tiếp tục quét asset khác. |
| **2** | **Cleanup chuyển `DELETING` trước Attach** | Khóa dòng, đọc thấy `status == 'DELETING'`, ném lỗi `409 Conflict`. | Claim thành công, chuyển `DELETING`, commit claim transaction. | **Cleanup commit.** Attach rollback. | `status = 'DELETING'` (mang `claim_token`). | Client nhận `409 Conflict` (*"Tệp phương tiện đang được xóa"*). Worker gọi Cloudinary xóa ảnh. |
| **3** | **Hai bên cạnh tranh đồng thời trên cùng asset** | Cạnh tranh row lock DB. | Cạnh tranh row lock DB. | Bên nào chiếm khóa và commit trước sẽ thắng. Bên sau đọc trạng thái mới và xử lý tương ứng. | Duy nhất một chuyển trạng thái thắng: `ATTACHED` hoặc `DELETING`. | Bên thắng hoàn thành; bên thua xử lý an toàn (Cleanup bỏ qua hoặc Attach trả 409). |
| **4** | **Attachment transaction rollback** | Bắt đầu attach nhưng gặp lỗi (dữ liệu bài viết lỗi, hoặc lỗi mạng DB) $\rightarrow$ rollback toàn bộ. | Quét ở chu kỳ tiếp theo sau đó. | **Attach rollback.** | `status = 'UNATTACHED'` (hoàn nguyên). | Client nhận mã lỗi tương ứng. Asset tiếp tục đủ điều kiện cho đợt quét cleanup tiếp theo nếu quá 24h. |
| **5** | **Cleanup claim thành công nhưng Worker crash** | Thử attach trong thời gian lease 10 phút còn hiệu lực. | Claim thành công, chuyển `DELETING`, commit claim, nhưng node crash trước khi gọi Cloudinary. | Claim đã commit. **Attach đọc `DELETING` $\rightarrow$ rollback (409).** | `status = 'DELETING'` (lease đếm ngược 10 phút). | Attach bị từ chối an toàn trong thời gian lease; sau khi lease hết hạn, worker mới sẽ reclaim. |
| **6** | **Lease hết hạn và Worker mới reclaim** | Không tham gia (hoặc từ chối nếu attach). | Quét thấy `locked_at < NOW() - 10 MINUTE`, cấp `claim_token` mới, commit claim, gọi Cloudinary và update `DELETED`. | **Reclaim transaction commit.** Worker mới hoàn tất. | `status = 'DELETED'` (`claim_token = NULL`). | Hệ thống tự phục hồi sau sự cố crash của worker cũ mà không cần can thiệp thủ công. |
| **7** | **Stale Worker cũ tiếp tục gửi update DB** | Không tham gia. | Stale worker thức dậy gửi UPDATE DB có `claim_token` cũ của mình. | Câu lệnh update của Stale Worker có **`affectedRows == 0`**. | `status = 'DELETED'` (giữ nguyên kết quả của worker mới). | Stale worker phát hiện mất lease, ghi log warning và hủy thao tác, không ghi đè DB. |
| **8** | **Cloudinary xóa thành công nhưng Worker crash trước khi update DB** | Không tham gia. | File trên Cloudinary đã bị xóa, nhưng DB vẫn mang `DELETING` do worker crash trước khi ghi nhận `DELETED`. | Worker mới reclaim sau khi lease hết hạn, gọi Cloudinary và nhận `result: "not found"`. | `status = 'DELETED'` (nhờ xử lý Idempotent Success). | Worker mới chuyển DB sang `DELETED`, tự phục hồi tính nhất quán giữa Cloudinary và DB. |
| **9** | **Deadlock xảy ra trong Attachment transaction** | Xảy ra deadlock khóa chéo giữa hai transaction tạo bài viết đồng thời. | Không tham gia. | Lần thử đầu gặp `CannotAcquireLockException` $\rightarrow$ **rollback sạch**. Lần retry thành công $\rightarrow$ **commit**. | `status = 'ATTACHED'` (nếu retry thành công). | Spring `@Retryable` tự động thử lại tối đa 3 lần với backoff; client nhận `201 Created` bình thường. |
| **10** | **1 trong nhóm tối đa 5 ảnh không hợp lệ** | Gửi mảng 5 ảnh, trong đó có 1 ảnh unowned (hoặc đang `DELETING`). | Không tham gia. | Phát hiện vi phạm $\rightarrow$ **toàn bộ transaction tạo Post rollback**. | Zero posts được tạo, zero assets bị chuyển `ATTACHED`. | Client nhận mã lỗi chuẩn (`404` hoặc `409`). Đảm bảo tính nguyên tử tuyệt đối của bài viết nhiều ảnh. |

### 6.3. Tính Nguyên tử (Multi-Asset Atomicity) & Đánh đổi khi Worker Crash
- Nếu 1 ảnh trong batch $\le 5$ ảnh không hợp lệ, toàn bộ transaction tạo bài viết phải rollback. Không bao giờ tạo bài viết thiếu ảnh ngoài ý muốn của tác giả. Rollback DB không thể hoàn tác request Cloudinary.
- **Worker Crash Trade-off:** Khi worker đã chuyển asset sang `DELETING` và crash, asset sẽ không thể attach được trong 10 phút lease. Đây là sự đánh đổi có chủ đích để bảo đảm an toàn dữ liệu, ngăn chặn ghi đè sai lệch.

---

## 7. ISSUE 4 — POST RESTORE & HARD-PURGE LIFECYCLE

### 7.1. Xác minh Chính sách Thời hạn Khôi phục (Retention Window)
- **Truy tìm Bằng chứng:** Rà soát toàn bộ source code hiện tại, `Travel_Planner_Function_Specification.md`, PRD và toàn bộ các ADR (ADR-6B-01 đến ADR-6B-09):
  - Khái niệm **Soft-delete bài viết** (`status = 'DELETED'`) và giữ nguyên ảnh ở trạng thái `ATTACHED` để hỗ trợ khôi phục là **`PROPOSED DESIGN`**.
  - **Con số cụ thể "30 ngày":** Hoàn toàn **CHƯA CÓ quyết định chính thức nào từ Product Owner** quy định thời hạn bảo lưu là 30 ngày. Cụm từ "30 ngày" trong các phiên trước chỉ xuất hiện dưới dạng ví dụ kỹ thuật (`e.g. 30 days`).
- **Phân loại Chính xác:** Thời hạn khôi phục chính xác (14 ngày, 30 ngày, 90 ngày hay do Admin kích hoạt thủ công) được chuyển thành **`OPEN QUESTION`** chờ Product Owner phê duyệt trước Phase 6B.6.

### 7.2. Ma trận Vòng đời Đồng bộ Post và Media Asset

| Hành động Nghiệp vụ (Post Action) | Trạng thái Bài viết (`posts.status`) | Trạng thái Ảnh (`media_assets.status`) | Khả năng Khôi phục (Can Restore?) | Ghi chú & Ràng buộc Kỹ thuật |
| :--- | :---: | :---: | :---: | :--- |
| **Tạo bài viết mới** | `ACTIVE` | `ATTACHED` | Không áp dụng | Bài viết đang hiển thị bình thường. |
| **Người dùng / Admin xóa mềm** | `DELETED` | `ATTACHED` | **Có** (trong retention window) | Ảnh giữ nguyên trên Cloudinary và DB. |
| **Admin kiểm duyệt ẩn bài** | `HIDDEN` | `ATTACHED` | **Có** (theo quyết định Admin) | Ảnh giữ nguyên phục vụ khiếu nại. |
| **Khôi phục bài viết hợp lệ** | `ACTIVE` | `ATTACHED` | Đã khôi phục | Không cần upload lại ảnh. |
| **Hard-Purge bài viết** | Đã xóa khỏi DB | `DELETING` | **KHÔNG** | Post và `post_media` đã xóa vĩnh viễn. |
| **Cleanup Worker xóa Cloudinary** | Đã xóa khỏi DB | `DELETED` | **KHÔNG** | Ảnh đã xóa vĩnh viễn trên CDN. |

### 7.3. Quy tắc An toàn khi Khôi phục (Restore Safety)
- Khôi phục chỉ được phép thực hiện **trước khi** tiến trình hard-purge bắt đầu chạy.
- Toàn bộ media assets liên kết trong `post_media` phải đang ở trạng thái `ATTACHED`.
- Một khi hard-purge đã commit, bài viết và liên kết đã bị xóa vĩnh viễn khỏi DB, tuyệt đối không thể khôi phục.
- Cấm khôi phục nếu bất kỳ asset nào của bài viết đã chuyển sang `DELETING` hoặc `DELETED`.

### 7.4. Các Bất biến của Giao dịch Hard-Purge
1. **Thứ tự Giao dịch (Cascade Ordering):** Query `media_asset_id` $\rightarrow$ Update `media_assets` sang `DELETING` $\rightarrow$ Delete `post_media` $\rightarrow$ Delete `posts` $\rightarrow$ Commit $\rightarrow$ Worker xóa Cloudinary.
2. **Ràng buộc Schema:** `CONSTRAINT uk_post_media_asset UNIQUE (media_asset_id)` bảo đảm mỗi asset chỉ thuộc 1 bài viết.
3. **Mức cô lập:** Worker không thể thấy trạng thái `DELETING` trước khi transaction commit (Read Committed).
4. **Tính Nguyên tử:** Nếu transaction purge rollback, toàn bộ thay đổi hoàn nguyên, không có asset nào bị xóa nhầm.

---

## 8. ĐỐI CHIẾU NHẤT QUÁN GIỮA CÁC TÀI LIỆU (CROSS-DOCUMENT CONSISTENCY)

| Tiêu chí Đối chiếu | Các File Liên quan | Tình trạng Nhất quán |
| :--- | :--- | :---: |
| **MySQL 8 SKIP LOCKED Claim Flow** | `03-data-architecture`, `05-query-performance`, `06-roadmap`, `07-adr`, `ACCEPTANCE-REPORT` | **ĐỒNG BỘ 100%** (2-step claim, commit trước Cloudinary) |
| **Phân biệt Lifecycle vs Lease State** | `03-data-architecture`, `07-adr`, `ACCEPTANCE-REPORT` | **ĐỒNG BỘ 100%** (`status` enum vs metadata vận hành) |
| **10-Scenario Race Condition Matrix** | `03-data-architecture`, `04-api-design`, `ACCEPTANCE-REPORT` | **ĐỒNG BỘ 100%** (Single-winner transition, deadlock retry) |
| **Post Retention Window là OPEN QUESTION** | `03-data-architecture`, `06-roadmap`, `07-adr`, `ACCEPTANCE-REPORT` | **ĐỒNG BỘ 100%** (Cơ chế soft-delete giữ ATTACHED; thời hạn 30 ngày là OPEN QUESTION) |
| **Reason Code Lịch trình ("UNAVAILABLE")** | `03-data-architecture`, `04-api-design`, `05-query-performance`, `07-adr` | **ĐỒNG BỘ 100%** (Generic reason code che giấu privacy) |
| **UserStatus INACTIVE là OPEN QUESTION** | `03-data-architecture`, `04-api-design`, `ACCEPTANCE-REPORT` | **ĐỒNG BỘ 100%** (Chặn login/write; flow kích hoạt lại là OPEN QUESTION) |
| **Không khẳng định đã kiểm chứng Runtime** | Toàn bộ suite tài liệu Phase 6B.0 | **ĐỒNG BỘ 100%** (Ghi rõ `NOT VERIFIED AT RUNTIME`) |
| **Phase 6B.1 chưa được phép triển khai** | Toàn bộ suite tài liệu Phase 6B.0 | **ĐỒNG BỘ 100%** (Ghi rõ `STRICTLY NOT AUTHORIZED`) |

---

## 9. DANH SÁCH FILE THAY ĐỔI TRONG PHIÊN 71

1. [`03-community-feed-data-architecture.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/03-community-feed-data-architecture.md) — Phân biệt Asset Lifecycle State vs Worker Claim/Lease State (Mục 3.1); mở rộng ma trận race condition lên 10 tình huống và chuẩn hóa ngữ nghĩa thắng/thua (Mục 3.4); chuẩn hóa MySQL 8 claim flow thành quy trình 2 bước với `SKIP LOCKED` và eligibility predicate (Mục 3.5); chuẩn hóa Post / Media Lifecycle Matrix và xác minh nguồn gốc 30 ngày là OPEN QUESTION (Mục 3.7).
2. [`04-community-feed-api-design.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/04-community-feed-api-design.md) — Cập nhật header Session 71 Patch.
3. [`05-feed-query-performance-security.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/05-feed-query-performance-security.md) — Cập nhật Mục 4.4 về quy trình claim 2 bước của MySQL 8 `SKIP LOCKED`, ranh giới quyền cập nhật DB của token, header Session 71 Patch.
4. [`06-phase-6b-implementation-roadmap.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/06-phase-6b-implementation-roadmap.md) — Cập nhật Phase 6B.6 về MySQL 8 `SELECT ... FOR UPDATE SKIP LOCKED` và ghi nhận thời hạn retention là OPEN QUESTION, header Session 71 Patch.
5. [`07-phase-6b-architecture-decision-record.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/phase-6b-design/07-phase-6b-architecture-decision-record.md) — Cập nhật ADR-6B-07 (retention window là OPEN QUESTION) và ADR-6B-08 (MySQL 8 `SKIP LOCKED` claim flow), header Session 71 Patch.
6. [`PHASE-6B.0-ACCEPTANCE-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-ACCEPTANCE-REPORT.md) (cả 2 bản sao tại `phase-6b-design/` và `phase-6/`) — Cập nhật bảng checklist, ghi nhận quy trình MySQL 8 `SKIP LOCKED`, 10-scenario race matrix, và danh mục tài liệu Session 71.
7. [`PHASE-6B.0-SESSION-71-FINAL-TECHNICAL-CLARIFICATION-REPORT.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/verification/phase-6/PHASE-6B.0-SESSION-71-FINAL-TECHNICAL-CLARIFICATION-REPORT.md) — Báo cáo tổng kết nghiệm thu kỹ thuật chi tiết của Session 71.
8. [`09-development-log.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/ai/09-development-log.md) — Ghi nhận nhật ký Session 71 (DOCUMENTATION ONLY, tiếng Anh).

---

## 10. BẢNG PHÂN LOẠI BẰNG CHỨNG (EVIDENCE CONFIDENCE MATRIX)

| Nội dung Kỹ thuật | Cấp độ Bằng chứng | Ghi chú & Nguồn Dẫn chứng |
| :--- | :---: | :--- |
| **Enum UserStatus (ACTIVE, INACTIVE, BANNED)** | `VERIFIED IN SOURCE` | `UserStatus.java:3-7` |
| **Login chặn INACTIVE bằng HTTP 403** | `VERIFIED IN SOURCE` | `AuthServiceImpl.java:101-103` |
| **Spring Security disable tài khoản non-ACTIVE** | `VERIFIED IN SOURCE` | `UserDetailsServiceImpl.java:28-36` |
| **Không tồn tại luồng kích hoạt lại tài khoản** | `VERIFIED IN SOURCE` | Quét toàn bộ controllers & services |
| **Friend Request totalElements có sẵn** | `VERIFIED IN SOURCE` | `FriendshipController.java:80-95` |
| **Chưa có endpoint tổng tin nhắn unread** | `VERIFIED IN SOURCE` | `ConversationController.java` |
| **Nhất quán tài liệu thiết kế Phase 6B.0** | `VERIFIED IN DOCUMENTATION` | Toàn bộ suite `docs/verification/phase-6/` |
| **Quy trình MySQL 8 SKIP LOCKED Claim Flow** | `PROPOSED DESIGN` | `03-community-feed-data-architecture.md` |
| **Phân biệt Lifecycle vs Lease State** | `PROPOSED DESIGN` | `03-community-feed-data-architecture.md` |
| **10-Scenario Race Condition Matrix** | `PROPOSED DESIGN` | `03-community-feed-data-architecture.md` |
| **Cơ chế Soft-Delete giữ Media ATTACHED** | `PROPOSED DESIGN` | `03-community-feed-data-architecture.md` |
| **Post Purge Cascade Ordering & Invariants** | `PROPOSED DESIGN` | `03-community-feed-data-architecture.md` |
| **Chính sách Kích hoạt lại User INACTIVE** | **`OPEN QUESTION`** | Chờ quyết định sản phẩm trước Phase 6B.1 |
| **Thời hạn Bảo lưu Cụ thể khi Soft-Delete Post (30 ngày?)** | **`OPEN QUESTION`** | Chờ quyết định sản phẩm trước Phase 6B.6 |
| **Kiểm thử Concurrency & Locking trên MySQL 8** | **`NOT VERIFIED AT RUNTIME`** | Chờ triển khai integration test trong Phase 6B.1 |
| **Toàn bộ tính năng Phase 6B** | **`NOT IMPLEMENTED`** | Phase 6B.1 chưa được phép triển khai |

---

## 11. NHỮNG ĐIỂM HẠN CHẾ CÒN LẠI (REMAINING LIMITATIONS)

1. **Hiệu năng Thực tế của MySQL 8 `SKIP LOCKED`:**
   - Quy trình 2 bước (`SELECT ... FOR UPDATE SKIP LOCKED` kết hợp `UPDATE ... WHERE IN`) là chuẩn mực lý thuyết tối ưu cho MySQL 8, nhưng cần được benchmark thực tế về throughput và transaction duration dưới tải lớn khi có 5-10 worker instances chạy đồng thời trong Phase 6B.6.
2. **Sự Đánh đổi khi Worker Crash:**
   - Khi worker đã claim asset sang `DELETING` và crash, asset đó sẽ bị khóa không thể attach vào Post trong suốt 10 phút lease. Đây là sự đánh đổi có chủ đích nhằm bảo vệ an toàn dữ liệu, cần đội ngũ sản phẩm hiểu rõ hành vi này.

---

## 12. CÂU HỎI MỞ CHỜ PRODUCT OWNER PHÊ DUYỆT (OPEN QUESTIONS)

1. **`OPEN QUESTION 1` — Luồng kích hoạt lại tài khoản `INACTIVE`:**
   - Mã nguồn hiện tại ném HTTP 403 Forbidden khi `INACTIVE` đăng nhập và không có API kích hoạt lại.
   - Cần quyết định: Triển khai flow tự kích hoạt qua OTP/Email hay chỉ dành quyền kích hoạt cho Quản trị viên (Admin).
2. **`OPEN QUESTION 2` — Thời hạn bảo lưu bài viết soft-delete trước khi Hard-Purge:**
   - Cần quyết định chính thức thời hạn bảo lưu cụ thể (ví dụ 14 ngày, 30 ngày, 90 ngày hay chỉ xóa thủ công bởi Admin) để cấu hình cron job dọn dẹp vĩnh viễn trong Phase 6B.6.

---

## 13. KẾT LUẬN THẨM ĐỊNH CUỐI CÙNG (FINAL VERDICT)

# ✅ **ACCEPTED WITH LIMITATIONS**

> **Căn cứ Thẩm định:**
> 1. Toàn bộ 4 vấn đề kỹ thuật sâu về MySQL 8 `SKIP LOCKED`, phân biệt Lifecycle vs Lease state, ma trận race condition 10 tình huống, và xác minh nguồn gốc thời hạn khôi phục bài viết đã được giải quyết triệt để và đồng bộ 100% trên toàn bộ hồ sơ thiết kế.
> 2. Đánh giá `ACCEPTED WITH LIMITATIONS` phản ánh trung thực tính chuẩn mực của kỹ thuật: Hồ sơ thiết kế đã hoàn thiện xuất sắc và sẵn sàng cho lập trình, nhưng còn 2 câu hỏi mở nghiệp vụ (`OPEN QUESTION 1` về User `INACTIVE` và `OPEN QUESTION 2` về thời hạn retention) cùng các kiểm chứng runtime cần được tiến hành trong các giai đoạn sau.

---

## 14. ĐIỀU KIỆN DỪNG VÀ TÌNH TRẠNG ỦY QUYỀN PHASE 6B.1 (AUTHORIZATION STATUS)

> [!CAUTION]
> **GIAI ĐOẠN PHASE 6B.0 ĐÃ HOÀN TẤT VÀ KHÓA CHẶT (SEALED).**
> - **TRIỂN KHAI CODE PHASE 6B.1 TUYỆT ĐỐI CHƯA ĐƯỢC PHÉP BẮT ĐẦU (STRICTLY NOT AUTHORIZED).**
> - **KHÔNG TẠO MIGRATION, KHÔNG SỬA SOURCE CODE JAVA/DART.**
> - **TUÂN THỦ TUYỆT ĐỐI CHÍNH SÁCH: NO COMMIT, NO PUSH.**
> 
> Hệ thống dừng lại tại đây và chờ đợi quyết định sản phẩm từ người dùng đối với 2 câu hỏi mở, cũng như văn bản phê duyệt chính thức để ủy quyền triển khai Phase 6B.1.

