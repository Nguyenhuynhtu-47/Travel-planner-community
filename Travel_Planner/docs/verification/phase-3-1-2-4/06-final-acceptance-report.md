# BÁO CÁO NGHIỆM THU KỸ THUẬT CUỐI CÙNG — PHASE 3.1.2.4
## FINAL ADMINISTRATIVE CATALOG INTEGRITY & ACCEPTANCE REPORT

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3.1.2.4 — Administrative Catalog Data Integrity Remediation  
**Tài liệu tham chiếu chuẩn:** `docs/verification/phase-3-1-2-4/00-canonical-correction-reference.md`  
**Mốc thời gian snapshot:** 2026-09-20  
**Ngày thực hiện kiểm toán:** 2026-11-11  

---

## 1. KẾT LUẬN NGHIỆM THU (ACCEPTANCE DECISION)

### Quyết định nghiệm thu: **ACCEPTED WITH EXPLICIT LIMITATIONS**
*(Chấp thuận nghiệm thu kỹ thuật với các giới hạn dữ liệu và điều kiện kích hoạt được ghi nhận tường minh)*

### Lý do nghiệm thu có điều kiện (Explicit Limitations):
1. **12 đơn vị cấp xã tại Bắc Ninh chưa xác minh sơ cấp (Primary Document Blocker):** Do phụ lục số hóa chính thức của Nghị quyết 388/NQ-UBTVQH16 chưa có trong source bundle của dự án, 12 đơn vị này được đánh dấu `UNVERIFIED_SOURCE_DOCUMENT_MISSING` và **bị chặn (blocked) không được tham gia vào Place Backfill** trong Phase 3.2 cho tới khi thu thập được toàn văn phụ lục.
2. **3.276 đơn vị cấp xã đối chiếu thứ cấp:** Chiếm 98.65% số đơn vị cấp xã, được đối soát toàn vẹn thông qua cơ sở dữ liệu mở của Tổng cục Thống kê (GSO) và Quyết định số 19/2025/QĐ-TTg.
3. **13 đặc khu hành chính (`SPECIAL_ZONE`):** Đã chuẩn hóa 100% đơn vị cấp tỉnh quản lý (Lâm Đồng, TP.HCM, An Giang,...), tuy nhiên cần xây dựng cơ chế routing và search phù hợp ở các giai đoạn sau do đặc thù địa giới hải đảo.

### Quyết định chuyển tiếp:
Hệ thống **ĐỦ ĐIỀU KIỆN TIÊN QUYẾT** để mở khóa và bắt đầu triển khai **Phase 3.2: Places – Administrative Area Integration** theo các nguyên tắc an toàn nghiêm ngặt.

---

## 2. TỔNG HỢP CÁC HIỆU CHỈNH ĐÃ THỰC HIỆN (VERIFIED CORRECTIONS)

| Hạng mục | Trạng thái trước hiệu chỉnh | Trạng thái sau hiệu chỉnh (Phase 3.1.2.4) |
|---|---|---|
| **Phân loại 34 đơn vị cấp tỉnh** | Có dấu hiệu nhắc lại tên tỉnh cũ ở báo cáo | **Chính xác 9 CENTRAL_CITY và 25 PROVINCE**; 0 tên tỉnh cũ; đối chiếu 100% pháp lý sơ cấp. |
| **10 Phường Đồng Nai (NQ 237)** | Báo cáo cũ liệt kê 10 phường sai (Long Hưng, Phước Tân,...) với mã giả định | **Đã sửa sang 10 phường chính thức** (Trảng Bom, Long Thành, Trị An, Nhơn Trạch, Tân Khai, Xuân Lộc, Tân Phú, Lộc Ninh, Dầu Giây, Đồng Phú) với mã chuẩn GSO. |
| **12 Phường Bắc Ninh (NQ 388)** | Báo cáo cũ tuyên bố xác minh sơ cấp dựa trên danh sách chưa có căn cứ phụ lục | **Rút lại xác minh sơ cấp**; gán cờ `UNVERIFIED_SOURCE_DOCUMENT_MISSING`; thiết lập rào cản ngăn chặn Place Backfill. |
| **Quan hệ cha của 5 Đặc khu** | Còn phụ thuộc vào các nhãn tỉnh cũ (Bình Thuận, Bà Rịa-Vũng Tàu, Kiên Giang) | **Đã sửa sang tỉnh cha mới sau sắp xếp**: Phú Quý $\rightarrow$ Lâm Đồng (`68`), Côn Đảo $\rightarrow$ TP.HCM (`79`), Phú Quốc, Thổ Châu, Kiên Hải $\rightarrow$ An Giang (`91`). |
| **Ngày ban hành các Nghị quyết** | Nhầm lẫn ngày làm việc của UBTVQH/Kỳ họp thành ngày ký | **Đã chuẩn hóa ngày ký ban hành chính thức**: NQ 30 (24/04/2026), NQ 36 (24/08/2026), NQ 39 (24/08/2026), NQ 237 (14/04/2026). |
| **Mã băm dữ liệu (Checksums)** | Nhầm lẫn giữa file hash tuần tự và Canonical Checksum | **Bóc tách rành mạch**: 3 file hashes độc lập, `DATASET_SHA256` (`8fa358a0...`) và `Canonical Content Checksum v1` (`af6e22c8...`). |
| **Đối soát cơ sở dữ liệu** | Chỉ kiểm tra số lượng bản ghi tổng quát | **Đối soát 1-1 từng bản ghi**: 3.355 bản ghi MySQL khớp 100% với JSON tệp nguồn, 0 sai lệch trường. |

---

## 3. CÁC BẢN GHI CHƯA XÁC MINH VÀ RÀO CẢN DỮ LIỆU (UNRESOLVED RECORDS & BLOCKERS)

Danh sách 12 đơn vị cấp xã tại Bắc Ninh bị chặn và đánh dấu `UNVERIFIED_SOURCE_DOCUMENT_MISSING`:
- `07294`: Phường Bố Hạ
- `07375`: Phường Lạng Giang
- `07399`: Phường Kép
- `07444`: Phường Lục Nam
- `07840`: Phường Hiệp Hoà
- `09193`: Phường Yên Phong
- `09292`: Phường Phù Lãng
- `09313`: Phường Chi Lăng
- `09319`: Phường Tiên Du
- `09454`: Phường Gia Bình
- `09475`: Phường Nhân Thắng
- `09496`: Phường Lương Tài

### Quy định kiểm soát tại Phase 3.2:
1. Khi thực hiện liên kết địa giới hành chính (`PlaceAdministrativeAreaResolverService`), nếu địa chỉ của một địa điểm (Place) thuộc tỉnh Bắc Ninh chứa các tên gọi trên, dịch vụ **phải gán `administrative_area_id = NULL`** và ghi nhận cảnh báo `UNRESOLVED_AREA`.
2. Tuyệt đối không tự ý gán ID của các bản ghi chưa xác minh này vào bảng `places`.

---

## 4. TỔNG HỢP THAY ĐỔI DỮ LIỆU VÀ MÃ NGUỒN (CHANGES SUMMARY)

### 4.1. Thay đổi dữ liệu & Tài liệu xác minh
- **Artifacts mới tại `Travel_Planner/docs/verification/phase-3-1-2-4/`:**
  1. `01-canonical-correction-results.md`: Tổng hợp kết quả sửa đổi, biên niên sử pháp lý và rào cản Bắc Ninh.
  2. `02-province-level-reconciliation.csv`: Đối soát chi tiết 34 đơn vị cấp tỉnh (100% VERIFIED_PRIMARY).
  3. `03-commune-level-correction.csv`: Đối soát chi tiết 3.321 đơn vị cấp xã (33 PRIMARY, 12 UNVERIFIED, 3.276 SECONDARY).
  4. `04-source-database-integrity.md`: Thông số file nguồn, checksums và kết quả audit DB-Source.
  5. `05-place-activity-preservation.md`: Bằng chứng bảo tồn 100% dữ liệu Places (24) và Activities (121).
  6. `06-final-acceptance-report.md`: Báo cáo nghiệm thu kỹ thuật hoàn chỉnh.

### 4.2. Cập nhật tài liệu kiến trúc và tiến độ
- `Travel_Planner/docs/architecture/phase-3-administrative-data-sources.md`: Cập nhật kết quả hiệu chỉnh Phase 3.1.2.4.
- `Travel_Planner/docs/architecture/phase-3-administrative-area-design.md`: Ghi nhận rào cản Bắc Ninh và quy tắc kiểm soát Phase 3.2.
- `Travel_Planner/docs/plan/phase-3-implementation-roadmap.md`: Cập nhật tiến độ Phase 3.1.2.4 hoàn tất, mở khóa Phase 3.2.
- `Travel_Planner/docs/ai/12-project-status-and-next-steps.md`: Cập nhật trạng thái Phase 3.1.2.4 ACCEPTED WITH EXPLICIT LIMITATIONS.
- `Travel_Planner/docs/ai/09-development-log.md`: Bổ sung nhật ký Session 48 bằng tiếng Anh.

---

## 5. MA TRẬN KẾT QUẢ KIỂM THỬ THỰC TẾ (TEST EXECUTION MATRIX)

Tất cả các số liệu dưới đây được đo lường trực tiếp từ lần chạy kiểm thử thực tế trên hệ thống (không dùng lại số liệu cũ):

| Phân hệ kiểm thử | Công cụ / Lệnh | Tổng số bài test | Kết quả thực tế | Lỗi mới | Trạng thái |
|---|---|:---:|:---:|:---:|:---:|
| **Validator Unit Tests** | `mvnw test -Dtest=AdministrativeAreaValidatorTest` | 11 | 11 Passed | 0 | **PASS** |
| **Migration Runner Tests** | `mvnw test -Dtest=AdministrativeAreaMigrationRunnerTest` | 17 | 17 Passed | 0 | **PASS** |
| **Repository Tests** | `mvnw test -Dtest=AdministrativeAreaRepositoryTest` | 5 | 5 Passed | 0 | **PASS** |
| **Controller Tests** | `mvnw test -Dtest=AdministrativeAreaControllerTest` | 8 | 8 Passed | 0 | **PASS** |
| **Catalog Dedicated Suite** | *4 bộ test trên* | **41** | **41 Passed** | **0** | **100% PASS** |
| **Toàn bộ Backend Suite** | `mvnw test` | **362** | **362 Passed** | **0** | **100% PASS** |
| **Flutter Web Analyzer** | `flutter analyze` | — | 0 issues | 0 | **PASS (Exit 0)** |
| **Flutter Web Test Suite** | `flutter test` | **33** | **33 Passed** | **0** | **100% PASS** |
| **Flutter Mobile Analyzer** | `flutter analyze` | — | 39 infos (0 errors) | 0 | **BASELINE (Exit 1)** |
| **Flutter Mobile Test Suite** | `flutter test` | **367** | **364 Passed, 3 Failed** | **0** | **BASELINE (3 Known)** |
| **TỔNG KIỂM THỬ HỆ THỐNG** | — | **803 tests** | **800 Passed, 3 Baseline** | **0** | **STABLE** |

### Chi tiết 3 lỗi Baseline đã tồn tại từ Phase 2.1.1 (Không phải lỗi mới):
1. `explore_test.dart: Explore Data Models Tests CreatorSummary falls back to username when fullName is null or empty`
2. `rating_ui_layout_test.dart: 1. Rating Dialog - Layout & RenderFlex Overflow Prevention Dialog renders cleanly without RenderFlex overflow`
3. `rating_ui_layout_test.dart: 2. Section Order - Comments Section precedes Rating Section CommentsSection is rendered BEFORE RatingSection`

---

## 6. ĐIỀU KIỆN TIÊN QUYẾT VÀ NGUYÊN TẮC THIẾT KẾ CHO PHASE 3.2

Hệ thống được phép triển khai Phase 3.2 (Places – Administrative Area Integration) tuân thủ nghiêm ngặt các nguyên tắc sau:
1. **Schema Migration:** Bổ sung trường khóa ngoại `administrative_area_id BIGINT NULL` vào bảng `places` và quan hệ `@ManyToOne` trong entity `Place`. Không can thiệp hoặc sửa đổi bảng `activities`.
2. **Conservative Resolver:** Phân giải địa giới dựa trên tọa độ chính xác kết hợp chuẩn hóa tên chuỗi địa chỉ. Nếu không đủ độ tin cậy hoặc thuộc 12 đơn vị bị chặn tại Bắc Ninh, bắt buộc để `administrative_area_id = NULL`.
3. **Idempotent Backfill Runner:** Thiết kế backfill có kiểm tra trạng thái, ghi log chi tiết từng địa điểm được liên kết, và hỗ trợ rollback an toàn.
4. **Activity Snapshot Protection:** Snapshot địa chỉ và tọa độ của 121 activities hiện có phải được giữ nguyên vẹn tuyệt đối.

---
*Báo cáo nghiệm thu Phase 3.1.2.4 hoàn tất với đầy đủ bằng chứng kiểm toán kỹ thuật và quản trị rủi ro.*

