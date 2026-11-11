# BÁO CÁO NGUỒN GỐC DỮ LIỆU & PHÂN TÍCH BẢN QUYỀN (PROVENANCE & LICENSE)
## Data Provenance, Distribution Channel & Intellectual Property Law Analysis

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3.1.2.2 — Administrative Catalog Legal & Data Remediation  
**Tài liệu:** `docs/verification/phase-3-1-2-2/02-dataset-provenance-and-license.md`  
**Ngày thực hiện:** 2026-11-11  
**Mốc snapshot:** 2026-09-20  

---

### 1. NGUỒN DỮ LIỆU SƠ CẤP & THỨ CẤP (DATA PROVENANCE)

Hệ thống Travel Planner áp dụng nguyên tắc truy nguyên đa tầng, phân định rõ ràng giữa Cơ quan quyền lực Nhà nước ban hành dữ liệu gốc và Kênh phân phối mã nguồn mở.

#### 1.1. Nguồn Dữ liệu Sơ cấp (Primary Authorities)
1. **Quốc hội nước Cộng hòa Xã hội Chủ nghĩa Việt Nam (`quochoi.vn`):**
   - Ban hành các đạo luật và nghị quyết xác lập cơ cấu đơn vị hành chính cấp tỉnh:
     - Nghị quyết số 202/2025/QH15 (sắp xếp 34 tỉnh/thành phố).
     - Nghị quyết số 175/2024/QH15 (thành lập Thành phố Huế trực thuộc TW).
     - Nghị quyết số 30/2026/QH16 (thành lập Thành phố Đồng Nai trực thuộc TW).
     - Nghị quyết số 36/2026/QH16 (thành lập Thành phố Quảng Ninh trực thuộc TW).
     - Nghị quyết số 39/2026/QH16 (thành lập Thành phố Bắc Ninh trực thuộc TW).
2. **Ủy ban Thường vụ Quốc hội khóa XVI:**
   - Ban hành các nghị quyết thành lập và điều chỉnh đơn vị hành chính cấp cơ sở:
     - Nghị quyết số 237/NQ-UBTVQH16 (thành lập 10 phường tại Đồng Nai).
     - Nghị quyết số 388/NQ-UBTVQH16 (thành lập 12 phường tại Bắc Ninh).
3. **Thủ tướng Chính phủ & Cục Thống kê (GSO / NSO — `danhmuchanhchinh.gso.gov.vn`):**
   - Quyết định số 19/2025/QĐ-TTg ban hành Bảng danh mục và hệ thống mã số hành chính quốc gia 2 cấp (mã 2 số cấp tỉnh, mã 5 số cấp cơ sở).

#### 1.2. Kênh Phân phối Thứ cấp (Secondary Distribution Channel)
- **Repository:** `https://github.com/thanglequoc/vietnamese-provinces-database`
- **Tác giả / Maintainer:** Thắng Lê Quốc (`thanglequoc`).
- **Phiên bản / Tag:** `v5.2.0-decree388` (phát hành ngày 20/09/2026).
- **Commit Reference:** `6b08f42`.
- **Vai trò trong hệ thống:** Là kênh phân phối đóng gói thứ cấp thuận tiện cho việc lập trình. Dữ liệu thô JSON của bên thứ ba được nạp vào Travel Planner nhưng **không được coi là nguồn chân lý duy nhất** nếu không trải qua bộ kiểm chuẩn độc lập `AdministrativeAreaValidator`.

---

### 2. PHÂN TÍCH PHÁP LÝ BẢN QUYỀN THEO LUẬT SỞ HỮU TRÍ TUỆ VIỆT NAM

> [!IMPORTANT]
> **Đính chính sai sót pháp lý của Phase 3.1.2.1:**  
> Báo cáo Phase 3.1.2.1 trước đây đã viện dẫn sai Điều 19 Luật Sở hữu trí tuệ để lập luận dữ liệu hành chính là Public Domain. Điều 19 quy định về "Quyền nhân thân của tác giả" (đặt tên tác phẩm, đứng tên, bảo vệ sự toàn vẹn của tác phẩm). Căn cứ pháp lý chính xác loại trừ quyền tác giả đối với thông tin hành chính là **Điều 15 Luật Sở hữu trí tuệ**.

#### 2.1. Căn cứ Pháp lý Trọng tâm: Điều 15 Luật Sở hữu trí tuệ
Căn cứ theo **Điều 15 Luật Sở hữu trí tuệ năm 2005 (đã được sửa đổi, bổ sung các năm 2009, 2019, 2022)** quy định về *Các đối tượng không thuộc phạm vi bảo hộ quyền tác giả*:

> *"1. Tin tức thời sự thuần tuý đưa tin.*  
> *2. Văn bản quy phạm pháp luật, văn bản hành chính, văn bản khác thuộc lĩnh vực tư pháp và bản dịch chính thức của văn bản đó.*  
> *3. Quy trình, hệ thống, phương pháp hoạt động, khái niệm, nguyên lý, số liệu."*

#### 2.2. Phân tích Chi tiết 6 Thành phần Dữ liệu & Hệ thống:

1. **Văn bản pháp luật gốc (Legal Acts):**
   - Các Nghị quyết của Quốc hội, Ủy ban Thường vụ Quốc hội và Quyết định của Thủ tướng Chính phủ là văn bản quy phạm pháp luật, thuộc **Khoản 2 Điều 15**. Các văn bản này hoàn toàn không thuộc đối tượng bảo hộ quyền tác giả, bất kỳ tổ chức hay cá nhân nào cũng có quyền sao chép, trích dẫn, phổ biến và sử dụng.
2. **Tên gọi và Mã số đơn vị hành chính (Administrative Names & Codes):**
   - Tên gọi địa danh và mã số định danh 2 chữ số / 5 chữ số do Nhà nước quy định là **dữ kiện thực tế và số liệu (factual data & numerical statistics)**, thuộc **Khoản 3 Điều 15**. Các dữ kiện này không có tính sáng tạo nguyên gốc (originality) và không thể được xác lập quyền tác giả bởi bất kỳ cá nhân hay tổ chức nào.
3. **Dataset do cơ quan nhà nước công bố (Official Government Dataset):**
   - Theo Nghị định số 47/2020/NĐ-CP về quản lý, kết nối và chia sẻ dữ liệu số của cơ quan nhà nước, dữ liệu danh mục hành chính thuộc nhóm dữ liệu mở của cơ quan nhà nước (Open Government Data), được khuyến khích khai thác, sử dụng tự do cho các mục đích dân sự, thương mại và nghiên cứu.
4. **Dataset phân phối trên GitHub của bên thứ ba (`thanglequoc`):**
   - Về mặt bản quyền: Dữ liệu thô bên trong các file JSON/SQL/CSV là sự phản ánh lại nguyên trạng dữ liệu Nhà nước. Bên phân phối thứ cấp không sở hữu quyền tác giả đối với nội dung địa giới.
   - Về quyền đối với Cơ sở dữ liệu (Database Sui Generis Rights): Pháp luật Sở hữu trí tuệ Việt Nam (Điều 22) chỉ bảo hộ quyền tác giả đối với cơ sở dữ liệu nếu có *"sự sáng tạo thể hiện ở việc tuyển chọn, sắp xếp các tư liệu"*. Do dữ liệu được sắp xếp theo cấu trúc hành chính 2 cấp tự nhiên của Nhà nước, khả năng có khiếu nại về quyền cơ sở dữ liệu là không đáng kể.
5. **Mã nguồn (Source Code, Tooling, Importer Scripts):**
   - File `LICENSE` trong repository GitHub của tác giả là **MIT License**. Giấy phép này áp dụng hợp lệ và đầy đủ cho các đoạn mã nguồn (Java, Python, Shell scripts) do tác giả tự tay viết để xuất dữ liệu. Travel Planner tự viết toàn bộ importer (`AdministrativeAreaMigrationRunner.java`) và validator (`AdministrativeAreaValidator.java`), hoàn toàn không sao chép source code từ repository của bên thứ ba.
6. **Cấu trúc, chú giải và phần mềm Travel Planner:**
   - Schema MySQL (`administrative_areas`, `administrative_catalog_metadata`), DTOs, Controllers, Services và kiểm thử do đội ngũ kỹ sư Travel Planner độc lập thiết kế và triển khai, thuộc quyền sở hữu của dự án Travel Planner (TLCN).

---

### 3. ĐÁNH GIÁ RỦI RO PHÁP LÝ & KHUYẾN NGHỊ TUÂN THỦ (COMPLIANCE)

#### 3.1. Đánh giá Mức độ Rủi ro Khách quan
- **Rủi ro vi phạm bản quyền dữ liệu:** **Rất thấp (Negligible Risk)**. Dữ liệu địa giới hành chính là thông tin công quyền và số liệu thuần túy theo Điều 15 Luật SHTT Việt Nam.
- **Rủi ro cấp phép mã nguồn:** **Không có rủi ro (No Risk)**. Toàn bộ mã nguồn backend, migration runner, validator và API trong Travel Planner được viết mới 100%, không tái sử dụng mã nguồn của tác giả repository.
- **Rủi ro phụ thuộc bên thứ ba:** Được kiểm soát chặt chẽ bằng việc lưu trữ bộ dữ liệu nội bộ tĩnh (`provinces.json`, `communes.json`, `metadata.json`) và xác minh bằng mã băm kiểm chuẩn Canonical Checksum v1 (`af6e22c85f46a03cd68f5d4335d6e12129dff9038c17eaabf285084d53ab8674`).

#### 3.2. Biện pháp Tuân thủ & Attribution
Nhằm thể hiện sự minh bạch học thuật và đạo đức nghề nghiệp phần mềm mã nguồn mở:
1. Ghi nhận rõ ràng nguồn phân phối thứ cấp trong file `NOTICE` và tài liệu kỹ thuật:
   > *"Administrative dataset redistributed via `thanglequoc/vietnamese-provinces-database` under MIT license terms, derived from official legal acts of the National Assembly and Prime Minister of Vietnam."*
2. Lưu giữ toàn văn bản quyền MIT của repository thứ cấp trong tài liệu đối chiếu.

---

### 4. BẢNG TRUY NGUYÊN NGUỒN GỐC TOÀN DIỆN (DATA PROVENANCE MATRIX)

| Thành phần dữ liệu | Cơ quan ban hành gốc (Primary Source) | Kênh phân phối / Công cụ (Secondary Channel) | Căn cứ pháp lý bản quyền | Tình trạng cấp phép | Rủi ro pháp lý |
|:---|:---|:---|:---|:---|:---:|
| **34 Đơn vị cấp Tỉnh** | Quốc hội Việt Nam (NQ 202/2025/QH15, NQ 175/2024/QH15, NQ 30, 36, 39/2026/QH16) | `thanglequoc/vietnamese-provinces-database` | Điều 15 Khoản 2 & 3 Luật SHTT 2005/2022 | Public Domain / Open Data | Rất thấp |
| **3.299 Xã/Phường cơ sở** | Thủ tướng Chính phủ (QĐ 19/2025/QĐ-TTg) & Cục Thống kê (GSO) | `thanglequoc/vietnamese-provinces-database` | Điều 15 Khoản 2 & 3 Luật SHTT 2005/2022 | Public Domain / Open Data | Rất thấp |
| **10 Phường mới Đồng Nai** | Ủy ban Thường vụ Quốc hội (NQ 237/NQ-UBTVQH16) | `thanglequoc/vietnamese-provinces-database` | Điều 15 Khoản 2 Luật SHTT 2005/2022 | Public Domain / Open Data | Rất thấp |
| **12 Phường mới Bắc Ninh** | Ủy ban Thường vụ Quốc hội (NQ 388/NQ-UBTVQH16) | `thanglequoc/vietnamese-provinces-database` | Điều 15 Khoản 2 Luật SHTT 2005/2022 | Public Domain / Open Data | Rất thấp |
| **Mã nguồn Tooling của tác giả** | Tác giả Thắng Lê Quốc | GitHub Repository | Bản quyền tác giả phần mềm | MIT License | Tuân thủ MIT |
| **Mã nguồn Importer Travel Planner** | Đội ngũ kỹ sư Travel Planner | Kho lưu trữ nội bộ Travel Planner | Bản quyền tác phẩm phần mềm TLCN | TLCN License | Không có |
