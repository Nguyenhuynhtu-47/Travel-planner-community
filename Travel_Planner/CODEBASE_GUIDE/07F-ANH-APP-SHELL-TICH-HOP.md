# 07F — Ảnh, app shell và tích hợp chéo

ImagePickerService bọc chọn ảnh; preview hiển thị trước khi gửi; `/api/media/images` nhận multipart và backend Cloudinary service trả URL/media metadata. Ảnh do người dùng tải lên tách biệt POI search, map tile và provider geocoding. Không mặc định dịch vụ map cấp ảnh đại diện địa điểm.

MainNavigationShell có năm tab: Explore, Community, Create itinerary, Collection, My itineraries. Community vẫn mở feed; dot của tab lấy snapshot riêng cho unread accepted/stranger messages và incoming friend requests. Từ feed có entry points tới Inbox thường, Stranger Inbox, Friends/Invites; Friends mở User Search. Các màn hình dùng chung repository và `MessagingRealtimeClient` do app shell sở hữu. Profile mở từ luồng người dùng; itinerary detail nối ngày/activity/map/comments; social posts và chat có screen riêng. Chat REST/WebSocket không được notification empty-state screen thể hiện như hệ thống thông báo.

AppTheme/AppColors/spacing/text styles và shared widgets là nơi tìm thành phần dùng chung trước khi tạo mới. ApiClient tập trung base URL, auth header, parsing/lỗi; mỗi app Mobile/Web vẫn có client riêng và cần đối chiếu API contract độc lập.
