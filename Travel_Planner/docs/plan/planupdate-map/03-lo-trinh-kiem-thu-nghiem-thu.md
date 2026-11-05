# 03. Lộ trình, kiểm thử và tiêu chí nghiệm thu

## 1. M0 — Baseline và kiểm chứng nhà cung cấp

- Ghi branch/HEAD, trạng thái Git, cấu hình provider theo tên biến; không sao chép secret.
- Chạy baseline backend/mobile/web ở môi trường phù hợp trước thay đổi mã.
- Kiểm tra quyền CARTO/grant; nếu không phù hợp, thử Geoapify tiles qua config hiện có.
- Kiểm tra LocationIQ autocomplete/nearby và quota tài khoản; kiểm tra ORS ở dashboard. Không dùng hạn mức trong plan cũ như kết quả đã xác minh hôm nay.
- Bộ benchmark đề xuất 30 truy vấn: 10 danh thắng, 10 quán ăn/cà phê, 5 lưu trú, 5 ga/sân bay/địa chỉ ít phổ biến; phân bố Hà Nội, Đà Nẵng, Đà Lạt, TP.HCM.
- Mỗi nhóm có tên có dấu/không dấu, tên một phần, tên trùng ở nhiều tỉnh và truy vấn không tồn tại.
- Lập bảng query, context, top 5, đúng POI/địa chỉ/tọa độ, latency, request count. Không đưa dữ liệu cá nhân thật vào benchmark.
- Mục tiêu đề xuất: ít nhất 24/30 truy vấn chuẩn có kết quả đúng trong top 5. Đây là tiêu chí dự án, chưa có số đo thực. Các biến thể đo riêng để không làm sai mẫu số.
- Chỉ thay provider khi có bằng chứng cải thiện và điều khoản/quota phù hợp.

Đầu ra: ghi nhận kết quả thực, lựa chọn provider và budget. Những mục chưa có quyền tài khoản được ghi chưa kiểm chứng, không giả định pass.

## 2. M1 — Sửa lỗi nền

Thực hiện theo test trước/sau cho race, tọa độ thiếu, cặp tọa độ thống nhất và hidden catalog. Giữ contract cũ.

File backend trọng tâm: LocationIqGeocodingProvider, LocationServiceImpl, ItineraryServiceImpl, RouteServiceImpl. File Flutter trọng tâm: location_picker_sheet.dart, activity_detail.dart.

Nghiệm thu: không có selection ghép nhầm metadata, không sinh điểm (0,0) từ dữ liệu thiếu; ba trạng thái vị trí vẫn được bảo toàn.

## 3. M2 — Tìm kiếm hợp nhất

Thêm envelope suggestions và discover; nguồn catalog + online, category/context, cache key đầy đủ, limiter tổng và trạng thái quota. Cập nhật UI chọn điểm theo một ô search.

Nghiệm thu: lỗi online không che catalog; bộ lọc “Tất cả” vẫn tìm các điểm ngoài du lịch; không gọi API cho mỗi frame kéo map; không tự insert kết quả tìm kiếm vào Destination.

## 4. M3 — Ảnh hoạt động

Migration bổ sung và asset tracking; mở rộng upload tương thích; UI chọn/xóa/dùng ảnh địa điểm; timeline đọc ảnh thống nhất.

Nghiệm thu: ảnh tồn tại sau tải lại; client cũ update không xóa ảnh; người dùng không gắn asset riêng của người khác; upload thất bại không mất form. Không thêm Google Photos vào milestone này.

## 5. M4 — Tích hợp map–timeline

Luồng thêm từ map vào đúng ngày, chọn activity, refresh theo dayId, route invalidate khi cần. Không thay thứ tự do tự tối ưu.

Nghiệm thu: sửa tọa độ/thứ tự làm marker và route thay đổi đúng; sửa ảnh không gọi lại route không cần thiết; điểm trùng vẫn mở đúng activity.

## 6. Ma trận kiểm thử backend

| Nhóm | Ca bắt buộc |
|---|---|
| Parser | Tọa độ thiếu, chuỗi lỗi, out-of-range; (0,0) hợp lệ; ID không ổn định không dùng định danh |
| Location | Catalog/custom/none; từ chối trộn; latitude/longitude thiếu một vế |
| Chuyển nguồn | Catalog → provider → pin → none; không giữ metadata cũ |
| Destination ẩn | Cấm gắn mới; giữ liên kết cũ khi chỉ sửa giờ; xử lý đổi sang ID ẩn khác |
| Search | Query ngắn/dài, limit, category sai, context thiếu cặp |
| Cache | Phân biệt provider/category/vùng/ngôn ngữ; hit không gọi upstream; TTL và lỗi không cache như empty |
| Quota | Tổng nhiều user/instance, restart, cache miss trùng, 429 Retry-After, không fallback trả phí |
| Partial result | Catalog còn khi online timeout/quota/disabled |
| Quyền | Guest ghi activity bị từ chối; non-owner; day không thuộc itinerary; private route |
| Ảnh | Upload sai loại/quá cỡ; asset không tồn tại/khác owner; absent/null/NONE/AUTO |
| Tương thích | Client cũ gửi PUT không trường ảnh giữ ảnh; response cũ/new parse được |
| Route | 0/1/n điểm, đổi mode/thứ tự/tọa độ; fallback không ETA giả; cache không rò domain data |
| Migration | Dữ liệu cũ đọc được, FK/default đúng, rollback flag không mất dữ liệu |

Tận dụng ActivityLocationTest, LocationServiceTest, RouteServiceTest, DestinationControllerTest, AdminDestinationControllerTest, CloudinaryImageUploadServiceTest. Thêm provider contract tests bằng fixture, không gọi dịch vụ thật trong CI thông thường.

## 7. Ma trận kiểm thử Flutter

| Ca | Kết quả cần đạt |
|---|---|
| A đang search, nhập B nhưng timer B chưa chạy | A không được thay danh sách mới |
| A đang search, xóa còn 0–1 ký tự | A không làm kết quả cũ hiện lại |
| Reverse A đang chờ, chọn POI B | A không đổi tên/ID/tọa độ B |
| Chọn kết quả thiếu tọa độ sau khi đã chọn A | Không dùng tọa độ A cho tên mới |
| Kéo map rồi chưa chọn | Camera center không bị coi là điểm đã xác nhận |
| Chọn điểm rồi hủy picker | Form cũ không đổi |
| Thêm từ map khi xem tất cả ngày | Phải chọn ngày đích, lưu đúng dayId |
| Hai activity cùng tọa độ | Chọn được từng activity; dữ liệu gốc không bị giãn |
| Đổi ngày/mode liên tục | Kết quả cũ không ghi đè; loading kết thúc đúng |
| Chọn/xóa ảnh và upload lỗi | Form được giữ, serializer absent/null đúng |
| Điểm không ảnh và ảnh 404 | Placeholder đúng kích thước; vẫn lưu được |
| 320 px + bàn phím + text scale | Không overflow/che CTA hoặc attribution |
| Reduced motion | Không animation gây chờ/loop ngoài loading |
| Web admin | CRUD destination, hidden state, map và attribution không hồi quy |

Dùng fake repository/Completer để kiểm soát thứ tự phản hồi. Các test có spinner dùng pump có thời lượng thay vì pumpAndSettle vô hạn.

## 8. Lệnh kiểm tra khi triển khai

Từ backend:

~~~powershell
.\mvnw.cmd test-compile
.\mvnw.cmd test
~~~

Từ frontend/mobile và frontend/web tương ứng:

~~~powershell
flutter analyze
flutter test
~~~

Kiểm tra format các file Dart thực sự thay đổi bằng dart format --output=none --set-exit-if-changed. Build mục tiêu khi có SDK và cấu hình phù hợp; kiểm tra thiết bị thật cho picker, bàn phím và image picker. Không chạy upload/search thật ngoài quota được chủ động dành cho smoke test.

**Các lệnh trên là checklist tương lai, chưa được chạy trong phiên viết tài liệu.** Các test pass được ghi ở development log trước đây là lịch sử, không phải chứng nhận mới.

## 9. Kịch bản nghiệm thu đầu-cuối

1. Tạo chuyến đi, thêm ngày; tìm POI có dấu tiếng Việt.
2. Chọn POI → tên hoạt động tự gợi ý → sửa tên → thêm ảnh → lưu.
3. Đóng/mở lại lịch trình: tên, vị trí và ảnh không mất; không cần search lại.
4. Chạm activity → marker đúng; chạm marker → activity đúng.
5. Đổi địa điểm → route ngày đó được cập nhật; ảnh tự động không còn gắn POI cũ.
6. Thêm hoạt động không vị trí; nó vẫn ở timeline nhưng không thành marker giả.
7. Tắt search/giả lập 429: catalog, ghim/nhập tọa độ và lưu hoạt động còn hoạt động khi backend khả dụng.
8. Tắt route: thấy đường thẳng ước lượng đúng nhãn.
9. Tắt tile/mất mạng: không mất form; không hứa chức năng chưa có như lưu offline lên server.
10. Đăng nhập tài khoản khác: không sửa được lịch trình/asset riêng.
11. Kiểm tra mobile cũ và web admin với backend mới.
12. Kiểm tra chỉ có provider đã chọn được gọi; không có billing/overage tự kích hoạt.

## 10. Phát hành và theo dõi

Deploy schema bổ sung → backend tương thích → mobile theo flag → theo dõi lỗi/quota → mở dần. Rollback flag nếu sai vị trí/ảnh hoặc quota bất thường; giữ dữ liệu để xử lý.

Cập nhật docs/ai/03-api-contract.md khi API thật được triển khai, sửa ghi chú trạng thái ở kiến trúc/status khi xác minh, và append development log trong cùng đợt. Không ghi toàn bộ MVP “hoàn thành” khi mới có UI hoặc tài liệu.

## 11. Kết quả thực của đợt lập tài liệu

- Đã kiểm tra Git: develop, HEAD c1873ad; working tree ban đầu sạch.
- Đã đọc mã và tìm các luồng liên quan bằng PowerShell/rg.
- Đã đối chiếu tài liệu công khai của provider; chưa kiểm tra tài khoản và khóa dự án.
- Chưa chạy Maven/Flutter test hoặc build vì thay đổi chỉ là Markdown.
- Kiểm tra cuối đợt: tính tồn tại của file, link nội bộ, encoding và diff; kết quả thực được ghi ở development log.
