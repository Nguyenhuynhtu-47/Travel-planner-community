# PHASE 3.0 — BÁO CÁO AUDIT KIẾN TRÚC ĐỊA GIỚI HÀNH CHÍNH
## Architectural Audit of Administrative Areas, Place Catalog & Location Search

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3.0 — Administrative Data Audit & Architecture Design  
**Ngày thực hiện:** 2026-11-11  
**Vai trò:** Senior Software Architect & Lead Geospatial Engineer  
**Phạm vi:** Audit Only (Không chỉnh sửa source code, không can thiệp database)  
**Trạng thái kiểm tra:** Hệ thống ở branch `develop` (HEAD: `9902ccd`), working tree sạch sẽ.

---

## 1. Tổng quan Mục tiêu Audit

Phase 3.0 thực hiện rà soát toàn diện hiện trạng kiến trúc dữ liệu của Travel Planner nhằm chuẩn bị nền tảng tích hợp **Đơn vị Hành chính (Administrative Areas)** vào hệ thống. Ba trụ cột chính được rà soát bao gồm:
1. **Kiến trúc Danh mục Địa điểm (`Place Catalog`):** Đánh giá cấu trúc lưu trữ địa chỉ, sự thiếu hụt dữ liệu phân cấp hành chính, và mức độ tương thích với mô hình hành chính mới của Việt Nam.
2. **Kiến trúc Ảnh chụp Vị trí Hoạt động (`Activity Location Snapshot`):** Đảm bảo nguyên tắc bất biến: việc bổ sung Administrative Area vào Place tuyệt đối không làm thay đổi snapshot vị trí độc lập của 121 hoạt động hiện có hoặc làm sai lệch routing.
3. **Kiến trúc Tìm kiếm Vị trí (`Location Search Architecture`):** Đánh giá năng lực của `QueryUnderstandingService`, `GeographicFilterService`, và `LocationServiceImpl` trong việc phân tích ý ngữ tìm kiếm (POI vs. Địa danh) và xác định các điểm nghẽn phụ thuộc vào mạng ngoại bộ khi giải quyết vùng địa lý.

---

## 2. Audit Kiến trúc Place Hiện tại

### 2.1. Cấu trúc Thực thể `Place` và Bảng `places`
Rà soát trực tiếp file mã nguồn [`Place.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/Place.java) và schema bảng `places` trên MySQL (`travel_planner`):

```sql
CREATE TABLE `places` (
  `place_id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  `normalized_name` varchar(150) NOT NULL,
  `address` varchar(255) NOT NULL,
  `description` text,
  `image_url` varchar(500) DEFAULT NULL,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `category` enum('ATTRACTION','CAFE','ENTERTAINMENT','HOTEL','OTHER','RESTAURANT','SHOPPING') NOT NULL,
  `status` enum('ACTIVE','HIDDEN') NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`place_id`),
  KEY `idx_places_normalized_name` (`normalized_name`),
  KEY `idx_places_category` (`category`),
  KEY `idx_places_status` (`status`),
  KEY `idx_places_coords` (`latitude`,`longitude`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### Phân tích Thuộc tính Địa chỉ:
1. **Thông tin địa chỉ hiện có:** Thực thể `Place` chỉ sở hữu duy nhất một trường chuỗi phi cấu trúc: `address` (`varchar(255)`). Không có bất kỳ cột nào lưu trữ thông tin cấu trúc như tỉnh/thành phố, quận/huyện, phường/xã, hay mã định danh hành chính chính thức.
2. **Nguồn gốc địa chỉ hiện tại:**
   - Trong `DataSeeder`: Địa chỉ của 24 địa điểm du lịch mẫu được định nghĩa thủ công dưới dạng văn bản tự do theo thói quen phân cấp cũ (ví dụ: `"Hoàn Kiếm, Hà Nội"`, `"02 Công xã Paris, Bến Nghé, Quận 1, TP. Hồ Chí Minh"`).
   - Trong luồng tạo/chỉnh sửa Place qua Admin Web (`AdminPlaceController` / `PlaceServiceImpl`): Địa chỉ được nhập từ form hoặc lấy từ trường `formattedAddress` do provider bản đồ ngoại bộ (LocationIQ / TomTom) trả về.
3. **Phân biệt địa chỉ gốc và địa chỉ chuẩn hóa:** Hệ thống **chưa phân biệt**. Chỉ có thuộc tính `name` được chuẩn hóa thành `normalizedName` (bỏ dấu tiếng Việt, viết thường) qua `LocationRankingServiceImpl.normalizeText()`. Chuỗi `address` hoàn toàn chưa được chuẩn hóa, không có parser tách thành phần đường/phường/tỉnh.
4. **Khả năng xác định Administrative Area từ tọa độ:**
   - 100% (24/24) Place hiện có đều sở hữu cặp tọa độ `latitude` và `longitude` chuẩn xác, nằm hoàn toàn trong lãnh thổ Việt Nam.
   - Do đó, về mặt kỹ thuật toán học/địa lý, hoàn toàn có thể xác định được đơn vị hành chính trực thuộc thông qua phép chiếu tọa độ (Point-in-Polygon hoặc Bounding Box + Khoảng cách tâm).
5. **Dữ liệu địa chỉ cũ không phù hợp với mô hình mới:**
   - **Thừa Thiên Huế $\rightarrow$ TP. Huế:** Place 7 (`Đại Nội Huế`) có địa chỉ `"Thuận Thành, TP. Huế, Thừa Thiên Huế"`, trong khi theo mô hình mới, Thừa Thiên Huế đã trở thành Thành phố Huế trực thuộc Trung ương. Place 8 (`Chùa Thiên Mụ`) ghi `"Đồi Hà Khê, Kim Long, TP. Huế"` thiếu định danh cấp tỉnh.
   - **Địa danh cấp xã/phường sáp nhập:** Place 5 (`Bản Cát Cát`) ghi `"San Sả Hồ, Sa Pa, Lào Cai"`, trong khi San Sả Hồ đã được sắp xếp lại đơn vị hành chính thị xã Sa Pa. Place 13 (`Hồ Xuân Hương`) ghi `"Phường 1, TP. Đà Lạt, Lâm Đồng"`, trong đợt sắp xếp các phường trung tâm Đà Lạt đã có sự thay đổi ranh giới.
   - **Mô hình chính quyền 2 cấp sau 01/07/2025:** Các Place 15 & 16 tại TP. Hồ Chí Minh ghi `"Quận 1, TP. Hồ Chí Minh"`. Sau ngày 01/07/2025, cấp huyện/quận bị bãi bỏ vai trò cấp chính quyền trung gian, quyền hạn chuyển trực tiếp xuống cấp cơ sở (Phường/Xã/Đặc khu) dưới tỉnh.

### 2.2. Quan hệ Provider Mapping (`PlaceProviderMapping`)
Rà soát [`PlaceProviderMapping.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/PlaceProviderMapping.java):
* Bảng `place_provider_mappings` lưu trữ liên kết giữa `place_id` nội bộ và các định danh nhà cung cấp ngoại bộ (`provider` + `provider_place_id`).
* Trường `metadata_json` cho phép lưu dữ liệu JSON bổ sung từ nhà cung cấp nhưng hiện tại chưa được khai thác để lưu các thành phần địa chỉ chi tiết (`address_components` như state, city, postcode).

---

## 3. Audit Kiến trúc Activity Location Snapshot

### 3.1. Tính Độc lập Bất biến của Snapshot Vị trí
Rà soát [`Activity.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/model/Activity.java) và logic nghiệp vụ trong [`ItineraryServiceImpl.java`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java):

```java
// Các trường snapshot độc lập trong Activity.java:
@Column(name = "location_name", length = 150)
private String locationName;

@Column(name = "location_address", length = 255)
private String locationAddress;

@Column(name = "latitude", precision = 10, scale = 7)
private BigDecimal latitude;

@Column(name = "longitude", precision = 10, scale = 7)
private BigDecimal longitude;

@Column(name = "place_id", length = 100)
private String placeId;

@Column(name = "location_provider", length = 30)
private String locationProvider;

@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "canonical_place_id", nullable = true)
private Place place;
```

### 3.2. Kết quả Rà soát Thực tế trên Cơ sở Dữ liệu (`travel_planner`)
Truy vấn trực tiếp xác nhận:
* **Tổng số hoạt động:** 121 bản ghi.
* **111 hoạt động liên kết catalog:** Có `canonical_place_id` trỏ về 24 Place trong catalog.
* **10 hoạt động tự do (Free-form):** Có `canonical_place_id IS NULL`, mang các `activity_id`: `{112, 113, 114, 116, 117, 120, 121, 122, 123, 124}`.
* **100% bản ghi sở hữu snapshot đầy đủ:** `location_name`, `location_address`, `latitude`, `longitude`, `place_id`, `location_provider` hoàn toàn không bị rỗng, 0 cặp tọa độ nửa null.
* **Tác động của Phase 3 tới Activity:**
  > [!IMPORTANT]
  > Khi triển khai Phase 3:
  > 1. `AdministrativeArea` chỉ được liên kết với `Place` (thông qua `places.administrative_area_id`), **tuyệt đối KHÔNG thêm foreign key trực tiếp vào bảng `activities`**.
  > 2. Mọi thay đổi về ranh giới hành chính, tên đơn vị hành chính mới, hay việc chuẩn hóa địa chỉ của `Place` **tuyệt đối KHÔNG được cascade cập nhật đè lên snapshot `location_name` hay `location_address` của `Activity`**.
  > 3. Tuyến đường chỉ đường (`RouteServiceImpl`) trích xuất tọa độ trực tiếp từ `activity.latitude` và `activity.longitude`, hoàn toàn độc lập với danh mục hành chính.

---

## 4. Audit Hệ thống Location Search

### 4.1. Luồng Tìm kiếm Hiện tại
Kiến trúc tìm kiếm hiện tại gồm 4 tầng dịch vụ:
1. [`QueryUnderstandingServiceImpl`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/QueryUnderstandingServiceImpl.java): Tách từ khóa và phân loại Intent (`POI_IN_LOCATION`, `LOCALITY`, `GENERIC_POI`, `SPECIFIC_PLACE`).
2. [`LocationServiceImpl.resolveTargetArea()`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationServiceImpl.java#L359-L380): Phân giải chuỗi địa danh thành bounding box và tọa độ tâm.
3. **Provider Gọi Ngoại bộ (`LocationIqGeocodingProvider` / `TomTomPlacesProvider`):** Tìm kiếm POI bị giới hạn trong khu vực.
4. [`GeographicFilterServiceImpl`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/GeographicFilterServiceImpl.java) & [`LocationRankingServiceImpl`](file:///d:/CODE/HCMUTE/TLCN/Travel-planner-community/Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/LocationRankingServiceImpl.java): Lọc ứng viên ngoài bán kính / ngoài tỉnh và sắp xếp theo độ tương đồng.

### 4.2. Đánh giá Khả năng Xử lý các Truy vấn Thử nghiệm

| Truy vấn Mẫu | Intent Nhận diện | Cách Hệ thống Hiện tại Xử lý | Điểm yếu & Hạn chế Kiến trúc Phát hiện |
|:---|:---|:---|:---|
| `Cơm tấm Long Xuyên` | `POI_IN_LOCATION`<br>(KW: `cơm tấm`, Loc: `Long Xuyên`) | Gọi LocationIQ để lấy BBox Long Xuyên, sau đó gọi `searchInArea("cơm tấm", bbox)`. | Tốn 2 network round-trips tới LocationIQ. Nếu LocationIQ không có POI cơm tấm trong bbox, hệ thống trả về fallback: `"Long Xuyên (Khu vực)"` (đây là lý do sinh ra bản ghi `locality_1793894615777`). |
| `Quán ăn ở Long Xuyên` | `POI_IN_LOCATION`<br>(KW: `quán ăn`, Loc: `Long Xuyên`) | Regex `ở` tách đúng `quán ăn` và `Long Xuyên`. Xử lý Two-stage tương tự. | Phụ thuộc vào từ điển cứng `KNOWN_ADMINISTRATIVE_REGIONS` (chỉ gồm 63 tỉnh cũ và một số thành phố lớn, không có danh sách xã/phường). |
| `Cafe Đà Lạt` | `POI_IN_LOCATION`<br>(KW: `cafe`, Loc: `Đà Lạt`) | Nhận diện prefix `cafe`, tách `Đà Lạt`. Tìm cafe trong bbox Đà Lạt. | Không lưu BBox Đà Lạt nội bộ, luôn phải resolve online qua LocationIQ. |
| `Khách sạn Vũng Tàu` | `POI_IN_LOCATION`<br>(KW: `khách sạn`, Loc: `Vũng Tàu`) | Nhận diện category `STAY`, resolve Vũng Tàu qua provider. | Không hỗ trợ các tên viết tắt thông dụng như `"VT"`, `"VungTau"`. |
| `Nhà hàng Quận 1` | `POI_IN_LOCATION`<br>(KW: `nhà hàng`, Loc: `Quận 1`) | Nhận diện `Quận 1` qua regex `ADMINISTRATIVE_PREFIX_PATTERN`. | Không biết `Quận 1` thuộc `TP. Hồ Chí Minh` nếu không gọi geocoding online. Dễ nhầm với Quận 1 ở các ngữ cảnh khác nếu có. |
| `Tiệm bánh gần Hồ Gươm` | `POI_IN_LOCATION`<br>(KW: `tiệm bánh`, Loc: `Hồ Gươm`) | Regex `gần` tách `tiệm bánh` và `Hồ Gươm`. | Hồ Gươm là Landmark, không phải Administrative Area. Hệ thống hiện xử lý gộp chung landmark và địa danh hành chính thành một loại. |
| `Địa danh cũ trước sáp nhập` (ví dụ: `Hà Tây`, `Bến Nghé cũ`, huyện cũ) | Thường rơi vào `SPECIFIC_PLACE` hoặc gọi provider trả về kết quả mồ côi | Không có bảng từ điển Alias lịch sử để ánh xạ địa danh cũ sang đơn vị hành chính mới. | Dễ dẫn đến việc không tìm thấy khu vực hoặc gửi truy vấn sai lệch tới provider. |
| `Tên phường/xã mới` | Thường bị coi là `SPECIFIC_PLACE` | `KNOWN_ADMINISTRATIVE_REGIONS` chỉ có cấp tỉnh/thành phố, hoàn toàn không có cấp xã/phường. | Không kích hoạt được chế độ `POI_IN_LOCATION` nếu người dùng gõ tên xã/phường mới mà không kèm prefix `"phường"`. |
| `Truy vấn không dấu` (ví dụ: `quan an o da lat`) | Chuẩn hóa NFD bỏ dấu tốt, regex match được. | Hoạt động tốt ở tầng phân tích từ ngữ, nhưng khi gọi provider ngoại bộ dễ bị trả kết quả sai lệch nếu provider không hỗ trợ tiếng Việt không dấu chuẩn. | Thiếu alias nội bộ có sẵn tọa độ và BBox chuẩn xác. |

### 4.3. Điểm nghẽn Cốt lõi của Hệ thống Tìm kiếm Hiện tại
1. **Phụ thuộc 100% vào Network Call để Resolve Địa giới:** Mỗi khi người dùng gõ `"quán ăn ở Đà Lạt"`, hệ thống phải tốn 1 HTTP request gọi LocationIQ để hỏi tọa độ Đà Lạt trước khi thực hiện bước tiếp theo. Nếu LocationIQ bị nghẽn mạng hoặc hết quota, toàn bộ tính năng tìm kiếm theo khu vực sụp đổ.
2. **Từ điển Địa danh Cứng (`Hardcoded In-Memory Set`):** Danh sách `KNOWN_ADMINISTRATIVE_REGIONS` trong `QueryUnderstandingServiceImpl` chỉ có khoảng 70 chuỗi văn bản tĩnh. Không thể mở rộng cho hơn 3.300 xã/phường/đặc khu và hàng nghìn tên gọi lịch sử.
3. **Không phân biệt Cấp bậc Hành chính:** Hệ thống không phân biệt được đâu là Tỉnh, Thành phố trực thuộc Trung ương, Xã, Phường hay Điểm mốc (Landmark).
4. **Không có Bounding Box Nội bộ:** Không lưu trữ BBox và Centroid cục bộ dẫn đến việc không thể thực hiện truy vấn không gian cục bộ (Spatial Query) đối với danh mục `Place` trong cơ sở dữ liệu.

---

## 5. Bảng So sánh Hiện trạng và Yêu cầu Mục tiêu Phase 3

| Tiêu chí Kiến trúc | Trạng thái Hiện tại (Phase 2.1.1) | Yêu cầu Mục tiêu (Phase 3) |
|:---|:---|:---|
| **Cấu trúc Địa giới Place** | Chuỗi `address` tự do, phi cấu trúc. Không có liên kết hành chính. | Có cột `administrative_area_id` nullable trỏ tới đơn vị hành chính cấp cơ sở (Xã/Phường/Đặc khu). |
| **Phân cấp Hành chính** | Không có. | Mô hình chính quyền địa phương 2 cấp của Việt Nam (Tỉnh/TP TW $\rightarrow$ Xã/Phường/Đặc khu). |
| **Xử lý Địa danh Lịch sử** | Không hỗ trợ, dễ phân tích sai hoặc gửi nguyên chuỗi cũ sang provider. | Bảng `administrative_area_aliases` hỗ trợ tên cũ, quận/huyện cũ, viết tắt, không dấu. |
| **Phân giải Địa danh Tìm kiếm** | Gọi HTTP geocoding online tới LocationIQ/HERE để lấy BBox. | Phân giải tức thì (0ms network) qua cơ sở dữ liệu `administrative_areas` & `aliases` cục bộ. |
| **Lưu trữ Ranh giới/Không gian** | Không có ranh giới, chỉ có tọa độ điểm `(lat, lon)`. | Lưu Bounding Box chuẩn (`min_lat`, `max_lat`, `min_lon`, `max_lon`) và Polygon/MultiPolygon GeoJSON. |
| **Tính Độc lập Snapshot** | Đã độc lập giữa Activity và Place. | **Bảo toàn tuyệt đối**: Mọi thay đổi ở Administrative Area và Place không ảnh hưởng đến Activity Snapshot. |

---

## 6. Rủi ro Kỹ thuật và Giới hạn Cần Lưu ý
1. **Rủi ro sáp nhập phức tạp:** Một số quận/huyện cũ trước 01/07/2025 không sáp nhập nguyên trạng thành 1 đơn vị mới mà bị chia tách vào nhiều xã/phường mới. Bảng Alias phải hỗ trợ quan hệ 1-N (một tên cũ trỏ về nhiều đơn vị mới có độ tương đồng/bán kính bao trùm).
2. **Dữ liệu tọa độ biên:** Place nằm sát ranh giới giữa 2 xã/phường có thể bị gán nhầm nếu chỉ dựa vào khoảng cách Haversine tới tâm. Cần ưu tiên kết hợp Bounding Box và Point-in-Polygon.
3. **Hiệu năng tìm kiếm không gian trên MySQL 8:** Cần tận dụng Spatial Index (`SPATIAL KEY`) và kiểu dữ liệu `GEOMETRY` của MySQL 8 cho các phép toán `ST_Contains`, tránh quét toàn bảng (`full table scan`).

---

## 7. Kết luận Audit
Kiến trúc hiện tại của Travel Planner đã xây dựng được một nền tảng rất tốt về tính độc lập của Activity Location Snapshot và luồng phân tích truy vấn 2 tầng (Two-Stage Search). Tuy nhiên, **sự thiếu vắng một catalog dữ liệu hành chính chuẩn hóa nội bộ** là rào cản lớn nhất khiến hệ thống phải phụ thuộc vào các cuộc gọi API ngoại bộ tốn kém, thiếu ổn định và không thể hỗ trợ các đặc thù địa giới hành chính của Việt Nam sau ngày 01/07/2025. 

Việc triển khai Phase 3 là hoàn toàn cấp thiết và khả thi về mặt kỹ thuật mà không làm phá vỡ bất kỳ thành quả kiến trúc nào đã đạt được ở các Phase trước.

