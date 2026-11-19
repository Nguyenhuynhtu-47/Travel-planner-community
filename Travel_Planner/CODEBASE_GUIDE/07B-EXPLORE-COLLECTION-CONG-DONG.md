# 07B — Khám phá, bộ sưu tập và cộng đồng

ExploreScreen/ExploreNotifier/ExploreRepository tải itinerary công khai có filter và pagination. Backend `/api/itineraries` áp dụng visibility, filter và pagination; đây là ranh giới dữ liệu, không chỉ điều kiện UI. Recommendation dùng `/api/itineraries/recommendations`.

Collection và saved itinerary là các quan hệ lưu; favorite và rating là quan hệ riêng. Mobile có flow community posts qua `/api/community/feed`, `/feed/following`, `/posts`, likes/comments/report; backend CommunityPostController và admin moderation xử lý dữ liệu tương ứng. Post comments là domain riêng với itinerary/activity comment threads. Follow là quan hệ xã hội, không đồng nghĩa friendship.

Khi sửa, giữ pagination ở repository/state, đồng bộ UI sau mutation, và xác minh backend không trả itinerary PRIVATE/HIDDEN/DELETED. Test tham khảo: `explore_test`, `explore_sections_test`, `filter_bottom_sheet_test`, `collection_notifier_test`, các social widget tests và backend community tests trong test inventory.
