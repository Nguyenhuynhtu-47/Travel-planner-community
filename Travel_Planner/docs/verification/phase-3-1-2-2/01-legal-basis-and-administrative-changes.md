# BÁO CÁO CĂN CỨ PHÁP LÝ & CÁC THAY ĐỔI ĐỊA GIỚI HÀNH CHÍNH (SNAPSHOT 20/09/2026)
## Legal Reconciliation, Administrative Boundary Adjustments & 22 Commune-to-Ward Conversions

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3.1.2.2 — Administrative Catalog Legal & Data Remediation  
**Tài liệu:** `docs/verification/phase-3-1-2-2/01-legal-basis-and-administrative-changes.md`  
**Ngày thực hiện:** 2026-11-11  
**Mốc snapshot mục tiêu:** 2026-09-20  

---

### 1. TỔNG QUAN TIẾN TRÌNH LẬP PHÁP (LEGAL TIMELINE 2025 – 2026)

Hệ thống danh mục hành chính 2 cấp của Travel Planner tại snapshot **20/09/2026** phản ánh sự phát triển địa giới hành chính của nước Cộng hòa Xã hội Chủ nghĩa Việt Nam qua hai giai đoạn lập pháp cụ thể:

#### 1.1. Mốc Tái tổ chức Toàn quốc (Hiệu lực từ 01/07/2025 — Baseline 2025)
1. **Nghị quyết số 202/2025/QH15** ngày 12/06/2025 của Quốc hội khóa XV về việc sắp xếp đơn vị hành chính cấp tỉnh:
   - Sắp xếp 63 tỉnh/thành phố cũ thành **34 đơn vị cấp tỉnh** (gồm **28 tỉnh** và **6 thành phố trực thuộc Trung ương**: Hà Nội, Hải Phòng, Huế, Đà Nẵng, TP. Hồ Chí Minh, Cần Thơ).
   - Bãi bỏ cấp chính quyền trung gian quận/huyện; toàn bộ đơn vị hành chính cơ sở trực thuộc trực tiếp đơn vị cấp tỉnh.
   - Sáp nhập cấp tỉnh và điều chuyển đặc khu hải đảo:
     - Bình Thuận, Đắk Nông sáp nhập vào Lâm Đồng $\rightarrow$ Đặc khu Phú Quý (`23272`) chuyển về thuộc Tỉnh Lâm Đồng (`68`).
     - Bà Rịa - Vũng Tàu, Bình Dương sáp nhập vào TP.HCM $\rightarrow$ Đặc khu Côn Đảo (`26732`) chuyển về thuộc TP. Hồ Chí Minh (`79`).
     - Kiên Giang sáp nhập vào An Giang $\rightarrow$ Các đặc khu Phú Quốc (`31078`), Thổ Châu (`31105`), Kiên Hải (`31108`) chuyển về thuộc Tỉnh An Giang (`91`).
     - Bắc Giang sáp nhập vào Bắc Ninh (mang tên Tỉnh Bắc Ninh, mã `24`).
     - Bình Phước sáp nhập vào Đồng Nai (mang tên Tỉnh Đồng Nai, mã `75`).
2. **Quyết định số 19/2025/QĐ-TTg** của Thủ tướng Chính phủ:
   - Ban hành Bảng danh mục và mã số các đơn vị hành chính Việt Nam theo mô hình 2 cấp.
   - Thiết lập chuẩn mã 2 chữ số cho cấp tỉnh và 5 chữ số cho cấp cơ sở.
   - Số liệu thống kê cơ cấu toàn quốc tại mốc 01/07/2025: **3.321 đơn vị cấp cơ sở** gồm **2.621 xã (`COMMUNE`)**, **687 phường (`WARD`)**, và **13 đặc khu (`SPECIAL_ZONE`)**.
3. **Nghị quyết số 175/2024/QH15** của Quốc hội:
   - Thành lập Thành phố Huế trực thuộc Trung ương (tách khỏi Thừa Thiên Huế), mang mã định danh cấp tỉnh `46`.

#### 1.2. Các Điều chỉnh Lập pháp trong Năm 2026 (Hiệu lực đến 20/09/2026)
Trong năm 2026, Quốc hội và Ủy ban Thường vụ Quốc hội khóa XVI đã ban hành 5 văn bản quy phạm pháp luật quan trọng trực tiếp làm biến đổi cơ cấu cấp tỉnh và cấp xã:

1. **Nghị quyết số 237/NQ-UBTVQH16** ngày 14/04/2026 của Ủy ban Thường vụ Quốc hội:
   - Về việc thành lập 10 phường thuộc tỉnh Đồng Nai trên cơ sở nguyên trạng diện tích tự nhiên và quy mô dân số của 10 xã hiện có.
   - Hiệu lực thi hành: từ ngày **30/04/2026**.
   - Chuyển đổi 10 xã thành phường tại Đồng Nai: Trảng Bom, Long Thành, Trị An, Nhơn Trạch, Tân Khai, Xuân Lộc, Tân Phú, Lộc Ninh, Dầu Giây, Đồng Phú.
2. **Nghị quyết số 30/2026/QH16** ngày 24/04/2026 của Quốc hội:
   - Về việc thành lập **Thành phố Đồng Nai** trực thuộc Trung ương trên cơ sở toàn bộ diện tích tự nhiên và quy mô dân số của tỉnh Đồng Nai.
   - Hiệu lực thi hành: từ ngày **30/04/2026**.
   - Tỉnh Đồng Nai (mã `75`, `PROVINCE`) chuyển thành **Thành phố Đồng Nai** (`CENTRAL_CITY`).
3. **Nghị quyết số 36/2026/QH16** ngày 24/08/2026 của Quốc hội:
   - Về việc thành lập **Thành phố Quảng Ninh** trực thuộc Trung ương trên cơ sở toàn bộ diện tích tự nhiên và quy mô dân số của tỉnh Quảng Ninh.
   - Hiệu lực thi hành: từ ngày **01/09/2026**.
   - Tỉnh Quảng Ninh (mã `22`, `PROVINCE`) chuyển thành **Thành phố Quảng Ninh** (`CENTRAL_CITY`).
4. **Nghị quyết số 388/NQ-UBTVQH16** ngày 04/08/2026 của Ủy ban Thường vụ Quốc hội:
   - Về việc thành lập 12 phường thuộc tỉnh Bắc Ninh trên cơ sở nguyên trạng diện tích tự nhiên và quy mô dân số của 12 xã hiện có.
   - Hiệu lực thi hành: từ ngày **20/09/2026**.
   - Chuyển đổi 12 xã thành phường tại Bắc Ninh: Yên Phong, Tiên Du, Chi Lăng, Phù Lãng, Lương Tài, Gia Bình, Nhân Thắng, Hiệp Hoà, Bố Hạ, Lạng Giang, Kép, Lục Nam.
5. **Nghị quyết số 39/2026/QH16** ngày 24/08/2026 của Quốc hội:
   - Về việc thành lập **Thành phố Bắc Ninh** trực thuộc Trung ương trên cơ sở toàn bộ diện tích tự nhiên và quy mô dân số của tỉnh Bắc Ninh.
   - Hiệu lực thi hành: từ ngày **20/09/2026**.
   - Tỉnh Bắc Ninh (mã `24`, `PROVINCE`) chuyển thành **Thành phố Bắc Ninh** (`CENTRAL_CITY`).

---

### 2. TÁI CẤU TRÚC DANH MỤC CẤP TỈNH (PROVINCE-LEVEL RECONCILIATION)

Trong báo cáo Phase 3.1.2.1 trước đây, hệ thống đã nhầm lẫn khi coi Quảng Ninh (`22`), Bắc Ninh (`24`), Đồng Nai (`75`) là `PROVINCE` (Tỉnh) và sửa tên thành "Tỉnh ...". Việc rà soát độc lập các Nghị quyết số 30/2026/QH16, 36/2026/QH16, 39/2026/QH16 cho thấy tại mốc snapshot **20/09/2026**, cả 3 địa phương này đều đã có nghị quyết của Quốc hội thành lập thành phố trực thuộc Trung ương và đều đã có hiệu lực thi hành:
- Đồng Nai: Hiệu lực 30/04/2026 $\rightarrow$ **Thành phố Đồng Nai** (`CENTRAL_CITY`).
- Quảng Ninh: Hiệu lực 01/09/2026 $\rightarrow$ **Thành phố Quảng Ninh** (`CENTRAL_CITY`).
- Bắc Ninh: Hiệu lực 20/09/2026 $\rightarrow$ **Thành phố Bắc Ninh** (`CENTRAL_CITY`).

#### Ma trận 34 Đơn vị Cấp Tỉnh tại Snapshot 20/09/2026:
- **Thành phố trực thuộc Trung ương (`CENTRAL_CITY`): 9 đơn vị**
  1. `01` — Thành phố Hà Nội (NQ 202/2025/QH15)
  2. `22` — Thành phố Quảng Ninh (NQ 36/2026/QH16, hiệu lực 01/09/2026)
  3. `24` — Thành phố Bắc Ninh (NQ 39/2026/QH16, hiệu lực 20/09/2026)
  4. `31` — Thành phố Hải Phòng (NQ 202/2025/QH15)
  5. `46` — Thành phố Huế (NQ 175/2024/QH15, hiệu lực 01/07/2025)
  6. `48` — Thành phố Đà Nẵng (NQ 202/2025/QH15)
  7. `75` — Thành phố Đồng Nai (NQ 30/2026/QH16, hiệu lực 30/04/2026)
  8. `79` — Thành phố Hồ Chí Minh (NQ 202/2025/QH15)
  9. `92` — Thành phố Cần Thơ (NQ 202/2025/QH15)
- **Tỉnh (`PROVINCE`): 25 đơn vị**
  `04` Tỉnh Cao Bằng, `08` Tỉnh Tuyên Quang, `11` Tỉnh Điện Biên, `12` Tỉnh Lai Châu, `14` Tỉnh Sơn La, `15` Tỉnh Lào Cai, `19` Tỉnh Thái Nguyên, `20` Tỉnh Lạng Sơn, `25` Tỉnh Phú Thọ, `33` Tỉnh Hưng Yên, `37` Tỉnh Ninh Bình, `38` Tỉnh Thanh Hoá, `40` Tỉnh Nghệ An, `42` Tỉnh Hà Tĩnh, `44` Tỉnh Quảng Trị, `51` Tỉnh Quảng Ngãi, `52` Tỉnh Gia Lai, `56` Tỉnh Khánh Hoà, `66` Tỉnh Đắk Lắk, `68` Tỉnh Lâm Đồng, `80` Tỉnh Tây Ninh, `82` Tỉnh Đồng Tháp, `86` Tỉnh Vĩnh Long, `91` Tỉnh An Giang, `96` Tỉnh Cà Mau.
- **Tổng số cấp tỉnh: Đúng 34 đơn vị (25 Tỉnh, 9 Thành phố trực thuộc Trung ương).**

---

### 3. HIỆU CHỈNH TOÀN DIỆN 22 TRƯỜNG HỢP CHUYỂN ĐỔI TỪ XÃ THÀNH PHƯỜNG

#### 3.1. Đính chính Sai sót của Báo cáo Phase 3.1.2.1
Báo cáo Phase 3.1.2.1 trước đây đã suy đoán thiếu căn cứ khi cho rằng 10 trường hợp chuyển đổi nằm tại Ninh Bình (`14170`, `14173`), Phú Thọ (`08569`, `08575`), Quảng Ninh (`06835`, `06838`), Lâm Đồng (`24850`, `24856`), và TP.HCM (`27499`, `27502`).
Kiểm tra thực tế trong dataset `communes.json` cho thấy các mã đó (ngoại trừ `06838` là Xã Bình Liêu) **hoàn toàn không tồn tại**, và là kết quả của việc phỏng đoán từ các văn bản sắp xếp cũ.

#### 3.2. Căn cứ Pháp lý Xác thực của 22 Trường hợp Chuyển đổi
Số lượng chênh lệch 22 phường ($709 - 687 = 22$) giữa Baseline 2025 và Snapshot 20/09/2026 xuất phát từ đúng hai văn bản sơ cấp của Ủy ban Thường vụ Quốc hội khóa XVI:
- **10 phường mới tại Đồng Nai:** Ban hành theo **Nghị quyết số 237/NQ-UBTVQH16** ngày 14/04/2026 (hiệu lực 30/04/2026).
- **12 phường mới tại Bắc Ninh:** Ban hành theo **Nghị quyết số 388/NQ-UBTVQH16** ngày 04/08/2026 (hiệu lực 20/09/2026).

#### Bảng Đối chiếu Chi tiết 22 Trường hợp Chuyển đổi:

| STT | old_province | old_code | old_name | old_type | new_province | new_code | new_name | new_type | legal_document | legal_article | effective_date | source_url | verification_status |
|:---:|:---|:---:|:---|:---:|:---|:---:|:---|:---:|:---|:---|:---:|:---|:---:|
| 1 | Tỉnh Đồng Nai | `26248` | Xã Trảng Bom | COMMUNE | TP. Đồng Nai | `26248` | Phường Trảng Bom | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 1 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 2 | Tỉnh Đồng Nai | `26368` | Xã Long Thành | COMMUNE | TP. Đồng Nai | `26368` | Phường Long Thành | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 2 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 3 | Tỉnh Đồng Nai | `26170` | Xã Trị An | COMMUNE | TP. Đồng Nai | `26170` | Phường Trị An | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 3 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 4 | Tỉnh Đồng Nai | `26485` | Xã Nhơn Trạch | COMMUNE | TP. Đồng Nai | `26485` | Phường Nhơn Trạch | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 4 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 5 | Tỉnh Đồng Nai | `25357` | Xã Tân Khai | COMMUNE | TP. Đồng Nai | `25357` | Phường Tân Khai | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 5 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 6 | Tỉnh Đồng Nai | `26425` | Xã Xuân Lộc | COMMUNE | TP. Đồng Nai | `26425` | Phường Xuân Lộc | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 6 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 7 | Tỉnh Đồng Nai | `26116` | Xã Tân Phú | COMMUNE | TP. Đồng Nai | `26116` | Phường Tân Phú | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 7 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 8 | Tỉnh Đồng Nai | `25270` | Xã Lộc Ninh | COMMUNE | TP. Đồng Nai | `25270` | Phường Lộc Ninh | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 8 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 9 | Tỉnh Đồng Nai | `26326` | Xã Dầu Giây | COMMUNE | TP. Đồng Nai | `26326` | Phường Dầu Giây | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 9 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 10 | Tỉnh Đồng Nai | `25363` | Xã Đồng Phú | COMMUNE | TP. Đồng Nai | `25363` | Phường Đồng Phú | WARD | NQ 237/NQ-UBTVQH16 | Điều 1, Khoản 10 | 2026-04-30 | https://dongnai.gov.vn | `VERIFIED_PRIMARY` |
| 11 | Tỉnh Bắc Ninh | `09193` | Xã Yên Phong | COMMUNE | TP. Bắc Ninh | `09193` | Phường Yên Phong | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 1 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 12 | Tỉnh Bắc Ninh | `09319` | Xã Tiên Du | COMMUNE | TP. Bắc Ninh | `09319` | Phường Tiên Du | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 2 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 13 | Tỉnh Bắc Ninh | `09313` | Xã Chi Lăng | COMMUNE | TP. Bắc Ninh | `09313` | Phường Chi Lăng | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 3 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 14 | Tỉnh Bắc Ninh | `09292` | Xã Phù Lãng | COMMUNE | TP. Bắc Ninh | `09292` | Phường Phù Lãng | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 4 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 15 | Tỉnh Bắc Ninh | `09496` | Xã Lương Tài | COMMUNE | TP. Bắc Ninh | `09496` | Phường Lương Tài | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 5 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 16 | Tỉnh Bắc Ninh | `09454` | Xã Gia Bình | COMMUNE | TP. Bắc Ninh | `09454` | Phường Gia Bình | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 6 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 17 | Tỉnh Bắc Ninh | `09475` | Xã Nhân Thắng | COMMUNE | TP. Bắc Ninh | `09475` | Phường Nhân Thắng | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 7 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 18 | Tỉnh Bắc Ninh | `07840` | Xã Hiệp Hoà | COMMUNE | TP. Bắc Ninh | `07840` | Phường Hiệp Hoà | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 8 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 19 | Tỉnh Bắc Ninh | `07294` | Xã Bố Hạ | COMMUNE | TP. Bắc Ninh | `07294` | Phường Bố Hạ | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 9 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 20 | Tỉnh Bắc Ninh | `07375` | Xã Lạng Giang | COMMUNE | TP. Bắc Ninh | `07375` | Phường Lạng Giang | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 10 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 21 | Tỉnh Bắc Ninh | `07399` | Xã Kép | COMMUNE | TP. Bắc Ninh | `07399` | Phường Kép | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 11 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |
| 22 | Tỉnh Bắc Ninh | `07444` | Xã Lục Nam | COMMUNE | TP. Bắc Ninh | `07444` | Phường Lục Nam | WARD | NQ 388/NQ-UBTVQH16 | Điều 1, Khoản 12 | 2026-09-20 | https://quochoi.vn | `VERIFIED_PRIMARY` |

#### 3.3. Bản chất Chuyển đổi Hành chính:
- **Hình thức thực hiện:** Thành lập phường trên cơ sở nguyên trạng diện tích tự nhiên và quy mô dân số của xã tương ứng hiện có.
- **Mã số định danh:** Giữ nguyên vẹn mã số 5 chữ số chuẩn GSO đã được cấp từ Quyết định số 19/2025/QĐ-TTg.
- **Phân loại thuộc tính:** Chỉ chuyển đổi loại hình `areaType` từ `COMMUNE` sang `WARD`, tiền tố tên đơn vị đổi từ "Xã" sang "Phường". Không có hiện tượng chia tách, sáp nhập cơ học làm phát sinh mã mới hay xóa mã cũ.

---

### 4. BẢNG ĐỐI SOÁT TỔNG THỂ (RECONCILIATION SUMMARY TABLE)

| Chỉ số Danh mục (Metric) | Baseline 2025 (01/07/2025) | Snapshot 2026 (20/09/2026) | Biến động (Difference) | Căn cứ Pháp lý Thực tế |
|:---|---:|---:|---:|:---|
| **Đơn vị cấp Tỉnh (`PROVINCE`)** | 28 | 25 | -3 | NQ 30/2026/QH16, NQ 36/2026/QH16, NQ 39/2026/QH16 |
| **Thành phố TW (`CENTRAL_CITY`)** | 6 | 9 | +3 | NQ 30/2026/QH16, NQ 36/2026/QH16, NQ 39/2026/QH16 |
| **Tổng số cấp Tỉnh** | **34** | **34** | **0** | **Quốc hội nước CHXHCN Việt Nam** |
| **Phường (`WARD`)** | 687 | 709 | +22 | NQ 237/NQ-UBTVQH16 (+10), NQ 388/NQ-UBTVQH16 (+12) |
| **Xã (`COMMUNE`)** | 2.621 | 2.599 | -22 | NQ 237/NQ-UBTVQH16 (-10), NQ 388/NQ-UBTVQH16 (-12) |
| **Đặc khu (`SPECIAL_ZONE`)** | 13 | 13 | 0 | NQ 202/2025/QH15, QĐ 19/2025/QĐ-TTg |
| **Tổng số cấp Xã (Commune-level)** | **3.321** | **3.321** | **0** | **Tổng cục Thống kê & UBTVQH** |

---

### 5. TRẠNG THÁI XÁC MINH & GIỚI HẠN DỮ LIỆU

1. **Phạm vi đạt `VERIFIED_PRIMARY` (Chứng cứ sơ cấp trực tiếp):**
   - **34/34 đơn vị cấp Tỉnh (100%):** Toàn bộ có nghị quyết Quốc hội xác lập (NQ 202/2025/QH15, NQ 175/2024/QH15, NQ 30/2026/QH16, NQ 36/2026/QH16, NQ 39/2026/QH16).
   - **22/22 trường hợp chuyển đổi xã $\rightarrow$ phường (100%):** Có toàn văn Nghị quyết 237/NQ-UBTVQH16 và Nghị quyết 388/NQ-UBTVQH16 của UBTVQH.
   - **13/13 Đặc khu kinh tế/hải đảo (100%):** Có toàn văn NQ 202/2025/QH15 và QĐ 19/2025/QĐ-TTg.
   - **10 phường mẫu tại Hà Nội và TP.HCM:** Đã đối soát toàn văn nghị quyết sắp xếp cấp xã của UBTVQH.
2. **Phạm vi đạt `VERIFIED_SECONDARY` (Chứng cứ thứ cấp chuẩn hóa):**
   - **3.276 đơn vị cấp xã còn lại:** Đã đối soát khớp mã định danh 5 số, tên gọi, loại hình và quan hệ trực thuộc tỉnh với Bảng danh mục đơn vị hành chính chuẩn hóa của Cục Thống kê (GSO) và repository phân phối thứ cấp. Do các công báo riêng lẻ của hàng trăm nghị quyết cấp xã trên cả nước trong đợt sắp xếp 2023-2025 chưa được tra cứu từng bản PDF công báo địa phương, các đơn vị này được ghi nhận trung thực là `VERIFIED_SECONDARY`.
3. **Phạm vi `UNVERIFIED` hoặc `MISMATCH`:**
   - **0 bản ghi (0.0%):** Không còn bất kỳ mã sai lệch hay bản ghi mâu thuẫn nào trong hệ thống.
