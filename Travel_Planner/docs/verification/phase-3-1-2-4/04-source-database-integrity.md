# KIỂM TOÁN TÍNH TOÀN VẸN TỆP NGUỒN VÀ CƠ SỞ DỮ LIỆU
## Phase 3.1.2.4 — Source & Database Integrity Audit

**Dự án:** Travel Planner  
**Mục tiêu:** Xác minh tính toàn vẹn vật lý và logic của tập dữ liệu Administrative Areas, đối soát từng bản ghi giữa source files và cơ sở dữ liệu MySQL, kiểm định mã băm (checksums), cơ chế concurrency và bảo toàn giao dịch.

---

## 1. THÔNG SỐ VẬT LÝ VÀ MÃ BĂM TỪNG TỆP DỮ LIỆU NGUỒN

Các tệp dữ liệu danh mục hành chính được lưu trữ tại `Travel_Planner/backend/src/main/resources/data/administrative/`:

| Tên tệp tin | Kích thước | Số dòng | Ký tự dòng | Encoding | SHA-256 Checksum độc lập |
|---|---|---|---|---|---|
| `metadata.json` | 2.276 bytes | 51 dòng | LF (`\n`) | UTF-8 | `c6bfae44fa44b5d628bbb30615ce512e6a5263ac2dd4db4d0964189214b9a27a` |
| `provinces.json` | 4.931 bytes | 240 dòng | CRLF (`\r\n`) | UTF-8 | `3a1fa97244882bc9548e295c2f739d651f71696e186b95a38a860ef3c9634a17` |
| `communes.json` | 473.956 bytes | 23.249 dòng | CRLF (`\r\n`) | UTF-8 | `fb0cd4e02348be791e5677323e9538b088f1d2f8dec939a353d7102d29b80638` |

### 1.1. Sequential Dataset SHA-256 (`DATASET_SHA256`)
- Phương pháp tính: Đọc tuần tự toàn bộ mảng byte của 3 tệp tin theo thứ tự `metadata.json` $\rightarrow$ `provinces.json` $\rightarrow$ `communes.json` thông qua bộ đệm 8KB của thuật toán `MessageDigest.getInstance("SHA-256")`.
- **Giá trị chuẩn xác:**
  $$\mathbf{8fa358a085cdc10e4533ef41a51ee02b8e2a81dd6b0cb642e44ab33f2b60b816}$$

### 1.2. Canonical Content Checksum v1 (`CANONICAL_CONTENT_CHECKSUM`)
- Phương pháp tính: Chuẩn hóa toàn bộ 3.355 thực thể thành chuỗi `code|name|area_type|parent_code`, sắp xếp theo thứ tự từ điển tăng dần theo `code`, thêm tiền tố phiên bản schema `v1\n` và tính SHA-256:
- **Giá trị chuẩn xác:**
  $$\mathbf{af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674}$$
- Giá trị này hoàn toàn độc lập với khoảng trắng, thứ tự JSON hay định dạng xuống dòng (`CRLF` vs `LF`).

---

## 2. KẾT QUẢ ĐỐI SOÁT TỪNG BẢN GHI GIỮA SOURCE VÀ CƠ SỞ DỮ LIỆU

Thực hiện kiểm tra đối sánh 1-1 trên toàn bộ 3.355 bản ghi giữa hai tệp `provinces.json` + `communes.json` và bảng `administrative_areas` trong MySQL (`travel_planner_test`):

```
Total rows in Source : 3355
Total rows in MySQL  : 3355
Missing rows in DB   : 0
Extra rows in DB     : 0
Field Discrepancies  : 0
Audit Result         : 100% MATCH
```

### 2.1. Kiểm tra các điều kiện bất biến (Database Invariants)
- **Mã hành chính trùng lặp (Duplicate codes):** **0** trường hợp (ràng buộc `UNIQUE KEY uk_admin_areas_code`).
- **Xã mồ côi (Orphan communes):** **0** trường hợp (100% bản ghi cấp xã có `parent_id` trỏ hợp lệ tới bản ghi cấp tỉnh).
- **Phân cấp 2 tầng nghiêm ngặt (2-tier hierarchy):** 
  - 34 đơn vị cấp tỉnh có `parent_id = NULL`.
  - 3.321 đơn vị cấp xã có `parent_id IS NOT NULL`.
  - 0 bản ghi có quan hệ vòng tròn (cycles).
- **Phân loại đơn vị hợp lệ:** 
  - `CENTRAL_CITY`: 9 bản ghi.
  - `PROVINCE`: 25 bản ghi.
  - `WARD`: 709 bản ghi.
  - `COMMUNE`: 2.599 bản ghi.
  - `SPECIAL_ZONE`: 13 bản ghi.

---

## 3. KIỂM THỬ KHẢ NĂNG CHẠY ĐỒNG THỜI (CONCURRENCY) VÀ IDEMPOTENCY

### 3.1. Khóa phân tán logic (MySQL Advisory Lock)
Migration runner sử dụng khóa logic phân tán thông qua hàm bản địa của MySQL:
`SELECT GET_LOCK('administrative_area_migration_lock', 10)`

- **Kiểm thử đa luồng (Multi-threaded Concurrency):**
  - Thực thi kiểm thử `testAdvisoryLock_TwoConnections_SecondConnectionBlocksOrTimesOut` và `testTwoIndependentRunners_ConcurrentExecution_OneAcquiresAndOtherWaitsOrBypasses`:
  - Luồng 1 chiếm khóa thành công (`GET_LOCK = 1`), bắt đầu quá trình kiểm tra/nạp.
  - Luồng 2 cạnh tranh khóa với timeout ngắn (1s) $\rightarrow$ nhận kết quả `GET_LOCK = 0` (chặn thành công mà không gây treo hệ thống hay deadlock).
  - Khi Luồng 1 giải phóng khóa (`RELEASE_LOCK`), Luồng 2 tiếp tục thực thi và kiểm tra thấy catalog đã up-to-date nên thoát an toàn trong dưới 5ms (Fast Bypass).

### 3.2. Tính lũy kế / Bất biến khi chạy lặp lại (Idempotency)
- Thực thi `testMigrationRunner_IsIdempotentOnRepeatedExecutions`:
  - Lần chạy 1: Nạp 3.355 bản ghi vào DB, lưu mã checksum `af6e22c8...` và `DATASET_SHA256`.
  - Lần chạy 2 (giả lập restart server): Runner đối chiếu checksum, phát hiện catalog đã cập nhật $\rightarrow$ bỏ qua nạp lại trong 3.2ms.
  - Kiểm tra số lượng bản ghi: Giữ nguyên 3.355.
  - Kiểm tra khóa chính `area_id`: Toàn bộ các giá trị ID nội bộ không bị thay đổi, bảo đảm an toàn tuyệt đối cho các bảng liên kết.

### 3.3. Cơ chế Tamper Detection (Phát hiện can thiệp trái phép)
- Khi can thiệp sửa đổi trực tiếp 1 trường dữ liệu trong MySQL (ví dụ: đổi tên Phường Ba Đình hoặc sửa `parent_id` của Đặc khu Phú Quý):
  - Phương thức `computeDatabaseCanonicalChecksum(conn)` tính toán checksum trực tiếp từ dữ liệu MySQL và phát hiện khác biệt với `af6e22c8...`.
  - Hệ thống ghi nhận mismatch, từ chối bypass và kích hoạt cơ chế sửa chữa đồng bộ dữ liệu.
- Mặc định, hệ thống **không bật chế độ tự động xóa hủy hoại (destructive auto-repair)**, bảo đảm an toàn dữ liệu và tính toàn vẹn quan hệ.

