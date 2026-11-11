# BÁO CÁO KIỂM CHỨNG CANONICAL CHECKSUM V1 & TOÀN VẸN CƠ SỞ DỮ LIỆU
## Verification of Canonical Checksum v1, DB Corruption Detection & Multithreaded Concurrency

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3.1.2.2 — Administrative Catalog Legal & Data Remediation  
**Tài liệu:** `docs/verification/phase-3-1-2-2/05-checksum-and-database-integrity.md`  
**Ngày thực hiện:** 2026-11-11  
**Mốc snapshot:** 2026-09-20  

---

### 1. ĐẶC TẢ & KIỂM TOÁN THUẬT TOÁN CANONICAL CONTENT CHECKSUM V1

Để đảm bảo tính toàn vẹn nội dung của Administrative Areas Catalog độc lập với định dạng file vật lý JSON (khoảng trắng, thứ tự key, ngắt dòng CRLF/LF), Travel Planner triển khai thuật toán **Canonical Content Checksum v1**.

#### 1.1. Quy cách Kỹ thuật Serialization
- **Thuật toán băm:** SHA-256 (`java.security.MessageDigest.getInstance("SHA-256")`).
- **Mã hóa chuỗi:** `StandardCharsets.UTF_8`.
- **Header phiên bản (Schema Prefix):** Nạp chuỗi `"v1\n"` đầu tiên vào digest.
- **Quy tắc chuẩn hóa dòng (Canonical Line Format):**
  ```text
  ${code.trim()}|${name.trim()}|${areaType.trim()}|${parentCode != null ? parentCode.trim() : ""}\n
  ```
- **Thứ tự chuẩn hóa (Canonical Sorting):** Toàn bộ danh sách 3.355 dòng (34 cấp tỉnh và 3.321 cấp cơ sở) được sắp xếp theo thứ tự từ điển (`Collections.sort(entries)`, ASCII / lexicographical order) trước khi đưa vào MessageDigest.

#### 1.2. Các Giá trị Mã Băm Chính thức (Snapshot 20/09/2026 Hiệu chỉnh)
Sau khi chuẩn hóa 3 thành phố trực thuộc Trung ương (Đồng Nai, Quảng Ninh, Bắc Ninh) và 22 phường mới:
- **Raw Dataset SHA-256 (3 file JSON):**
  `8fa358a085cdc10e4533ef41a51ee02b8e2a81dd6b0cb642e44ab33f2b60b816`
- **Canonical Content Checksum v1:**
  `af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`

---

### 2. PHÂN TÍCH RỦI RO & ĐẶC TÍNH SERIALIZATION (SERIALIZATION AUDIT)

#### 2.1. Hành vi của Phương thức `.trim()`
- **Thực tế mã nguồn:** Hàm chuẩn hóa gọi `.trim()` trên từng trường: `code.trim()`, `name.trim()`, `areaType.trim()`, `parentCode.trim()`.
- **Hệ quả kỹ thuật:**
  - Khoảng trắng thừa ở **đầu và cuối** chuỗi (Leading & Trailing Whitespace) sẽ bị loại bỏ trước khi tính mã băm. Do đó, nếu dữ liệu nguồn có thêm khoảng trắng ở đầu hoặc cuối (ví dụ: `"  Thành phố Hà Nội  "` so với `"Thành phố Hà Nội"`), checksum **sẽ KHÔNG thay đổi**.
  - Kiểm thử `testCanonicalChecksum_whitespaceBehavior()` đã chứng minh điều này.
  - Tuy nhiên, khoảng trắng **bên trong** chuỗi (Internal Whitespace, ví dụ: `"Hà   Nội"`) được giữ nguyên vẹn và **làm thay đổi checksum ngay lập tức**.
- **Kết luận:** Checksum không nhạy cảm tuyệt đối với khoảng trắng đầu/cuối, nhưng bảo toàn ngữ nghĩa nội dung thực tế.

#### 2.2. Kiểm tra Delimiter Collision & Control Characters
- **Ký tự phân cách:** Dấu gạch đứng `|`.
- **Rủi ro:** Nếu tên đơn vị hành chính chứa ký tự `|`, có thể dẫn đến việc nhập nhằng ranh giới trường (Field Boundary Ambiguity).
- **Kiểm chứng thực tế:**
  - Quét 100% bản ghi trong `provinces.json` và `communes.json`.
  - **Kết quả:** **0 bản ghi** chứa ký tự `|`, và **0 bản ghi** chứa các ký tự điều khiển ẩn (`\n`, `\r`, `\t`).
  - Toàn bộ dữ liệu nằm trong miền an toàn delimiter của schema v1.

#### 2.3. Xử lý Unicode (NFC vs NFD)
- **Thực tế mã nguồn:** `AdministrativeAreaValidator` hiện tại **không tự động gọi `Normalizer.normalize(..., Form.NFC)`**. Checksum được băm trực tiếp từ các chuỗi byte UTF-8 của Java String.
- **Rủi ro:** Tiếng Việt dựng sẵn (NFC) và tiếng Việt tổ hợp (NFD) có cùng mặt chữ trên màn hình nhưng khác biệt hoàn toàn về mã byte UTF-8. Nếu nạp chuỗi NFD, mã băm sẽ bị lệch.
- **Kiểm chứng thực tế:**
  - Toàn bộ dữ liệu nguồn trong `provinces.json` và `communes.json` đã được kiểm chứng chuẩn hóa **100% Unicode NFC**.
  - Test case `testCanonicalChecksum_nfcVsNfdBehavior()` xác nhận hệ thống có khả năng phân biệt sự khác nhau giữa NFC và NFD, giúp phát hiện ngay lập tức nguồn dữ liệu bị nhiễm ký tự tổ hợp.

#### 2.4. Tính tương đương giữa Null và Empty Parent
- Cấp tỉnh không có đơn vị cha: Trong Java `p.parentCode` là `null`, trong SQL `LEFT JOIN` trả về `parent_code` là `NULL`.
- Biểu thức `parentCode != null ? parentCode.trim() : ""` biến cả `null` và `""` thành chuỗi rỗng `""`.
- Đảm bảo tính nhất quán tuyệt đối giữa bộ nhớ Java, file JSON và hàng dữ liệu MySQL.

---

### 3. KẾT QUẢ THỰC NGHIỆM ĐỐI CHỨNG MÃ BĂM (TEST EVIDENCE)

Tất cả 11 kịch bản kiểm thử trong `AdministrativeAreaValidatorTest` đều đạt kết quả PASS:

| STT | Kịch bản kiểm thử | Hành vi Checksum | Kết quả đánh giá |
|:---:|:---|:---:|:---:|
| 1 | Hoán đổi thứ tự các bản ghi JSON | **KHÔNG ĐỔI** | PASS (Độc lập thứ tự nhờ sort) |
| 2 | Format lại JSON (khoảng trắng / xuống dòng) | **KHÔNG ĐỔI** | PASS (Bất biến trước JSON layout) |
| 3 | Sửa 1 ký tự trong tên ("Ba Đình" $\rightarrow$ "Phúc Xá") | **THAY ĐỔI** | PASS (Nhạy cảm với nội dung) |
| 4 | Sửa `parent_code` (Phú Quý đổi từ 68 sang 60) | **THAY ĐỔI** | PASS (Nhạy cảm với quan hệ cha-con) |
| 5 | Sửa `area_type` (WARD $\rightarrow$ COMMUNE) | **THAY ĐỔI** | PASS (Nhạy cảm với phân loại) |
| 6 | Xóa 1 bản ghi bất kỳ | **THAY ĐỔI** | PASS (Nhạy cảm với mất mát dữ liệu) |
| 7 | Thêm 1 bản ghi mới | **THAY ĐỔI** | PASS (Nhạy cảm với chèn bản ghi) |
| 8 | Khoảng trắng đầu/cuối chuỗi (`.trim()`) | **KHÔNG ĐỔI** | PASS (Được chuẩn hóa loại bỏ) |
| 9 | Khoảng trắng bên trong chuỗi ("Hà   Nội") | **THAY ĐỔI** | PASS (Nhạy cảm với cấu trúc từ) |
| 10 | Unicode NFC vs NFD | **THAY ĐỔI** | PASS (Phát hiện ký tự tổ hợp) |
| 11 | Null parent vs Blank parent ("   ") | **KHÔNG ĐỔI** | PASS (Chuẩn hóa về rỗng đồng nhất) |

---

### 4. XÁC MINH TOÀN VẸN DATABASE & PHÁT HIỆN CAN THIỆP (CORRUPTION DETECTION)

Kịch bản kiểm thử `testDatabaseCorruption_TamperProvinceNameAndVerifyRejectionAndRestoration` đã chứng minh khả năng phát hiện lỗi can thiệp trực tiếp vào MySQL:
1. **Bước 1 (Trạng thái bình thường):** Database được import chuẩn, live database checksum khớp `af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`, hàm `isCatalogUpToDate(...)` trả về `true`.
2. **Bước 2 (Can thiệp trái phép qua SQL):**
   ```sql
   UPDATE administrative_areas SET name = 'Thành phố Bắc Ninh Sửa' WHERE code = '24';
   ```
   *Lưu ý: Bảng `administrative_catalog_metadata` vẫn giữ nguyên giá trị checksum cũ.*
3. **Bước 3 (Phát hiện tức thì):**
   Hàm `migrationRunner.isCatalogUpToDate(...)` truy vấn lại toàn bộ 3.355 dòng trong database và tính Live Checksum:
   - Checksum thực tế của DB bị thay đổi thành `41919192df70d9d97c7108ee9f3a4c1dcd43608ba78d4f6b652e8313a7ce9d5e`.
   - `isCatalogUpToDate` phát hiện lệch mã băm và lập tức trả về **`false`**.
   - `auditDatabaseAgainstSource(...)` ghi nhận chính xác:
     ```text
     Record discrepancy for code 24: expected [24|Thành phố Bắc Ninh|CENTRAL_CITY|], found [24|Thành phố Bắc Ninh Sửa|CENTRAL_CITY|]
     ```
4. **Bước 4 (Tự động phục hồi):**
   Chạy lại `migrationRunner.migrateAndImport()`:
   - Runner thực hiện reconciliation, khôi phục lại tên chính thức `Thành phố Bắc Ninh` cho mã `24`.
   - Live checksum quay về đúng `af6e22c8...`, `isCatalogUpToDate(...)` trả về `true`.

---

### 5. KIỂM THỬ TƯƠNG TRANH ĐA TIẾN TRÌNH & ADVISORY LOCK (CONCURRENCY TESTING)

#### 5.1. Kiểm thử Khóa trên 2 Kết nối MySQL Độc lập
Đã thực thi `testAdvisoryLock_TwoConnections_SecondConnectionBlocksOrTimesOut`:
- Connection 1 lấy khóa `administrative_area_migration_lock`.
- Connection 2 thử lấy khóa với timeout 1 giây $\rightarrow$ Bị chặn hoàn toàn, trả về `0` (Timeout).
- Connection 1 nhả khóa $\rightarrow$ Connection 2 thử lại và lấy thành công (trả về `1`).
- Đảm bảo giải phóng khóa bằng khối `finally`.

#### 5.2. Kiểm thử 2 Migration Runner Chạy Đồng thời trên 2 Luồng Độc lập (Multithreaded Integration Test)
Đã thực thi kịch bản kiểm thử mới `testTwoIndependentRunners_ConcurrentExecution_OneAcquiresAndOtherWaitsOrBypasses`:
- Tạo 2 instance `AdministrativeAreaMigrationRunner` độc lập (`runner1` và `runner2`) cùng kết nối tới MySQL thông qua HikariCP Connection Pool.
- Sử dụng `java.util.concurrent.ExecutorService` và `CountDownLatch` để kích hoạt 2 runner thực thi migration **hoàn toàn đồng thời** trên 2 thread riêng biệt.
- **Kết quả thực nghiệm:**
  - Runner 1 chiếm được advisory lock trước và tiến hành kiểm tra/nạp dữ liệu.
  - Runner 2 chờ runner 1 nhả khóa, sau đó kiểm tra thấy dữ liệu đã được cập nhật (`isCatalogUpToDate = true`) và an toàn bypass mà không xảy ra race condition hay ghi đè trùng lặp.
  - Cả 2 luồng hoàn thành trong vòng $< 3\text{ giây}$ mà không phát sinh bất kỳ ngoại lệ nào.
  - Toàn bộ cơ sở dữ liệu sau khi chạy đồng thời đạt đúng 34 tỉnh/thành, 3.321 xã/phường và khớp mã băm Canonical Checksum chuẩn.

---

### 6. BẰNG CHỨNG DỮ LIỆU CƠ SỞ TRƯỚC VÀ SAU REMEDIATION (BEFORE / AFTER EVIDENCE)

| Cơ sở dữ liệu | Chỉ số / Bảng | Trước Remediation (Phase 3.1.2.1) | Sau Remediation (Phase 3.1.2.2) | Đánh giá |
|:---|:---|:---:|:---:|:---:|
| **`travel_planner` (Dev/Prod)** | `places` count | 24 | 24 | **Nguyên vẹn 100%** |
| | `activities` count | 121 | 121 | **Nguyên vẹn 100%** |
| | Linked activities (`canonical_place_id IS NOT NULL`) | 111 | 111 | **Nguyên vẹn 100%** |
| | Free-form activities (`canonical_place_id IS NULL`) | 10 | 10 | **Nguyên vẹn 100%** |
| | Cột `places.administrative_area_id` | Chưa có | Chưa có | **Đúng phạm vi Phase 3.1** |
| **`travel_planner_test` (Test)** | `administrative_areas` count | 3.355 | 3.355 | **Nhất quán** |
| | `COUNT_CENTRAL_CITY` | 6 | **9** | **Cập nhật chính xác** |
| | `COUNT_PROVINCE` | 28 | **25** | **Cập nhật chính xác** |
| | `COUNT_WARD` | 709 | 709 | **Nhất quán** |
| | `COUNT_COMMUNE` | 2.599 | 2.599 | **Nhất quán** |
| | `COUNT_SPECIAL_ZONE` | 13 | 13 | **Nhất quán** |
| | `CANONICAL_CONTENT_CHECKSUM` | `44a715a9...` | **`af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`** | **Mã băm chuẩn hóa mới** |
| | `DATASET_SHA256` | `eb5c213a...` | **`8fa358a085cdc10e4533ef41a51ee02b8e2a81dd6b0cb642e44ab33f2b60b816`** | **Mã băm file mới** |
