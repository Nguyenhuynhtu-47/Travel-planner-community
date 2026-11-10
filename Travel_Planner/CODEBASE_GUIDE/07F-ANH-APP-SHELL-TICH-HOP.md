# 07F — Ảnh, app shell và tích hợp chéo

ImagePickerService bọc chọn ảnh; ImageUploadPreview cho xem trước; backend ImageUploadController gọi CloudinaryImageUploadService và trả secure URL. Đây là ảnh người dùng upload, tách biệt ảnh POI từ map provider.

MainNavigationShell nối các màn hình chính. AppTheme/AppColors/AppSpacing/AppTextStyles là token thiết kế; shared widgets gồm map, marker, input/button, avatar, empty/error state. Hãy tìm trong shared trước khi tạo widget trùng.

Các hành trình liên feature thường là explore → itinerary detail → day/activity/map/comments; creator/avatar mở profile; saved/collection tạo thêm lối vào itinerary. ApiClient tập trung base URL, token và lỗi HTTP. 401 cần đồng bộ session và trạng thái UI.
