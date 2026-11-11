# BÁO CÁO NGUỒN GỐC DỮ LIỆU VÀ ĐÁNH GIÁ BẢN QUYỀN (IP LAW & PROVENANCE REVIEW)
## Comprehensive Multi-Layer IP Analysis, Upstream Lineage & Copyright Assessment

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 3.1.2.3 — Final Administrative Catalog Correction & Acceptance Verification  
**Tài liệu:** `docs/verification/phase-3-1-2-3/05-dataset-provenance-and-license-review.md`  
**Ngày thực hiện:** 2026-11-11  

---

### 1. NGUỒN GỐC XUẤT XỨ (PROVENANCE & UPSTREAM LINEAGE)

Catalog địa giới hành chính hiện hành của Travel Planner được tích hợp từ kênh phân phối mở thứ cấp:
- **Repository URL:** `https://github.com/thanglequoc/vietnamese-provinces-database`
- **Release Tag:** `v5.2.0-decree388`
- **Commit Hash:** `6b08f42` (tháng 09/2026)
- **Cơ quan quản trị dữ liệu gốc (Upstream Data Authority):**
  - Cục Thống kê (NSO / GSO) — Bộ Kế hoạch và Đầu tư / Bộ Tài chính.
  - Văn phòng Quốc hội & Cổng thông tin điện tử Chính phủ nước CHXHCN Việt Nam.
- **Nội dung cập nhật tại tag `v5.2.0-decree388`:**
  - Cập nhật 34 đơn vị cấp tỉnh theo Nghị quyết 202/2025/QH15 và các Nghị quyết 30, 36, 39/2026/QH16.
  - Cập nhật 3.321 đơn vị cấp xã theo Quyết định 19/2025/QĐ-TTg, Nghị quyết 237/NQ-UBTVQH16 và Nghị quyết 388/NQ-UBTVQH16.

---

### 2. PHÂN TÍCH ĐA CHIỀU PHÁP LÝ BẢN QUYỀN (VIETNAMESE IP LAW ANALYSIS)

Trước đây, báo cáo Phase 3.1.2.1 đã trích dẫn nhầm Điều 19 Luật Sở hữu trí tuệ (quy định về Quyền nhân thân của tác giả) và kết luận võ đoán "0% rủi ro". Đợt rà soát Phase 3.1.2.3 bóc tách bản quyền độc lập theo từng tầng cấu thành theo quy định của **Luật Sở hữu trí tuệ số 50/2005/QH11** (sửa đổi, bổ sung các năm 2009, 2019, 2022):

#### 2.1. Tầng 1: Văn bản Quy phạm Pháp luật và Văn bản Hành chính
- **Căn cứ pháp lý:** **Khoản 2 Điều 15 Luật Sở hữu trí tuệ**:
  > *"Văn bản quy phạm pháp luật, văn bản hành chính, văn bản khác thuộc lĩnh vực tư pháp và bản dịch chính thức của văn bản đó không thuộc phạm vi bảo hộ quyền tác giả."*
- **Áp dụng:** Toàn bộ nội dung các Nghị quyết của Quốc hội (NQ 202, NQ 175, NQ 30, NQ 36, NQ 39), Nghị quyết của UBTVQH (NQ 237, NQ 388) và Quyết định của Thủ tướng Chính phủ (QĐ 19) thuộc diện tài sản công quyền, bất kỳ tổ chức hay cá nhân nào cũng có quyền tiếp cận, trích dẫn, sao chép và áp dụng mà không phải xin phép hay trả thù lao bản quyền.

#### 2.2. Tầng 2: Dữ liệu Hành chính Thuần túy, Mã số và Sự kiện
- **Căn cứ pháp lý:** **Khoản 3 Điều 15 Luật Sở hữu trí tuệ**:
  > *"Quy trình, hệ thống, phương pháp hoạt động, khái niệm, nguyên lý, số liệu không thuộc phạm vi bảo hộ quyền tác giả."*
- **Áp dụng:** Danh sách tên tỉnh ("Thành phố Hà Nội", "Tỉnh Cao Bằng"), mã định danh GSO ("01", "26248"), loại hình ("CENTRAL_CITY", "WARD") và quan hệ phân cấp địa giới hành chính là số liệu và sự kiện hành chính thuần túy. Không ai có quyền xác lập quyền tác giả đối với tên gọi hay mã số địa giới do Nhà nước ban hành.

#### 2.3. Tầng 3: Tác phẩm Sưu tập Dữ liệu (Database Compilation / Collections)
- **Căn cứ pháp lý:** **Điều 14 (Khoản 1, Điểm g) Luật Sở hữu trí tuệ**:
  > *"Tác phẩm sưu tập dữ liệu được bảo hộ quyền tác giả nếu sự lựa chọn hoặc sắp xếp dữ liệu thể hiện tính sáng tạo của tác giả."*
- **Áp dụng:**
  - Nếu một bộ dữ liệu có cấu trúc sắp xếp mang tính sáng tạo độc đáo riêng biệt của tác giả, cấu trúc tuyển chọn đó có thể được bảo hộ quyền tác giả (chứ không bảo hộ bản thân các số liệu).
  - Đối với repository `thanglequoc`, tác giả tổng hợp dữ liệu bám sát 100% bảng danh mục hành chính nhà nước của GSO (bố cục bảng biểu hành chính chuẩn hóa). Tác giả đã công bố phân phối toàn bộ dự án theo **MIT License**.
  - Không thể kết luận rằng "toàn bộ database tuyệt đối không thể được bảo hộ", nhưng trong bối cảnh cụ thể này, Travel Planner tuân thủ đầy đủ điều khoản ghi nhận nguồn (Attribution requirement) của tác giả trong file `metadata.json`.

#### 2.4. Tầng 4: Mã nguồn Chuyển đổi ETL (Converter / Importer Scripts)
- **Căn cứ pháp lý:** Tác phẩm phần mềm theo Điều 14 Luật SHTT.
- **Áp dụng:** Mã nguồn Java/Python của tác giả trong repo `thanglequoc` được phát hành theo **MIT License**. Travel Planner không sao chép nguyên trạng mã nguồn của repo, mà chỉ nạp output JSON thông qua runner tự viết (`AdministrativeAreaMigrationRunner.java`), do đó hoàn toàn không có xung đột bản quyền phần mềm.

---

### 3. ĐÁNH GIÁ RỦI RO CÓ ĐIỀU KIỆN (CONDITIONAL RISK EVALUATION)

Thay vì kết luận "0% rủi ro" mang tính hình thức, đánh giá rủi ro thực tế của Travel Planner đối với việc sử dụng catalog này như sau:

| Khía cạnh | Mức độ rủi ro | Căn cứ xác định | Giải pháp bảo vệ |
|---|:---:|---|---|
| **Tranh chấp bản quyền tên gọi & mã số hành chính** | **Rất thấp (Negligible)** | Khoản 2 & 3 Điều 15 Luật SHTT quy định rõ số liệu, sự kiện và văn bản nhà nước không bảo hộ quyền tác giả. | Lưu trữ trích dẫn văn bản pháp lý chính thức trong database metadata. |
| **Tranh chấp quyền sưu tập dữ liệu với tác giả upstream** | **Thấp (Low)** | Tác giả cấp phép theo MIT License; Travel Planner ghi nhận attribution minh bạch trong metadata và tài liệu kiến trúc. | Giữ nguyên ghi nhận tác giả và link GitHub trong `metadata.json`. |
| **Quyền cơ sở dữ liệu (Sui Generis Database Rights)** | **Không có (None)** | Pháp luật Việt Nam hiện hành không có quy định về quyền sui generis cho nhà sản xuất cơ sở dữ liệu độc lập với quyền tác giả. | Tuân thủ pháp luật Việt Nam. |
| **Rủi ro thay đổi chính sách dữ liệu mở** | **Thấp (Low)** | Dữ liệu hành chính là thông tin bắt buộc công khai theo Luật Tiếp cận thông tin năm 2016. | Hệ thống lưu trữ offline-first độc lập trong DB nội bộ. |
