# 11 — Mobile tests

Mobile test set hiện có 43 file. Test widget/unit không thay thế kiểm thử integration trên thiết bị và backend đang chạy. Kiểm kê: 2026-11-17.

## Cách chạy
```text
cd frontend/mobile; flutter test
```

Lần chạy toàn bộ trước thay đổi navigation/search ngày 2026-11-17: 427 tests passed, 26 failed (lỗi widget itinerary/activity/rating ngoài messaging). Sau bổ sung, `flutter test test/features/messaging` PASS 7/7; messaging + Community feed/badge PASS tổng 20/20. Analyzer trên năm file route/model mới PASS; phân tích rộng hơn các file đã sửa trước đó còn 17 lint mức info. Chưa test runtime bằng hai thiết bị.

## File inventory
- activity_detail_screen_test.dart
- activity_location_model_test.dart
- animation_enhancements_test.dart
- auth_401_test.dart
- bottom_navigation_test.dart
- create_itinerary_test.dart
- explore_sections_test.dart
- explore_test.dart
- features/collection/collection_notifier_test.dart
- features/collection/collection_screen_test.dart
- features/comments/comment_thread_widget_test.dart
- features/comments/comments_notifier_test.dart
- features/itinerary/add_place_to_itinerary_sheet_test.dart
- features/itinerary/day_picker_test.dart
- features/itinerary/itinerary_picker_test.dart
- features/itinerary/location_activity_mapper_test.dart
- features/itinerary/my_itineraries_overview_test.dart
- features/itinerary/phase_6a_e2e_integration_test.dart
- features/messaging/messaging_models_test.dart (bao gồm parse user search result)
- features/messaging/chat_screen_test.dart
- features/profile/public_profile_screen_test.dart
- features/profile/user_handle_test.dart
- features/social/community_feed_test.dart
- features/social/rating_ui_layout_test.dart
- features/social/social_ui_sync_test.dart
- filter_bottom_sheet_test.dart
- image_upload_test.dart
- itinerary_activity_management_test.dart
- itinerary_clone_test.dart
- itinerary_day_management_test.dart
- itinerary_detail_test.dart
- itinerary_edit_delete_test.dart
- itinerary_map_test.dart
- itinerary_route_test.dart
- itinerary_saved_places_test.dart
- location_picker_test.dart
- location_repository_test.dart
- map_api_key_test.dart
- map_smoke_test.dart
- map_view_test.dart
- my_itineraries_test.dart
- username_validation_test.dart
- widget_test.dart
