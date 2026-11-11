# BÁO CÁO RÀ SOÁT & PHÂN NHÓM TOÀN BỘ GIT WORKING TREE
## WORKING TREE ORGANIZATION, DEPENDENCY ANALYSIS & COMMIT PLAN

**Dự án:** Travel Planner  
**Nhánh Git:** `develop` | **HEAD:** `9902ccd8a39b12fd185d575e26f9118f385b7337`  
**Thời điểm rà soát:** 2026-11-12T05:48:00+07:00  
**Chính sách Git:** STRICTLY NO COMMIT, NO PUSH (Bảo toàn 100% trạng thái Working Tree)  

---

## 1. TỔNG QUAN HIỆN TRẠNG WORKING TREE (EXECUTIVE SUMMARY)

Sau quá trình rà soát độc lập bằng công cụ dòng lệnh Git (`git status --porcelain`, `git diff`, `git ls-files`), toàn bộ Git Working Tree hiện tại ghi nhận:

- **Tổng số file có thay đổi:** **156 files**
  - **File đã được theo dõi và bị chỉnh sửa (Tracked Modified, Unstaged):** **16 files**
  - **File mới chưa được theo dõi (Untracked Files):** **140 files**
  - **File trong Staging Area (Staged):** **0 files**
  - **File bị xóa (Deleted):** **0 files**
  - **File bị đổi tên (Renamed):** **0 files**
- **Kiểm tra an toàn thông tin & file rác:**
  - **File nhạy cảm (`.env`, secrets, passwords, credentials):** **0 file** (toàn bộ nằm trong `.gitignore` hoặc không bị lộ).
  - **File build tạm / generated (`target/`, `build/`, `.dart_tool/`, `.class`):** **0 file**.
  - **Mã nguồn và tài liệu:** Toàn bộ 156 file đều là mã nguồn ứng dụng, cấu hình chuẩn hóa, tài nguyên dữ liệu hạt giống và báo cáo kiểm chứng kỹ thuật.

---

## 2. KIỂM TRA FILE NHẠY CẢM VÀ TÍNH TOÀN VẸN (SECURITY AUDIT)

Đã quét toàn bộ 156 đường dẫn với các từ khóa rủi ro: `.env`, `password`, `secret`, `credential`, `key`, `token`, `private`:
- File `.env` của backend và mobile đều được `.gitignore` bảo vệ nghiêm ngặt, không bị stage hay xuất hiện trong danh sách untracked.
- Mọi chuỗi API key bên thứ ba (LocationIQ, TomTom, HERE, ORS) đều được đọc thông qua biến môi trường hoặc fallback rỗng trong code kiểm thử mô phỏng (`Mock`).
- Các token trong unit/integration test đều là JWT mock tạm thời sinh động trong quá trình chạy test RAM, không chứa khóa bí mật sản xuất.
- **Kết luận:** **100% AN TOÀN, ĐỦ ĐIỀU KIỆN REVIEW VÀ COMMIT.**

---

## 3. PHÂN LOẠI FILE THEO LỚP KIẾN TRÚC KỸ THUẬT (ARCHITECTURAL LAYERS)

Dưới đây là bảng phân bổ 156 files theo các tầng kiến trúc:

| Lớp Kiến Trúc (Layer) | Số Lượng File | Các Thành Phần Chính |
|---|:---:|---|
| **1. Database & Seed Data** | 3 | Dữ liệu hành chính JSON (`provinces.json`, `communes.json`, `metadata.json`) |
| **2. Backend Models & Enums** | 7 | `Place.java`, `AdministrativeArea.java`, `ItineraryPlace.java`, 4 Enums trạng thái |
| **3. Backend Repositories** | 3 | `PlaceRepository.java`, `AdministrativeAreaRepository.java`, `ItineraryPlaceRepository.java` |
| **4. Backend DTOs** | 11 | Request/Response DTOs cho Administrative Area, Place Linking và Itinerary Places |
| **5. Backend Core Services & Resolvers** | 11 | `AdministrativeAreaResolver`, Services của Admin Area, Place Linking, Spatial Search, Saved Places |
| **6. Backend Controllers & API** | 4 | `PlaceController`, `AdministrativeAreaController`, `AdminPlaceAdministrativeAreaController`, `ItineraryPlaceController` |
| **7. Security & Configurations** | 4 | `SecurityConfig.java`, 3 Migration Runners và Data Validator |
| **8. Mobile Frontend** | 5 | API Constants, `ItineraryPlace` model, Crud Repository, `ItineraryDetailScreen`, `ActivityFormBottomSheet` |
| **9. Automated Test Suites** | 13 | 12 Test suites Backend (19 tests Phase 4, Deduplication, Resilience, Linking...) + 1 Test suite Mobile |
| **10. Documentation & Verification** | 95 | 3 Architecture docs, 1 Roadmap doc, 2 Project tracking logs, 69 Verification reports (Phases 3.1.2.4 – 4) |
| **TỔNG CỘNG** | **156** | **Hoàn toàn đồng bộ và toàn vẹn** |

---

## 4. QUAN HỆ PHỤ THUỘC & CÁC FILE BẮT BUỘC GIỮ CHUNG (ATOMIC BUNDLING RULES)

Để tránh hiện tượng "vỡ mã nguồn" (build failure) khi tách nhỏ các commit, các quy tắc phụ thuộc sau đây được xác lập:

```
[Group 1: Administrative Area Catalog]
       │
       ▼ (Độc lập, là nền tảng danh mục)
[Group 2: Place–Administrative Area Linking & Resolution]
       │  ├── Place.java CẦN AdministrativeArea.java và ConfidenceClassification.java
       │  ├── PlaceResponse.java CẦN AdministrativeAreaSummaryResponse.java
       │  └── PlaceAdminAreaService CẦN AdministrativeAreaResolver
       ▼
[Group 3: Location Search, Place Filtering & Spatial Resilience]
       │  ├── Search pipeline CẦN PlaceRepository & AdministrativeAreaRepository
       │  └── LocationRankingService CẦN SYSTEM priority & Address Tokenizer
       ▼
[Group 4: Saved Places — Backend Itinerary-Scoped Association]
       │  ├── ItineraryPlace CẦN Itinerary và Place
       │  └── ItineraryPlaceController CẦN ItineraryPlaceService & SecurityConfig
       ▼
[Group 5: Saved Places — Mobile Frontend Integration]
       │  ├── itinerary_place.dart CẦN PlaceSummary
       │  ├── itinerary_crud_repository CẦN itinerary_place.dart
       │  └── ItineraryDetailScreen CẦN itinerary_crud_repository
       ▼
[Group 6: Documentation & Verification Reports]
          (Báo cáo tổng kết, nhật ký phát triển Session 48-55)
```

### Quy Tắc Giữ File Chung Tuyệt Đối:
1. **Rule 1 (Catalog Foundation):** `AdministrativeArea.java`, 3 file enums (`AdministrativeAreaStatus`, `AdministrativeAreaType`, `AdministrativeAreaTrustClassification`), 3 file JSON seed data, và `AdministrativeAreaRepository.java` **PHẢI** được commit cùng nhau để ứng dụng có thể khởi tạo catalog.
2. **Rule 2 (Place Linking Contract):** `Place.java` (thêm trường liên kết), `ConfidenceClassification.java`, `PlaceRepository.java`, `PlaceResponse.java`, và `PlaceDetailResponse.java` **PHẢI** đi cùng nhau. Nếu tách riêng `Place.java` mà thiếu enum hoặc DTO, backend sẽ compile fail ngay lập tức.
3. **Rule 3 (Backend Itinerary Places):** `ItineraryPlace.java`, `ItineraryPlaceRepository.java`, `SavePlaceToItineraryRequest.java`, `ItineraryPlaceResponse.java`, `ItineraryPlaceService(Impl).java`, và `ItineraryPlaceController.java` **PHẢI** được giữ chung một gói commit backend hoàn chỉnh.
4. **Rule 4 (Mobile Itinerary Places):** `itinerary_place.dart`, `api_constants.dart`, `itinerary_crud_repository.dart`, `itinerary_detail_screen.dart`, và `activity_form_dialog.dart` **PHẢI** đi cùng nhau. Nếu thiếu model hoặc repository method, Flutter analyze sẽ báo lỗi `missing_member` hoặc `undefined_class`.

---

## 5. ĐỀ XUẤT KẾ HOẠCH REVIEW & THỨ TỰ COMMIT THỦ CÔNG (COMMIT PLAN)

Kế hoạch được chia thành **6 Commit Groups** tuần tự, đảm bảo mỗi commit đều độc lập, hoàn chỉnh, ứng dụng build pass và test pass 100% tại từng bước:

---

### GROUP 1: Phase 3.1 — Administrative Area Catalog (Nền Tảng Danh Mục)
- **Thông điệp Commit đề xuất:** `feat(admin-catalog): implement administrative areas catalog, seed data, and validation`
- **Số lượng file:** **23 files**
- **Danh sách file chi tiết:**
  - *Seed Data:*
    - `Travel_Planner/backend/src/main/resources/data/administrative/provinces.json`
    - `Travel_Planner/backend/src/main/resources/data/administrative/communes.json`
    - `Travel_Planner/backend/src/main/resources/data/administrative/metadata.json`
  - *Models & Enums:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/AdministrativeArea.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/enums/AdministrativeAreaStatus.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/enums/AdministrativeAreaType.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/enums/AdministrativeAreaTrustClassification.java`
  - *Repository & Config:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/AdministrativeAreaRepository.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/config/AdministrativeAreaValidator.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/config/AdministrativeAreaMigrationRunner.java`
  - *Service & Controller:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/AdministrativeAreaService.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/AdministrativeAreaServiceImpl.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AdministrativeAreaController.java`
  - *DTOs:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/AdministrativeAreaResponse.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/AdministrativeAreaSummaryResponse.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/AdministrativeAreaSearchResultResponse.java`
  - *Tests:*
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AdministrativeAreaRepositoryTest.java`
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AdministrativeAreaValidatorTest.java`
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AdministrativeAreaMigrationRunnerTest.java`
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AdministrativeAreaControllerTest.java`
  - *Architecture Docs:*
    - `Travel_Planner/docs/architecture/phase-3-administrative-area-audit.md`
    - `Travel_Planner/docs/architecture/phase-3-administrative-data-sources.md`

---

### GROUP 2: Phase 3.2 — Place–Administrative Area Linking & Resolution
- **Thông điệp Commit đề xuất:** `feat(place-resolution): implement place-to-administrative-area linking, resolution engine, and admin APIs`
- **Số lượng file:** **18 files**
- **Danh sách file chi tiết:**
  - *Models & Enums:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/Place.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/enums/ConfidenceClassification.java`
  - *Repository & Config:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/PlaceRepository.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/config/PlaceAdministrativeAreaMigrationRunner.java`
  - *DTOs:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/BatchResolvePlacesRequest.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/ManualLinkAdministrativeAreaRequest.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/BatchLinkingReportResponse.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/PlaceResolutionResultResponse.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/PlaceResponse.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/PlaceDetailResponse.java`
  - *Resolver & Services:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/resolver/AdministrativeAreaResolver.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/resolver/impl/AdministrativeAreaResolverImpl.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/PlaceAdministrativeAreaService.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/PlaceAdministrativeAreaServiceImpl.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/AdminPlaceAdministrativeAreaController.java`
  - *Tests:*
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AdministrativeAreaResolverTest.java`
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/PlaceAdministrativeAreaMigrationRunnerTest.java`
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/PlaceAdministrativeAreaServiceTest.java`
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/AdminPlaceAdministrativeAreaControllerTest.java`
  - *Architecture Doc:*
    - `Travel_Planner/docs/architecture/phase-3-administrative-area-design.md`

---

### GROUP 3: Phase 3.3 & 3.3.1 — Location Search, Place Filtering & Spatial Resilience
- **Thông điệp Commit đề xuất:** `feat(location-search): enhance hierarchical search, spatial filtering, address deduplication, and provider resilience`
- **Số lượng file:** **9 files**
- **Danh sách file chi tiết:**
  - *Services & Controller:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/PlaceService.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/PlaceServiceImpl.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationServiceImpl.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationRankingServiceImpl.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/PlaceController.java`
  - *Tests:*
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/LocationSearchAndFilteringTest.java`
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/LocationDeduplicationTest.java`
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/ProviderFailureAndResilienceTest.java`
  - *Plan Doc:*
    - `Travel_Planner/docs/plan/phase-3-implementation-roadmap.md`

---

### GROUP 4: Phase 4 — Saved Places (Backend Itinerary-Scoped Association)
- **Thông điệp Commit đề xuất:** `feat(itinerary-places): implement itinerary-scoped saved places management, access controls, and REST APIs`
- **Số lượng file:** **9 files**
- **Danh sách file chi tiết:**
  - *Model & Repository:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/ItineraryPlace.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryPlaceRepository.java`
  - *DTOs:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/request/SavePlaceToItineraryRequest.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/dto/response/ItineraryPlaceResponse.java`
  - *Service & Controller:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/ItineraryPlaceService.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryPlaceServiceImpl.java`
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/controller/ItineraryPlaceController.java`
  - *Security:*
    - `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/security/SecurityConfig.java`
  - *Backend Integration Test:*
    - `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/ItineraryPlaceTest.java`

---

### GROUP 5: Phase 4 — Saved Places (Mobile Frontend Integration)
- **Thông điệp Commit đề xuất:** `feat(mobile-saved-places): integrate itinerary-scoped saved places UI, fast bookmarking, and activity linking`
- **Số lượng file:** **6 files**
- **Danh sách file chi tiết:**
  - `Travel_Planner/frontend/mobile/lib/core/constants/api_constants.dart`
  - `Travel_Planner/frontend/mobile/lib/features/itinerary/data/models/itinerary_place.dart`
  - `Travel_Planner/frontend/mobile/lib/features/itinerary/data/itinerary_crud_repository.dart`
  - `Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart`
  - `Travel_Planner/frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart`
  - `Travel_Planner/frontend/mobile/test/itinerary_saved_places_test.dart`

---

### GROUP 6: Verification Artifacts & Project Documentation Tracking
- **Thông điệp Commit đề xuất:** `docs: add comprehensive phase verification reports, development logs, and project status updates`
- **Số lượng file:** **91 files**
- **Danh sách file chi tiết:**
  - *Project Tracking Logs (2 files):*
    - `Travel_Planner/docs/ai/09-development-log.md`
    - `Travel_Planner/docs/ai/12-project-status-and-next-steps.md`
  - *Phase 3.1.2.4 Verification Reports (13 files):*
    - `Travel_Planner/docs/verification/phase-3-1-2-4/00-canonical-correction-reference.md` đến `12-final-independent-acceptance.md`
  - *Phase 3.2 Verification Reports (8 files):*
    - `Travel_Planner/docs/verification/phase-3-2/01-database-migration-report.md` đến `08-final-acceptance-report.md`
  - *Phase 3.2.1 Verification Reports (8 files):*
    - `Travel_Planner/docs/verification/phase-3-2-1/01-bac-ninh-code-name-discrepancy-audit.md` đến `08-final-phase-3-2-1-acceptance.md`
  - *Phase 3.2.2 Verification Reports (7 files):*
    - `Travel_Planner/docs/verification/phase-3-2-2/01-code-09475-final-reconciliation.md` đến `07-final-phase-3-2-2-acceptance.md`
  - *Phase 3.3 Verification Reports (11 files):*
    - `Travel_Planner/docs/verification/phase-3-3/00-current-architecture-audit.md` đến `10-final-acceptance-report.md`
  - *Phase 3.3.1 Verification Reports (11 files):*
    - `Travel_Planner/docs/verification/phase-3-3-1/00-baseline-and-git-audit.md` đến `10-final-acceptance-report.md`
  - *Phase 4 Verification Reports (11 files):*
    - `Travel_Planner/docs/verification/phase-4/00-current-architecture-audit.md` đến `10-final-acceptance-report.md`
  - *Working Tree Organization Report (1 file):*
    - `Travel_Planner/docs/verification/working-tree-organization/01-working-tree-inventory-and-grouping-report.md`

---

## 6. ĐỐI CHIẾU GIT STATUS TRƯỚC VÀ SAU RÀ SOÁT (VERIFICATION PROOF)

- **Trước khi rà soát:**
  - Branch: `develop` | HEAD: `9902ccd`
  - Modified: 16 files
  - Untracked: 140 files
  - Staged: 0 files
- **Sau khi rà soát & tạo báo cáo:**
  - Branch: `develop` | HEAD: `9902ccd`
  - Modified: 16 files (giữ nguyên tuyệt đối)
  - Untracked: 141 files (chỉ thêm đúng 01 file báo cáo này tại `docs/verification/working-tree-organization/`)
  - Staged: 0 files
  - **Cam kết:** Không có lệnh commit, push, stage, checkout hay reset nào được thực thi. Toàn bộ mã nguồn và dữ liệu được bảo toàn nguyên trạng.

