# 07C — Lịch trình, activity, địa điểm và bản đồ

Itinerary có ngày; mỗi ngày có activities. Activity vừa lưu thông tin lịch trình vừa giữ snapshot vị trí (tên, địa chỉ, tọa độ, provider/place id, ảnh) và có thể tham chiếu `Place` nội bộ qua `canonicalPlaceId`. Backend hiện không có Destination entity/API độc lập. `Place` là catalog chuẩn; `ItineraryPlace` lưu Place theo từng lịch trình. Chọn POI external hoặc ghim map chỉ lưu snapshot activity, không tự tạo Place catalog.

## Luồng tạo/sửa activity
`ActivityFormDialog` → `LocationPickerSheet`/saved Place → `LocationActivityMapper` và `CreateActivityRequest`/`UpdateActivityRequest` → `ItineraryCrudRepository` → `/api/itineraries/{id}/days/{dayId}/activities` → `ItineraryController` → `ItineraryServiceImpl.applyLocation` → Activity + optional Place relation → `ActivityResponse` → `ActivityDetail`. `ActivityResponse.commentCount` là số bình luận trạng thái ACTIVE gắn với hoạt động; response danh sách ngày/lịch trình tính số lượng bằng một truy vấn nhóm. Request mới gửi canonicalPlaceId hoặc tọa độ cùng metadata; backend giữ tương thích `destinationId` bằng cách diễn giải số đó như Place ID. Không gửi đồng thời canonical catalog ID và custom coordinates. Tên/địa chỉ custom cần tọa độ; lat/lon phải đi theo cặp.

## Tìm/chọn Place và lưu theo itinerary
`LocationPickerSheet` search dùng `LocationRepository` gọi `/api/locations/search`, có debounce và loại response cũ; chọn provider result hoặc pin, có thể reverse geocode. Khi muốn gắn catalog nội bộ, client gọi `/api/places/resolve` để lấy canonical Place ID. Quản lý địa điểm đã lưu gọi `/api/itineraries/{id}/places` (add/list/all/delete). Đây là saved-place relation theo itinerary, khác Activity snapshot và global Place catalog.

Mobile repository còn method legacy `getDestinations()` và model `DestinationSummary`; không có call site hiện tại và backend không còn `/api/destinations`. Đây là phần dead/stale contract cần dọn khi thay đổi code; không mô tả như chức năng đang chạy.

## Map/provider separation
`flutter_map`/`AppMapView`/`ItineraryMapScreen` render tile và activity markers. CARTO là nền tile. POI search/geocoding gọi LocationController và provider đã cấu hình (TomTom, LocationIQ, HERE tùy code/config); TomTom details là endpoint riêng. RouteRepository gọi backend route service/provider. `NavigationLauncherHelper` mở ứng dụng chỉ đường. Upload người dùng đi qua `/api/media/images` và Cloudinary. Không lấy ảnh Google từ CARTO hay suy ra ảnh provider POI tự động được trả về.

Search theo địa danh/tỉnh phụ thuộc query + target context, ranking/geographic filter và provider response; không bảo đảm mọi kết quả luôn cùng tỉnh nếu không có target filter phù hợp. Kiểm tra `LocationService`, `QueryUnderstandingService`, `GeographicFilterService`, config và test.

## Hiện trạng khớp backend/mobile
Các luồng location search, activity snapshot, canonical Place resolve/saved places, itinerary CRUD và route đều có implementation ở hai phía. Điểm stale rõ là API Destination; các test/callers có thể còn legacy naming. Hợp đồng activity được chuyển tiếp bằng field legacy, nhưng Place ID phải là canonical ID nếu dùng `destinationId` compatibility.

Test tham khảo: `location_picker_test`, `location_repository_test`, `activity_location_model_test`, `itinerary_activity_management_test`, `itinerary_map_test`, `itinerary_route_test`, `itinerary_saved_places_test`; backend `LocationServiceTest`, `ActivityLocationTest`, `RouteServiceTest` và các tests Place/migration.
