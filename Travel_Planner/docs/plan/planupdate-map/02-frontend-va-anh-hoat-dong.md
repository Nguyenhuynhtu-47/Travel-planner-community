# Flutter picker và Activity — kế hoạch refactor

## Hiện trạng đã xác minh

Picker là `LocationPickerSheet`: một ô input, map `AppMapView`/CARTO, marker, result list, manual pin, Hủy/Xác nhận. Refactor đã gỡ repository client method nearby và không còn nearby/category chips. Backend nearby route/provider còn legacy nhưng không được picker gọi.

Picker đã bỏ provider toggle, query context và viewport coordinates. Gõ gửi nguyên văn query theo `mode=SUGGEST`; submit keyboard hoặc discoverAction gửi `mode=SEARCH`. Di chuyển map không làm thay đổi search request.

Trước refactor, Activity form nhận `locationContext` từ itinerary detail và chỉ auto-fill title nếu trống. Hiện form không nhận context; nếu title vẫn đúng giá trị đã tự điền từ POI A thì chọn POI B cập nhật title, còn title người dùng sửa tay được giữ nguyên. Manual map tap clear placeId/provider/name POI cũ và giữ tọa độ tap; reverse chỉ bổ sung địa chỉ. DB save nằm trong `ItineraryCrudRepository` và schema hiện tại.

`ItineraryLocationSearchField` là autocomplete cho chuỗi itinerary.location (không phải activity POI). Field vẫn gợi ý text điểm đến nhưng đã bỏ nút đổi provider và gọi cùng unified search API; dữ liệu điểm đến không truyền sang Activity picker.

## Luồng UI đích

1. Mở picker dùng activity tọa độ đã lưu làm camera ban đầu nếu có; nếu không thì vị trí fallback theo thiết kế. Camera không trở thành search parameter.
2. Một ô query nguyên văn. Debounce 400–500 ms/min 2 ký tự gọi `GET /api/locations/search` mode Suggest. Provider không xuất hiện trong UI. Tạo UUID session một lần trong picker.
3. Submit bàn phím hoặc nút search gọi mode Search; TomTom dùng Discover. Nếu Suggest trả discoverAction và người dùng chọn, query cũng được gửi mode Search.
4. Một danh sách response theo thứ tự backend; loading/empty/error/retry rõ ràng; không auto-select. Generation/request ID giữ lại để response cũ không ghi đè.
5. Chọn result có coords: validate finite/range, cập nhật location object nguyên tử, marker và camera. Result TomTom cần Details thì chỉ fetch sau tap chọn; Discover có coords không fetch Details lại.
6. Chạm map tạo MANUAL_PIN ở đúng tọa độ tap, clear POI name/address/id/provider. Reverse-geocode chỉ gợi ý địa chỉ, không thay coordinate; tên cho pin nhập được.
7. Hủy không đổi form. Xác nhận trả `CustomLocationResult` với name/address/coords/placeId/provider hợp lệ.
8. Form Activity: nếu title trống hoặc vẫn đúng giá trị auto-fill lần trước, chọn POI mới cập nhật title. Nếu đã chỉnh khác thì không ghi đè. Manual pin không auto-fill tên POI. Save vẫn qua API activity hiện tại, không phát sinh request provider.

## File Flutter cần sửa

| File | Hiện trạng | Sửa | Giữ/Xóa | Test |
|---|---|---|---|---|
| `frontend/mobile/lib/features/location/presentation/widgets/location_picker_sheet.dart` | Trước đây ghép context, gửi viewport và có source switch | query raw, submit Search; một provider/list do backend điều khiển | giữ debounce, request IDs, map, validation, manual pin, confirm | query exact/no geo params, request stale, marker/manual, details |
| `frontend/mobile/lib/features/location/data/location_repository.dart` | provider/lat/lon parameters, TomTom detail/discover, dead nearby method | unified mode query/session; detail/discover; no picker geo args | remove nearby method nếu repo-wide không có caller; giữ reverse | URL/JSON/Unicode/no geo params |
| `frontend/mobile/lib/features/location/data/models/location_search_result.dart` | DTO chung có nullable provider metadata | giữ model, bảo đảm JSON parse/serialize null coords, type/id/details/session | không tạo model provider trùng | suggest/details/discover mapping |
| `frontend/mobile/lib/features/itinerary/presentation/widgets/activity_form_dialog.dart` | truyền locationContext; auto-fill chỉ khi blank | bỏ context; theo dõi title auto-fill gần nhất; giữ title đã sửa; không auto-fill MANUAL_PIN | giữ create/edit, image upload, destination/custom exclusivity | blank/auto/manual title; create/update roundtrip |
| `frontend/mobile/lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart` | truyền `itinerary.location` vào add/edit Activity dialog | bỏ arguments để itinerary location không tới picker | giữ luồng dialog/reload | regression add/edit activity |
| `frontend/mobile/lib/features/itinerary/presentation/widgets/itinerary_location_search_field.dart` | một text field nhưng có provider toggle riêng | dùng unified search mode, bỏ toggle; giữ autocomplete điểm đến dạng text | không truyền kết quả/coords sang Activity | điểm đến text search |
| `frontend/mobile/lib/core/constants/api_constants.dart` | location search/details/discover/nearby constants | giữ routes thực sự gọi; bỏ nearby nếu dead | không thêm route trùng | constant references |
| `frontend/mobile/lib/features/itinerary/data/models/{create_activity_request,update_activity_request,activity_detail}.dart` và `itinerary_crud_repository.dart` | map fields custom location | chỉ sửa nếu tests tìm lỗi contract | giữ API và fields/schema | create/update/read roundtrip |
| `frontend/mobile/test/location_picker_test.dart` | tests format context và TomTom toggle | thay bằng tests independent itinerary, single field/list, submit mode, no context/bias, race guard/autofill/manual pin | bỏ tests cho logic cố ý xóa | full picker tests |
| `frontend/mobile/test/location_repository_test.dart` | test provider + coordinates + nearby | test unified modes, exact Unicode, session, no lat/lon; xóa nearby test khi client method bỏ | giữ reverse test | repository tests |

## Không thay đổi

- `app_base_map.dart`, `app_map_view.dart`, CARTO tile config, marker builder: chỉ sửa nếu test chứng minh marker callback/camera có lỗi.
- Activity photo upload/Cloudinary; không lấy ảnh từ TomTom/Google.
- Itinerary map/ORS route, Destination catalog CRUD, các form lịch trình ngoài việc bỏ context truyền sang Activity.
- README dự án: người dùng yêu cầu giữ nội dung cấu hình đang test.

## Gỡ code cũ có kiểm soát

- `locationContext` và `formatQueryWithContext` đã bị xóa khỏi show dialog/widget/call-site; test append context cũng đã bỏ.
- Xóa `_searchProvider`, toggle UI, provider-specific source selection khỏi picker và destination search field; provider selection server-side.
- Bỏ truyền viewport vào search/Discover và bỏ callback `onPositionChanged`; vẫn giữ `initialCenter` để hiển thị map theo Activity đã lưu.
- Nearby: method và API constant phía mobile đã xóa sau `rg` xác nhận không có caller. Backend route/provider legacy được giữ để tránh phá consumer API ngoài mobile project.
- Không xóa adapter LocationIQ, reverse-geocode, TomTom Details, Activity custom fields hoặc manual pin.
