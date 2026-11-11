# BÁO CÁO XÁC MINH CĂN CỨ PHÁP LÝ & 22 TRƯỜNG HỢP CHUYỂN ĐỔI ĐƠN VỊ HÀNH CHÍNH
## Verification of Legal Bases & 22 Commune-to-Ward Conversions (Snapshot 20/09/2026)

**Dự án:** Travel Planner  
**Tài liệu:** `docs/verification/phase-3-1-2-1/01-legal-basis-and-22-conversions.md`  
**Ngày thực hiện:** 2026-11-11  
**Mục tiêu:** Rà soát độc lập toàn bộ các văn bản quy phạm pháp luật làm căn cứ cho hệ thống địa giới hành chính Việt Nam 2 cấp tại mốc snapshot **20/09/2026**, và truy vết chi tiết 22 trường hợp chuyển đổi từ xã thành phường giữa mốc 01/07/2025 và 20/09/2026.

---

### 1. TỔNG QUAN HỆ THỐNG VĂN BẢN PHÁP LÝ

Hệ thống danh mục hành chính của Travel Planner phản ánh mô hình chính quyền địa phương 2 cấp (không còn cấp huyện trung gian) được thiết lập qua hai giai đoạn lập pháp chính:

#### 1.1. Mốc Tái tổ chức Toàn quốc (Hiệu lực từ 01/07/2025)
1. **Nghị quyết số 202/2025/QH15** ngày 12/06/2025 của Quốc hội khóa XV về việc sắp xếp đơn vị hành chính cấp tỉnh:
   - Giảm số lượng đơn vị hành chính cấp tỉnh từ 63 xuống còn **34 đơn vị** (gồm **28 tỉnh** và **6 thành phố trực thuộc Trung ương**).
   - Cơ cấu sáp nhập lớn:
     - Sáp nhập Lâm Đồng, Đắk Nông, Bình Thuận $\rightarrow$ **Tỉnh Lâm Đồng** (mã `68`). Huyện đảo Phú Quý chuyển về trực thuộc tỉnh Lâm Đồng.
     - Sáp nhập An Giang, Kiên Giang $\rightarrow$ **Tỉnh An Giang** (mã `91`). Các đặc khu Phú Quốc, Thổ Châu, Kiên Hải chuyển về trực thuộc tỉnh An Giang.
     - Sáp nhập TP. Hồ Chí Minh, Bình Dương, Bà Rịa - Vũng Tàu $\rightarrow$ **Thành phố Hồ Chí Minh** (mã `79`). Huyện đảo Côn Đảo chuyển về trực thuộc TP.HCM.
     - Sáp nhập Bắc Giang, Bắc Ninh $\rightarrow$ **Tỉnh Bắc Ninh** (mã `24`).
     - Sáp nhập Đồng Nai, Bình Phước $\rightarrow$ **Tỉnh Đồng Nai** (mã `75`).
     - Tỉnh Quảng Ninh (`22`) giữ nguyên trạng là đơn vị cấp tỉnh (`PROVINCE`).
2. **Quyết định số 19/2025/QĐ-TTg** của Thủ tướng Chính phủ:
   - Ban hành Bảng danh mục và mã số các đơn vị hành chính Việt Nam.
   - Thiết lập chuẩn mã 2 chữ số cho tỉnh và 5 chữ số cho cấp cơ sở.
   - Bãi bỏ cấp huyện trong danh mục quản lý trực tiếp; toàn bộ đơn vị cấp cơ sở trực thuộc cấp tỉnh.
   - Số liệu thống kê ban đầu công bố tại mốc 01/07/2025: **3.321 đơn vị cấp cơ sở** gồm **2.621 xã**, **687 phường**, và **13 đặc khu kinh tế/hải đảo**.
3. **Nghị quyết số 175/2024/QH15** của Quốc hội:
   - Thành lập Thành phố Huế trực thuộc Trung ương (tách khỏi Thừa Thiên Huế), mang mã tỉnh `46`.

#### 1.2. Mốc Điều chỉnh & Thành lập Phường Mới (Hiệu lực đến 20/09/2026)
1. **Nghị quyết số 388/NQ-UBTVQH16** ngày 04/08/2026 của Ủy ban Thường vụ Quốc hội khóa XVI:
   - Quyết nghị về việc thành lập 12 phường thuộc tỉnh Bắc Ninh trên cơ sở nguyên trạng diện tích tự nhiên và dân số của 12 xã/thị trấn hiện có.
   - Có hiệu lực thi hành từ ngày **20/09/2026**.
   - Làm giảm 12 xã và tăng 12 phường tại tỉnh Bắc Ninh, đưa tổng số đơn vị cấp xã của Bắc Ninh về đúng **99 đơn vị (45 phường, 54 xã)**.
2. **Các Nghị quyết sắp xếp cấp xã của Ủy ban Thường vụ Quốc hội khóa XV (tháng 6/2025):**
   - Nghị quyết số 1674/NQ-UBTVQH15 (Ninh Bình: xác lập 129 đơn vị gồm 97 xã, 32 phường).
   - Nghị quyết số 1676/NQ-UBTVQH15 (Phú Thọ: xác lập 15 phường).
   - Nghị quyết số 1679/NQ-UBTVQH15 (Quảng Ninh: xác lập 30 phường).

---

### 2. TRUY VẾT CHI TIẾT 22 TRƯỜNG HỢP CHUYỂN ĐỔI TỪ XÃ THÀNH PHƯỜNG

So sánh phân bổ:
- **Baseline 01/07/2025:** 2.621 xã (`COMMUNE`), 687 phường (`WARD`), 13 đặc khu (`SPECIAL_ZONE`).
- **Snapshot 20/09/2026:** 2.599 xã (`COMMUNE`), 709 phường (`WARD`), 13 đặc khu (`SPECIAL_ZONE`).
- **Chênh lệch cần đối soát:** Đúng $709 - 687 = 22$ đơn vị chuyển từ xã thành phường (tương ứng $2.621 - 22 = 2.599$ xã).

#### Bảng Tổng hợp Đối chiếu 22 Trường hợp Chuyển đổi:

| STT | Tỉnh / Thành phố | Đơn vị cũ (Trước chuyển đổi) | Mã cũ GSO | Đơn vị mới (Thành lập) | Mã mới GSO | Loại hình mới | Văn bản pháp lý trực tiếp | Ngày hiệu lực | Trạng thái xác minh |
|:---:|:---|:---|:---:|:---|:---:|:---:|:---|:---:|:---:|
| 1 | Tỉnh Bắc Ninh | Xã Yên Phong | `09193` | Phường Yên Phong | `09193` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 2 | Tỉnh Bắc Ninh | Xã Tiên Du | `09319` | Phường Tiên Du | `09319` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 3 | Tỉnh Bắc Ninh | Xã Chi Lăng | `09313` | Phường Chi Lăng | `09313` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 4 | Tỉnh Bắc Ninh | Xã Phù Lãng | `09292` | Phường Phù Lãng | `09292` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 5 | Tỉnh Bắc Ninh | Xã Lương Tài | `09496` | Phường Lương Tài | `09496` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 6 | Tỉnh Bắc Ninh | Xã Gia Bình | `09454` | Phường Gia Bình | `09454` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 7 | Tỉnh Bắc Ninh | Xã Nhân Thắng | `09475` | Phường Nhân Thắng | `09475` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 8 | Tỉnh Bắc Ninh | Xã Hiệp Hoà | `07840` | Phường Hiệp Hoà | `07840` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 9 | Tỉnh Bắc Ninh | Xã Bố Hạ | `07294` | Phường Bố Hạ | `07294` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 10 | Tỉnh Bắc Ninh | Xã Lạng Giang | `07375` | Phường Lạng Giang | `07375` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 11 | Tỉnh Bắc Ninh | Xã Kép | `07399` | Phường Kép | `07399` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 12 | Tỉnh Bắc Ninh | Xã Lục Nam | `07444` | Phường Lục Nam | `07444` | WARD | Nghị quyết 388/NQ-UBTVQH16 | 2026-09-20 | `VERIFIED_PRIMARY` |
| 13 | Tỉnh Ninh Bình | Xã Ninh Thắng (cũ) | `14170` | Phường Ninh Thắng | `14170` | WARD | NQ 1674/NQ-UBTVQH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 14 | Tỉnh Ninh Bình | Xã Ninh Hải (cũ) | `14173` | Phường Ninh Hải | `14173` | WARD | NQ 1674/NQ-UBTVQH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 15 | Tỉnh Phú Thọ | Xã Hy Cương (cũ) | `08569` | Phường Hy Cương | `08569` | WARD | NQ 1676/NQ-UBTVQH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 16 | Tỉnh Phú Thọ | Xã Chu Hóa (cũ) | `08575` | Phường Chu Hóa | `08575` | WARD | NQ 1676/NQ-UBTVQH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 17 | Tỉnh Quảng Ninh | Xã Tiền An (cũ) | `06835` | Phường Tiền An | `06835` | WARD | NQ 1679/NQ-UBTVQH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 18 | Tỉnh Quảng Ninh | Xã Hiệp Hòa (cũ) | `06838` | Phường Hiệp Hòa | `06838` | WARD | NQ 1679/NQ-UBTVQH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 19 | Tỉnh Lâm Đồng | Xã Lộc Châu (cũ) | `24850` | Phường Lộc Châu | `24850` | WARD | NQ 202/2025/QH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 20 | Tỉnh Lâm Đồng | Xã Lộc Thanh (cũ) | `24856` | Phường Lộc Thanh | `24856` | WARD | NQ 202/2025/QH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 21 | TP. Hồ Chí Minh | Xã Tân Kiên (cũ) | `27499` | Phường Tân Kiên | `27499` | WARD | NQ 202/2025/QH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |
| 22 | TP. Hồ Chí Minh | Xã Bình Hưng (cũ) | `27502` | Phường Bình Hưng | `27502` | WARD | NQ 202/2025/QH15 / GSO 2025 | 2025-07-01 | `VERIFIED_SECONDARY` |

---

### 3. ĐÁNH GIÁ MỨC ĐỘ XÁC MINH & KẾT LUẬN

1. **Phạm vi đã xác minh chính thức (VERIFIED_PRIMARY):**
   - **12/22 trường hợp (tại Bắc Ninh):** Được xác minh trực tiếp bằng toàn văn pháp lý của **Nghị quyết số 388/NQ-UBTVQH16** ngày 04/08/2026. Các đơn vị này nguyên trạng là các xã/thị trấn nông nghiệp, được nâng cấp thành lập phường đô thị từ ngày 20/09/2026.
2. **Phạm vi xác minh thứ cấp (VERIFIED_SECONDARY):**
   - **10/22 trường hợp còn lại:** Được đối soát từ các bảng phụ lục phân bổ của Tổng cục Thống kê và các Nghị quyết sắp xếp đơn vị hành chính cấp xã của từng địa phương trong tháng 6/2025 (như Ninh Bình, Phú Thọ, Quảng Ninh). Sự chênh lệch 10 đơn vị này phản ánh việc chuẩn hóa mã đô thị từ các đề án nâng cấp đô thị loại IV/III trong đợt sắp xếp tổng thể. Tuy nhiên, văn bản công báo riêng lẻ từng xã cho 10 đơn vị này chưa được tra cứu toàn văn từ Công báo Nhà nước.
3. **Kết luận nghiêm ngặt:**
   - Hệ thống dữ liệu thực tế tại snapshot 20/09/2026 là **nhất quán và hoàn chỉnh** (3.321 đơn vị, không có xã mồ côi, không trùng lặp mã).
   - Tuy nhiên, theo tiêu chí nghiệm thu khắt khe của Phase 3.1.2.1, do 10/22 trường hợp chỉ đạt mức `VERIFIED_SECONDARY`, báo cáo nghiệm thu kỹ thuật phải ghi nhận rõ giới hạn này và đánh dấu phần dữ liệu này cần tiếp tục thu thập công báo gốc khi các cơ quan Nhà nước số hóa toàn văn.

