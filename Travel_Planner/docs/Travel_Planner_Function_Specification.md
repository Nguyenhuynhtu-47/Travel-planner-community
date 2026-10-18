# Travel Planner — Đặc tả chức năng dự án

> Bản tổng hợp các chức năng đã trao đổi. Những chi tiết chưa được chốt được đánh dấu **Cần xác nhận**; không nên xem chúng là chức năng đã triển khai.

## 1. Tổng quan

Travel Planner là nền tảng cộng đồng cho phép người dùng tạo, chia sẻ, khám phá, đánh giá, lưu và cá nhân hóa lịch trình du lịch do cộng đồng đóng góp.

### Mục tiêu
- Lập kế hoạch chuyến đi theo ngày, địa điểm, thời gian và hoạt động.
- Chia sẻ lịch trình và kinh nghiệm du lịch.
- Tìm kiếm, lọc, sắp xếp lịch trình công khai.
- Lưu, sao chép và cá nhân hóa lịch trình tham khảo.
- Đánh giá, bình luận và kiểm duyệt nội dung cộng đồng.

### Công nghệ
- Mobile: Flutter.
- Web: Flutter Web, dự kiến ưu tiên giao diện quản trị.
- Backend: Spring Boot cung cấp API dùng chung.
- Database: MySQL.
- Frontend gọi API của backend; không truy cập trực tiếp cơ sở dữ liệu.

Cấu trúc đã được trao đổi ở mức định hướng:

```text
Travel_Planner/
├── backend/
├── frontend/
│   ├── mobile/
│   └── web/            # Ứng dụng Flutter Web (ưu tiên giao diện quản trị)
└── docs/
```

Tên thư mục thực tế trong repository là `frontend/web/`.

## 2. Tác nhân và quyền hạn

### Guest — Khách chưa đăng nhập
- Xem lịch trình công khai.
- Tìm kiếm, lọc và sắp xếp lịch trình.
- Xem chi tiết lịch trình, địa điểm và nội dung cộng đồng công khai.
- Đăng ký, đăng nhập.
- Không được thực hiện các thao tác yêu cầu tài khoản như tạo lịch trình, lưu, đánh giá hoặc bình luận.

### User — Người dùng đã đăng nhập
- Quản lý hồ sơ và quyền riêng tư.
- Tạo, xem, chỉnh sửa và xóa lịch trình của mình.
- Quản lý ngày, điểm đến, hoạt động và thông tin chuyến đi.
- Khám phá và xem chi tiết lịch trình công khai.
- Lưu/yêu thích lịch trình.
- Sao chép, tái sử dụng và cá nhân hóa lịch trình.
- Đánh giá, bình luận và tương tác cộng đồng theo quy định.
- Theo dõi người dùng khác nếu chức năng được triển khai.
- Xem lịch trình đã tạo, đã lưu và đã tái sử dụng.
- Nhận thông báo nếu hệ thống hỗ trợ.

### Admin — Quản trị viên
- Xem dashboard và thống kê.
- Quản lý người dùng.
- Quản lý lịch trình.
- Quản lý địa điểm.
- Quản lý đánh giá và bình luận.
- Kiểm duyệt nội dung và xử lý vi phạm.
- Khóa hoặc giới hạn tài khoản theo chính sách.
- Soạn, xem trước và gửi thông báo.

## 3. Tài khoản và xác thực

### Đăng ký
- Nhập thông tin tạo tài khoản.
- Kiểm tra trường bắt buộc, định dạng và dữ liệu trùng.
- Hiển thị kết quả thành công hoặc lỗi.

### Đăng nhập
- Nhập thông tin xác thực.
- Backend xác thực tài khoản.
- Kiểm tra trạng thái tài khoản và quyền truy cập.
- Chỉ cho phép truy cập chức năng riêng tư khi đã xác thực.

### Đăng xuất và phân quyền
- Kết thúc phiên đăng nhập và xóa thông tin xác thực cục bộ theo cơ chế sử dụng.
- Backend kiểm tra quyền và quyền sở hữu trước thao tác cập nhật/xóa.
- API quản trị chỉ dành cho Admin; không chỉ dựa vào việc ẩn nút ở frontend.

**Cần xác nhận:** phương thức đăng nhập, xác minh email, khôi phục mật khẩu, token/session và cơ chế làm mới phiên.

## 4. Hồ sơ và quyền riêng tư

- Xem và cập nhật hồ sơ cá nhân.
- Các trường có thể chỉnh sửa trong phiên bản hiện tại: họ và tên, URL ảnh đại diện, số điện thoại, địa chỉ và giới thiệu.
- Tên đăng nhập, email, vai trò, trạng thái tài khoản và ngày tham gia được hiển thị theo dữ liệu tài khoản; màn hình hồ sơ không cho chỉnh sửa các trường này.
- Cấu hình hồ sơ hoặc lịch trình ở chế độ công khai/riêng tư theo phạm vi sản phẩm.
- Chỉ hiển thị dữ liệu riêng tư cho chủ sở hữu và đối tượng được phép.
- Có thể xem danh sách lịch trình đã tạo, đã lưu và đã tái sử dụng.

**Cần xác nhận:** quyền riêng tư áp dụng cho hồ sơ, từng lịch trình hay cả hai; quy tắc hiển thị với người theo dõi.

## 5. Quản lý lịch trình

### Tạo lịch trình
Thông tin dự kiến:
- Tên và mô tả.
- Điểm đến/khu vực.
- Số ngày.
- Ngân sách dự kiến.
- Chủ đề/phong cách chuyến đi.
- Trạng thái công khai/riêng tư.
- Danh sách ngày, địa điểm và hoạt động.

### Quản lý ngày
- Thêm, sửa và xóa ngày.
- Sắp xếp thứ tự ngày.
- Hiển thị hoạt động thuộc đúng ngày.
- Xử lý dữ liệu hoạt động khi ngày bị xóa hoặc thay đổi.

### Quản lý địa điểm và hoạt động
- Thêm, sửa, xóa địa điểm/hoạt động.
- Sắp xếp thứ tự hoạt động.
- Có thể lưu thời gian dự kiến, ghi chú và chi phí nếu mô hình dữ liệu hỗ trợ.
- Hiển thị vị trí trên bản đồ khi có dữ liệu tọa độ.

### Chỉnh sửa và xóa
- Chủ sở hữu được chỉnh sửa hoặc xóa lịch trình của mình.
- Kiểm tra quyền sở hữu ở backend.
- Xác nhận trước hành động có thể gây mất dữ liệu.
- Xử lý các dữ liệu liên quan như ngày, hoạt động, đánh giá, bình luận và lịch sử lưu/tái sử dụng theo chính sách.

**Cần xác nhận:** các trường bắt buộc, ngày bắt đầu/kết thúc, ảnh bìa, giờ hoạt động, xóa mềm/xóa cứng và cách xử lý nội dung liên quan.

### Xem chi tiết
Có thể hiển thị tên, mô tả, tác giả, điểm đến, số ngày, ngân sách, chủ đề, lịch trình từng ngày, địa điểm, bản đồ, đánh giá và bình luận. Các hành động phải phù hợp với trạng thái đăng nhập, quyền sở hữu và quyền riêng tư.

## 6. Khám phá, tìm kiếm, lọc và sắp xếp

### Khám phá
- Hiển thị các lịch trình công khai mà người dùng có quyền xem.
- Có trạng thái loading, lỗi và không có dữ liệu.
- Cho phép mở trang chi tiết.

### Tìm kiếm
- Tìm theo tên lịch trình, địa điểm/khu vực, chủ đề hoặc mô tả nếu dữ liệu hỗ trợ.
- **Cần xác nhận:** trường tìm kiếm chính thức và cách xử lý dấu tiếng Việt.

### Lọc
Các tiêu chí đã được đề cập:
- Địa điểm.
- Ngân sách.
- Số ngày.
- Chủ đề.
- Điểm đánh giá nếu có dữ liệu.

Cho phép kết hợp nhiều điều kiện và xóa bộ lọc đang áp dụng.

### Sắp xếp và nhóm nổi bật
- Sắp xếp theo mức độ phổ biến hoặc điểm đánh giá cao.
- Có thể có nhóm lịch trình nổi bật, phổ biến và được đánh giá cao.
- Không hiển thị lịch trình riêng tư hoặc nội dung đã bị ẩn/gỡ.

**Cần xác nhận:** công thức tính phổ biến, quy tắc xếp hạng và cách chọn nội dung nổi bật.

## 7. Lưu, yêu thích và tái sử dụng

### Lưu/yêu thích
- Người dùng đăng nhập có thể lưu hoặc bỏ lưu lịch trình.
- Xem danh sách lịch trình đã lưu.
- Ngăn tạo bản ghi lưu trùng.
- Xử lý khi lịch trình nguồn bị xóa hoặc chuyển riêng tư.

### Sao chép/tái sử dụng
- Chọn lịch trình công khai làm nguồn tham khảo.
- Tạo bản lịch trình riêng thuộc quyền sở hữu của người dùng nếu nghiệp vụ áp dụng cơ chế sao chép.
- Cá nhân hóa ngày, địa điểm, hoạt động, ngân sách và chủ đề.
- Không cho phép chỉnh sửa trực tiếp lịch trình gốc của người khác.
- Có thể ghi nhận lịch sử tái sử dụng.

**Cần xác nhận:** bản sao độc lập hay liên kết nguồn; trường dữ liệu lịch sử cần lưu; điều kiện đánh giá/bình luận sau khi tái sử dụng.

## 8. Bản đồ và địa điểm

- Hiển thị các địa điểm trên bản đồ nếu có dữ liệu vị trí.
- Kết hợp danh sách địa điểm và bản đồ.
- Hiển thị thông tin địa điểm như tên, địa chỉ, mô tả và vị trí nếu dữ liệu có sẵn.
- Xử lý trường hợp bản đồ không tải được.
- Admin có thể xem, thêm, cập nhật hoặc xử lý địa điểm theo quyền.
- Kiểm tra các lịch trình đang tham chiếu khi xóa/ẩn địa điểm.

**Cần xác nhận:** nhà cung cấp bản đồ, nguồn dữ liệu địa điểm, API key, chi phí và giới hạn sử dụng.

## 9. Đánh giá và bình luận

### Đánh giá
- Người dùng đủ điều kiện có thể đánh giá lịch trình.
- Hiển thị điểm trung bình và số lượng đánh giá nếu có.
- Kiểm tra giá trị đầu vào và cập nhật kết quả sau khi thay đổi.

### Bình luận
- Người dùng đủ điều kiện có thể bình luận về lịch trình.
- Hiển thị nội dung, tác giả và thời gian.
- Có thể cho sửa/xóa bình luận của chính người dùng nếu nghiệp vụ quy định.

### Kiểm duyệt
- Admin xem và xử lý đánh giá/bình luận vi phạm.
- Nội dung bị ẩn/gỡ không tiếp tục xuất hiện ở khu vực công khai.

**Cần xác nhận:** thang điểm, quyền sửa/xóa, báo cáo nội dung và điều kiện được đánh giá/bình luận. Trước đây có đề cập điều kiện người dùng phải sao chép và sử dụng lịch trình trước khi đánh giá/bình luận; cần chốt quy tắc này trước triển khai.

## 10. Cộng đồng và theo dõi

- Xem hồ sơ công khai và lịch trình công khai của người dùng khác.
- Theo dõi/bỏ theo dõi người dùng nếu tính năng được triển khai.
- Có thể hiển thị danh sách người theo dõi/đang theo dõi theo cài đặt quyền riêng tư.
- Ngăn người dùng tự theo dõi chính mình hoặc tạo quan hệ trùng.
- Các tương tác phải tôn trọng quyền riêng tư và trạng thái kiểm duyệt.

**Cần xác nhận:** bảng tin hoạt động, thông báo người theo dõi mới và chia sẻ liên kết ngoài có thuộc phạm vi phiên bản hiện tại không.

## 11. Thông báo

### Admin gửi thông báo
- Soạn nội dung.
- Chọn nhóm người nhận.
- Xem trước.
- Xác nhận gửi.
- Hiển thị kết quả gửi và lỗi nếu có.

### Người dùng nhận thông báo
Có thể liên quan đến hoạt động tài khoản, tương tác cộng đồng, thông báo Admin và các sự kiện nghiệp vụ khác.

**Cần xác nhận:** thông báo trong ứng dụng, push notification, email hay kết hợp; danh sách sự kiện; trạng thái đã đọc/chưa đọc; lịch sử gửi.

## 12. Quản trị hệ thống

### Tổng quan
- Hiển thị số liệu tổng quan người dùng, lịch trình và hoạt động nội dung.
- Biểu đồ phải dùng dữ liệu thật từ backend.
- Có lối tắt đến các khu vực quản trị.

### Quản lý người dùng
- Xem, tìm kiếm người dùng.
- Xem thông tin tài khoản phục vụ quản trị.
- Khóa, mở khóa hoặc giới hạn tài khoản theo quyền và chính sách.
- Lưu lý do/trạng thái xử lý nếu hệ thống hỗ trợ.

### Quản lý lịch trình
- Xem, tìm kiếm và lọc lịch trình.
- Xem chi tiết nội dung.
- Ẩn/gỡ nội dung vi phạm theo chính sách.
- Không chỉnh sửa nội dung người dùng ngoài quy trình quản trị đã thống nhất.

### Quản lý địa điểm
- Xem, thêm, cập nhật và xử lý địa điểm.
- Kiểm tra dữ liệu và liên kết đến lịch trình.

### Quản lý đánh giá/bình luận
- Xem và kiểm tra nội dung.
- Xử lý nội dung bị báo cáo hoặc vi phạm.
- Lưu trạng thái xử lý nếu hỗ trợ.

### Kiểm duyệt và xử lý vi phạm
- Xem danh sách nội dung cần xem xét.
- Phân loại theo trạng thái.
- Chấp thuận, ẩn hoặc gỡ theo quy trình.
- Xử lý vi phạm và khóa/giới hạn tài khoản khi có căn cứ.

### Thông báo quản trị
- Soạn thông báo, chọn người nhận, xem trước và xác nhận gửi.

**Cần xác nhận:** luồng báo cáo, cấp độ vi phạm, thời hạn khóa, khiếu nại và nhật ký kiểm duyệt.

## 13. Danh sách màn hình dự kiến

### Mobile — người dùng
1. Đăng nhập.
2. Đăng ký.
3. Khám phá lịch trình.
4. Tìm kiếm và lọc.
5. Chi tiết lịch trình.
6. Bản đồ/chi tiết địa điểm.
7. Tạo lịch trình.
8. Chỉnh sửa lịch trình.
9. Quản lý ngày và hoạt động.
10. Lịch trình của tôi.
11. Lịch trình đã lưu/yêu thích.
12. Lịch trình đã tái sử dụng.
13. Đánh giá và bình luận.
14. Hồ sơ cá nhân.
15. Chỉnh sửa hồ sơ.
16. Cài đặt quyền riêng tư.
17. Hồ sơ công khai người dùng khác.
18. Người theo dõi/đang theo dõi nếu triển khai.
19. Thông báo nếu triển khai.

### Web — quản trị
1. Đăng nhập quản trị.
2. Tổng quan.
3. Quản lý người dùng.
4. Chi tiết/trạng thái tài khoản.
5. Quản lý lịch trình.
6. Chi tiết và xử lý lịch trình.
7. Quản lý địa điểm.
8. Quản lý đánh giá.
9. Quản lý bình luận.
10. Kiểm duyệt nội dung.
11. Xử lý vi phạm.
12. Soạn thông báo.
13. Chọn người nhận, xem trước và xác nhận gửi.
14. Hồ sơ cá nhân và chỉnh sửa thông tin tài khoản.

Đây là danh sách dự kiến, không khẳng định tất cả màn hình đã được lập trình.

## 14. Quy tắc UI/UX

- Ưu tiên giao diện sạch, nền sáng, dễ đọc và ít màu.
- Phân cấp nội dung rõ ràng.
- Không lạm dụng card, bo góc lớn, gradient, bóng đổ hoặc icon trang trí.
- Dùng thống nhất typography, màu, spacing, button, input và thông báo.
- Tái sử dụng theme/component; tránh tạo component trùng lặp.
- Mobile ưu tiên thao tác cảm ứng và màn hình nhỏ.
- Web tận dụng không gian rộng; giao diện quản trị cần dễ tra cứu.
- Hai nền tảng dùng chung ngôn ngữ thiết kế nhưng không cần bố cục giống hệt.
- Màn hình gọi API cần xử lý loading, success, error, empty, không có kết quả, không có quyền và phiên hết hạn nếu có.
- Xác nhận trước hành động có thể làm mất dữ liệu.

## 15. Yêu cầu kỹ thuật và chất lượng

- Frontend gọi API qua lớp dịch vụ phù hợp.
- Backend chịu trách nhiệm xác thực, phân quyền, kiểm tra dữ liệu và nghiệp vụ.
- Không để lộ bí mật hoặc thông tin xác thực trong mã nguồn.
- Xử lý lỗi API và dữ liệu thiếu an toàn.
- Không làm hỏng chức năng hiện có khi chỉnh UI.
- Chạy formatter, analyzer, build và test phù hợp sau thay đổi.
- Không báo kiểm tra thành công nếu chưa chạy thực tế.
- Thống kê, điểm đánh giá và độ phổ biến phải có định nghĩa rõ ràng, không tạo số liệu giả.

## 16. Những nội dung cần chốt

1. Web chỉ dành cho Admin hay có cả giao diện người dùng?
2. Phương thức đăng nhập và khôi phục mật khẩu.
3. Quyền riêng tư áp dụng cho hồ sơ, lịch trình hay cả hai.
4. Các trường chính thức của lịch trình, ngày, địa điểm và hoạt động.
5. Thang điểm và điều kiện đánh giá/bình luận.
6. Cách tính lịch trình nổi bật/phổ biến/được đánh giá cao.
7. Nhà cung cấp bản đồ và nguồn dữ liệu địa điểm.
8. Cơ chế tái sử dụng lịch trình và lịch sử cần lưu.
9. Kênh thông báo và các sự kiện kích hoạt.
10. Quy trình báo cáo, kiểm duyệt, khóa tài khoản và khiếu nại.
11. Theo dõi, bảng tin và chia sẻ ngoài có thuộc phạm vi hiện tại không.
12. Danh sách cần phân trang/tìm kiếm nâng cao.

## 17. Cách sử dụng với AI coding agent

1. Yêu cầu Agent đọc tài liệu này và kiểm tra repository thực tế.
2. Phân loại chức năng thành: đã có, còn thiếu, chưa xác định.
3. Chỉ triển khai chức năng được giao.
4. Không tự suy diễn mục “Cần xác nhận” thành yêu cầu đã chốt.
5. Không đổi API, schema database hoặc nghiệp vụ ngoài phạm vi khi chưa có kế hoạch.
6. Cập nhật tài liệu nếu hành vi thực tế thay đổi.

---

**Trạng thái:** Đặc tả tổng hợp ở mức dự án. Cần đối chiếu với repository, use case, mô hình dữ liệu và yêu cầu cuối cùng của nhóm/giảng viên trước khi xem là đặc tả đã chốt.
