# BÁO CÁO KIỂM TOÁN CHECKSUM, IMPORTER VÀ KHÓA TƯƠNG TRANH
## Technical Specification, Checksum Dual-Engine, Advisory Lock Concurrency & Database Healing

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3.1.2.3 — Final Administrative Catalog Correction & Acceptance Verification  
**Tài liệu:** `docs/verification/phase-3-1-2-3/06-checksum-importer-concurrency-integrity.md`  
**Ngày thực hiện:** 2026-11-11  

---

### 1. ĐẶC TẢ THÔNG SỐ VẬT LÝ VÀ CHECKSUM TỪNG FILE NGUỒN (RAW DATASET METRICS)

Để đảm bảo tính minh bạch, các thông số vật lý của từng file nguồn JSON trong `backend/src/main/resources/data/administrative/` được ghi nhận độc lập và đầy đủ:

| Tên file nguồn | Đường dẫn tương đối | Dung lượng (Bytes) | Chuẩn mã hóa | Định dạng xuống dòng | SHA-256 Checksum độc lập |
|---|---|:---:|:---:|:---:|---|
| `metadata.json` | `data/administrative/metadata.json` | 2.276 | UTF-8 | LF (`\n`) | `c6bfae44fa44b5d628bbb30615ce512e6a5263ac2dd4db4d0964189214b9a27a` |
| `provinces.json` | `data/administrative/provinces.json` | 4.931 | UTF-8 | CRLF (`\r\n`) | `3a1fa97244882bc9548e295c2f739d651f71696e186b95a38a860ef3c9634a17` |
| `communes.json` | `data/administrative/communes.json` | 473.956 | UTF-8 | CRLF (`\r\n`) | `fb0cd4e02348be791e5677323e9538b088f1d2f8dec939a353d7102d29b80638` |

#### Quy cách Tính toán Sequential Concatenated SHA-256 (`DATASET_SHA256`):
- `AdministrativeAreaMigrationRunner.computeDatasetSha256()` đọc tuần tự luồng byte (`InputStream`) của 3 tệp theo thứ tự: `metadata.json` $\rightarrow$ `provinces.json` $\rightarrow$ `communes.json` vào cùng một đối tượng `java.security.MessageDigest("SHA-256")`.
- **Sequential Concatenated SHA-256:** `8fa358a085cdc10e4533ef41a51ee02b8e2a81dd6b0cb642e44ab33f2b60b816`.

---

### 2. THUẬT TOÁN CANONICAL CONTENT CHECKSUM (PHIÊN BẢN v1)

Thuật toán Canonical Content Checksum v1 được thiết kế độc lập với thứ tự các bản ghi trong file JSON và định dạng xuống dòng, cho phép đối chiếu trực tiếp giữa nội dung nguồn và dữ liệu thực tế đang lưu trong MySQL.

#### 2.1. Quy cách chuẩn hóa:
- Mỗi bản ghi đơn vị hành chính được trích xuất thành 4 trường:
  $$\text{entry} = \text{code.trim()} + \text{"|"} + \text{name.trim()} + \text{"|"} + \text{areaType.trim()} + \text{"|"} + \text{parentCode.trim()}$$
- Nếu `parentCode == null`, gán thành chuỗi rỗng `""`.
- Tập hợp toàn bộ 3.355 chuỗi (34 tỉnh + 3.321 xã) được sắp xếp theo thứ tự bảng chữ cái (`Collections.sort(entries)`).
- Băm `MessageDigest("SHA-256")`:
  1. Ghi tiền tố phiên bản: `"v1\n"`.
  2. Ghi từng dòng `entry + "\n"` theo chuẩn UTF-8.
- **Canonical Content Checksum v1:** `af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`.

#### 2.2. Kiểm định An toàn Kỹ thuật:
1. **Khử Khoảng trắng Thừa (`.trim()`):** Ngăn ngừa sai lệch checksum do trình soạn thảo chèn thêm khoảng trắng ở đầu hoặc cuối chuỗi.
2. **Yêu cầu Unicode NFC:** Đã kiểm thử chứng minh ký tự tiếng Việt dạng tổ hợp (NFD) và dựng sẵn (NFC) tạo ra mã byte khác nhau. Toàn bộ file JSON nguồn bắt buộc được chuẩn hóa NFC 100%.
3. **Chống Xung đột Ký tự Phân cách Pipe (`|`):** Đã kiểm thử tự động xác nhận 100% trong số 3.355 bản ghi, không có bất kỳ trường nào chứa ký tự `|`.
4. **Đối chiếu Trực tiếp Cơ sở Dữ liệu (Live DB Checksum):**
   - Phương thức `validator.computeDatabaseCanonicalChecksum(conn)` chạy câu truy vấn SQL:
     ```sql
     SELECT c.code, c.name, c.area_type, p.code AS parent_code
     FROM administrative_areas c
     LEFT JOIN administrative_areas p ON c.parent_id = p.area_id
     ```
   - Xây dựng danh sách chuỗi canonical trực tiếp từ các hàng trong MySQL và băm theo thuật toán trên.
   - Nếu ai đó sửa trực tiếp một ký tự trong database (ví dụ: sửa tên, sửa loại hình, sửa đơn vị cha), hệ thống sẽ phát hiện ngay sự sai lệch và kích hoạt quy trình tự sửa chữa (reconciliation).

---

### 3. KIỂM TOÁN KHÓA TƯƠNG TRANH VÀ AN TOÀN ĐA LUỒNG (CONCURRENCY HARDENING)

Đã triển khai và vượt qua 3 cấp độ kiểm thử tương tranh và chịu lỗi:

1. **Cấp độ Đa luồng JVM Thực sự (`testTwoIndependentRunners_ConcurrentExecution_OneAcquiresAndOtherWaitsOrBypasses`):**
   - Khởi tạo `ExecutorService` gồm 2 luồng worker song song, cùng kích hoạt `migrateAndImport()` trên 2 instance runner độc lập.
   - Luồng 1 giành được `administrative_area_migration_lock` và thực thi migration.
   - Luồng 2 cạnh tranh lock và bị chặn chờ. Sau khi Luồng 1 giải phóng lock, Luồng 2 lấy lock và lập tức kiểm tra `isCatalogUpToDate() == true` rồi thoát an toàn (bypass).
   - Kết quả: Không có lỗi xung đột, không có dữ liệu trùng lặp.
2. **Cấp độ 2 JDBC Connection Cạnh tranh Advisory Lock (`testAdvisoryLock_TwoConnections_SecondConnectionBlocksOrTimesOut`):**
   - Connection 1 gọi `GET_LOCK('administrative_area_migration_lock', 10)` thành công.
   - Connection 2 gọi `GET_LOCK(..., 1)` trả về `0` (bị khóa, không thể chiếm dụng).
   - Connection 1 gọi `RELEASE_LOCK(...)`.
   - Connection 2 gọi lại và lấy được lock.
3. **Cấp độ Phát hiện Can thiệp DB và Tự Khôi phục (`testDatabaseCorruption_TamperProvinceNameAndVerifyRejectionAndRestoration`):**
   - Giả lập hành vi can thiệp trái phép: `UPDATE administrative_areas SET name = 'Thành phố Bắc Ninh Sửa' WHERE code = '24'`.
   - `isCatalogUpToDate()` so sánh live DB checksum với source checksum $\rightarrow$ phát hiện sai lệch và từ chối bypass.
   - Runner thực thi reconciliation: khôi phục nguyên vẹn dữ liệu chuẩn mà không làm mất tính toàn vẹn khóa ngoại.

---

### 4. BẢO TỒN DỮ LIỆU NGHIỆP VỤ (PLACE & ACTIVITY INVARIANTS)

Đã kiểm tra trực tiếp trên cơ sở dữ liệu `travel_planner`:
- **Bảng `places`:** Đúng 24 bản ghi. Cột `administrative_area_id` không tồn tại (chưa thêm trong Phase 3.1).
- **Bảng `activities`:** Đúng 121 bản ghi (111 linked tới `canonical_place_id`, 10 free-form). Snapshot vị trí và tọa độ hoàn toàn nguyên vẹn.
