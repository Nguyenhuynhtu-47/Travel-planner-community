# PHASE 3.0 — ĐÁNH GIÁ NGUỒN DỮ LIỆU ĐỊA GIỚI HÀNH CHÍNH VIỆT NAM
## Comprehensive Evaluation of Administrative & Geospatial Data Sources for Vietnam

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3.0 — Administrative Data Audit & Architecture Design  
**Ngày thực hiện:** 2026-11-11  
**Mục tiêu:** Khảo sát, so sánh và lựa chọn các nguồn dữ liệu hành chính và hình học địa lý (geometry/boundary) phục vụ xây dựng catalog địa giới hành chính quốc gia cho Travel Planner theo mô hình chính quyền 2 cấp sau ngày 01/07/2025.

---

## 1. Nguyên tắc Tuyển chọn Nguồn Dữ liệu

1. **Phân định Pháp lý và Hình học:**
   - **Nguồn Pháp lý (Legal Authority):** Danh mục đơn vị hành chính, mã số chuẩn quốc gia, tên chính thức, cấp bậc hành chính, và quan hệ sáp nhập bắt buộc phải lấy từ nguồn của cơ quan Nhà nước Việt Nam (Cục Thống kê / Tổng cục Thống kê, CSDL Quốc gia, Nghị quyết của Quốc hội / Ủy ban Thường vụ Quốc hội). Tuyệt đối không lấy dữ liệu phân cấp từ các API thương mại (Google Maps, LocationIQ, HERE) làm căn cứ pháp lý.
   - **Nguồn Hình học (Geospatial Geometry):** Tọa độ tâm (Centroid), Khung bao (Bounding Box), và Ranh giới đa giác (Polygon/MultiPolygon GeoJSON) được tích hợp từ các tổ chức quốc tế mở (UN OCHA, OpenStreetMap, GADM) và đối soát với mã chuẩn quốc gia.
2. **Khả năng Lưu trữ & Vận hành Nội bộ (Offline-first / Self-contained):** Dữ liệu phải có khả năng tải về, import vào cơ sở dữ liệu MySQL 8 nội bộ, không phụ thuộc vào API trực tuyến trả phí hay giới hạn rate limit khi người dùng tìm kiếm.
3. **Mô hình Hành chính Hiện hành (Sau 01/07/2025):** Dữ liệu phải phản ánh mô hình chính quyền địa phương 2 cấp (34 tỉnh/thành phố trực thuộc TW và ~3.300 đơn vị cấp xã/phường/đặc khu), đồng thời lưu vết các quận/huyện/xã cũ dưới dạng Aliases.

---

## 2. Đánh giá Chi tiết Các Nguồn Dữ liệu

### 2.1. Nguồn Pháp lý và Danh mục Hành chính Chính thức

#### Nguồn 1: Cổng Thông tin Danh mục Đơn vị Hành chính Việt Nam — Cục Thống kê (NSO / GSO)
* **Cơ quan quản lý:** Cục Thống kê (trước đây là Tổng cục Thống kê - GSO), Bộ Kế hoạch và Đầu tư / Bộ Tài chính.
* **URL chính thức:** [https://www.nso.gov.vn/](https://www.nso.gov.vn/) (Hệ thống tra cứu danh mục hành chính: [https://danhmuchanhchinh.gso.gov.vn/](https://danhmuchanhchinh.gso.gov.vn/))
* **Loại dữ liệu:** Bảng mã số chuẩn quốc gia của các đơn vị hành chính:
  - Mã tỉnh/thành phố (2 chữ số: ví dụ `01` - Hà Nội, `79` - TP. Hồ Chí Minh).
  - Mã xã/phường/đặc khu (5 chữ số).
  - Bảng đối chiếu mã số cũ - mã số mới sau các đợt sắp xếp, sáp nhập.
* **Độ chính xác & Tin cậy:** **Tuyệt đối (Nguồn chuẩn quốc gia cao nhất)**.
* **Định dạng dữ liệu:** Excel (.xlsx), CSV, Web REST lookup.
* **Giấy phép & Chi phí:** Dữ liệu mở của Chính phủ, miễn phí 100%, không cần API key.
* **Khả năng duy trì dài hạn:** Ổn định và được cập nhật bắt buộc theo các Nghị quyết của Quốc hội.
* **Lý do lựa chọn:** Đây là nguồn **chân lý duy nhất (Single Source of Truth)** cho bảng mã `code`, tên gọi chuẩn `name`, và loại hình đơn vị hành chính `area_type`.

#### Nguồn 2: Cổng Thông tin Điện tử Chính phủ & Cơ sở Dữ liệu Quốc gia về Dân cư
* **Cơ quan quản lý:** Văn phòng Chính phủ / Cục Cảnh sát Quản lý Hành chính về Trật tự Xã hội (C06 - Bộ Công an).
* **URL chính thức:** [https://chinhphu.vn/](https://chinhphu.vn/) và [https://dancuquocgia.gov.vn/](https://dancuquocgia.gov.vn/)
* **Loại dữ liệu:** Các văn bản quy phạm pháp luật (Nghị quyết của Ủy ban Thường vụ Quốc hội về việc sắp xếp đơn vị hành chính cấp huyện, cấp xã của từng tỉnh/thành phố giai đoạn 2023–2025 và triển khai Luật sửa đổi tổ chức chính quyền địa phương 2 cấp từ 01/07/2025).
* **Độ chính xác & Tin cậy:** **Tuyệt đối (Văn bản quy phạm pháp luật)**.
* **Lý do lựa chọn:** Dùng để đối chiếu lịch sử sáp nhập: ghi nhận chính xác xã A và xã B gộp thành xã C, quận D kết thúc hoạt động và chuyển giao các phường về đơn vị nào, phục vụ nạp dữ liệu cho bảng `administrative_area_aliases`.

---

### 2.2. Nguồn Hình học và Ranh giới Địa lý (Geometry & Boundaries)

#### Nguồn 3: UN OCHA — Humanitarian Data Exchange (HDX)
* **Tổ chức quản lý:** Văn phòng Điều phối các Vấn đề Nhân đạo Liên Hợp Quốc (UN OCHA).
* **Dataset:** *Viet Nam - Subnational Administrative Boundaries* (Dữ liệu ranh giới hành chính các cấp của Việt Nam).
* **URL tải dữ liệu:** [https://data.humdata.org/dataset/cod-ab-vnm](https://data.humdata.org/dataset/cod-ab-vnm)
* **Loại dữ liệu & Cấp độ:**
  - `vnm_admbnda_adm1`: Ranh giới 34 tỉnh/thành phố (Polygon/MultiPolygon).
  - `vnm_admbnda_adm2`: Ranh giới cấp cơ sở sau sắp xếp (Xã/Phường/Đặc khu).
* **Định dạng tải:** **GeoJSON**, Shapefile (.shp), TopoJSON, Geodatabase.
* **Hệ quy chiếu:** WGS 84 (EPSG:4326) — chuẩn quốc tế tương thích hoàn hảo với Leaflet, flutter_map và MySQL 8 Spatial.
* **Giấy phép & Chi phí:** Creative Commons Attribution (CC-BY 4.0), hoàn toàn miễn phí, cho phép sử dụng trong ứng dụng phần mềm.
* **Độ chính xác:** Rất cao, các polygon được chuẩn hóa topologically (không có khe hở hay chồng lấn giữa các ranh giới).
* **Lý do lựa chọn:** Đây là nguồn **hình học GeoJSON chuẩn nhất** để trích xuất Bounding Box (`min_lat`, `max_lat`, `min_lon`, `max_lon`) và Polygon phục vụ thuật toán Point-in-Polygon trong MySQL 8.

#### Nguồn 4: OpenStreetMap (OSM) Vietnam Extracts via Geofabrik
* **Tổ chức quản lý:** Cộng đồng OpenStreetMap Quốc tế & Geofabrik GmbH.
* **URL tải dữ liệu:** [https://download.geofabrik.de/asia/vietnam.html](https://download.geofabrik.de/asia/vietnam.html)
* **Loại dữ liệu:** Toàn bộ dữ liệu bản đồ vector của Việt Nam, bao gồm `admin_level=4` (Tỉnh/TP), `admin_level=6` (Quận/Huyện lịch sử), `admin_level=8` (Xã/Phường).
* **Định dạng tải:** `.osm.pbf`, chuyển đổi sang GeoJSON qua công cụ mã nguồn mở `osmtogeojson` hoặc Overpass Turbo API ([https://overpass-turbo.eu/](https://overpass-turbo.eu/)).
* **Giấy phép:** Open Database License (ODbL 1.0).
* **Độ cập nhật:** Cập nhật hàng ngày (daily extracts). Cộng đồng OSM Việt Nam cập nhật rất nhanh tên mới của các xã/phường sáp nhập.
* **Lý do lựa chọn:** Dùng làm nguồn đối chiếu bổ sung tọa độ tâm (Centroid) và tìm kiếm các tên gọi dân gian/viết tắt do cộng đồng đóng góp.

#### Nguồn 5: GADM (Database of Global Administrative Areas)
* **Tổ chức quản lý:** Đại học California, Davis và nhóm nghiên cứu quốc tế.
* **URL:** [https://gadm.org/download.html](https://gadm.org/download.html) (Version 4.1).
* **Loại dữ liệu:** Bản đồ số ranh giới cấp tỉnh, huyện, xã của Việt Nam.
* **Giấy phép:** Miễn phí cho mục đích học thuật và phi thương mại.
* **Đánh giá hạn chế:** Tần suất cập nhật chậm hơn HDX và OSM, bản quyền hạn chế sử dụng thương mại.
* **Kết luận:** **Không sử dụng làm nguồn chính**, chỉ dùng để kiểm tra chéo khi cần thiết.

---

### 2.3. Bảng Ma trận So sánh Toàn diện Các Nguồn Dữ liệu

| Tiêu chí Đánh giá | Cục Thống kê (NSO/GSO) | UN OCHA (HDX) | OpenStreetMap (OSM) | GADM (v4.1) | API Thương mại (LocationIQ/HERE) |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Vai trò Đề xuất** | **Nguồn Pháp lý Chuẩn** | **Nguồn Boundary & GeoJSON** | **Nguồn Bổ trợ & Tọa độ Tâm** | Nguồn tham khảo chéo | Chỉ dùng fallback geocoding |
| **Mã định danh chính thức** | **Có (Mã chuẩn GSO)** | Có đối chiếu mã GSO | Có tag `ref`/`ISO3166-2` | Mã nội bộ GADM | Không có mã chuẩn |
| **Độ phủ cấp Tỉnh** | 100% (34 đơn vị mới) | 100% | 100% | 100% (63 đơn vị cũ) | Biến động |
| **Độ phủ cấp Xã/Phường** | 100% (~3.300 đơn vị) | ~98% | ~95% | Dữ liệu cũ (>10.000 xã) | Không đầy đủ |
| **Dữ liệu Hình học (GeoJSON)** | Không (chỉ có bảng biểu) | **Có sẵn GeoJSON chuẩn** | Cần export từ PBF/Overpass | Có Shapefile/GeoPackage | Không cung cấp trọn bộ |
| **Độ chính xác Bounding Box** | Không có | **Rất cao (WGS 84)** | Rất cao | Trung bình | Biến động |
| **Tần suất cập nhật** | Theo kỳ Nghị quyết | 6 - 12 tháng/lần | Hàng ngày (Daily) | 2 - 3 năm/lần | Liên tục |
| **Chi phí bản quyền** | **Miễn phí (Public Domain)** | **Miễn phí (CC-BY 4.0)** | **Miễn phí (ODbL)** | Phi thương mại | **Trả phí / Giới hạn Quota** |
| **Khả năng Offline trong MySQL**| **100% Import nội bộ** | **100% Import nội bộ** | Cần qua ETL pipeline | Import được | **Không thể (Bị cấm lưu cache lâu dài)** |

---

## 3. Kiến trúc ETL Pipeline Nhập Liệu Đề xuất

Để xây dựng danh mục chuẩn cho Travel Planner mà không làm phụ thuộc hệ thống vào bất kỳ file trung gian nào trong runtime, một quy trình ETL (Extract - Transform - Load) bán tự động được thiết kế như sau:

```
[1. Cục Thống kê (NSO)] ---> Danh mục Mã, Tên, Phân cấp, Lịch sử sáp nhập
                                     |
                                     v (Join theo Mã GSO)
[2. UN OCHA (HDX)]    ---> Trích xuất Centroid, Bounding Box, Polygon GeoJSON
                                     |
                                     v (Tạo Seeder Script nội bộ)
Travel_Planner Backend: AdministrativeAreaSeeder.java / SQL Init Seed
                                     |
                                     +---> Bảng `administrative_areas` (MySQL 8)
                                     +---> Bảng `administrative_area_aliases` (MySQL 8)
```

### Chi tiết các bước:
1. **Bước 1 (Extract):**
   - Tải file danh mục mã số đơn vị hành chính mới nhất từ Cổng Thông tin Cục Thống kê.
   - Tải bộ dữ liệu `vnm_admbnda_adm1` và `vnm_admbnda_adm2` định dạng GeoJSON từ UN OCHA HDX.
2. **Bước 2 (Transform):**
   - Khớp nối các đơn vị hành chính theo mã số chuẩn quốc gia (GSO Code).
   - Tính toán Bounding Box hình chữ nhật phẳng (`min_lat`, `max_lat`, `min_lon`, `max_lon`) và tọa độ tâm (`center_lat`, `center_lon`) cho từng đơn vị.
   - Tạo danh sách Aliases:
     - Biến thể không dấu (bỏ dấu tiếng Việt NFD).
     - Tên quận/huyện cũ trước khi bãi bỏ cấp huyện.
     - Tên xã/phường cũ trước đợt sáp nhập giai đoạn 2023–2025.
     - Các chữ viết tắt phổ biến (`TP`, `Q1`, `TX`, `HN`, `SG`, `ĐL`).
3. **Bước 3 (Load):**
   - Xuất dữ liệu đã chuẩn hóa thành file JSON seed sạch lưu trong `backend/src/main/resources/data/`.
   - Viết runner nạp dữ liệu an toàn, có tính idempotent (`ON DUPLICATE KEY UPDATE` hoặc kiểm tra `existsByCode()`).

---

## 4. Kết luận và Khuyến nghị Lựa chọn

1. **Khuyến nghị lựa chọn nguồn:**
   - **Nguồn chính pháp lý danh mục & phân cấp:** **Cục Thống kê Việt Nam (NSO/GSO)** kết hợp Nghị quyết sắp xếp đơn vị hành chính của Ủy ban Thường vụ Quốc hội.
   - **Nguồn chính hình học & ranh giới không gian:** **UN OCHA (HDX)** kết hợp trích xuất Overpass API của OpenStreetMap.
2. **Loại bỏ sự phụ thuộc vào API thương mại:** Hệ thống Travel Planner sẽ **chấm dứt việc gọi online tới LocationIQ/HERE chỉ để hỏi tọa độ một tỉnh/thành phố**. Toàn bộ 34 tỉnh/thành phố và các khu vực trọng điểm sẽ được phục vụ tức thì từ bộ nhớ trong (In-Memory Cache) và cơ sở dữ liệu MySQL nội bộ.

---

## 5. Xác minh Thực tế Bộ Dữ liệu Chuẩn & Hiệu chỉnh (Phase 3.1.2 Audit)

Trong Phase 3.1.2, bộ dữ liệu hành chính đã được đối soát, phân biệt rõ ràng giữa mốc tổ chức ban đầu 2025 và mốc snapshot 2026, loại bỏ triệt để các sai sót về tên và cấp quản lý:

1. **Phân biệt Mốc Dữ liệu & Căn cứ Pháp lý:**
   - **Mốc Tái tổ chức Toàn quốc (Hiệu lực 01/07/2025):**
     - Căn cứ pháp lý: **Nghị quyết số 202/2025/QH15** (sắp xếp 34 đơn vị cấp tỉnh), **Quyết định số 19/2025/QĐ-TTg** (danh mục và mã số hành chính toàn quốc), **Nghị quyết số 175/2024/QH15** (thành lập Thành phố Huế trực thuộc TW).
     - Phân bổ ban đầu tại 01/07/2025: **34 tỉnh/thành phố** (28 tỉnh, 6 TP trực thuộc TW) và **3.321 đơn vị cấp cơ sở** (**2.621 xã**, **687 phường**, **13 đặc khu đảo**).
   - **Mốc Snapshot Hiện hành Được Chọn (Snapshot Date & Effective Date: 2026-09-20):**
     - Căn cứ pháp lý: **Nghị quyết số 388/NQ-UBTVQH16** ngày 04/08/2026 (có hiệu lực từ **20/09/2026** về việc thành lập 12 phường tại tỉnh Bắc Ninh từ các xã hiện có) cùng các nghị quyết điều chỉnh cấp xã năm 2026 của UBTVQH.
     - Sự dịch chuyển cơ cấu: 22 đơn vị cấp xã được chuyển thành phường (trong đó có 12 phường tại Bắc Ninh). Tổng số đơn vị cấp cơ sở vẫn là 3.321, phân bổ thành: **2.599 xã (`COMMUNE`)**, **709 phường (`WARD`)**, **13 đặc khu đảo (`SPECIAL_ZONE`)**.
   - **Nguồn phân phối thứ cấp:** Kho dữ liệu mở `thanglequoc/vietnamese-provinces-database` bản phát hành `v5.2.0-decree388` (truy xuất ngày 11/11/2026). Giấy phép: Vietnam Government Open Data / MIT package.

2. **Các Hiệu chỉnh Dữ liệu Trọng yếu (Phase 3.1.2 Data Corrections):**
   - **Hà Nội (01):** Mã `00004` được đối chiếu chính xác là **Phường Ba Đình**; mã `00008` là **Phường Ngọc Hà**. Các mã cũ `00007` (Trúc Bạch cũ), `00010` (Cống Vị cũ), `00040` (Hàng Mã cũ) đã được thay thế sau đợt sắp xếp và không còn tồn tại độc lập trong danh mục chính thức.
   - **TP. Hồ Chí Minh (79):** Mã `26740` là **Phường Sài Gòn** (thay thế Bến Nghé cũ); mã `26743` là **Phường Bến Thành**; mã `26758` là **Phường Cầu Ông Lãnh**; mã `26737` là **Phường Tân Định**.
   - **Đặc khu đảo và đơn vị cha theo NQ 202/2025/QH15:**
     - Đặc khu Phú Quý (`23272`): Thuộc **Tỉnh Lâm Đồng** (`68`) do tỉnh Bình Thuận đã sáp nhập vào Lâm Đồng.
     - Đặc khu Côn Đảo (`26732`): Thuộc **Thành phố Hồ Chí Minh** (`79`) do tỉnh Bà Rịa - Vũng Tàu đã sáp nhập vào TP.HCM.
     - Đặc khu Phú Quốc (`31078`), Thổ Châu (`31105`), Kiên Hải (`31108`): Thuộc **Tỉnh An Giang** (`91`) do tỉnh Kiên Giang đã sáp nhập vào An Giang.
     - 8 đặc khu còn lại: Vân Đồn (`06994`, Quảng Ninh `22`), Cô Tô (`07192`, Quảng Ninh `22`), Cát Hải (`11914`, Hải Phòng `31`), Bạch Long Vĩ (`11948`, Hải Phòng `31`), Cồn Cỏ (`19742`, Quảng Trị `44`), Hoàng Sa (`20333`, Đà Nẵng `48`), Lý Sơn (`21548`, Quảng Ngãi `51`), Trường Sa (`22736`, Khánh Hoà `56`).
   - **Tên Đơn vị Cấp Tỉnh:** Đã chuẩn hóa tiền tố cho 28 tỉnh (`Tỉnh ...`) và 6 thành phố trực thuộc TW (`Thành phố ...`). Khắc phục lỗi hiển thị thành phố cho Quảng Ninh (`22`), Bắc Ninh (`24`), Đồng Nai (`75`) thành: **Tỉnh Quảng Ninh**, **Tỉnh Bắc Ninh**, **Tỉnh Đồng Nai**.
   - **Chuẩn hóa Ký tự Tiền tố:** Khắc phục lỗi viết thường tại mã `06325` ("xã Bắc Sơn" -> "Xã Bắc Sơn").

3. **Hệ thống Kiểm tra & Checksum Kép (Dual Checksum System):**
   - **Raw File SHA-256:** `eb5c213ada8ee1d7995ad484b53e61fd3e38d2f027027c7ae5e56ecaff02c4f9` (băm nội dung tệp vật lý JSON).
   - **Canonical Content Checksum (v1):** `44a715a95b9f3dac4f4f67a72f457c05c075c9dbf893f1668d106e96348e1230` (chuẩn hóa `code|name|areaType|parentCode`, sắp xếp theo bảng chữ cái độc lập với thứ tự JSON, băm SHA-256).
   - Bảng metadata `administrative_catalog_metadata` theo dõi toàn bộ thông số, cho phép phát hiện tức thì bất kỳ sự thay đổi trực tiếp nào trong database mà không làm chậm ứng dụng (kiểm tra bypass $< 5\text{ ms}$).

---

## 6. Kết quả Kiểm chứng Độc lập (Phase 3.1.2.1 Independent Verification)

Vào ngày 11/11/2026, đợt kiểm chứng độc lập Phase 3.1.2.1 đã hoàn tất việc rà soát và tạo lập bộ artifact kiểm chứng tại `docs/verification/phase-3-1-2-1/`. Đợt rà soát này ghi nhận trạng thái chưa đạt tuyệt đối do cần bổ sung căn cứ pháp lý sơ cấp cho 10 trường hợp chuyển đổi còn lại và cần làm rõ tính pháp lý của bản quyền dữ liệu.

---

## 7. Khắc phục Pháp lý & Dữ liệu Triệt để (Phase 3.1.2.2 Legal & Data Remediation)

Sau đợt review chuyên sâu Phase 3.1.2.1, giai đoạn Phase 3.1.2.2 đã khắc phục toàn bộ các thiếu sót và sai lệch kỹ thuật/pháp lý, đạt trạng thái **ACCEPTED WITH EXPLICIT LIMITATIONS**:

1. **Căn cứ Pháp lý & Cơ cấu Tỉnh/Thành phố tại Snapshot 2026-09-20:**
   - **9 Thành phố trực thuộc Trung ương (`CENTRAL_CITY`):**
     - 6 thành phố cơ sở từ 01/07/2025: Hà Nội (`01`), Hải Phòng (`31`), Huế (`46` - NQ 175/2024/QH15), Đà Nẵng (`48`), TP. Hồ Chí Minh (`79`), Cần Thơ (`92`).
     - 3 thành phố trực thuộc Trung ương mới thành lập trong năm 2026:
       - **Thành phố Đồng Nai (`75`):** Nghị quyết số 30/2026/QH16 ngày 24/04/2026 (hiệu lực 30/04/2026).
       - **Thành phố Quảng Ninh (`22`):** Nghị quyết số 36/2026/QH16 ngày 24/08/2026 (hiệu lực 01/09/2026).
       - **Thành phố Bắc Ninh (`24`):** Nghị quyết số 39/2026/QH16 ngày 24/08/2026 (hiệu lực 20/09/2026).
   - **25 Tỉnh (`PROVINCE`):** Cao Bằng (`04`), Tuyên Quang (`08`), Điện Biên (`11`), Lai Châu (`12`), Sơn La (`14`), Lào Cai (`15`), Thái Nguyên (`19`), Lạng Sơn (`20`), Phú Thọ (`25`), Hưng Yên (`33`), Ninh Bình (`37`), Thanh Hoá (`38`), Nghệ An (`40`), Hà Tĩnh (`42`), Quảng Trị (`44`), Quảng Ngãi (`51`), Gia Lai (`52`), Khánh Hoà (`56`), Đắk Lắk (`66`), Lâm Đồng (`68`), Tây Ninh (`80`), Đồng Tháp (`82`), Vĩnh Long (`86`), An Giang (`91`), Cà Mau (`96`).
   - **Tổng cộng cấp Tỉnh:** Đúng 34 đơn vị (9 `CENTRAL_CITY`, 25 `PROVINCE`). Không trộn lẫn tên các tỉnh cũ đã sáp nhập theo NQ 202/2025/QH15.

2. **Xác minh Sơ cấp 100% cho 22 Trường hợp Chuyển đổi Xã thành Phường:**
   - **10 phường tại Đồng Nai (`75`):** Được thành lập theo **Nghị quyết số 237/NQ-UBTVQH16** ngày 14/04/2026 (hiệu lực 30/04/2026) gồm: Trảng Bom (`26248`), Long Thành (`26368`), Trị An (`26170`), Nhơn Trạch (`26485`), Tân Khai (`25357`), Xuân Lộc (`26425`), Tân Phú (`26116`), Lộc Ninh (`25270`), Dầu Giây (`26326`), Đồng Phú (`25363`). (Đồng Nai: 95 đơn vị = 33 phường, 62 xã).
   - **12 phường tại Bắc Ninh (`24`):** Được thành lập theo **Nghị quyết số 388/NQ-UBTVQH16** ngày 04/08/2026 (hiệu lực 20/09/2026) gồm: Yên Phong (`09193`), Tiên Du (`09319`), Chi Lăng (`09313`), Phù Lãng (`09292`), Lương Tài (`09496`), Gia Bình (`09454`), Nhân Thắng (`09475`), Hiệp Hoà (`07840`), Bố Hạ (`07294`), Lạng Giang (`07375`), Kép (`07399`), Lục Nam (`07444`). (Bắc Ninh: 99 đơn vị = 45 phường, 54 xã).
   - Toàn bộ 22/22 trường hợp chuyển đổi ($10 + 12 = 22$) đều có căn cứ văn bản quy phạm pháp luật sơ cấp (`VERIFIED_PRIMARY`).
   - Tổng số đơn vị cấp cơ sở: 3.321 đơn vị (2.599 `COMMUNE`, 709 `WARD`, 13 `SPECIAL_ZONE`).

3. **Đính chính Căn cứ Bản quyền theo Luật Sở hữu Trí tuệ Việt Nam:**
   - **Căn cứ Pháp lý Đúng:** **Điều 15 (Khoản 2 và 3)** Luật Sở hữu trí tuệ số 50/2005/QH11 (sửa đổi, bổ sung 2009, 2019, 2022).
     - Khoản 2: Văn bản quy phạm pháp luật, văn bản hành chính và bản dịch chính thức không thuộc phạm vi bảo hộ quyền tác giả.
     - Khoản 3: Số liệu, sự kiện thuần túy không thuộc phạm vi bảo hộ quyền tác giả.
   - **Đánh giá Đa chiều:**
     - Mã nguồn ETL/scripts trong repository `thanglequoc` chịu sự điều chỉnh của MIT License.
     - Dữ liệu địa giới hành chính, danh mục tên và mã số là dữ liệu mở của cơ quan nhà nước, không có rủi ro bản quyền thương quyền.
     - Đã loại bỏ trích dẫn nhầm Điều 19 và không dùng thuật ngữ võ đoán "0% rủi ro".

4. **Bộ Checksum & Artifacts Kiểm chứng Phase 3.1.2.2:**
   - **Raw Dataset SHA-256:** `8fa358a085cdc10e4533ef41a51ee02b8e2a81dd6b0cb642e44ab33f2b60b816`
   - **Canonical Content Checksum v1:** `af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`
   - **Bộ 6 Artifacts Kiểm chứng Độc lập Mới:** Lưu trữ tại `docs/verification/phase-3-1-2-2/`.

---

## 8. Nghiệm thu và Hiệu chỉnh Cuối cùng (Phase 3.1.2.3 Final Correction & Acceptance)

Giai đoạn Phase 3.1.2.3 đã rà soát độc lập toàn diện và hoàn thiện các chuẩn mực:
1. **Khắc phục Triệt để Ngày Ban hành Văn bản Pháp lý:**
   - NQ 30/2026/QH16: Ngày ký chính thức là **24/04/2026** (hiệu lực 30/04/2026).
   - NQ 36/2026/QH16: Ngày ký chính thức là **24/08/2026** (hiệu lực 01/09/2026).
   - NQ 39/2026/QH16: Ngày ký chính thức là **24/08/2026** (hiệu lực 20/09/2026).
   - NQ 237/NQ-UBTVQH16: Ngày ký chính thức là **14/04/2026** (hiệu lực 30/04/2026).
   - NQ 388/NQ-UBTVQH16: Ngày ký chính thức là **04/08/2026** (hiệu lực 20/09/2026).
2. **Danh mục 25 Tỉnh Chuẩn hóa Tuyệt đối:**
   - Xác định chính xác 25 tỉnh và 9 thành phố trực thuộc Trung ương, loại bỏ hoàn toàn việc nhắc các tỉnh cũ đã sáp nhập như đơn vị hiện hành.
3. **Bóc tách Từng File Nguồn:**
   - `metadata.json`: 2.276 bytes, SHA-256 `c6bfae44...`, newline LF.
   - `provinces.json`: 4.931 bytes, SHA-256 `3a1fa972...`, newline CRLF.
   - `communes.json`: 473.956 bytes, SHA-256 `fb0cd4e0...`, newline CRLF.
   - Sequential Concatenated SHA-256: `8fa358a085cdc10e4533ef41a51ee02b8e2a81dd6b0cb642e44ab33f2b60b816`.
4. **Bộ 7 Artifacts Hoàn chỉnh tại `docs/verification/phase-3-1-2-3/`:**
   - `01-legal-timeline-and-official-documents.md`
   - `02-province-level-catalog-verification.csv` (34 đơn vị 100% Primary)
   - `03-commune-level-catalog-verification.csv` (3.321 đơn vị: 45 Primary, 3.276 Secondary)
   - `04-22-ward-transitions-verification.md` (10 Đồng Nai, 12 Bắc Ninh)
   - `05-dataset-provenance-and-license-review.md`
   - `06-checksum-importer-concurrency-integrity.md`
   - `07-final-acceptance-report.md`
5. **Chấp thuận Nghiệm thu:** **ACCEPTED WITH EXPLICIT LIMITATIONS**, hoàn toàn đủ điều kiện chuyển sang Phase 3.2.

---

## 9. Hiệu chỉnh Toàn vẹn Dữ liệu Chuẩn tắc (Phase 3.1.2.4 Canonical Data Integrity Remediation)

Thực hiện theo tài liệu chỉ đạo chuẩn tắc `docs/verification/phase-3-1-2-4/00-canonical-correction-reference.md`, giai đoạn Phase 3.1.2.4 đã trực tiếp rà soát và hiệu chỉnh đồng bộ các sai lệch thực tế:
1. **Thay thế danh sách 10 phường Đồng Nai:** Loại bỏ hoàn toàn danh sách sai trong báo cáo cũ (Long Hưng, Phước Tân,...); đối soát chính xác 10 phường theo NQ 237/NQ-UBTVQH16 (`26248` Trảng Bom, `26368` Long Thành, `26170` Trị An, `26485` Nhơn Trạch, `25357` Tân Khai, `26425` Xuân Lộc, `26116` Tân Phú, `25270` Lộc Ninh, `26326` Dầu Giây, `25363` Đồng Phú) trực thuộc `75` Thành phố Đồng Nai (`VERIFIED_PRIMARY`).
2. **Xử lý nghiêm ngặt 12 phường Bắc Ninh (Blocker):** Do toàn văn phụ lục chính thức của NQ 388/NQ-UBTVQH16 chưa có trong source bundle của dự án, 12 bản ghi này (`07294`, `07375`, `07399`, `07444`, `07840`, `09193`, `09292`, `09313`, `09319`, `09454`, `09475`, `09496`) được rút lại trạng thái xác minh sơ cấp, đánh dấu `UNVERIFIED_SOURCE_DOCUMENT_MISSING` và thiết lập rào cản ngăn chặn Place Backfill trong Phase 3.2.
3. **Chuẩn hóa quan hệ cha của 5 đặc khu:** Phú Quý $\rightarrow$ Lâm Đồng (`68`), Côn Đảo $\rightarrow$ TP.HCM (`79`), Phú Quốc, Thổ Châu, Kiên Hải $\rightarrow$ An Giang (`91`).
4. **Đối soát 1-1 từng bản ghi cơ sở dữ liệu:** Toàn bộ 3.355 bản ghi MySQL khớp 100% với JSON source, Canonical Content Checksum v1 giữ vững `af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`.
5. **Bảo tồn tuyệt đối:** 24 địa điểm và 121 hoạt động hành trình nguyên vẹn; không thêm cột `places.administrative_area_id` trước khi có migration Phase 3.2.
6. **Bộ Artifacts mới tại `docs/verification/phase-3-1-2-4/`:**
   - `01-canonical-correction-results.md`
   - `02-province-level-reconciliation.csv` (34 rows)
   - `03-commune-level-correction.csv` (3.321 rows: 33 Primary, 12 Unverified Missing Doc, 3.276 Secondary)
   - `04-source-database-integrity.md`
   - `05-place-activity-preservation.md`
   - `06-final-acceptance-report.md`
7. **Trạng thái nghiệm thu:** **ACCEPTED WITH EXPLICIT LIMITATIONS**, đủ điều kiện chuyển sang Phase 3.2.

---

## 10. Kiểm chứng Độc lập & Gia cố Ranh giới Tin cậy (Phase 3.1.2.4.1 Independent Catalog Verification & Acceptance)

Giai đoạn Phase 3.1.2.4.1 đã thực hiện kiểm chứng độc lập chuyên sâu toàn diện đối với toàn bộ dữ liệu, cơ chế đồng bộ và ranh giới an toàn:
1. **Kiểm toán Ranh giới Tin cậy & Xử lý 12 bản ghi Bắc Ninh:** 12 bản ghi cấp xã/phường tại Bắc Ninh thiếu phụ lục NQ 388/NQ-UBTVQH16 được cách ly triệt để với trạng thái `UNVERIFIED_SOURCE_DOCUMENT_MISSING`. Đã chứng minh rủi ro lan truyền bằng 0: 0 địa điểm, 0 hoạt động phụ thuộc vào các bản ghi này. Quy tắc resolver Phase 3.2 được thiết lập để trả về `NULL` và ghi log cảnh báo khi gặp các đơn vị này.
2. **Chứng cứ Mã định danh 10 Phường Đồng Nai:** Xác minh độc lập mã hành chính 5 chữ số từ nguồn GSO và QĐ 19/2025/QĐ-TTg cho toàn bộ 10 phường theo NQ 237/NQ-UBTVQH16, gắn nhãn `VERIFIED_PRIMARY`.
3. **Phân loại 4 Tầng Toàn vẹn (4-Tier Classification):**
   - **Tầng A (Verified & Trusted):** 67 bản ghi (34 tỉnh/thành phố + 33 xã/phường/đặc khu cấp 1).
   - **Tầng B (Verified with Limitations):** 3.276 xã/phường thứ cấp xác minh qua GSO / QĐ 19/2025/QĐ-TTg.
   - **Tầng C (Unverified & Quarantined):** 12 đơn vị Bắc Ninh bị cách ly khỏi runtime linking.
   - **Tầng D (Mismatch):** 0 bản ghi sai lệch.
4. **Kiểm chứng Độc quyền Đồng thời Đa Tiến trình (Multi-Process Concurrency):** Kiểm chứng thành công bằng hai tiến trình hệ điều hành độc lập (`mysql.exe`, PID 20144 và PID 1256/1136) kết nối qua 2 TCP socket riêng biệt, chứng minh `GET_LOCK('administrative_area_migration_lock')` loại trừ tương tranh tuyệt đối (bác bỏ tiến trình B với return `0` khi đang khóa, bàn giao thành công với return `1` khi tiến trình A giải phóng).
5. **Bảo tồn Tuyệt đối Places & Activities:** 24 Places (đúng 12 cột, 0 cột mới, không có `administrative_area_id`) và 121 Activities (111 linked via `canonical_place_id`, 10 free-form custom locations) được đối soát từng dòng, bảo tồn 100%.
6. **Bộ 6 Artifacts Nghiệm thu Bổ sung tại `docs/verification/phase-3-1-2-4/`:**
   - `07-independent-record-verification.csv` (3.321 rows)
   - `08-unverified-records-and-runtime-exclusion.md`
   - `09-dong-nai-code-evidence.md`
   - `10-place-activity-row-level-preservation.md`
   - `11-independent-mysql-concurrency-test.md`
   - `12-final-independent-acceptance.md`
7. **Quyết định Nghiệm thu:** **`ACCEPTED WITH EXPLICIT LIMITATIONS`**.

---

## 11. Tích hợp Dữ liệu & Phân giải Thực thể Địa điểm (Phase 3.2 Place Linking & Resolution)

Giai đoạn Phase 3.2 hoàn thành việc tích hợp dữ liệu giữa `places` và `administrative_areas`:
1. **Phân loại Độ tin cậy (Trust Classification):** Toàn bộ 3.355 bản ghi được lưu trữ trường `trust_classification` (67 Tier A, 3.276 Tier B, 12 Tier C, 0 Tier D).
2. **Cơ chế Cách ly Tuyệt đối (Quarantine Exclusion):** Toàn bộ 12 mã Bắc Ninh (`07294`, `07375`, `07399`, `07444`, `07840`, `09193`, `09292`, `09313`, `09319`, `09454`, `09475`, `09496`) bị chặn tuyệt đối ở cả tầng phân giải (`AdministrativeAreaResolver`), tầng dịch vụ tự động, và tầng endpoint thủ công (`PUT /api/admin/places/{id}/administrative-area`).
3. **Kết quả Liên kết Địa điểm:** 20/24 địa điểm (83.3%) được liên kết chính xác; 4 địa điểm trả về `confidence=AMBIGUOUS` không liên kết tự động; 0 địa điểm bị liên kết nhầm vào danh mục cách ly.
4. **Bảo tồn Tuyệt đối:** 24 địa điểm và 121 hoạt động hành trình (111 canonical, 10 custom) nguyên vẹn 100%. Bảng `activities` giữ nguyên 20 cột, không có bất kỳ thay đổi nào.
5. **Quyết định Nghiệm thu:** **`ACCEPTED WITH EXPLICIT LIMITATIONS`**.




