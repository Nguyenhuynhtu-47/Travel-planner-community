# Kế hoạch refactor luồng tìm kiếm địa điểm

Ngày rà soát: 06/11/2026. Phạm vi: Flutter Mobile, Spring Boot, LocationIQ, TomTom Places Search v3, CARTO và dữ liệu Activity hiện có.

## Quyết định và trạng thái

Kế hoạch này thay thế các mô tả triển khai cũ trong thư mục. Refactor code đã thực hiện: hoạt động không còn truyền `itinerary.location` vào picker; query không bị ghép vùng và camera map không đi vào request tìm kiếm. Picker và ô điểm đến dùng một luồng search, không còn chọn nguồn bằng nút. Gõ gọi Suggest; submit gọi Discover qua cùng endpoint.

Thiết kế đích có một ô search, một danh sách, một backend search API và cùng map CARTO. Provider do backend chọn theo cấu hình: TomTom khi `app.map.tomtom.enabled` và key hợp lệ; nếu TomTom tắt thì LocationIQ. Mỗi response chỉ dùng một nguồn, không gộp hoặc đổi thứ tự kết quả TomTom. Flutter không chọn provider, không gửi điểm đến lịch trình, tọa độ camera, viewport, bounds, radius hay bias. Query TomTom giữ nguyên chữ người dùng và chỉ lọc quốc gia Việt Nam.

**Ràng buộc điều khoản:** TomTom Acceptable Use Policy đang công bố cấm thay đổi thứ tự kết quả tìm kiếm hoặc gộp chúng với dịch vụ tìm kiếm khác. Vì vậy không triển khai danh sách trộn LocationIQ + TomTom nếu chưa có ngoại lệ bằng văn bản trong thỏa thuận tài khoản. TomTom Search API dùng như nguồn chính khi được bật; LocationIQ giữ nguyên và được dùng khi TomTom tắt. Nếu người dùng muốn trộn hai nguồn trong cùng một danh sách, đó là hạng mục bị chặn chờ xác nhận từ TomTom. Xem [AUP](https://www.tomtom.com/en-gb/legal/acceptable-use-policy/).

Điều khoản công khai đã xác nhận LocationIQ cho phép lưu response data lâu dài và giới hạn cache request/response free đến 48 giờ; điều khoản TomTom theo tài khoản hiện chưa xác minh quyền lưu/share tên, địa chỉ, tọa độ và ID trong MySQL. Giữ schema hiện tại; không mở rộng persistence TomTom cho phát hành trước khi xác nhận quyền. Khi chưa xác minh, người dùng vẫn có thể ghim thủ công và tự nhập dữ liệu của mình. Xem [LocationIQ Terms](https://api.locationiq.com/tos) và [TomTom account terms](https://www.tomtom.com/en-gb/legal/third-party-product-terms/).

README dự án được giữ nguyên theo yêu cầu ở đề bài; không ghi key hoặc sửa lệnh cấu hình trong README.

## Hiện trạng dữ liệu và lưu trữ

- `itineraries.location` là chuỗi mô tả điểm đến; entity hiện không có tọa độ điểm đến.
- `activities.destination_id` liên kết tới catalog `destinations`; custom POI/ghim lưu ở các cột hiện có: `custom_location_name`, `custom_address`, `latitude`, `longitude`, `place_id`, `location_provider`.
- `activities.name` là tiêu đề hoạt động độc lập với tên địa điểm. `image_url` là ảnh user upload/catalog; không lấy ảnh từ TomTom/Google trong luồng này.
- DTO tạo/sửa/đọc Activity đã chuyển các trường location; `applyLocation` bảo đảm catalog và custom location loại trừ nhau, validate cặp tọa độ và không tạo Destination mới. Không cần migration.
- Không tìm thấy service/API sao chép lịch trình trong backend; `original_itinerary_id` chỉ được dùng như metadata/seeder, nên không thêm logic copy vào phạm vi.

## Request flow hiện tại

```text
Flutter ô search
  ├─ gõ sau debounce → GET /api/locations/search?query=<nguyên văn>&mode=SUGGEST&sessionId=...
  ├─ submit bàn phím/nút tìm → GET /api/locations/search?query=<nguyên văn>&mode=SEARCH&sessionId=...
  ├─ chọn Suggest thiếu tọa độ → GET /api/locations/providers/tomtom/details?type=...&id=...&sessionId=...
  └─ chọn discoverAction → GET /api/locations/search?query=<nguyên văn>&mode=SEARCH&sessionId=...
       ↓
Backend chọn duy nhất một provider từ cấu hình:
  TomTom enabled + key → Suggest hoặc Discover; không chèn origin/geometry/proximity
  TomTom disabled       → LocationIQ, không nhận tọa độ từ picker
       ↓
DTO chuẩn hóa giữ nguyên thứ tự/provider, Flutter kiểm tra tọa độ
       ↓
Marker CARTO; xác nhận trả location về form Activity; không ghi DB khi gõ/tìm
       ↓
Lưu qua API Activity hiện tại và MySQL theo cổng điều khoản ở trên
```

## TomTom request parity

- Suggest dùng POST `/maps/orbis/places/suggest`, Discover dùng POST `/maps/orbis/places/discover`; Details dùng GET `/maps/orbis/places/details/{type}/{id}`.
- Headers: `Accept: application/json`, `Accept-Language: vi-VN`, `TomTom-Api-Version: 3`, `TomTom-Api-Key` chỉ phía backend, `Content-Type: application/json`, `Attributes` giới hạn field.
- Body Suggest/Discover: query chính xác sau trim khoảng trắng ngoài, `maxResults` tối đa 10, `filters.countryCodesIso2: ["VN"]`. Không gửi `origin`, `preferences.geometry`, `filters.geometry`, tỉnh/thành phố, POI category hay radius mặc định.
- Session UUID v4/v7 được khởi tạo một lần mỗi picker, dùng xuyên suốt Suggest → Discover/Details, không lưu vào Activity.
- Suggest không bảo đảm tọa độ. Chỉ gọi Details khi người dùng chọn item cần resolve; Discover đã có tọa độ thì không gọi Details lại. Chuyển `[longitude, latitude]` thành `latitude/longitude` đúng thứ tự.
- Giữ nguyên thứ tự response TomTom, không xếp hạng, dedupe hoặc ghép LocationIQ. Không log key/raw response.

## Các phase

1. **Plan:** hoàn tất rà soát và sửa bốn file trong thư mục này trước mọi thay đổi source.
2. **Backend:** thống nhất mode Suggest/Search trên route hiện có; provider do server chọn; bỏ lat/lon khỏi search activity; giữ Details/Discover có validate; kiểm thử raw request, mapping, lỗi và config.
3. **Flutter:** bỏ `locationContext`, provider toggle, viewport params và nearby/search-category code khỏi picker; thêm submit Discover; giữ search generation guard; chỉ một danh sách; tự điền tiêu đề có theo dõi giá trị đã tự điền.
4. **Activity:** giữ nguyên API/schema/catalog-vs-custom; kiểm thử create/update/read, manual pin, ảnh upload và không gọi provider khi save/reopen.
5. **Verification:** test backend/mobile, đối chiếu request `Hồ Hoàn Kiếm` khi itinerary là Đà Lạt, rà references trước khi xóa code; ghi rõ hạng mục bị chặn về điều khoản.

## Tiêu chí nghiệm thu

- Itinerary Đà Lạt + activity query `Hồ Hoàn Kiếm` gửi đúng nguyên văn; không gửi Đà Lạt, tọa độ, origin, bounds hoặc bias.
- Search gõ và Search submit dùng Suggest/Discover tương ứng, đều giới hạn VN; response TomTom không bị thay thứ tự hoặc trộn nguồn.
- Flutter có một ô, một list, map CARTO, marker, Hủy, Xác nhận; không có provider toggle hoặc category chips.
- Response cũ không đè query mới; không tự chọn kết quả đầu; Details chỉ chạy khi cần.
- Chọn POI điền tiêu đề nếu trống/đang còn là giá trị tự động trước đó; sửa tay thì không ghi đè. Manual pin xóa provider ID/name cũ.
- Không ghi DB khi search. Activity dùng schema hiện có; TomTom persistence giữ sau cổng điều khoản.
- Không thay README; LocationIQ/reverse, lịch trình, ảnh upload, CARTO và ORS route không hồi quy.

## Tài liệu con

- [Backend API và dữ liệu](01-backend-api-va-du-lieu.md)
- [Flutter picker và form hoạt động](02-frontend-va-anh-hoat-dong.md)
- [Lộ trình, kiểm thử và nghiệm thu](03-lo-trinh-kiem-thu-nghiem-thu.md)
