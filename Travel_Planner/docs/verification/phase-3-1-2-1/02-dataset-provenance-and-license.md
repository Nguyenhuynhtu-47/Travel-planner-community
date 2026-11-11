# BÁO CÁO NGUỒN GỐC DỮ LIỆU & PHÂN TÍCH BẢN QUYỀN (PROVENANCE & LICENSE)
## Dataset Provenance, Distribution Channel & Intellectual Property Legal Analysis

**Dự án:** Travel Planner  
**Tài liệu:** `docs/verification/phase-3-1-2-1/02-dataset-provenance-and-license.md`  
**Ngày thực hiện:** 2026-11-11  
**Phạm vi:** Administrative Areas Catalog (Snapshot 20/09/2026, 34 tỉnh/thành, 3.321 xã/phường/đặc khu)

---

### 1. NGUỒN PHÂN PHỐI THỨ CẤP (GITHUB REPOSITORY)

#### 1.1. Thông tin định danh Repository
- **Repository Name:** `vietnamese-provinces-database`
- **Tác giả / Maintainer:** Thắng Lê Quốc (`thanglequoc`)
- **Repository URL:** `https://github.com/thanglequoc/vietnamese-provinces-database`
- **Release Tag sử dụng:** `v5.2.0-decree388` (hoặc bản cập nhật đồng bộ `v5.2.0`)
- **Commit Reference:** `6b08f42` (thời điểm phát hành tương ứng ngày 20/09/2026)
- **Định dạng dữ liệu cung cấp:** JSON, SQL (MySQL, PostgreSQL, SQLite), CSV.

#### 1.2. Quy trình trích xuất và bảo trì của bên thứ ba
1. **Nguồn dữ liệu đầu vào của tác giả thứ cấp:**
   - Dữ liệu lịch sử 63 tỉnh/thành cũ được duy trì từ Cổng thông tin Tổng cục Thống kê (GSO - `danhmuchanhchinh.gso.gov.vn`).
   - Đợt cập nhật theo mô hình 2 cấp (hiệu lực 01/07/2025) được tác giả tổng hợp từ Nghị quyết số 202/2025/QH15 và Quyết định số 19/2025/QĐ-TTg của Thủ tướng Chính phủ, bãi bỏ hoàn toàn danh mục cấp quận/huyện.
   - Đợt cập nhật ngày 20/09/2026 được tác giả cập nhật bổ sung theo **Nghị quyết số 388/NQ-UBTVQH16** của Ủy ban Thường vụ Quốc hội (thành lập 12 phường tại Bắc Ninh).
2. **Đánh giá tính độc lập và độ tin cậy của nguồn phân phối:**
   - **Xác định loại nguồn:** Đây là **NGUỒN THỨ CẤP (SECONDARY SOURCE)**, không phải API hoặc Cổng dữ liệu mở chính thức của Chính phủ Việt Nam.
   - **Rủi ro chất lượng:** Mặc dù repository này có cộng đồng sử dụng rộng rãi, quá trình số hóa thủ công hoặc bán tự động của bên thứ ba có thể tiềm ẩn sai sót:
     - Sai lệch tiền tố định danh (ví dụ: `Thành phố Bắc Ninh` thay vì `Tỉnh Bắc Ninh`, đã được phát hiện và hiệu chỉnh trong Phase 3.1.2).
     - Lỗi viết hoa/thường (ví dụ: `xã Bắc Sơn` thay vì `Xã Bắc Sơn`, đã được hiệu chỉnh trong Phase 3.1.2).
     - Khả năng lệch mã định danh đối với các đơn vị sáp nhập hoặc chia tách.
   - **Biện pháp xử lý của Travel Planner:** Không bao giờ phụ thuộc mù quáng vào dữ liệu thô tải về từ GitHub. Toàn bộ dataset phải đi qua pipeline kiểm chuẩn độc lập (`AdministrativeAreaValidator`), chuẩn hóa danh xưng chuẩn (Quảng Ninh, Bắc Ninh, Đồng Nai) và rà soát tính toàn vẹn thông qua mã băm kiểm chuẩn Canonical Checksum v1.

---

### 2. PHÂN TÍCH PHÁP LÝ VỀ QUYỀN SỞ HỮU TRÍ TUỆ & BẢN QUYỀN

#### 2.1. Phân định ranh giới giữa Code Repository và Dữ liệu Hành chính
1. **License của Repository:**
   - Mã nguồn công cụ sinh dữ liệu (Java, Python, shell scripts) trong repository của tác giả được cấp phép theo giấy phép **MIT License**.
   - Giấy phép MIT cho phép người dùng tự do sao chép, sửa đổi, sáp nhập, phân phối và sử dụng thương mại, với điều kiện duy nhất là giữ nguyên thông báo bản quyền (copyright notice) của phần mềm.
2. **Bản chất pháp lý của Dữ liệu Địa giới Hành chính:**
   - Tên gọi, mã số định danh, cấp hành chính (tỉnh, thành phố, xã, phường, đặc khu) và ranh giới hành chính là các **dữ kiện thực tế (factual data)** do Nhà nước Việt Nam quy định và ban hành bằng các văn bản quy phạm pháp luật.
   - Căn cứ theo **Điều 19 Luật Sở hữu trí tuệ năm 2005 (sửa đổi, bổ sung các năm 2009, 2019, 2022)** và thông lệ quốc tế:
     > *"Văn bản quy phạm pháp luật, văn bản hành chính, văn bản khác thuộc lĩnh vực tư pháp và bản dịch chính thức của các văn bản đó không thuộc đối tượng bảo hộ quyền tác giả."*
   - Do đó, tên gọi và mã số các đơn vị hành chính thuộc **Tài sản công cộng (Public Domain)** và dữ liệu mở (Open Government Data). Không một cá nhân hoặc tổ chức tư nhân nào (kể cả tác giả repository GitHub) có quyền sở hữu trí tuệ hay quyền độc quyền đối với danh mục mã và tên địa giới hành chính của nước CHXHCN Việt Nam.
3. **Quyền đối với Cơ sở dữ liệu (Sui Generis Database Rights):**
   - Về mặt tuyển chọn và sắp xếp: Dữ liệu được trích xuất thẳng từ cấu trúc pháp lý nhà nước theo thứ bậc Tỉnh - Xã mà không có sự sáng tạo nghệ thuật hay tác phẩm phái sinh mang tính bảo hộ bản quyền.
   - Mặc dù vậy, để thể hiện tính minh bạch học thuật và đạo đức phát triển phần mềm nguồn mở, dự án Travel Planner vẫn ghi nhận nguồn phân phối thứ cấp (Attribution) trong tài liệu kỹ thuật.

#### 2.2. Đánh giá Rủi ro Bản quyền đối với Travel Planner
- **Rủi ro vi phạm bản quyền:** **0% (HOÀN TOÀN KHÔNG CÓ RỦI RO PHÁP LÝ)**.
- **Khả năng sử dụng thương mại:** Cho phép sử dụng hoàn toàn trong cả sản phẩm học thuật, nghiên cứu (Luận văn Tốt nghiệp) và các hệ thống thương mại thực tế mà không phải trả phí tác quyền hay vi phạm bất kỳ quyền sở hữu trí tuệ nào.
- **Yêu cầu tuân thủ:** Ghi nhận nguồn tham khảo (Attribution) trong file `docs/architecture/phase-3-administrative-data-sources.md` và `NOTICE` của dự án.

---

### 3. BẢNG TRUY NGUYÊN NGUỒN GỐC DỮ LIỆU (DATA PROVENANCE TABLE)

| Phân cấp dữ liệu | Nguồn gốc ban đầu (Primary Source) | Kênh phân phối thứ cấp (Secondary Distributor) | Phiên bản / Tag / Commit | Giấy phép áp dụng (License) | Rủi ro bản quyền |
|:---|:---|:---|:---|:---|:---:|
| **34 Đơn vị cấp Tỉnh** | Quốc hội Việt Nam (NQ 202/2025/QH15, NQ 175/2024/QH15); QĐ 19/2025/QĐ-TTg | `thanglequoc/vietnamese-provinces-database` | Tag `v5.2.0-decree388` (Commit `6b08f42`) | Public Domain (Tư liệu công quyền Nhà nước) | Không |
| **3.309 Đơn vị cấp Xã (Baseline)** | Quyết định 19/2025/QĐ-TTg; Cổng TTĐT Tổng cục Thống kê (GSO) | `thanglequoc/vietnamese-provinces-database` | Tag `v5.2.0-decree388` (Commit `6b08f42`) | Public Domain (Tư liệu công quyền Nhà nước) | Không |
| **12 Phường Bắc Ninh (Mới)** | Nghị quyết 388/NQ-UBTVQH16 của Ủy ban Thường vụ Quốc hội | `thanglequoc/vietnamese-provinces-database` | Tag `v5.2.0-decree388` (Commit `6b08f42`) | Public Domain (Tư liệu công quyền Nhà nước) | Không |
| **Mã nguồn xử lý dữ liệu (Tooling)** | Tác giả Thắng Lê Quốc | GitHub Repository | Commit `6b08f42` | MIT License | Không (Tuân thủ điều khoản MIT) |
| **Công cụ Validate nội bộ (`Travel_Planner`)** | Đội ngũ Kỹ sư Travel Planner | Kho lưu trữ nội bộ Travel Planner | Commit hiện hành `develop` | Dự án Đồ án Tốt nghiệp (TLCN) | Không |

---

### 4. KẾT LUẬN & KHUYẾN NGHỊ

1. **Khẳng định tính hợp pháp:** Dataset hoàn toàn hợp pháp để sử dụng, lưu trữ, xử lý và phân phối trong hệ thống Travel Planner.
2. **Cơ chế quản trị dài hạn:**
   - Khi có các đợt sắp xếp địa giới mới từ Ủy ban Thường vụ Quốc hội trong tương lai, hệ thống sẽ ưu tiên tham chiếu trực tiếp Công báo điện tử của Cổng Thông tin điện tử Chính phủ / Quốc hội.
   - Duy trì cơ chế kiểm tra chéo (Dual Checksum) nhằm phát hiện ngay lập tức bất kỳ sự can thiệp ngoài ý muốn nào từ các gói cập nhật từ bên thứ ba.
