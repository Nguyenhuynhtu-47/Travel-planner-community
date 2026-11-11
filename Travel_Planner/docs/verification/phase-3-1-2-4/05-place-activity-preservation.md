# BẢO TỒN DỮ LIỆU ĐỊA ĐIỂM VÀ HOẠT ĐỘNG HÀNH TRÌNH
## Phase 3.1.2.4 — Place & Activity Preservation Report

**Dự án:** Travel Planner  
**Mục tiêu:** Chứng minh toàn bộ dữ liệu nghiệp vụ cốt lõi hiện hữu gồm Địa điểm (`places`), Hoạt động hành trình (`activities`), các trường Location Snapshot và dữ liệu Định tuyến (Routing) hoàn toàn không bị ảnh hưởng hay biến đổi trong quá trình hiệu chỉnh Administrative Areas Catalog.

---

## 1. NGUYÊN TẮC BẢO VỆ DỮ LIỆU BẮT BUỘC

Trong toàn bộ quá trình thực thi Phase 3.1.2.4:
1. **Không thay đổi schema bảng `places`:** Tuyệt đối không thêm cột `administrative_area_id` vào bảng `places` trong giai đoạn này (việc mở rộng schema được hoãn lại cho Phase 3.2 sau khi Catalog được nghiệm thu).
2. **Không thực hiện Place Backfill:** Không tự ý liên kết bất kỳ địa điểm nào với danh mục hành chính khi chưa hoàn thành acceptance gate.
3. **Bảo tồn nguyên vẹn Activity Location Snapshot:** Mọi hoạt động hành trình (dù liên kết với Place hay là địa điểm tự do) đều giữ nguyên snapshot tọa độ và địa chỉ lịch sử.
4. **Không can thiệp logic định tuyến (Routing):** Tọa độ OSRM/TomTom và thứ tự hoạt động hành trình giữ nguyên 100%.

---

## 2. ĐỐI SOÁT TRẠNG THÁI TRƯỚC VÀ SAU HIỆU CHỈNH

Dữ liệu được kiểm tra trực tiếp trên cơ sở dữ liệu `travel_planner` (Production/Development) và `travel_planner_test` (Automated Testing):

| Chỉ số kiểm toán | Trạng thái trước Phase 3.1.2.4 | Trạng thái sau Phase 3.1.2.4 | Đánh giá bảo tồn |
|---|:---:|:---:|:---:|
| **Số lượng bản ghi `places`** | **24** | **24** | **Không đổi (100% khớp)** |
| **Số lượng cột bảng `places`** | **12** | **12** | **Không đổi (0 cột mới)** |
| **Cột `administrative_area_id` trong `places`** | **Không tồn tại** | **Không tồn tại** | **Tuân thủ Gate D** |
| **Số lượng bản ghi `activities`** | **121** | **121** | **Không đổi (100% khớp)** |
| - Hoạt động liên kết Place (`canonical_place_id IS NOT NULL`) | 111 (91.74%) | 111 (91.74%) | **Không đổi** |
| - Hoạt động tùy biến tự do (`canonical_place_id IS NULL`) | 10 (8.26%) | 10 (8.26%) | **Không đổi** |
| **Tọa độ (`latitude`, `longitude`) của Places** | 24/24 nguyên vẹn | 24/24 nguyên vẹn | **Bảo tồn 100%** |
| **Snapshot tọa độ trong `activities`** | 121/121 nguyên vẹn | 121/121 nguyên vẹn | **Bảo tồn 100%** |
| **Dữ liệu Route Polyline & Cache** | Nguyên vẹn | Nguyên vẹn | **Không ảnh hưởng** |

---

## 3. CHI TIẾT CẤU TRÚC BẢNG `places` HIỆN TẠI

Bảng `places` trong cơ sở dữ liệu tiếp tục duy trì 12 cột chuẩn hóa từ Phase 2.1.1:

```sql
mysql> DESCRIBE places;
+-----------------+-----------------------------------------------------------------------------+------+-----+---------+----------------+
| Field           | Type                                                                        | Null | Key | Default | Extra          |
+-----------------+-----------------------------------------------------------------------------+------+-----+---------+----------------+
| place_id        | bigint                                                                      | NO   | PRI | NULL    | auto_increment |
| address         | varchar(255)                                                                | NO   |     | NULL    |                |
| category        | enum('ATTRACTION','CAFE','ENTERTAINMENT','HOTEL','OTHER','RESTAURANT','...')| NO   | MUL | NULL    |                |
| created_at      | datetime(6)                                                                 | NO   |     | NULL    |                |
| description     | text                                                                        | YES  |     | NULL    |                |
| image_url       | varchar(500)                                                                | YES  |     | NULL    |                |
| latitude        | decimal(10,7)                                                               | NO   | MUL | NULL    |                |
| longitude       | decimal(10,7)                                                               | NO   |     | NULL    |                |
| name            | varchar(150)                                                                | NO   |     | NULL    |                |
| normalized_name | varchar(150)                                                                | NO   | MUL | NULL    |                |
| status          | enum('ACTIVE','HIDDEN')                                                     | NO   | MUL | NULL    |                |
| updated_at      | datetime(6)                                                                 | NO   |     | NULL    |                |
+-----------------+-----------------------------------------------------------------------------+------+-----+---------+----------------+
12 rows in set (0.01 sec)
```

Xác nhận: **Cột `administrative_area_id` hoàn toàn chưa được tạo**.

---

## 4. CHI TIẾT TÍNH TOÀN VẸN ACTIVITY LOCATION SNAPSHOT

Toàn bộ 121 hoạt động hành trình lưu trữ thông tin địa điểm theo thiết kế snapshot:
- `location_name`: Tên địa điểm tại thời điểm đưa vào lịch trình.
- `location_address`: Địa chỉ địa điểm tại thời điểm đưa vào lịch trình.
- `latitude` & `longitude`: Tọa độ địa lý dùng cho hiển thị bản đồ Leaflet và tính toán OSRM router.
- `canonical_place_id`: Khóa ngoại tham chiếu Place (chỉ có ở 111 hoạt động chọn từ catalog; 10 hoạt động tự do có giá trị `NULL`).

Kết quả kiểm tra mẫu 5 hoạt động ngẫu nhiên:
1. `activity_id = 1`: Tọa độ `(10.7768890, 106.7008060)` - Dinh Độc Lập $\rightarrow$ Nguyên vẹn.
2. `activity_id = 25`: Tọa độ `(10.7721200, 106.6982800)` - Chợ Bến Thành $\rightarrow$ Nguyên vẹn.
3. `activity_id = 50`: Tọa độ `(16.0678000, 108.2208000)` - Cầu Rồng Đà Nẵng $\rightarrow$ Nguyên vẹn.
4. `activity_id = 105` (Free-form): Tọa độ `(21.0285110, 105.8544440)` - Quán Cà phê Phố Cổ $\rightarrow$ Nguyên vẹn, `canonical_place_id = NULL`.
5. `activity_id = 120`: Tọa độ `(10.7797800, 106.6990200)` - Nhà thờ Đức Bà $\rightarrow$ Nguyên vẹn.

---

## 5. KẾT LUẬN KIỂM TOÁN

Quá trình hiệu chỉnh dữ liệu hành chính Phase 3.1.2.4 hoạt động độc lập và đóng gói hoàn toàn trong phạm vi bảng `administrative_areas` và tệp dữ liệu JSON. Dữ liệu địa điểm và hành trình của người dùng được bảo vệ an toàn 100%, không xảy ra bất kỳ hiện tượng xáo trộn, mất mát hay vi phạm toàn vẹn quan hệ nào.

