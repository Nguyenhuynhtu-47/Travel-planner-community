# PHASE 3 — LỘ TRÌNH TRIỂN KHAI TÍCH HỢP ĐỊA GIỚI HÀNH CHÍNH
## Detailed Implementation Roadmap: Phase 3.1 – 3.4

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3 — Administrative Areas Implementation  
**Tài liệu tham chiếu:**
- [`docs/architecture/phase-3-administrative-area-audit.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/architecture/phase-3-administrative-area-audit.md)
- [`docs/architecture/phase-3-administrative-area-design.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/architecture/phase-3-administrative-area-design.md)
- [`docs/architecture/phase-3-administrative-data-sources.md`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/docs/architecture/phase-3-administrative-data-sources.md)

---

## 1. Tổng quan Phân kỳ Triển khai

Lộ trình triển khai Phase 3 được chia làm 4 bước tuần tự, tuân thủ nghiêm ngặt nguyên tắc **Expand-Contract** và bảo toàn tính độc lập của Activity Location Snapshot:

```
[Phase 3.0: Audit & Architecture Design] (Hoàn thành)
                   |
                   v
[Phase 3.1: Administrative Areas Catalog] (Hoàn thành)
  - Schema: administrative_areas (code, name, normalized_name, area_type, status, parent_id)
  - Seeder: 34 tỉnh/TP TW + 3.321 xã/phường chuẩn GSO
  - Backend API: GET provinces, children, search (disambiguated), code detail
  - Testing: 19 new tests, 340/340 backend test suite PASS
                   |
                   v
[Phase 3.1.1: Catalog Data Verification & Migration Hardening] (Hoàn thành)
  - Official Decree 388/NQ-UBTVQH16 & QĐ 19/2025/QĐ-TTg dataset verification
  - Accurate breakdown: 28 PROVINCE, 6 CENTRAL_CITY, 709 WARD, 2,599 COMMUNE, 13 SPECIAL_ZONE
  - SHA-256 fingerprinting over JSON sources & administrative_catalog_metadata table
  - Advisory lock single-connection hardening, atomic reconciliation of synthetic data
  - Testing: 24 tests in catalog suite, 345/345 full backend regression suite PASS
                   |
                   v
[Phase 3.1.2: Catalog Data Correction & Verification] (Hoàn thành)
  - Phân định mốc pháp lý: 2025 baseline (NQ 202/2025/QH15, QĐ 19) vs snapshot 2026-09-20 (NQ 388/NQ-UBTVQH16)
  - Hiệu chỉnh & khóa mapping trọng yếu: Hà Nội (00004 Ba Đình, 00008 Ngọc Hà), TP.HCM (26740 Sài Gòn, 26743 Bến Thành, 26758 Cầu Ông Lãnh, 26737 Tân Định), Phú Quý (Lâm Đồng 68), Côn Đảo (TP.HCM 79), Phú Quốc/Thổ Châu/Kiên Hải (An Giang 91)
  - Chuẩn hóa tên tỉnh (Tỉnh Quảng Ninh, Tỉnh Bắc Ninh, Tỉnh Đồng Nai) và tiền tố
  - Engine Checksum Kép: Canonical Checksum v1 độc lập thứ tự (44a715a9...) & đối chiếu trực tiếp dữ liệu DB
  - Phát hiện sai lệch/sửa trực tiếp trong DB mà không đổi hash metadata; xử lý concurrency an toàn
  - Testing: 32 catalog tests PASS, 353/353 full backend regression suite PASS
                   |
                   v
[Phase 3.1.2.1: Independent Legal & Dataset Verification] (Hoàn thành)
  - Truy vết căn cứ pháp lý & 22 chuyển đổi xã thành phường; tạo 6 artifacts trong docs/verification/phase-3-1-2-1/
  - Đóng dấu kỹ thuật; bảo lưu trạng thái nghiệm thu do 10 trường hợp chuyển đổi ở mức thứ cấp
                   |
                   v
[Phase 3.1.2.2: Administrative Catalog Legal & Data Remediation] (Hoàn thành)
  - Phân loại chuẩn 9 CENTRAL_CITY + 25 PROVINCE; xác minh sơ cấp 22 chuyển đổi xã thành phường
  - Đính chính căn cứ bản quyền: Điều 15 (khoản 2 & 3) Luật SHTT; bộ 6 artifacts tại phase-3-1-2-2/
                   |
                   v
[Phase 3.1.2.3: Final Administrative Catalog Correction & Acceptance Verification] (Hoàn thành)
  - Đính chính ngày ký chính thức: NQ 30 (24/04/2026), NQ 36 (24/08/2026), NQ 39 (24/08/2026), NQ 237 (14/04/2026), NQ 388 (04/08/2026)
  - Chuẩn hóa 25 tỉnh và 9 thành phố trực thuộc TW; loại bỏ hoàn toàn việc nhắc các tỉnh cũ đã sáp nhập
  - Bóc tách thông số vật lý và SHA-256 từng file nguồn JSON; xác minh Sequential SHA-256 (8fa358a0...) và Canonical Checksum v1 (af6e22c8...)
  - Bộ 7 artifacts hoàn chỉnh tại docs/verification/phase-3-1-2-3/; 362/362 backend tests PASS (exit code 0)
                   |
                   v
[Phase 3.1.2.4: Administrative Catalog Data Integrity Remediation] (ACCEPTED WITH EXPLICIT LIMITATIONS)
  - Sửa sai lệch dữ liệu theo 00-canonical-correction-reference.md; xác minh 10 phường Đồng Nai chính thức theo NQ 237
  - Đánh dấu 12 phường Bắc Ninh UNVERIFIED_SOURCE_DOCUMENT_MISSING do thiếu phụ lục số hóa gốc của NQ 388; thiết lập blocker Place backfill
  - Đối soát 1-1 từng bản ghi: 3.355 bản ghi MySQL khớp 100% với JSON tệp nguồn; bảo tồn 100% 24 Places và 121 Activities (0 cột mới)
  - Bộ 6 artifacts tại docs/verification/phase-3-1-2-4/; 800/803 tests pass; chính thức mở khóa chuyển tiếp Phase 3.2
                   |
                   v
[Phase 3.2: Place – Administrative Area Integration]
  - Schema: places.administrative_area_id (nullable FK)
  - Multi-tier matching runner: tự động liên kết 24 địa điểm hiện có
  - Backend API: Lọc Place theo khu vực hành chính
                   |
                   v
[Phase 3.3: Location Search Integration]
  - Query Understanding: nhận diện địa danh qua DB/Cache cục bộ
  - Enhanced Two-Stage Search: zero-latency BBox resolution
  - Phân tích và lọc kết quả POI theo khu vực
                   |
                   v
[Phase 3.4: Flutter Integration & Final Acceptance]
  - Web Admin: gán/chỉnh sửa đơn vị hành chính cho Place
  - Mobile: gợi ý khu vực trong Location Picker
  - Quality Gate: chạy toàn bộ 721+ test stack, nghiệm thu Phase 3
```

---

## 2. Kế hoạch Chi tiết Từng Giai đoạn

### 2.1. Phase 3.1 — Administrative Areas Catalog (Hoàn thành)

#### Trạng thái: **COMPLETED** (Đã nghiệm thu ngày 2026-11-11)

#### Mục tiêu:
Xây dựng cơ sở dữ liệu danh mục hành chính chuẩn quốc gia của Việt Nam theo mô hình chính quyền 2 cấp sau ngày 01/07/2025 (34 tỉnh/thành phố trực thuộc TW và 3.321 đơn vị cấp cơ sở), mã GSO chuẩn, quan hệ cha-con tự tham chiếu tin cậy, đồng bộ idempotent, tra cứu nội bộ theo mã và tên, sẵn sàng tích hợp Place và Location Search.

#### Phạm vi Kỹ thuật Đã Triển khai:
* Tạo thực thể `AdministrativeArea` (bảng `administrative_areas`).
* Tạo `AdministrativeAreaRepository`, `AdministrativeAreaResponse`, `AdministrativeAreaSearchResultResponse`, `AdministrativeAreaService`, `AdministrativeAreaServiceImpl`, `AdministrativeAreaController`.
* Viết `AdministrativeAreaMigrationRunner` (@Order(5)) nạp dữ liệu chuẩn từ bộ JSON (`metadata.json`, `provinces.json`, `communes.json`) với MySQL Advisory Lock `administrative_area_migration_lock`, kiểm tra schema DDL tự động, kiểm tra tính hợp lệ dữ liệu và cơ chế bypass idempotent.
* Bộ nhớ đệm in-memory (Caffeine) cho `provincesCache`, `childrenCache`, `codeCache`.
* Cấu hình Spring Security: công khai (`permitAll`) các endpoint `GET /api/administrative-areas/**`.
* *Lưu ý:* Phân kỳ boundary geometry/spatial columns và bảng aliases sang Phase 3.2+ / 3.3.

#### Kết quả Kiểm thử:
* **Repository Tests:** `AdministrativeAreaRepositoryTest` (5 tests PASS).
* **Migration Runner Tests:** `AdministrativeAreaMigrationRunnerTest` (6 tests PASS: 34 provinces, 3,321 communes, idempotency, duplicate code rejection, missing parent rejection, invalid areaType rejection, advisory lock acquisition/release).
* **Controller Tests:** `AdministrativeAreaControllerTest` (8 tests PASS: provinces listing, children listing, 404 unknown parent, exact & unaccented search, search disambiguation, empty query handling, detail by code, 404 unknown code).
* **Regression Tests:** 340 / 340 backend tests PASS (0 failures, 0 errors, exit code 0).

---

### 2.2. Phase 3.1.1 — Catalog Data Verification & Migration Hardening (Hoàn thành)

#### Trạng thái: **COMPLETED** (Đã nghiệm thu ngày 2026-11-11)

#### Mục tiêu:
Xác minh tính chính xác của dữ liệu danh mục hành chính thực tế theo Nghị quyết 388/NQ-UBTVQH16 và Quyết định 19/2025/QĐ-TTg, thay thế hoàn toàn bộ dữ liệu mẫu/giả lập; gia cố Migration Runner với fingerprint SHA-256 trên dataset, đối soát an toàn (reconciliation) không drop/truncate bảng, và kiểm thử toàn diện.

#### Phạm vi Kỹ thuật Đã Triển khai:
* **Chuẩn hóa Dữ liệu Thực tế:**
  - 34 đơn vị cấp tỉnh: 28 tỉnh (`PROVINCE`) và 6 thành phố trực thuộc TW (`CENTRAL_CITY`: Hà Nội, Hải Phòng, Huế, Đà Nẵng, TP.HCM, Cần Thơ).
  - 3.321 đơn vị cấp cơ sở chuẩn GSO: 709 phường (`WARD`), 2.599 xã (`COMMUNE`), 13 đặc khu đảo (`SPECIAL_ZONE`). Mã hành chính chuẩn 5 chữ số GSO (lên đến `32248`).
* **Bảng Metadata & SHA-256 Dataset Fingerprinting:**
  - Tạo bảng `administrative_catalog_metadata` lưu fingerprint SHA-256 (`9cfd9b08faec5f53fafcaae0ce177f1455c36f3fa816d2f548254e2fe9915e91`), phiên bản dataset `v5.2.0-decree388`, số lượng bản ghi và timestamp.
* **Gia cố Migration Runner:**
  - Cơ chế bypass đa điều kiện: kiểm tra SHA-256 khớp, đủ 34 tỉnh, 3.321 xã, 0 xã mồ côi (`parent_id IS NULL`), đủ cả 5 phân loại đơn vị. Thời gian bypass $< 5\text{ ms}$.
  - Cơ chế reconciliation an toàn: cập nhật/chèn dữ liệu mới, xóa dữ liệu giả lập cũ trong transaction duy nhất bằng JPA repo, không DDL `TRUNCATE`/`DROP`.
  - Advisory lock đơn kết nối (`administrative_area_migration_lock`) với release trong `finally`.
* **Repository:** Bổ sung `findByCodeWithParent` (tránh `LazyInitializationException`) và `countByAreaType`.

#### Kết quả Kiểm thử:
* **Catalog Suite:** 24/24 tests PASS (`AdministrativeAreaRepositoryTest` 5, `AdministrativeAreaMigrationRunnerTest` 11, `AdministrativeAreaControllerTest` 8).
* **Full Backend Regression:** 345 / 345 backend tests PASS (0 failures, 0 errors, exit code 0).

---

### 2.3. Phase 3.1.2 — Catalog Data Correction & Verification (Hoàn thành)

#### Trạng thái: **COMPLETED** (Đã nghiệm thu ngày 2026-11-11)

#### Mục tiêu:
Kiểm tra, hiệu chỉnh và xác minh toàn bộ dữ liệu hành chính Việt Nam trong database; phân định rõ ràng giữa mốc tổ chức ban đầu (01/07/2025 theo NQ 202/2025/QH15 & QĐ 19/2025/QĐ-TTg) và mốc snapshot được chọn (20/09/2026 sau NQ 388/NQ-UBTVQH16); sửa toàn bộ các mapping sai; thiết lập validator độc lập và hệ thống checksum kép đối chiếu trực tiếp dữ liệu DB, bảo vệ toàn diện tính toàn vẹn dữ liệu.

#### Phạm vi Kỹ thuật Đã Triển khai:
* **Hiệu chỉnh Dữ liệu Nguồn:**
  - Hà Nội: `00004` (Phường Ba Đình), `00008` (Phường Ngọc Hà); xác nhận các mã cũ `00007`, `00010`, `00040` đã được thay thế.
  - TP.HCM: `26740` (Phường Sài Gòn), `26743` (Phường Bến Thành), `26758` (Phường Cầu Ông Lãnh), `26737` (Phường Tân Định).
  - Đặc khu đảo theo NQ 202/2025/QH15: Phú Quý thuộc Lâm Đồng (`68`); Côn Đảo thuộc TP.HCM (`79`); Phú Quốc, Thổ Châu, Kiên Hải thuộc An Giang (`91`); cùng toàn bộ 8 đặc khu khác đã được xác minh.
  - Chuẩn hóa tên tỉnh: Tỉnh Quảng Ninh (`22`), Tỉnh Bắc Ninh (`24`), Tỉnh Đồng Nai (`75`) mang tiền tố "Tỉnh".
  - Sửa lỗi viết hoa: `06325` ("Xã Bắc Sơn").
* **Hệ thống Checksum Kép & Validator Độc lập (`AdministrativeAreaValidator`):**
  - Tách rời validator khỏi importer, kiểm tra 100% cấu trúc, số lượng và tính hợp lệ cây 2 cấp.
  - Canonical Checksum v1 (`44a715a95b9f3dac4f4f67a72f457c05c075c9dbf893f1668d106e96348e1230`) độc lập với thứ tự các dòng trong JSON.
  - So sánh trực tiếp DB checksum với Source checksum: Phát hiện sửa tên/đơn vị cha trực tiếp trong MySQL mà không thay đổi hash metadata.
  - Advisory lock có cơ chế fail-fast và kiểm tra an toàn sau timeout.
* **Metadata Quản lý Toàn diện:** Lưu trữ `DATASET_VERSION`, `SNAPSHOT_DATE`, `EFFECTIVE_DATE`, `LEGAL_BASIS`, `SOURCE_NAME`, `CANONICAL_CONTENT_CHECKSUM`, `DATASET_SHA256`, số lượng từng loại và trạng thái `COMPLETED`.

#### Kết quả Kiểm thử:
* **Catalog Suite:** 32/32 tests PASS (`AdministrativeAreaValidatorTest` 5, `AdministrativeAreaRepositoryTest` 5, `AdministrativeAreaMigrationRunnerTest` 14, `AdministrativeAreaControllerTest` 8).
* **Full Backend Regression:** 353 / 353 backend tests PASS (0 failures, 0 errors, exit code 0).

---

### 2.4. Phase 3.1.2.1 — Independent Legal & Dataset Verification (Hoàn thành)

#### Trạng thái: **AUDITED & CONDITIONALLY ACCEPTED** (2026-11-11)

#### Mục tiêu:
Thực hiện đợt kiểm chứng độc lập chuyên sâu đối với Administrative Areas Catalog, truy vết văn bản pháp lý sơ cấp cho 22 chuyển đổi xã thành phường, lập bảng đối chiếu toàn bộ 34 tỉnh và 3.321 xã, phân tích license và provenance, đánh giá an toàn Canonical Checksum v1, kiểm thử concurrency 2 connection MySQL Advisory Lock và phát hiện tham nhũng dữ liệu DB.

#### Kết quả:
* **Artifacts Độc lập:** Tạo 6 artifacts tại `docs/verification/phase-3-1-2-1/`.
* **Pháp lý:** 12 phường Bắc Ninh đạt `VERIFIED_PRIMARY` (NQ 388/NQ-UBTVQH16); 10 đơn vị còn lại đạt `VERIFIED_SECONDARY`.
* **Testing:** 38 catalog tests PASS, 359/359 full backend regression tests PASS.
* **Quyết định:** Bảo lưu trạng thái nghiệm thu hoàn toàn để tiến hành đợt remediation Phase 3.1.2.2.

---

### 2.5. Phase 3.1.2.2 — Administrative Catalog Legal & Data Remediation (Hoàn thành)

#### Trạng thái: **ACCEPTED WITH EXPLICIT LIMITATIONS** (2026-11-11)

#### Mục tiêu:
Khắc phục toàn diện các vấn đề pháp lý và kỹ thuật từ Phase 3.1.2.1:
1. Xác định chính xác 9 thành phố trực thuộc Trung ương (`CENTRAL_CITY`: Hà Nội, Quảng Ninh, Bắc Ninh, Hải Phòng, Huế, Đà Nẵng, Đồng Nai, TP.HCM, Cần Thơ) và 25 tỉnh (`PROVINCE`).
2. Xác minh sơ cấp 100% cho 22 chuyển đổi xã thành phường: 10 phường tại Đồng Nai (NQ 237/NQ-UBTVQH16) và 12 phường tại Bắc Ninh (NQ 388/NQ-UBTVQH16).
3. Đính chính căn cứ bản quyền: Trích dẫn Điều 15 (khoản 2 và 3) Luật Sở hữu trí tuệ Việt Nam; phân tích đa chiều về MIT license của công cụ ETL và tính chất công cộng của dữ liệu mở hành chính.
4. Cập nhật Checksum kép: Raw Dataset SHA-256 (`8fa358a085cdc10e4533ef41a51ee02b8e2a81dd6b0cb642e44ab33f2b60b816`) và Canonical Content Checksum v1 (`af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`).
5. Gia cố kiểm thử tương tranh đa luồng thực sự: Bổ sung `testTwoIndependentRunners_ConcurrentExecution_OneAcquiresAndOtherWaitsOrBypasses` với 2 luồng song song cạnh tranh lock; kiểm thử chuẩn hóa whitespace `.trim()`.

#### Kết quả Kiểm thử & Nghiệm thu:
* **Bộ Artifacts Mới:** 6 artifacts tại `docs/verification/phase-3-1-2-2/` (01-legal-basis, 02-provenance-and-license, 03-provinces-verification.csv, 04-communes-verification.csv, 05-checksum-integrity, 06-final-acceptance-report).
* **Catalog Suite:** 28 tests PASS (11 `AdministrativeAreaValidatorTest`, 17 `AdministrativeAreaMigrationRunnerTest`).
* **Full Backend Regression:** 362 / 362 backend tests PASS (0 failures, 0 errors, exit code 0).
* **Bảo toàn Invariants:** 24 places và 121 activities hoàn toàn nguyên vẹn; chưa thêm cột `administrative_area_id` vào `places`.
* **Kết luận:** Đạt nghiệm thu **ACCEPTED WITH EXPLICIT LIMITATIONS**, chính thức mở cổng kỹ thuật cho Phase 3.2.

---

### 2.6. Phase 3.1.2.3 — Final Administrative Catalog Correction & Acceptance Verification (Hoàn thành)

#### Trạng thái: **ACCEPTED WITH EXPLICIT LIMITATIONS** (2026-11-11)

#### Mục tiêu:
Hiệu chỉnh và xác minh cuối cùng danh mục địa giới hành chính tại snapshot `2026-09-20`:
1. Đính chính ngày ký chính thức của các văn bản quy phạm pháp luật: NQ 30/2026/QH16 (24/04/2026), NQ 36/2026/QH16 (24/08/2026), NQ 39/2026/QH16 (24/08/2026), NQ 237/NQ-UBTVQH16 (14/04/2026), NQ 388/NQ-UBTVQH16 (04/08/2026).
2. Chuẩn hóa danh mục 25 tỉnh và 9 thành phố trực thuộc Trung ương, loại bỏ hoàn toàn việc nhắc các tỉnh cũ đã sáp nhập như đơn vị hiện hành độc lập.
3. Bóc tách thông số vật lý và SHA-256 từng file nguồn JSON (`metadata.json`: 2.276 bytes, `provinces.json`: 4.931 bytes, `communes.json`: 473.956 bytes) và Sequential SHA-256 (`8fa358a0...`).
4. Đối soát Canonical Checksum v1 (`af6e22c8...`), kiểm tra Unicode NFC, delimiter safety, và live DB checksum.
5. Chứng minh an toàn khóa tương tranh đa luồng JVM (`ExecutorService`) và đa kết nối JDBC.
6. Xác minh tính toàn vẹn cơ sở dữ liệu: 24 places và 121 activities nguyên vẹn.

#### Kết quả Kiểm thử & Nghiệm thu:
* **Bộ Artifacts Mới:** 7 artifacts hoàn chỉnh tại `docs/verification/phase-3-1-2-3/`.
* **Testing:** 41/41 catalog tests PASS; 362/362 full backend regression tests PASS (exit code 0).
* **Kết luận:** **ACCEPTED WITH EXPLICIT LIMITATIONS**, chính thức mở cổng kỹ thuật cho Phase 3.2.

---

### 2.7. Phase 3.1.2.4 — Administrative Catalog Data Integrity Remediation (Hoàn thành)

#### Trạng thái: **ACCEPTED WITH EXPLICIT LIMITATIONS** (2026-11-11)

#### Mục tiêu & Kết quả Thực hiện:
Hiệu chỉnh toàn diện dữ liệu danh mục hành chính theo `00-canonical-correction-reference.md`:
1. Thay thế danh sách 10 phường Đồng Nai bằng 10 phường chính thức theo NQ 237/NQ-UBTVQH16 (`26248` Trảng Bom, `26368` Long Thành, `26170` Trị An, `26485` Nhơn Trạch, `25357` Tân Khai, `26425` Xuân Lộc, `26116` Tân Phú, `25270` Lộc Ninh, `26326` Dầu Giây, `25363` Đồng Phú) trực thuộc `75` Đồng Nai (`VERIFIED_PRIMARY`).
2. Cách ly 12 phường Bắc Ninh do thiếu phụ lục NQ 388/NQ-UBTVQH16, gán cờ `UNVERIFIED_SOURCE_DOCUMENT_MISSING` và chặn Place linking trong Phase 3.2.
3. Chuẩn hóa quan hệ tỉnh cha cho 5 đặc khu (Phú Quý -> Lâm Đồng, Côn Đảo -> TP.HCM, Phú Quốc, Thổ Châu, Kiên Hải -> An Giang).
4. Đồng bộ 100% giữa JSON source và MySQL live database; bảo toàn 24 places và 121 activities.
5. Bộ 6 artifacts nghiệm thu kỹ thuật tại `docs/verification/phase-3-1-2-4/` (01..06).

---

### 2.8. Phase 3.1.2.4.1 — Independent Catalog Integrity Verification & Final Acceptance (Hoàn thành)

#### Trạng thái: **ACCEPTED WITH EXPLICIT LIMITATIONS** (2026-11-11)

#### Mục tiêu & Kết quả Thực hiện:
Thực hiện đợt kiểm chứng độc lập chuyên sâu đối với việc khắc phục dữ liệu và cơ chế đồng bộ:
1. **Kiểm toán Ranh giới Tin cậy (Critical Tasks A & D):** Xác lập 4 tầng dữ liệu: Tầng A (67 bản ghi tin cậy sơ cấp: 34 tỉnh + 33 xã/phường/đặc khu), Tầng B (3.276 bản ghi tin cậy thứ cấp theo GSO), Tầng C (12 bản ghi Bắc Ninh cách ly với trạng thái `UNVERIFIED_SOURCE_DOCUMENT_MISSING`), Tầng D (0 sai lệch). Thiết lập quy tắc resolver Phase 3.2 trả về `NULL` đối với Tầng C.
2. **Chứng cứ Mã định danh 10 Phường Đồng Nai (Critical Task B):** Lập hồ sơ chứng cứ độc lập với URL Quốc hội/Chính phủ, phụ lục 2 NQ 237 và mã 5 chữ số GSO (`VERIFIED_PRIMARY`).
3. **Đối soát 3.321 Đơn vị Cấp Xã (Critical Task C):** Xuất artifact `07-independent-record-verification.csv` phân loại chi tiết từng dòng.
4. **Bảo tồn Tuyệt đối Places & Activities (Critical Task E):** Xuất báo cáo `10-place-activity-row-level-preservation.md` chứng minh 24 places (đúng 12 cột, 0 cột mới) và 121 activities (111 linked, 10 free-form) nguyên vẹn 100%.
5. **Kiểm chứng Độc quyền Đồng thời Đa Tiến trình (Critical Task F):** Chạy thực nghiệm 2 tiến trình độc lập (`mysql.exe`, PID 20144 và PID 1256/1136) trên 2 socket TCP kết nối MySQL; chứng minh cơ chế advisory lock `administrative_area_migration_lock` loại trừ tương tranh tuyệt đối.
6. **Bộ 6 Artifacts Nghiệm thu Độc lập:** `07` đến `12` tại `docs/verification/phase-3-1-2-4/`.
7. **Quyết định Nghiệm thu Cuối cùng:** **`ACCEPTED WITH EXPLICIT LIMITATIONS`**, chính thức mở khóa Phase 3.2.

---

### 2.9. Phase 3.2 — Place – Administrative Area Integration

#### Mục tiêu:
Liên kết thực thể `Place` với `AdministrativeArea` một cách an toàn, tự động đối soát và gán khu vực hành chính cho 24 địa điểm du lịch hiện có trong database, không làm thay đổi các thuộc tính khác của Place.

#### Phạm vi Kỹ thuật:
* Bổ sung cột khóa ngoại nullable `places.administrative_area_id`.
* Xây dựng công cụ phân giải tự động đa tầng (Multi-tier Area Resolver) dựa trên:
  1. Point-in-Polygon qua `ST_Contains()` trên MySQL 8.
  2. Bounding Box & Khoảng cách Haversine tới tâm.
  3. Chuỗi địa chỉ `address` đối chiếu với bảng Aliases.
* Cập nhật `PlaceResponse` và `PlaceDetailResponse` trả về thông tin khu vực hành chính kèm tên tỉnh/thành phố cha.

#### Thay đổi Cơ sở Dữ liệu Dự kiến:
```sql
ALTER TABLE `places` ADD COLUMN `administrative_area_id` bigint DEFAULT NULL;
ALTER TABLE `places` ADD CONSTRAINT `fk_places_admin_area` FOREIGN KEY (`administrative_area_id`) REFERENCES `administrative_areas` (`area_id`) ON DELETE SET NULL;
CREATE INDEX `idx_places_admin_area` ON `places` (`administrative_area_id`);
```

#### File / Module Dự kiến Chỉnh sửa:
* `backend/.../model/Place.java` (thêm `@ManyToOne administrativeArea`)
* `backend/.../repository/PlaceRepository.java` (thêm `findByAdministrativeArea_AreaId`, `findByAdministrativeArea_Parent_AreaId`)
* `backend/.../dto/response/PlaceResponse.java` & `PlaceDetailResponse.java` (thêm `AdministrativeAreaSummaryResponse`)
* `backend/.../service/impl/PlaceServiceImpl.java` (xử lý lọc theo khu vực)
* `backend/.../config/PlaceAdministrativeAreaLinkingRunner.java` (migration runner liên kết an toàn)

#### Kế hoạch Kiểm thử & Tiêu chí Nghiệm thu:
* **Place Linking Tests:**
  - 24/24 địa điểm mẫu trong catalog được gán thành công vào đúng đơn vị hành chính cấp tỉnh tương ứng.
  - Các địa điểm có địa chỉ cũ (ví dụ: San Sả Hồ, Thừa Thiên Huế) được tự động nhận diện đúng đơn vị hành chính mới nhờ bảng Aliases.
  - Place có `administrative_area_id = NULL` vẫn hoạt động bình thường, không gây `NullPointerException`.
  - **Regression Test:** Snapshot của 121 activities hoàn toàn không suy chuyển; các tọa độ chỉ đường giữ nguyên.
* **Test File:** `PlaceAdministrativeAreaIntegrationTest.java`.

---

### 2.8. Phase 3.3 — Location Search Integration

#### Mục tiêu:
Tích hợp catalog Administrative Areas vào hệ thống tìm kiếm địa điểm, thay thế các cuộc gọi HTTP ngoại bộ bằng việc phân giải địa giới nội bộ tức thì, nâng cao độ chính xác khi tìm kiếm POI theo khu vực (ví dụ: `Cơm tấm Long Xuyên`, `Quán ăn ở Long Xuyên`, `Cafe Đà Lạt`).

#### Phạm vi Kỹ thuật:
* Refactor [`QueryUnderstandingServiceImpl`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/QueryUnderstandingServiceImpl.java): Thay thế danh sách tĩnh `KNOWN_ADMINISTRATIVE_REGIONS` bằng service tra cứu linh hoạt `AdministrativeAreaService` kết hợp Caffeine Cache.
* Nâng cấp [`LocationServiceImpl.resolveTargetArea()`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationServiceImpl.java#L359): Phân giải BBox và Centroid trực tiếp từ cơ sở dữ liệu nội bộ.
* Bổ sung cơ chế xử lý địa danh trùng tên (Disambiguation) và hỗ trợ tên viết tắt / không dấu qua bảng Aliases.

#### File / Module Dự kiến Chỉnh sửa:
* `backend/.../service/impl/QueryUnderstandingServiceImpl.java`
* `backend/.../service/impl/LocationServiceImpl.java`
* `backend/.../service/impl/GeographicFilterServiceImpl.java`
* `backend/.../dto/location/GeographicTargetArea.java`

#### Kế hoạch Kiểm thử & Tiêu chí Nghiệm thu:
* **Search Integration Tests:**
  - Truy vấn `Cơm tấm Long Xuyên`: Phân giải được Long Xuyên với 0 cuộc gọi mạng ra ngoài; tìm kiếm các quán ăn thực tế trong BBox của Long Xuyên; không trả về fallback giả lập `locality_...`.
  - Truy vấn tên viết tắt: `cafe sg`, `khách sạn vt`, `homestay dl` nhận diện đúng TP. Hồ Chí Minh, Vũng Tàu, Đà Lạt.
  - Truy vấn địa danh lịch sử: `quán ăn ở Hà Tây cũ` phân giải đúng vùng địa giới của Hà Tây cũ.
  - Truy vấn địa danh trùng tên: `Châu Thành` xử lý ưu tiên theo tọa độ người dùng hoặc gợi ý kèm tỉnh.
* **Test File:** `AdministrativeLocationSearchTest.java` (tối thiểu 15 kịch bản tìm kiếm phức tạp).

---

### 2.9. Phase 3.4 — Flutter Integration & Final Acceptance

#### Mục tiêu:
Tích hợp dữ liệu khu vực hành chính vào giao diện người dùng trên Flutter Web Admin và Flutter Mobile, thực hiện toàn diện quy trình kiểm thử hồi quy và tổ chức nghiệm thu Phase 3.

#### Phạm vi Giao diện & Trải nghiệm:
* **Flutter Web Admin (`AdminPlacesScreen` & `PlaceFormDialog`):**
  - Bổ sung Dropdown chọn Tỉnh/Thành phố và Xã/Phường khi thêm hoặc sửa Place.
  - Hiển thị nhãn đơn vị hành chính trên bảng danh sách địa điểm.
  - Bộ lọc Place theo Tỉnh/Thành phố.
* **Flutter Mobile App (`LocationPickerSheet` & `ExploreScreen`):**
  - Hiển thị gợi ý khu vực hành chính trong thanh tìm kiếm vị trí.
  - Cho phép người dùng chọn nhanh một tỉnh/thành phố để xem các địa điểm thuộc khu vực đó.

#### File Dự kiến Chỉnh sửa trên Frontend:
* **Web Admin:**
  - `frontend/web/lib/features/locations/data/models/place_model.dart`
  - `frontend/web/lib/features/locations/presentation/screens/admin_places_screen.dart`
  - `frontend/web/lib/features/locations/presentation/widgets/place_form_dialog.dart`
  - `frontend/web/test/admin_place_test.dart`
* **Mobile App:**
  - `frontend/mobile/lib/features/itinerary/data/models/place_summary.dart`
  - Các widget hiển thị thông tin địa chỉ nếu cần.

#### Tiêu chí Nghiệm thu Cuối cùng (Final Acceptance Gate):
1. **Backend Tests:** 100% tests PASS (321 test baseline + các test mới của Phase 3.1–3.3, tổng cộng $\ge 350$ tests, exit code 0).
2. **Flutter Web Tests:** 100% tests PASS, `flutter analyze` 0 errors, 0 warnings.
3. **Flutter Mobile Tests:** Không phát sinh bất kỳ lỗi hồi quy mới nào (duy trì 0 regression).
4. **Data Invariants:**
   - 121 activities bảo toàn nguyên vẹn snapshot vị trí và tọa độ.
   - Tính toán lộ trình chỉ đường trên bản đồ hoạt động hoàn hảo.
   - 24 places liên kết đúng đơn vị hành chính.

---

## 3. Quản lý Rủi ro và Kế hoạch Dự phòng (Risk Matrix)

| Rủi ro Kỹ thuật | Xác suất | Tác động | Giải pháp Phòng ngừa & Xử lý |
|:---|:---:|:---:|:---|
| **Dung lượng GeoJSON Polygon quá lớn làm chậm truy vấn** | Trung bình | Cao | Đơn giản hóa đa giác (Polygon Simplification bằng thuật toán Douglas-Peucker) trước khi lưu. Chỉ nạp GeoJSON chi tiết khi người dùng yêu cầu vẽ viền ranh giới trên bản đồ. Các truy vấn tìm kiếm chỉ dùng Bounding Box số thực. |
| **Place nằm sát ranh giới 2 xã/phường bị gán nhầm** | Thấp | Trung bình | Kết hợp cả 3 tín hiệu: Point-in-Polygon, BBox và đối chiếu từ khóa tên xã trong chuỗi `address`. Nếu độ tin cậy $< 0.85$, để `administrative_area_id = NULL` và gắn cờ kiểm tra thủ công. |
| **Người dùng tìm kiếm địa danh xã/phường rất mới chưa có trong từ điển** | Trung bình | Thấp | Nếu tìm kiếm nội bộ không thấy, hệ thống tự động fallback sang cơ chế geocoding ngoại bộ của LocationIQ/HERE như kiến trúc hiện tại, ghi log để bổ sung alias sau này. |
| **Xung đột Advisory Lock khi triển khai nhiều instance** | Thấp | Cao | Sử dụng cơ chế lock đơn kết nối `GET_LOCK('administrative_area_migration_lock', 5)` có giới hạn số lần retry đã được kiểm chứng ở Phase 2.1. |

---

## 4. Bảng Kế hoạch Thực hiện (Timeline & Milestones)

| Giai đoạn | Nội dung Công việc Trọng tâm | Deliverables Chính | Thời lượng Dự kiến |
|:---|:---|:---|:---:|
| **Phase 3.0** | Audit hiện trạng & Thiết kế kiến trúc | Bộ 4 tài liệu audit, design, sources, roadmap | **Hoàn thành** |
| **Phase 3.1** | Schema, Seeder & Catalog API Administrative Areas | Thực thể, repositories, seed runner, 34 tỉnh + xã, test catalog | **Hoàn thành** |
| **Phase 3.1.1** | Catalog Data Verification & Migration Hardening | Dữ liệu chuẩn NQ 388/QĐ 19 (709/2.599/13), SHA-256 fingerprint, reconciliation | **Hoàn thành** |
| **Phase 3.1.2** | Catalog Data Correction & Verification | Hiệu chỉnh mapping (Hà Nội, TP.HCM, Đặc khu/Lâm Đồng/An Giang/TP.HCM), Checksum kép, Audit DB | **Hoàn thành** |
| **Phase 3.1.2.1** | Independent Legal & Dataset Verification | Bộ 6 artifacts kiểm chứng độc lập (docs/verification/phase-3-1-2-1/), 359 tests PASS | **Hoàn thành** |
| **Phase 3.1.2.2** | Legal & Data Remediation | 9 CENTRAL_CITY + 25 PROVINCE, 22 chuyển đổi sơ cấp, check Điều 15 SHTT, 362 tests PASS | **Hoàn thành** |
| **Phase 3.1.2.3** | Final Correction & Acceptance Verification | Sửa ngày ký, chuẩn hóa 25 tỉnh, bóc tách file SHA-256, bộ 7 artifacts, 362 tests PASS | **Hoàn thành (Accepted)** |
| **Phase 3.2** | Tích hợp Place – Administrative Area | Migration runner liên kết 24 places, API lọc theo tỉnh/khu vực | Milestone 2 |
| **Phase 3.3** | Nâng cấp Two-Stage Location Search với Local BBox | Refactor QueryUnderstanding, zero-latency resolve, test search | Milestone 3 |
| **Phase 3.4** | Tích hợp Flutter Web Admin/Mobile & Nghiệm thu | UI Web Admin, Location Picker, chạy full stack test suite | Milestone 4 |

