# 07C — Itinerary, activity, địa điểm và bản đồ

Itinerary là chuyến đi; có nhiều day; mỗi day chứa activities theo thời gian/thứ tự. Activity lưu thông tin lịch trình và có thể giữ tọa độ/metadata địa điểm. Destination là danh mục điểm đến riêng; activity không bắt buộc tham chiếu entity destination. Chi tiết quan hệ xem 05-DATABASE-VA-DU-LIEU.md.

Tạo/sửa đi qua create/detail/edit screens, notifier và repository. Form dialogs quản lý day/activity; reorder và delete có widget riêng. Khi chọn địa điểm, ItineraryLocationSearchField mở LocationPickerSheet. Picker debounce truy vấn, bỏ kết quả cũ bằng request ID, dùng session ID cho suggestion, cho phép chọn kết quả hoặc đặt pin thủ công, xác nhận tọa độ hữu hạn và trong biên hợp lệ.

Mobile LocationRepository gọi unified search, chi tiết suggestion và reverse-geocode. Backend LocationController gọi LocationService; implementation phối hợp parser ý định, provider, geographic filtering/ranking và cache. LocationIQ/HERE/TomTom là các geocoding/search provider; route service dùng provider routing riêng như OpenRouteService. Cấu hình runtime quyết định provider. Không nên mặc định mọi truy vấn tự giới hạn đúng tỉnh thành; cần xác minh parser/query và test.

Map tile chỉ là nền bản đồ; POI search, geocoding, routing và ảnh địa điểm là dịch vụ riêng. AppBaseMap/AppMapView hiển thị tile; marker builder hiển thị activity; ItineraryMapScreen tổng hợp điểm; RouteRepository lấy tuyến; NavigationLauncherHelper mở ứng dụng chỉ đường. Ảnh người dùng upload qua ImageUploadController/CloudinaryImageUploadService; không suy ra rằng provider geocoding cấp ảnh Google.

Test tham khảo: location_picker_test, location_repository_test, activity_location_model_test, itinerary_activity_management_test, itinerary_map_test, itinerary_route_test, map_view_test; backend LocationServiceTest, TomTomPlacesProviderTest, RouteServiceTest.
