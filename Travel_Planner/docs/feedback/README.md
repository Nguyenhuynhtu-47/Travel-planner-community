# Đánh giá và định hướng bản đồ – địa điểm – hoạt động

Ngày đánh giá: **05/11/2026**. Nhánh: **develop**, HEAD: **c1873ad**.

## Đọc từ đâu?

1. [Đánh giá hiện trạng](01-danh-gia-hien-trang-map.md): chức năng đã có, bằng chứng từ mã nguồn, vấn đề và mức ưu tiên.
2. [Destination và Activity](02-mo-hinh-dia-diem-va-hoat-dong.md): giải thích hai nơi lưu tọa độ, lựa chọn kiến trúc và quy tắc dữ liệu.
3. [API miễn phí và ảnh](03-api-mien-phi-va-anh-dia-diem.md): lựa chọn nhà cung cấp, hạn mức, quyền lưu dữ liệu, ảnh Google và nguồn thay thế.
4. [Trải nghiệm đề xuất](04-trai-nghiem-them-dia-diem.md): tìm địa điểm, thêm hoạt động, chọn ảnh, liên kết timeline–map.
5. [Kế hoạch thực hiện](../plan/planupdate-map/README.md): thứ tự triển khai, hợp đồng API, dữ liệu, giao diện và kiểm thử.

## Kết luận chính

Dự án **đã có phần lớn nền móng bản đồ**, gồm hiển thị map, tìm kiếm LocationIQ, ghim vị trí, tuyến đường theo ngày và mở ứng dụng chỉ đường. Không cần viết lại toàn bộ module.

Hai bảng có tọa độ **không đồng nghĩa một hoạt động đang lưu hai tọa độ mâu thuẫn**. Backend hiện áp dụng ba trạng thái loại trừ nhau: địa điểm danh mục, vị trí riêng, không có vị trí. Điểm yếu thực sự là trải nghiệm nhập còn chia đôi, quy tắc nguồn dữ liệu chưa rõ trong API, thiếu ảnh hoạt động và một số tình huống bất đồng bộ có thể chọn sai địa điểm.

Khuyến nghị phiên bản đầu:

- Giữ Destination làm danh mục do quản trị viên quản lý.
- Giữ vị trí riêng của Activity để thêm nhanh kết quả tìm kiếm hoặc ghim tay; không tự đưa địa chỉ riêng của người dùng vào danh mục công khai.
- Một ô “Tìm địa điểm” hợp nhất danh mục và tìm kiếm trực tuyến; hỗ trợ gợi ý tham quan, ăn uống, cà phê, lưu trú.
- Thêm ảnh riêng cho hoạt động, ưu tiên ảnh tải lên và ảnh danh mục; ảnh mở có nguồn rõ ràng là giai đoạn sau.
- Tiếp tục tận dụng LocationIQ trước khi thay nhà cung cấp. Google Places/Photos là phương án khác có điều kiện, không phải mặc định của bản miễn phí.
- Đánh giá lại quyền sử dụng CARTO; không lấy hạn mức cũ trong tài liệu làm bằng chứng còn hiệu lực.

## Phạm vi và giới hạn đánh giá

Đã khảo sát cấu trúc backend Spring Boot, Flutter mobile, Flutter web, entity/DTO/controller/service, các module liên quan, bộ kiểm thử hiện hữu, tài liệu thiết kế và tài liệu dự án. Đọc sâu luồng địa điểm–hoạt động–bản đồ–ảnh; rà soát tài liệu lịch sử và các kế hoạch khác để xác định phụ thuộc.

Đây là **đánh giá tĩnh và kế hoạch**, không phải xác nhận từng dòng của mọi file sinh tự động, toàn bộ lịch sử log hay kiểm toán toàn hệ thống. Chưa chạy ứng dụng, chưa truy cập cơ sở dữ liệu thực, chưa thử API bằng khóa tài khoản của dự án. Không dùng số test pass trong log cũ làm kết quả kiểm thử của phiên này.

Tất cả trường, endpoint, migration và hành vi được ghi “đề xuất” trong bộ tài liệu đều **chưa được triển khai**. Mã nghiệp vụ và schema không thay đổi trong đợt tài liệu này.

Tên “woander” được hiểu là trải nghiệm lập lịch trình kiểu Wanderlog: tìm địa điểm → chọn → thêm vào ngày → xem trên bản đồ. Đây là cách diễn giải ý tưởng của người dùng, không phải khẳng định về kiến trúc nội bộ của ứng dụng đó.
