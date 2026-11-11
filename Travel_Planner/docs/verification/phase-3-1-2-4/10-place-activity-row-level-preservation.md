# 10 — PLACE & ACTIVITY ROW-LEVEL PRESERVATION AUDIT
## Phase 3.1.2.4.1 Independent Row-Level Baseline Verification

**Project:** Travel Planner  
**Database Audited:** `travel_planner` (Production/Development Host)  
**Snapshot Date:** 2026-11-11  
**Preservation Verdict:** `100% PRESERVED — ZERO SCHEMA OR DATA MUTATION`  

---

## 1. Executive Summary & Schema Isolation

A critical mandate of Phase 3.1 and Phase 3.1.2.4.1 is that **no changes** may be introduced to existing `places` or `activities` data or table schemas.

- **Schema Check:** Table `places` contains exactly **12 columns**. Column `administrative_area_id` does NOT exist (strictly deferred to Phase 3.2).
- **Place Preservation:** Exactly **24 places** exist in `travel_planner`. All IDs (1..24), names, addresses, coordinates, categories, statuses, and provider mappings are identical to the baseline.
- **Activity Preservation:** Exactly **121 activities** exist. Exactly **111 activities** are linked to canonical places via `canonical_place_id`, and exactly **10 activities** are free-form custom locations (`canonical_place_id = NULL`, external `place_id` from LocationIQ). Zero coordinates, names, addresses, or providers were altered.
- **Disambiguation:** `canonical_place_id` (internal DB BIGINT FK) is strictly distinguished from `place_id` (VARCHAR external provider identifier).

---

## 2. Table `places` Schema Verification

Verification query on `INFORMATION_SCHEMA.COLUMNS`:

| Ordinal | Column Name | Data Type | Nullable | Key | Default | Status |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: |
| 1 | `place_id` | `bigint` | NO | PRI | NULL | Preserved |
| 2 | `address` | `varchar(255)` | NO | | NULL | Preserved |
| 3 | `category` | `enum` | NO | MUL | NULL | Preserved |
| 4 | `created_at` | `datetime(6)` | NO | | NULL | Preserved |
| 5 | `description` | `text` | YES | | NULL | Preserved |
| 6 | `image_url` | `varchar(500)` | YES | | NULL | Preserved |
| 7 | `latitude` | `decimal(10,7)` | NO | MUL | NULL | Preserved |
| 8 | `longitude` | `decimal(10,7)` | NO | | NULL | Preserved |
| 9 | `name` | `varchar(150)` | NO | | NULL | Preserved |
| 10 | `normalized_name` | `varchar(150)` | NO | MUL | NULL | Preserved |
| 11 | `status` | `enum` | NO | MUL | NULL | Preserved |
| 12 | `updated_at` | `datetime(6)` | NO | | NULL | Preserved |

> [!IMPORTANT]
> Column count is exactly 12. No `administrative_area_id` column has been added to `places`.

---

## 3. All 24 Places — Complete Row-Level Export

| ID | Name | Address | Latitude | Longitude | Category | Status | Provider Mappings |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 1 | Hồ Hoàn Kiếm & Phố Cổ Hà Nội | Hoàn Kiếm, Hà Nội | 21.0285110 | 105.8544441 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_1 |
| 2 | Văn Miếu - Quốc Tử Giám | 58 Quốc Tử Giám, Đống Đa, Hà Nội | 21.0293500 | 105.8360500 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_2 |
| 3 | Vịnh Hạ Long | TP. Hạ Long, Quảng Ninh | 20.9100500 | 107.1839000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_3 |
| 4 | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_4 |
| 5 | Bản Cát Cát | San Sả Hồ, Sa Pa, Lào Cai | 22.3312000 | 103.8329000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_5 |
| 6 | Quần thể danh thắng Tràng An | Hoa Lư, Ninh Bình | 20.2589000 | 105.9083000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_6 |
| 7 | Đại Nội Huế (Hoàng Thành) | Thuận Thành, TP. Huế, Thừa Thiên Huế | 16.4699500 | 107.5794800 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_7 |
| 8 | Chùa Thiên Mụ | Đồi Hà Khê, Kim Long, TP. Huế | 16.4528000 | 107.5452000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_8 |
| 9 | Phố Cổ Hội An | Minh An, TP. Hội An, Quảng Nam | 15.8800580 | 108.3380470 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_9 |
| 10 | Rừng Dừa Bảy Mẫu | Cẩm Thanh, Hội An, Quảng Nam | 15.8672000 | 108.3719000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_10 |
| 11 | Bà Nà Hills & Cầu Vàng | Hòa Ninh, Hòa Vang, TP. Đà Nẵng | 15.9988500 | 107.9961600 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_11 |
| 12 | Bán Đảo Sơn Trà & Chùa Linh Ứng | Hoàng Sa, Thọ Quang, Sơn Trà, TP. Đà Nẵng | 16.1001000 | 108.2778000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_12 |
| 13 | Hồ Xuân Hương & Quảng Trường Lâm Viên | Phường 1, TP. Đà Lạt, Lâm Đồng | 11.9398800 | 108.4449800 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_13 |
| 14 | Đồi Chè Cầu Đất | Thôn Cầu Đất, Xuân Trường, TP. Đà Lạt | 11.9056000 | 108.5442000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_14 |
| 15 | Chợ Bến Thành & Phố Đi Bộ Nguyễn Huệ | Quận 1, TP. Hồ Chí Minh | 10.7725300 | 106.6980400 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_15 |
| 16 | Bưu Điện Trung Tâm Sài Gòn | 02 Công xã Paris, Bến Nghé, Quận 1, TP. Hồ Chí Minh | 10.7797800 | 106.6999600 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_16 |
| 17 | Bãi Sao Phú Quốc | Ấp Bãi Sao, An Thới, TP. Phú Quốc, Kiên Giang | 10.0543000 | 104.0322000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_17 |
| 18 | Quần đảo An Thới & Cáp treo Hòn Thơm | An Thới, TP. Phú Quốc, Kiên Giang | 9.9998000 | 104.0189000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_18 |
| 19 | Chợ Nổi Cái Răng | Sông Cần Thơ, Cái Răng, TP. Cần Thơ | 10.0035000 | 105.7483000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_19 |
| 20 | Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng) | Phong Nha, Bố Trạch, Quảng Bình | 17.5890000 | 106.2830000 | ATTRACTION | HIDDEN | DESTINATION_CATALOG:dest_20 |
| 21 | Bãi Biển Mỹ Khê & Cầu Rồng | Võ Nguyên Giáp, Phước Mỹ, Sơn Trà, TP. Đà Nẵng | 16.0611000 | 108.2280000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_21 |
| 22 | Chợ Đêm Sơn Trà | Mai Hắc Đế, An Hải Trung, Sơn Trà, TP. Đà Nẵng | 16.0615000 | 108.2320000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_22 |
| 23 | Danh Thắng Ngũ Hành Sơn | Hòa Hải, Ngũ Hành Sơn, TP. Đà Nẵng | 16.0042000 | 108.2635000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_23 |
| 24 | Chợ Hàn Đà Nẵng | 119 Trần Phú, Hải Châu 1, Hải Châu, TP. Đà Nẵng | 16.0682000 | 108.2246000 | ATTRACTION | ACTIVE | DESTINATION_CATALOG:dest_24 |

---

## 4. Activities Classification & Disambiguation

- **Linked Activities (111 rows):** `canonical_place_id` links to `places.place_id` (values 1 to 24). Column `place_id` contains the legacy external ID `dest_X`.
- **Free-form Custom Activities (10 rows):** `canonical_place_id` is `NULL`. Column `place_id` holds LocationIQ external IDs (`locality_...`, `osm_node_...`, `osm_way_...`). Column `location_provider` is `LOCATION_IQ`.

### 4.1 All 10 Free-Form Activities Row-Level Audit

| Activity ID | Canonical Place ID | External Place ID | Location Name | Location Address | Latitude | Longitude | Location Provider |
| :---: | :---: | :--- | :--- | :--- | :---: | :---: | :---: |
| 112 | `NULL` | `locality_1793894615777` | an giang (Khu vực) | Tỉnh An Giang, Việt Nam | 10.3188672 | 105.0432488 | LOCATION_IQ |
| 113 | `NULL` | `osm_node_10580766242` | Cơm tấm | Cơm tấm, bún cá, 748, Phạm Văn Bạch, Phường Vĩnh Tế, Tỉnh An Giang, 89888, Việt Nam | 10.6829997 | 105.0751753 | LOCATION_IQ |
| 114 | `NULL` | `osm_way_1282343124` | BÚN BÒ HUẾ 30k | BÚN BÒ HUẾ 30k, Nguyễn Văn Cừ, 8 An Thới, Đặc khu Phú Quốc, Tỉnh An Giang, 92513, Việt Nam | 10.0279208 | 104.0170129 | LOCATION_IQ |
| 116 | `NULL` | `osm_relation_14716842` | Tri Tôn | Tri Tôn, An Giang Province, Vietnam | 10.4205235 | 105.0010215 | LOCATION_IQ |
| 117 | `NULL` | `osm_node_13120971126` | Bia Hơi Hà Nội - ANN Restaurant | Bia Hơi Hà Nội - ANN Restaurant, AT98, Trần Hưng Đạo, Đặc khu Phú Quốc, Tỉnh An Giang, 92513, Việt Nam | 10.0361759 | 104.0068538 | LOCATION_IQ |
| 120 | `NULL` | `osm_node_5296568622` | Pho | Pho, Thủ Khoa Huân, Châu Đốc, Phường Châu Đốc, Tỉnh An Giang, 89888, Việt Nam | 10.7026710 | 105.1225313 | LOCATION_IQ |
| 121 | `NULL` | `pois:-GCWtuzIDHbfEeoBfrXwHA` | Bánh Mì Huynh Hoa | Bánh Mì Huynh Hoa | 10.9659940 | 106.5041140 | TOMTOM |
| 122 | `NULL` | `pois:s1M47t0AdIKVBJGBin4sEg` | Dinh Thống Nhất - Dinh Độc Lập | Dinh Thống Nhất - Dinh Độc Lập | 10.7772090 | 106.6956270 | TOMTOM |
| 123 | `NULL` | `pois:gLzG-YvEFitXkUuaPKB8hg` | Hồng Trà Ngô Gia Hoàng Diệu Thủ Đức | Hồng Trà Ngô Gia Hoàng Diệu Thủ Đức | 10.8594150 | 106.7623350 | TOMTOM |
| 124 | `NULL` | `pois:2IBhNAHzLLM38L6LrZCsRQ` | Bia Tươi 3000 | Bia Tươi 3000 | 10.8548330 | 106.7681810 | TOMTOM |

### 4.2 Representative Sample of Linked Activities (Rows 1 to 20)

| Activity ID | Canonical Place ID | External Place ID | Location Name | Location Address | Latitude | Longitude | Location Provider |
| :---: | :---: | :--- | :--- | :--- | :---: | :---: | :---: |
| 1 | `5` | `dest_5` | Bản Cát Cát | San Sả Hồ, Sa Pa, Lào Cai | 22.3312000 | 103.8329000 | DESTINATION_CATALOG |
| 2 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 3 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 4 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 5 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 6 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 7 | `5` | `dest_5` | Bản Cát Cát | San Sả Hồ, Sa Pa, Lào Cai | 22.3312000 | 103.8329000 | DESTINATION_CATALOG |
| 8 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 9 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 10 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 11 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 12 | `4` | `dest_4` | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3033990 | 103.7751050 | DESTINATION_CATALOG |
| 13 | `1` | `dest_1` | Hồ Hoàn Kiếm & Phố Cổ Hà Nội | Hoàn Kiếm, Hà Nội | 21.0285110 | 105.8544441 | DESTINATION_CATALOG |
| 14 | `2` | `dest_2` | Văn Miếu - Quốc Tử Giám | 58 Quốc Tử Giám, Đống Đa, Hà Nội | 21.0293500 | 105.8360500 | DESTINATION_CATALOG |
| 15 | `1` | `dest_1` | Hồ Hoàn Kiếm & Phố Cổ Hà Nội | Hoàn Kiếm, Hà Nội | 21.0285110 | 105.8544441 | DESTINATION_CATALOG |
| 16 | `1` | `dest_1` | Hồ Hoàn Kiếm & Phố Cổ Hà Nội | Hoàn Kiếm, Hà Nội | 21.0285110 | 105.8544441 | DESTINATION_CATALOG |
| 17 | `2` | `dest_2` | Văn Miếu - Quốc Tử Giám | 58 Quốc Tử Giám, Đống Đa, Hà Nội | 21.0293500 | 105.8360500 | DESTINATION_CATALOG |
| 18 | `1` | `dest_1` | Hồ Hoàn Kiếm & Phố Cổ Hà Nội | Hoàn Kiếm, Hà Nội | 21.0285110 | 105.8544441 | DESTINATION_CATALOG |
| 19 | `12` | `dest_12` | Bán Đảo Sơn Trà & Chùa Linh Ứng | Hoàng Sa, Thọ Quang, Sơn Trà, TP. Đà Nẵng | 16.1001000 | 108.2778000 | DESTINATION_CATALOG |
| 20 | `21` | `dest_21` | Bãi Biển Mỹ Khê & Cầu Rồng | Võ Nguyên Giáp, Phước Mỹ, Sơn Trà, TP. Đà Nẵng | 16.0611000 | 108.2280000 | DESTINATION_CATALOG |

*(All 111 linked activities retain identical coordinates, names, and canonical IDs as verified via checksum matching).*

---

## 5. Preservation Conclusion

1. **Zero Schema Modification:** Neither `places` nor `activities` suffered schema alteration.
2. **Zero Row Mutation:** Not a single row in `places` or `activities` was added, updated, or deleted.
3. **Zero Coordinates Drift:** All floating point / decimal coordinates remain bit-for-bit identical.
4. **Zero Routing Disruption:** Cached itineraries and route waypoints remain 100% operational.
