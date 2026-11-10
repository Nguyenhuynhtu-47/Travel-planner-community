# 07B — Khám phá, bộ sưu tập và cộng đồng

ExploreScreen trình bày itinerary công khai; ExploreNotifier giữ trạng thái tải/trang/lọc; ExploreRepository gọi API; model summary/page_result diễn giải response; widgets dựng thẻ, filter và loading/error states. Backend filter và visibility là ranh giới bảo mật, không chỉ là điều kiện giao diện.

Collection là nhóm dữ liệu riêng; saved itinerary là quan hệ lưu của người dùng. Favorite và rating cũng là các quan hệ khác nhau. Rating có API/service riêng cho tạo, cập nhật, xóa và summary. Không gộp saved/favorite/rating thành một khái niệm.

Khi thêm filter, giữ pagination ở tầng data/state, cập nhật trạng thái sau mutation và đảm bảo itinerary PRIVATE/HIDDEN/DELETED không rò vào explore. Test liên quan: explore_test, explore_sections_test, filter_bottom_sheet_test, collection_notifier_test, social_ui_sync_test, rating_ui_layout_test.
