# 04. Trải nghiệm đề xuất: tìm địa điểm rồi thêm hoạt động

## 1. Hành trình chính

1. Mở lịch trình → chọn ngày → “Thêm địa điểm”.
2. Màn chọn có một ô “Tìm địa điểm, quán ăn, điểm tham quan…”.
3. Khi chưa gõ: hiển thị khu vực đang tìm, danh mục gợi ý; có “Tham quan”, “Ăn uống”, “Cà phê”, “Lưu trú”, “Tất cả”.
4. Gõ tên → debounce → kết quả gồm tên, địa chỉ, loại, khoảng cách nếu biết tâm tìm, thumbnail nếu có.
5. Chọn kết quả → map focus đúng điểm, hiện thẻ địa điểm và nút “Thêm vào ngày 2”.
6. Tên hoạt động mặc định là tên địa điểm, nhưng được sửa thành “Ăn trưa tại…”; giờ, ghi chú, chi phí và ảnh là tùy chọn.
7. Lưu thành công → xuất hiện đúng thứ tự trong timeline; marker được cập nhật; chỉ tính lại tuyến ngày bị ảnh hưởng.

Vẫn có nút “Hoạt động không có địa điểm” cho nghỉ ngơi hoặc ghi chú, và “Ghim vị trí” cho nơi chưa tìm thấy.

Không tự ghi DB ngay khi chạm một kết quả tìm kiếm. Đó mới là lựa chọn nháp; thao tác “Thêm vào ngày…” mới tạo hoạt động.

## 2. Một giao diện, nhiều nguồn kết quả

Người dùng không cần hiểu bảng Destination. Kết quả nội bộ có thể đánh dấu nhẹ “Địa điểm gợi ý”, nhưng không bắt người dùng chọn dropdown catalog trước rồi mở map thứ hai.

Đề xuất cách xếp hạng:

- Khớp tên chính xác hoặc tiền tố.
- Phù hợp khu vực đang lên kế hoạch.
- Phù hợp loại đang chọn.
- Địa điểm có thông tin được quản trị xác nhận.
- Khoảng cách chỉ là một tín hiệu; không ép địa điểm tên đúng ở xa xuống dưới địa điểm tên gần giống.

Đây là heuristic của sản phẩm, không giả vờ là điểm phổ biến từ Google. Chưa có nguồn rating/giờ mở cửa đáng tin thì không hiển thị các số này. Điểm rating lịch trình của hệ thống không được gắn thành rating địa điểm.

Không lọc cứng chỉ “du lịch”: ga, sân bay, bệnh viện hoặc địa chỉ lưu trú vẫn cần tìm được. Tab “Tất cả” và tìm chính xác phải còn hoạt động.

## 3. Bối cảnh khu vực

Thứ tự ưu tiên khi xác định tâm:

1. Địa điểm hiện đang sửa.
2. Điểm gần nhất đã có trong ngày được chọn.
3. Khu vực chuyến đi đã được người dùng xác định.
4. Vị trí thiết bị khi người dùng chủ động chọn “Gần tôi” và cấp quyền.
5. Tâm mặc định Việt Nam; hiển thị rằng chưa xác định khu vực cụ thể.

Itinerary.location hiện chỉ là chuỗi. Không coi chuỗi “Đà Lạt” đã có tọa độ trung tâm. MVP có thể truyền tâm từ các hoạt động sẵn có; geocode khu vực chỉ khi cần, có cache và được người dùng xác nhận. Không geocode lại mỗi lần mở form.

Khi kéo bản đồ, có nút “Tìm trong khu vực này”; không gọi API theo từng frame chuyển động. Tách trường viewportCenter khỏi selectedPoint: mở map ở Đà Lạt không có nghĩa người dùng đã chọn tâm Đà Lạt làm hoạt động.

## 4. Tìm kiếm và lỗi

| Trạng thái | Hiển thị và hành động |
|---|---|
| Chưa nhập | Gợi ý nội bộ và nhóm loại; chưa gọi search tên |
| Đang gõ | Loading nhỏ; không animation đổi thứ tự liên tục |
| Không có kết quả | “Chưa tìm thấy địa điểm phù hợp”; đổi khu vực, tìm tất cả, ghim |
| Hết quota | “Tìm kiếm trực tuyến tạm hết lượt”; giữ danh mục và lựa chọn hiện tại |
| Thiếu cấu hình | Thông báo dịch vụ chưa sẵn sàng; không giả là không có địa điểm |
| Mất mạng | Giữ dữ liệu form; thử lại có chủ đích |
| Không có tọa độ | Không cho chọn như POI hoàn chỉnh; gợi ý ghim xác nhận |
| Ảnh lỗi | Placeholder giữ nguyên kích thước; không chặn lưu |
| Người dùng đổi ý nhanh | Chỉ phản hồi thuộc truy vấn/lựa chọn mới nhất được cập nhật |

Địa điểm ghim tay giữ tọa độ người dùng chạm. Reverse chỉ giúp gợi ý tên/địa chỉ, không chứng minh đó là đúng cửa vào hoặc cùng POI.

## 5. Ảnh hoạt động

Form có vùng ảnh nhỏ với “Thêm ảnh”, “Đổi ảnh”, “Xóa ảnh”, “Dùng ảnh địa điểm”. Ảnh preview không buộc tải lên ngay khi chọn.

- Upload lỗi vẫn giữ các trường và cho lưu không ảnh.
- Khi đổi địa điểm, ảnh tự động cập nhật theo địa điểm mới.
- Nếu đã chọn ảnh cá nhân, hiển thị để người dùng quyết định giữ hay đổi.
- Timeline hiển thị một thumbnail cho hoạt động, không lặp hai card ảnh chỉ vì nó liên kết catalog.
- Khi xem ảnh nguồn ngoài, có nút xem nguồn/tác giả; không giấu attribution sau nội dung không truy cập được.
- Placeholder thể hiện “chưa có ảnh”; không dùng ảnh thành phố để gây hiểu nhầm đó là ảnh POI.

## 6. Liên kết timeline và bản đồ

Chạm activity trên timeline → focus marker tương ứng. Chạm marker → hiện tóm tắt và nút xem/sửa tùy quyền. Định danh bằng activityId, không bằng tọa độ vì cùng nơi có thể có nhiều hoạt động.

Ngày không có điểm vẫn hiển thị các hoạt động không vị trí. Một điểm chỉ cần marker; từ hai điểm mới có route. Khi xem nhiều ngày, không nối điểm cuối ngày 1 với đầu ngày 2 thành một tuyến liên tục trừ khi có tính năng riêng.

Giãn marker trùng chỉ là hiển thị. Không ghi tọa độ đã giãn vào DB hoặc gửi cho ORS. Thứ tự marker phản ánh timeline, không tự tối ưu tuyến mà đổi lịch của người dùng.

Map cho người xem lịch trình không nhất thiết có quyền chỉnh sửa. Backend tiếp tục kiểm tra owner, visibility và trạng thái nội dung ở mọi thao tác.

## 7. Áp dụng DESIGN.md

Theo DESIGN.md và docs/ai/04-ui-design-system.md: nền trắng, ảnh là nội dung chính, màu nhấn Rausch tiết chế, đường viền nhẹ, dùng token hiện có và font ứng dụng. Không thay toàn bộ theme hoặc thêm thư viện UI chỉ để sửa map.

Mobile ưu tiên màn tìm kiếm rộng, bàn phím không che nút xác nhận; tránh xếp nhiều bottom sheet cùng lúc. Web giữ vai trò quản trị, tận dụng bảng và panel chi tiết; không mở rộng thành trình lập kế hoạch cho người dùng web trong cùng việc này.

Search result đổi trực tiếp, không animation bố cục. Sheet có thể dùng transition Flutter 150–200 ms; tắt khi disableAnimations. Touch target tối thiểu 48 dp, hỗ trợ text scale, tên địa điểm dài và màn 320 px. Attribution của bản đồ phải còn thấy khi mở thẻ hoặc bàn phím.

## 8. Ví dụ nghiệm thu

Người dùng tạo lịch trình Đà Lạt 3 ngày, chọn ngày 2 và tìm “Quảng trường Lâm Viên”. Chọn kết quả → đổi tên hoạt động thành “Chụp ảnh buổi sáng” → thêm ảnh cá nhân → lưu. Timeline có tên hoạt động, tên địa điểm và ảnh; map có marker của đúng activity. Lần mở lại đọc dữ liệu đã lưu, không cần tìm lại địa điểm qua provider.

Nếu quota search đã hết, người dùng vẫn chọn được địa điểm nội bộ hoặc nhập một cặp tọa độ và tên. Không hứa ghim trên nền map mới tải được khi cả kết nối mạng lẫn tile đều không sẵn sàng.
