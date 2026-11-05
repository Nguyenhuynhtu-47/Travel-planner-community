# Kế hoạch cập nhật map, tìm địa điểm và ảnh hoạt động

Ngày lập: **05/11/2026**. Cơ sở mã: develop tại c1873ad.
Trạng thái: **Đang triển khai MVP trong nhánh làm việc**. M1, tìm kiếm LocationIQ giới hạn Việt Nam với ngữ cảnh tỉnh/thành lịch trình, nearby theo nhóm POI và ảnh hoạt động đã được nối vào code; kiểm thử mục tiêu đã qua. Nearby mặc định tắt bằng cấu hình. Search hợp nhất catalog/online, migration media asset có ownership, ảnh mở kèm license và các hạng mục map–timeline nâng cao vẫn nằm ngoài phần đã hoàn tất.

## 1. Mục tiêu và tài liệu

Cho phép người dùng tìm địa điểm theo cách quen thuộc của ứng dụng bản đồ, chọn vào ngày trong lịch trình, thêm ảnh riêng và xem hoạt động nhất quán trên timeline/map; ưu tiên dịch vụ miễn phí có giới hạn và không tự phát sinh phí.

- [Đánh giá hiện trạng](../../feedback/01-danh-gia-hien-trang-map.md).
- [Quyết định mô hình](../../feedback/02-mo-hinh-dia-diem-va-hoat-dong.md).
- [Nhà cung cấp và nguồn ảnh](../../feedback/03-api-mien-phi-va-anh-dia-diem.md).
- [Backend, API và dữ liệu](01-backend-api-va-du-lieu.md).
- [Frontend và ảnh](02-frontend-va-anh-hoat-dong.md).
- [Triển khai, kiểm thử và nghiệm thu](03-lo-trinh-kiem-thu-nghiem-thu.md).

Kế hoạch này bổ sung và cập nhật hướng phát triển sau [plan map ban đầu](../01-map-integration-audit-and-plan.md). Các mô tả “chưa có map/search/tọa độ Activity” ở đầu plan cũ là lịch sử, không phải hiện trạng để triển khai lại.

## 2. Quyết định khuyến nghị

| Quyết định | Lý do |
|---|---|
| Giữ flutter_map và luồng route hiện có | Đã có renderer, marker, tuyến theo ngày, fallback |
| Ưu tiên LocationIQ cho tìm tên | Đã tích hợp, cải thiện UX và chất lượng trước khi thay |
| Nearby LocationIQ có cờ cấu hình; benchmark nhà cung cấp khác | Gợi ý nhóm POI khác với autocomplete tên; chất lượng/quota tài khoản cần xác minh |
| Giữ catalog Destination và vị trí riêng Activity trong MVP | Tránh migration lớn; không làm lộ pin riêng vào danh mục chung |
| Giữ search hiện có và thêm API nearby dạng List | Tương thích contract cũ; endpoint hợp nhất có envelope vẫn là phần sau |
| Ảnh upload + catalog là phạm vi bắt buộc | Đáp ứng ảnh hoạt động mà không phụ thuộc Google Photos |
| Ảnh Commons tự động là phần mở rộng | Cần khớp địa điểm, license và attribution |
| Google Places/Photos không bật mặc định | Không phù hợp yêu cầu không phát sinh phí và map nền hiện tại |
| Xác minh CARTO trước phát hành | Điều kiện tài khoản phải được kiểm tra lại |

### Phạm vi tìm kiếm của MVP

- Mọi truy vấn LocationIQ Autocomplete tiếp tục bị giới hạn ở Việt Nam bằng `countrycodes=vn` tại backend.
- Khi thêm hoặc sửa hoạt động trong một lịch trình, mobile truyền `itinerary.location` (tỉnh/thành của chuyến đi) làm ngữ cảnh: người dùng gõ `Hồ Hoàn Kiếm` trong lịch trình Hà Nội thì API nhận `Hồ Hoàn Kiếm, Hà Nội`.
- Ngữ cảnh tỉnh/thành giúp xếp hạng kết quả gần đúng địa điểm chuyến đi; đây là bias bằng văn bản, không phải ranh giới địa lý cứng. Nếu cần loại tuyệt đối kết quả ngoài tỉnh, phải có tọa độ/vùng hành chính chuẩn cho điểm đến và lọc kết quả theo vùng.
- Search vẫn debounce 400 ms, giới hạn tối đa 20 kết quả và dùng API proxy backend; không gọi LocationIQ trực tiếp từ app. Hạn mức free được kiểm soát bởi provider và rate limiter hiện có; vượt hạn mức phải hiện trạng thái lỗi, không tự đổi sang dịch vụ trả phí.

Chưa tạo places/activity_locations trong MVP. Đó là lựa chọn dài hạn có phân tích trong feedback, không phải một hạng mục bắt buộc chạy ngầm cùng nâng cấp UI.

## 3. Chia giai đoạn

| Giai đoạn | Kết quả cụ thể | Phụ thuộc |
|---|---|---|
| M0 — Kiểm chứng | Baseline test, mẫu truy vấn Việt Nam, quyền provider, ngân sách | Không |
| M1 — Sửa tính đúng | Không stale selection, không tọa độ mặc định 0, nguồn vị trí nhất quán | M0 |
| M2 — Search theo vùng | Chỉ Việt Nam + `itinerary.location` làm ngữ cảnh tỉnh/thành; catalog + online và category vẫn là phần mở rộng | M1 |
| M3 — Ảnh hoạt động | Upload/chọn/xóa ảnh, response, timeline, migration bổ sung | M1; tích hợp với M2 |
| M4 — Luồng map–timeline | Thêm từ map vào ngày, focus, reload và route đúng | M2 + M3 |
| M5 — Hoàn thiện | Kiểm thử hồi quy, cấu hình free, cập nhật contract và vận hành | M4 |
| M6 — Tùy chọn | Ảnh mở tự động, thư viện POI/chuẩn hóa bảng | Sau khi có nhu cầu và bằng chứng |

Đây là thứ tự công việc, không phải cam kết số ngày hoàn thành. Dừng thay provider nếu benchmark không chứng minh cải thiện; vẫn có thể hoàn thành M1, ảnh upload và UI bằng nền hiện có.

## 4. Ranh giới phạm vi

Bao gồm đánh giá và kế hoạch cho backend, mobile và tương thích web admin. Không bao gồm xây lại social, thông báo, thanh toán, đặt chỗ, tối ưu lộ trình tự động, gallery nhiều ảnh, chỉ đường turn-by-turn trong app hoặc offline bản đồ toàn phần.

Không tạo tài khoản/billing, không đăng ký dịch vụ, không thay key và không chạy migration trong phiên lập tài liệu. Những việc này là bước triển khai sau có cấu hình cụ thể.

## 5. Điều kiện hoàn thành MVP

- Tìm theo tên và theo nhóm POI trong khu vực đã chọn; luôn có “Tất cả” và ghim tay.
- Không trộn catalog với custom; giữ hoạt động không vị trí.
- Tên, ID và tọa độ thuộc cùng một lựa chọn sau các thao tác nhanh.
- Có ảnh riêng hoạt động; fallback catalog/placeholder; không ảnh vẫn lưu.
- Map, timeline và route nhất quán sau thêm/sửa/xóa/reorder.
- Hết quota không làm mất dữ liệu; không tự chuyển sang dịch vụ trả phí.
- Client cũ và web admin còn đọc/ghi theo hợp đồng cũ đã xác định.
- Bộ kiểm thử ở M5 được chạy và ghi kết quả thực; lỗi còn lại được nêu rõ.
