# Phase 3.2 — Destination (Place) Administrative Linking Results
**Target Snapshot:** 2026-09-20  
**Phase:** 3.2 — Place–Administrative Area Linking & Resolution  
**Total Destinations Examined:** 24 Places (IDs 1..24)  
**Execution Mode:** Persisted in `travel_planner` production database  
**Audit Date:** 2026-11-11

---

## 1. Executive Summary

| Total Places | Auto-Linked | Linked to Communes | Linked to Provinces (Fallback) | Ambiguous (Unlinked) | Quarantined Matches |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **24** | **20** (83.3%) | **17** | **3** | **4** (16.7%) | **0** (0.0%) |

All 24 places preserved their original primary keys (IDs 1..24), names, addresses, coordinates, and statuses.

---

## 2. Complete Linking Results Table (Places 1 to 24)

| ID | Place Name | Address | Lat, Lon | Linked Code | Linked Name | Area Type | Parent Code/Name | Confidence | Match Method | Eligible | Status |
| :---: | :--- | :--- | :---: | :---: | :--- | :---: | :--- | :---: | :--- | :---: | :---: |
| **1** | Hồ Hoàn Kiếm & Phố Cổ Hà Nội | Hoàn Kiếm, Hà Nội | 21.0285, 105.8542 | `00070` | Phường Hoàn Kiếm | WARD | `01` TP. Hà Nội | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **2** | Văn Miếu - Quốc Tử Giám | 58 Quốc Tử Giám, Đống Đa, Hà Nội | 21.0276, 105.8355 | `00226` | Phường Văn Miếu - Quốc Tử Giám | WARD | `01` TP. Hà Nội | MEDIUM | SPECIFIC_COMMUNE_MATCH | Yes | Linked |
| **3** | Vịnh Hạ Long | TP. Hạ Long, Quảng Ninh | 20.9101, 107.1839 | `06688` | Phường Hạ Long | WARD | `22` TP. Quảng Ninh | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **4** | Đỉnh Fansipan - Nóc Nhà Đông Dương | Sa Pa, Lào Cai | 22.3034, 103.7751 | `03006` | Phường Sa Pa | WARD | `15` Tỉnh Lào Cai | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **5** | Bản Cát Cát | San Sả Hồ, Sa Pa, Lào Cai | 22.3292, 103.8336 | `03006` | Phường Sa Pa | WARD | `15` Tỉnh Lào Cai | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **6** | Quần thể danh thắng Tràng An | Hoa Lư, Ninh Bình | 20.2536, 105.9048 | `14329` | Phường Hoa Lư | WARD | `37` Tỉnh Ninh Bình | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **7** | Đại Nội Huế (Hoàng Thành) | Thuận Thành, TP. Huế, Thừa Thiên Huế | 16.4698, 107.5796 | `46` | Thành phố Huế | CENTRAL_CITY | *(None - Province level)* | MEDIUM | PROVINCE_LEVEL_FALLBACK | Yes | Linked |
| **8** | Chùa Thiên Mụ | Đồi Hà Khê, Kim Long, TP. Huế | 16.4528, 107.5451 | `19774` | Phường Kim Long | WARD | `46` TP. Huế | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **9** | Phố Cổ Hội An | Minh An, TP. Hội An, Quảng Nam | 15.8777, 108.3262 | `20410` | Phường Hội An | WARD | `48` TP. Đà Nẵng | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **10** | Rừng Dừa Bảy Mẫu | Cẩm Thanh, Hội An, Quảng Nam | 15.8711, 108.3644 | `20410` | Phường Hội An | WARD | `48` TP. Đà Nẵng | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **11** | Bà Nà Hills & Cầu Vàng | Hòa Ninh, Hòa Vang, TP. Đà Nẵng | 15.9989, 107.9962 | *NULL* | *Unlinked* | - | - | AMBIGUOUS | AMBIGUOUS_MULTI_COMMUNES | No | Unlinked |
| **12** | Bán Đảo Sơn Trà & Chùa Linh Ứng | Hoàng Sa, Thọ Quang, Sơn Trà, TP. Đà Nẵng | 16.1002, 108.2768 | *NULL* | *Unlinked* | - | - | AMBIGUOUS | AMBIGUOUS_MULTI_COMMUNES | No | Unlinked |
| **13** | Hồ Xuân Hương & Quảng Trường Lâm Viên | Phường 1, TP. Đà Lạt, Lâm Đồng | 11.9404, 108.4453 | `68` | Tỉnh Lâm Đồng | PROVINCE | *(None - Province level)* | MEDIUM | PROVINCE_LEVEL_FALLBACK | Yes | Linked |
| **14** | Đồi Chè Cầu Đất | Thôn Cầu Đất, Xuân Trường, TP. Đà Lạt | 11.8542, 108.5487 | `68` | Tỉnh Lâm Đồng | PROVINCE | *(None - Province level)* | MEDIUM | PROVINCE_LEVEL_FALLBACK | Yes | Linked |
| **15** | Chợ Bến Thành & Phố Đi Bộ Nguyễn Huệ | Quận 1, TP. Hồ Chí Minh | 10.7725, 106.6980 | `26743` | Phường Bến Thành | WARD | `79` TP. Hồ Chí Minh | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **16** | Bưu Điện Trung Tâm Sài Gòn | 02 Công xã Paris, Bến Nghé, Quận 1, TP. Hồ Chí Minh | 10.7798, 106.6999 | `26740` | Phường Sài Gòn | WARD | `79` TP. Hồ Chí Minh | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **17** | Bãi Sao Phú Quốc | Ấp Bãi Sao, An Thới, TP. Phú Quốc, Kiên Giang | 10.0543, 104.0336 | `31078` | Đặc khu Phú Quốc | SPECIAL_ZONE | `91` Tỉnh An Giang | HIGH | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **18** | Quần đảo An Thới & Cáp treo Hòn Thơm | An Thới, TP. Phú Quốc, Kiên Giang | 10.0274, 104.0135 | `31078` | Đặc khu Phú Quốc | SPECIAL_ZONE | `91` Tỉnh An Giang | HIGH | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **19** | Chợ Nổi Cái Răng | Sông Cần Thơ, Cái Răng, TP. Cần Thơ | 10.0051, 105.7468 | `31186` | Phường Cái Răng | WARD | `92` TP. Cần Thơ | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **20** | Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng) | Phong Nha, Bố Trạch, Quảng Bình | 17.5891, 106.2829 | *NULL* | *Unlinked* | - | - | AMBIGUOUS | AMBIGUOUS_MULTI_COMMUNES | No | Unlinked |
| **21** | Bãi Biển Mỹ Khê & Cầu Rồng | Võ Nguyên Giáp, Phước Mỹ, Sơn Trà, TP. Đà Nẵng | 16.0601, 108.2435 | `20263` | Phường Sơn Trà | WARD | `48` TP. Đà Nẵng | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **22** | Chợ Đêm Sơn Trà | Mai Hắc Đế, An Hải Trung, Sơn Trà, TP. Đà Nẵng | 16.0617, 108.2322 | *NULL* | *Unlinked* | - | - | AMBIGUOUS | AMBIGUOUS_MULTI_COMMUNES | No | Unlinked |
| **23** | Danh Thắng Ngũ Hành Sơn | Hòa Hải, Ngũ Hành Sơn, TP. Đà Nẵng | 16.0041, 108.2632 | `20285` | Phường Ngũ Hành Sơn | WARD | `48` TP. Đà Nẵng | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |
| **24** | Chợ Hàn Đà Nẵng | 119 Trần Phú, Hải Châu 1, Hải Châu, TP. Đà Nẵng | 16.0682, 108.2241 | `20242` | Phường Hải Châu | WARD | `48` TP. Đà Nẵng | MEDIUM | STRUCTURED_COMMUNE_MATCH | Yes | Linked |

---

## 3. Analysis of Unlinked Ambiguous Destinations

The 4 destinations left unlinked were flagged with `confidence = AMBIGUOUS` and `eligibleForAutoLink = false`:
1. **Place 11 (Bà Nà Hills & Cầu Vàng):** Address contains both `Xã Bà Nà` (`20308`) and `Xã Hoà Vang` (`20320`).
2. **Place 12 (Bán Đảo Sơn Trà & Chùa Linh Ứng):** Address contains `Hoàng Sa` (`20333 Đặc khu Hoàng Sa`) and `Sơn Trà` (`20263 Phường Sơn Trà`).
3. **Place 20 (Phong Nha):** Address contains both `Xã Phong Nha` (`19138`) and `Xã Bố Trạch` (`19141`).
4. **Place 22 (Chợ Đêm Sơn Trà):** Address contains `An Hải` (`20275 Phường An Hải`) and `Sơn Trà` (`20263 Phường Sơn Trà`).

These destinations have candidates attached to the response payload and can be linked cleanly via the manual administration endpoint `PUT /api/admin/places/{id}/administrative-area` once operational policies designate preferred commune mappings.

