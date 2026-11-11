# KẾT QUẢ ĐỐI CHIẾU VÀ HIỆU CHỈNH CHUẨN HOÁ DANH MỤC HÀNH CHÍNH
## Phase 3.1.2.4 — Canonical Correction Results

**Dự án:** Travel Planner  
**Tài liệu tham chiếu chuẩn:** `docs/verification/phase-3-1-2-4/00-canonical-correction-reference.md`  
**Mốc thời gian snapshot:** 2026-09-20  
**Tình trạng:** Khắc phục triệt để sai lệch dữ liệu, đối soát từng bản ghi và thiết lập rào cản kiểm soát dữ liệu chưa xác minh.

---

## 1. TỔNG QUAN VÀ MỤC ĐÍCH THỰC HIỆN

Tài liệu này ghi nhận kết quả rà soát, đối chiếu và hiệu chỉnh thực tế của Administrative Areas Catalog theo văn bản chỉ đạo và tài liệu chuẩn `00-canonical-correction-reference.md`.

Đợt hiệu chỉnh Phase 3.1.2.4 tập trung giải quyết dứt điểm các sai lệch cốt lõi đã tồn tại trong báo cáo Phase 3.1.2.3:
1. **Sai lệch danh sách 10 phường tại Đồng Nai:** Báo cáo Phase 3.1.2.3 đã ghi nhận sai danh sách 10 phường chuyển đổi (Long Hưng, Phước Tân, Tam Phước, An Phước, Long Đức, Lộc An, Bình Sơn, Hiệp Phước, Phước Thiền, Phú Hội) với các mã hành chính không có thực trong source package. Danh sách này đã được thay thế hoàn toàn bằng 10 phường chuẩn hóa theo đúng Nghị quyết 237/NQ-UBTVQH16 và Cổng thông tin điện tử tỉnh Đồng Nai.
2. **Xử lý dứt điểm 12 phường tại Bắc Ninh:** Phụ lục văn bản chính thức của Nghị quyết 388/NQ-UBTVQH16 chưa được số hóa đầy đủ trong gói dữ liệu nội bộ của dự án. Thực hiện nghiêm ngặt quy tắc không suy đoán, không dùng danh sách chưa xác minh, toàn bộ 12 bản ghi này được rút lại trạng thái xác minh sơ cấp, đánh dấu rõ ràng là `UNVERIFIED_SOURCE_DOCUMENT_MISSING` và thiết lập blocker ngăn chặn Place backfill tại các đơn vị này.
3. **Hiệu chỉnh quan hệ trực thuộc (parent_code) của 5 đặc khu hành chính:** Bảo đảm Phú Quý thuộc Lâm Đồng (`68`), Côn Đảo thuộc TP.HCM (`79`), Phú Quốc, Thổ Châu, Kiên Hải thuộc An Giang (`91`), loại bỏ hoàn toàn các tên tỉnh cũ đã sáp nhập.
4. **Chuẩn hóa ngày ban hành và ngày có hiệu lực:** Phân định rõ ràng ngày ký ban hành của Quốc hội/UBTVQH và ngày có hiệu lực thi hành của các văn bản.
5. **Đồng bộ hóa 100% giữa tệp nguồn, cơ sở dữ liệu và mã kiểm tra (checksum):** Bảo đảm mọi bản ghi trong MySQL trùng khớp tuyệt đối với `provinces.json` và `communes.json`.

---

## 2. BIÊN NIÊN SỬ PHÁP LÝ VÀ HIỆU CHỈNH NGÀY VĂN BẢN

Toàn bộ các văn bản quy phạm pháp luật cấu thành hệ thống danh mục hành chính tại mốc snapshot 2026-09-20 đã được rà soát và ghi nhận chính xác:

| Ký hiệu văn bản | Loại văn bản | Nội dung trích yếu | Ngày ký ban hành | Ngày có hiệu lực | Ghi chú hiệu chỉnh |
|---|---|---|---|---|---|
| **NQ 202/2025/QH15** | Nghị quyết Quốc hội | Sắp xếp đơn vị hành chính cấp tỉnh năm 2025 | **12/06/2025** | **01/07/2025** | Sáp nhập tỉnh, thiết lập 34 đơn vị cấp tỉnh |
| **QĐ 19/2025/QĐ-TTg** | Quyết định Thủ tướng | Ban hành danh mục mã số đơn vị hành chính Việt Nam | **15/06/2025** | **01/07/2025** | Hệ thống mã số chuẩn GSO |
| **NQ 175/2024/QH15** | Nghị quyết Quốc hội | Thành lập Thành phố Huế trực thuộc TW | **30/11/2024** | **01/01/2025** | Huế trở thành Thành phố trực thuộc TW |
| **NQ 237/NQ-UBTVQH16** | Nghị quyết UBTVQH | Thành lập 10 phường thuộc Thành phố Đồng Nai | **14/04/2026** | **30/04/2026** | Đã sửa sai ngày ký (trước ghi 10/04/2026) |
| **NQ 30/2026/QH16** | Nghị quyết Quốc hội | Thành lập Thành phố Đồng Nai trực thuộc TW | **24/04/2026** | **30/04/2026** | Đã sửa sai ngày ký (trước ghi 25/03/2026) |
| **NQ 36/2026/QH16** | Nghị quyết Quốc hội | Thành lập Thành phố Quảng Ninh trực thuộc TW | **24/08/2026** | **01/09/2026** | Đã sửa sai ngày ký (trước ghi 24/06/2026) |
| **NQ 388/NQ-UBTVQH16** | Nghị quyết UBTVQH | Thành lập 12 phường thuộc Thành phố Bắc Ninh | **04/08/2026** | **20/09/2026** | Phụ lục chưa có trong source bundle |
| **NQ 39/2026/QH16** | Nghị quyết Quốc hội | Thành lập Thành phố Bắc Ninh trực thuộc TW | **24/08/2026** | **20/09/2026** | Đã sửa sai ngày ký (trước ghi 28/06/2026) |

---

## 3. DANH MỤC 34 ĐƠN VỊ CẤP TỈNH (9 CENTRAL_CITY, 25 PROVINCE)

Hệ thống ghi nhận chính xác 34 đơn vị hành chính cấp tỉnh tại snapshot 2026-09-20, phân bổ thành **9 Thành phố trực thuộc Trung ương** và **25 Tỉnh**, tuyệt đối không chứa bất kỳ tên tỉnh lịch sử nào đã bị sáp nhập:

### 3.1. 9 Thành phố trực thuộc Trung ương (`CENTRAL_CITY`)
1. `01`: Thành phố Hà Nội
2. `22`: Thành phố Quảng Ninh *(nâng cấp theo NQ 36/2026/QH16 từ 01/09/2026)*
3. `24`: Thành phố Bắc Ninh *(nâng cấp theo NQ 39/2026/QH16 từ 20/09/2026)*
4. `31`: Thành phố Hải Phòng
5. `46`: Thành phố Huế *(thành lập theo NQ 175/2024/QH15 từ 01/01/2025)*
6. `48`: Thành phố Đà Nẵng
7. `75`: Thành phố Đồng Nai *(nâng cấp theo NQ 30/2026/QH16 từ 30/04/2026)*
8. `79`: Thành phố Hồ Chí Minh
9. `92`: Thành phố Cần Thơ

### 3.2. 25 Tỉnh (`PROVINCE`)
1. `04`: Tỉnh Cao Bằng
2. `08`: Tỉnh Tuyên Quang
3. `11`: Tỉnh Điện Biên
4. `12`: Tỉnh Lai Châu
5. `14`: Tỉnh Sơn La
6. `15`: Tỉnh Lào Cai
7. `19`: Tỉnh Thái Nguyên
8. `20`: Tỉnh Lạng Sơn
9. `25`: Tỉnh Phú Thọ
10. `33`: Tỉnh Hưng Yên
11. `37`: Tỉnh Ninh Bình
12. `38`: Tỉnh Thanh Hoá
13. `40`: Tỉnh Nghệ An
14. `42`: Tỉnh Hà Tĩnh
15. `44`: Tỉnh Quảng Trị
16. `51`: Tỉnh Quảng Ngãi
17. `52`: Tỉnh Gia Lai
18. `56`: Tỉnh Khánh Hoà
19. `66`: Tỉnh Đắk Lắk
20. `68`: Tỉnh Lâm Đồng
21. `80`: Tỉnh Tây Ninh
22. `82`: Tỉnh Đồng Tháp
23. `86`: Tỉnh Vĩnh Long
24. `91`: Tỉnh An Giang
25. `96`: Tỉnh Cà Mau

---

## 4. KẾT QUẢ ĐỐI SOÁT 10 PHƯỜNG ĐỒNG NAI (NGHỊ QUYẾT 237/NQ-UBTVQH16)

Theo Nghị quyết số 237/NQ-UBTVQH16 (ký ngày 14/04/2026, có hiệu lực từ ngày 30/04/2026), 10 xã thuộc Đồng Nai được nâng cấp thành lập phường. Các mã số hành chính được bảo tồn nguyên trạng từ mã đơn vị cấp xã hiện hữu trong danh mục GSO và chuyển đổi loại hình sang `WARD`:

| STT | Mã hành chính | Tên phường chính thức | Loại hình | Đơn vị cha | Căn cứ pháp lý | Trạng thái xác minh |
|:---:|:---:|:---|:---:|:---|:---|:---:|
| 1 | `25270` | Phường Lộc Ninh | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 2 | `25357` | Phường Tân Khai | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 3 | `25363` | Phường Đồng Phú | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 4 | `26116` | Phường Tân Phú | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 5 | `26170` | Phường Trị An | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 6 | `26248` | Phường Trảng Bom | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 7 | `26326` | Phường Dầu Giây | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 8 | `26368` | Phường Long Thành | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 9 | `26425` | Phường Xuân Lộc | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |
| 10 | `26485` | Phường Nhơn Trạch | `WARD` | `75` (Thành phố Đồng Nai) | NQ 237/NQ-UBTVQH16 | **VERIFIED_PRIMARY** |

> [!NOTE]
> Toàn bộ danh sách cũ gồm 10 tên (Long Hưng, Phước Tân, Tam Phước, An Phước, Long Đức, Lộc An, Bình Sơn, Hiệp Phước, Phước Thiền, Phú Hội) và các mã giả định (`26053`, `26056`,...) xuất hiện trong báo cáo Phase 3.1.2.3 đã bị loại bỏ hoàn toàn khỏi các tài liệu xác minh chính thức.

---

## 5. XỬ LÝ 12 PHƯỜNG BẮC NINH — BLOCKER & QUẢN TRỊ RỦI RO

### 5.1. Tình trạng tài liệu pháp lý sơ cấp
- **Văn bản pháp lý:** Nghị quyết số 388/NQ-UBTVQH16 được ban hành ngày 04/08/2026, có hiệu lực từ ngày 20/09/2026 về việc thành lập 12 phường thuộc tỉnh/thành phố Bắc Ninh.
- **Rào cản dữ liệu (Critical Limitation):** Toàn văn phụ lục chi tiết quy định tên gọi và phân định ranh giới của 12 phường này chưa được đính kèm trong gói tài nguyên source package hiện có của kho mã nguồn dự án.
- **Tuân thủ nguyên tắc cẩn trọng:** Dự án **không tự suy đoán mã**, **không dùng tên huyện/thị trấn thay thế**, và **rút lại danh sách dự thảo cũ** (Yên Phong, Tiên Du, Chi Lăng, Phù Lãng, Lương Tài, Gia Bình, Nhân Thắng, Hiệp Hòa, Bố Hạ, Lạng Giang, Kép, Lục Nam).

### 5.2. Danh sách 12 bản ghi bị chặn và gán cờ `UNVERIFIED_SOURCE_DOCUMENT_MISSING`

| Mã hành chính | Tên bản ghi hiện diện | Loại hình | Đơn vị cha | Trạng thái xác minh Phase 3.1.2.4 | Biện pháp kiểm soát |
|:---:|:---|:---:|:---:|:---:|:---|
| `07294` | Phường Bố Hạ | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `07375` | Phường Lạng Giang | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `07399` | Phường Kép | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `07444` | Phường Lục Nam | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `07840` | Phường Hiệp Hoà | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `09193` | Phường Yên Phong | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `09292` | Phường Phù Lãng | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `09313` | Phường Chi Lăng | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `09319` | Phường Tiên Du | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `09454` | Phường Gia Bình | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `09475` | Phường Nhân Thắng | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |
| `09496` | Phường Lương Tài | `WARD` | `24` | **UNVERIFIED_SOURCE_DOCUMENT_MISSING** | **Chặn Place Backfill** |

> [!WARNING]
> **Rào cản bắt buộc (Strict Gate Rule):** Trong Phase 3.2, nếu một địa điểm (Place) thuộc tỉnh Bắc Ninh có địa chỉ khớp với 12 đơn vị nêu trên, dịch vụ gắn kết (resolver) **bắt buộc phải giữ giá trị `administrative_area_id = NULL`** và ghi nhận trạng thái chưa phân giải (`unresolved`), tuyệt đối không gán khóa ngoại cho tới khi phụ lục số hóa chính thức của NQ 388 được tích hợp.

---

## 6. HIỆU CHỈNH QUAN HỆ TRỰC THUỘC CỦA 5 ĐẶC KHU HÀNH CHÍNH

Theo phương án sắp xếp đơn vị hành chính cấp tỉnh năm 2025 (Nghị quyết 202/2025/QH15), quan hệ trực thuộc của 5 đặc khu đã được hiệu chỉnh chính xác:

| Mã số | Tên đặc khu | Tỉnh/thành cha cũ | Tỉnh/thành cha chuẩn hoá (Snapshot 2026-09-20) | Mã cha | Tình trạng kiểm toán |
|:---:|:---|:---|:---|:---:|:---:|
| `23272` | Đặc khu Phú Quý | Tỉnh Bình Thuận | **Tỉnh Lâm Đồng** | `68` | **Đã đồng bộ 100% trong JSON & MySQL** |
| `26732` | Đặc khu Côn Đảo | Tỉnh Bà Rịa - Vũng Tàu | **Thành phố Hồ Chí Minh** | `79` | **Đã đồng bộ 100% trong JSON & MySQL** |
| `31078` | Đặc khu Phú Quốc | Tỉnh Kiên Giang | **Tỉnh An Giang** | `91` | **Đã đồng bộ 100% trong JSON & MySQL** |
| `31105` | Đặc khu Thổ Châu | Tỉnh Kiên Giang | **Tỉnh An Giang** | `91` | **Đã đồng bộ 100% trong JSON & MySQL** |
| `31108` | Đặc khu Kiên Hải | Tỉnh Kiên Giang | **Tỉnh An Giang** | `91` | **Đã đồng bộ 100% trong JSON & MySQL** |

---

## 7. TỔNG KẾT TÌNH TRẠNG XÁC MINH CẤP XÃ (3.321 ĐƠN VỊ)

| Nhóm dữ liệu | Số lượng bản ghi | Tỷ lệ | Trạng thái xác minh | Căn cứ xác minh |
|---|---:|---:|:---|:---|
| 10 Phường Đồng Nai | 10 | 0.30% | `VERIFIED_PRIMARY` | NQ 237/NQ-UBTVQH16 ngày 14/04/2026 |
| 13 Đặc khu hành chính | 13 | 0.39% | `VERIFIED_PRIMARY` | NQ 202/2025/QH15 ngày 12/06/2025 |
| 10 Phường đô thị đối chứng | 10 | 0.30% | `VERIFIED_PRIMARY` | NQ 202/2025/QH15 & QĐ 19/2025/QĐ-TTg |
| 12 Phường Bắc Ninh | 12 | 0.36% | `UNVERIFIED_SOURCE_DOCUMENT_MISSING` | Thiếu phụ lục NQ 388 chính thức (Blocker) |
| 3.276 Xã / Phường còn lại | 3.276 | 98.65% | `VERIFIED_SECONDARY` | QĐ 19/2025/QĐ-TTg & Niên giám GSO 2025 |
| **Tổng cộng cấp xã** | **3.321** | **100%** | — | — |

