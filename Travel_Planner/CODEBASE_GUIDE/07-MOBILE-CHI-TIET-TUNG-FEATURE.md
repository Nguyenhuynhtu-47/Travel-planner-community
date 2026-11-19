# 07 — Mobile: feature catalogue và bản đồ file

Mobile chia core, shared và features. Luồng thường đi screen/widget → notifier/state → repository → model/API. Danh mục file được kiểm kê ngày 2026-11-16; khai báo được trích bằng pattern đơn giản và có thể không bao gồm hàm/extension hoặc class sinh tự động.

| Feature | Trách nhiệm trong source |
|---|---|
| auth | đăng nhập và session |
| explore / itinerary | khám phá, lịch trình, ngày, activity, map, route |
| location | POI search, reverse, resolve, picker |
| comments / reviews | comment thread và rating |
| collection / saved_itineraries | saved/favorite collections |
| social | community feed/post, follow/profile integration |
| messaging | conversation, REST messages, STOMP realtime, friendship |
| notifications | placeholder empty state; chưa có backend notification API |
| profile | hồ sơ cá nhân/công khai |

## Danh mục file Dart

### core/constants/api_constants.dart
- Khai báo: class ApiConstants

### core/constants/map_constants.dart
- Khai báo: class MapConstants

### core/constants/map_tile_provider_config.dart
- Khai báo: class MapTileProviderConfig

### core/network/api_client.dart
- Khai báo: class ApiClient

### core/network/api_exception.dart
- Khai báo: class ApiException

### core/theme/app_colors.dart
- Khai báo: class AppColors

### core/theme/app_spacing.dart
- Khai báo: không có khai báo class/enum/type nổi bật (xem hàm top-level trong source)

### core/theme/app_text_styles.dart
- Khai báo: không có khai báo class/enum/type nổi bật (xem hàm top-level trong source)

### core/theme/app_theme.dart
- Khai báo: class AppTheme

### features/auth/data/auth_repository.dart
- Khai báo: class AuthRepository

### features/auth/data/auth_storage.dart
- Khai báo: class AuthStorage

### features/auth/presentation/auth_notifier.dart
- Khai báo: enum AuthStatus; class AuthNotifier

### features/auth/presentation/screens/login_screen.dart
- Khai báo: class LoginScreen; class _LoginScreenState

### features/auth/presentation/screens/register_screen.dart
- Khai báo: class RegisterScreen; class _RegisterScreenState

### features/collection/data/collection_repository.dart
- Khai báo: class CollectionRepository

### features/collection/presentation/collection_notifier.dart
- Khai báo: class SubListState; class CollectionNotifier

### features/collection/presentation/screens/collection_screen.dart
- Khai báo: class CollectionScreen; class _CollectionScreenState

### features/comments/data/comments_repository.dart
- Khai báo: class CommentsRepository

### features/comments/data/models/itinerary_comment.dart
- Khai báo: class ItineraryComment

### features/comments/presentation/comments_notifier.dart
- Khai báo: class CommentsNotifier

### features/comments/presentation/widgets/itinerary_comments_section.dart
- Khai báo: class ItineraryCommentsSection; class _ItineraryCommentsSectionState; class _CommentTile; class _CommentThread; class _CommentThreadState; class ActivityCommentsSection

### features/explore/data/explore_repository.dart
- Khai báo: class ExploreRepository

### features/explore/data/models/creator_summary.dart
- Khai báo: class CreatorSummary

### features/explore/data/models/itinerary_summary.dart
- Khai báo: class ItinerarySummary

### features/explore/data/models/page_result.dart
- Khai báo: class PageResult

### features/explore/presentation/explore_notifier.dart
- Khai báo: enum ExploreStatus; enum SectionStatus; enum HomeSectionType; class SectionState; class ExploreFilter; class ExploreNotifier

### features/explore/presentation/screens/explore_screen.dart
- Khai báo: class ExploreScreen; class _ExploreScreenState

### features/explore/presentation/widgets/compact_itinerary_card.dart
- Khai báo: enum CompactCardHighlight; class CompactItineraryCard

### features/explore/presentation/widgets/featured_itinerary_card.dart
- Khai báo: class FeaturedItineraryCard

### features/explore/presentation/widgets/filter_bottom_sheet.dart
- Khai báo: class FilterBottomSheet; class _FilterBottomSheetState

### features/explore/presentation/widgets/itinerary_card.dart
- Khai báo: class ItineraryCard; class _FavoriteHeartButton; class _FavoriteHeartButtonState; class _CustomCardActionButton; class _CustomCardActionButtonState

### features/explore/presentation/widgets/search_bar_pill.dart
- Khai báo: class SearchBarPill

### features/explore/presentation/widgets/section_error_view.dart
- Khai báo: class SectionErrorView

### features/explore/presentation/widgets/section_header.dart
- Khai báo: class SectionHeader

### features/explore/presentation/widgets/section_skeleton_loader.dart
- Khai báo: class SectionSkeletonLoader; class _SectionSkeletonLoaderState

### features/explore/presentation/widgets/theme_category_card.dart
- Khai báo: class ThemeCategoryItem; class ThemeCategoryCard

### features/itinerary/data/helpers/location_activity_mapper.dart
- Khai báo: class LocationActivityMapper

### features/itinerary/data/itinerary_crud_repository.dart
- Khai báo: class ItineraryCrudRepository

### features/itinerary/data/itinerary_repository.dart
- Khai báo: class ItineraryRepository

### features/itinerary/data/models/activity_detail.dart
- Khai báo: class ActivityDetail

### features/itinerary/data/models/create_activity_request.dart
- Khai báo: class CreateActivityRequest

### features/itinerary/data/models/create_day_request.dart
- Khai báo: class CreateDayRequest

### features/itinerary/data/models/create_itinerary_request.dart
- Khai báo: class CreateItineraryRequest

### features/itinerary/data/models/destination_summary.dart
- Khai báo: class DestinationSummary

### features/itinerary/data/models/itinerary_day_detail.dart
- Khai báo: class ItineraryDayDetail

### features/itinerary/data/models/itinerary_detail.dart
- Khai báo: class ItineraryDetail

### features/itinerary/data/models/itinerary_place.dart
- Khai báo: class ItineraryPlace

### features/itinerary/data/models/place_summary.dart
- Khai báo: class PlaceSummary

### features/itinerary/data/models/reorder_activity_item.dart
- Khai báo: class ReorderActivityItem

### features/itinerary/data/models/route_models.dart
- Khai báo: class RouteWaypoint; class RouteResponse

### features/itinerary/data/models/update_activity_request.dart
- Khai báo: class UpdateActivityRequest

### features/itinerary/data/models/update_day_request.dart
- Khai báo: class UpdateDayRequest

### features/itinerary/data/models/update_itinerary_request.dart
- Khai báo: class UpdateItineraryRequest

### features/itinerary/data/route_repository.dart
- Khai báo: class RouteRepository

### features/itinerary/presentation/itinerary_detail_notifier.dart
- Khai báo: class ItineraryDetailNotifier

### features/itinerary/presentation/my_itineraries_notifier.dart
- Khai báo: enum MyItinerariesStatus; class MyItinerariesNotifier

### features/itinerary/presentation/screens/activity_detail_screen.dart
- Khai báo: class ActivityDetailScreen

### features/itinerary/presentation/screens/create_itinerary_screen.dart
- Khai báo: class CreateItineraryScreen; class _CreateItineraryScreenState

### features/itinerary/presentation/screens/edit_itinerary_screen.dart
- Khai báo: class EditItineraryScreen; class _EditItineraryScreenState

### features/itinerary/presentation/screens/itinerary_detail_screen.dart
- Khai báo: class ItineraryDetailScreen; class _ItineraryDetailScreenState; class _KeepAliveTabWrapper; class _KeepAliveTabWrapperState

### features/itinerary/presentation/screens/itinerary_map_screen.dart
- Khai báo: class ItineraryMapScreen; class _ItineraryMapScreenState

### features/itinerary/presentation/screens/my_itineraries_screen.dart
- Khai báo: class MyItinerariesScreen; class _MyItinerariesScreenState

### features/itinerary/presentation/widgets/activity_form_dialog.dart
- Khai báo: class ActivityFormBottomSheet; class _ActivityFormBottomSheetState

### features/itinerary/presentation/widgets/activity_timeline_item.dart
- Khai báo: class ActivityTimelineItem

### features/itinerary/presentation/widgets/add_place_to_itinerary_sheet.dart
- Khai báo: class AddPlaceToItinerarySheet; class _AddPlaceToItinerarySheetState

### features/itinerary/presentation/widgets/day_form_dialog.dart
- Khai báo: class DayFormDialog; class _DayFormDialogState

### features/itinerary/presentation/widgets/day_picker_bottom_sheet.dart
- Khai báo: class DayPickerBottomSheet; class _DayPickerBottomSheetState

### features/itinerary/presentation/widgets/delete_activity_dialog.dart
- Khai báo: không có khai báo class/enum/type nổi bật (xem hàm top-level trong source)

### features/itinerary/presentation/widgets/delete_day_dialog.dart
- Khai báo: không có khai báo class/enum/type nổi bật (xem hàm top-level trong source)

### features/itinerary/presentation/widgets/delete_itinerary_dialog.dart
- Khai báo: không có khai báo class/enum/type nổi bật (xem hàm top-level trong source)

### features/itinerary/presentation/widgets/itinerary_day_card.dart
- Khai báo: class ItineraryDayCard; class _ItineraryDayCardState

### features/itinerary/presentation/widgets/itinerary_location_search_field.dart
- Khai báo: class ItineraryLocationSearchField; class _ItineraryLocationSearchFieldState

### features/itinerary/presentation/widgets/itinerary_map_helper.dart
- Khai báo: class MappedActivityStop; class ItineraryMapHelper

### features/itinerary/presentation/widgets/itinerary_map_preview_card.dart
- Khai báo: class ItineraryMapPreviewCard; class _ItineraryMapPreviewCardState

### features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart
- Khai báo: enum ItineraryPickerMode; class ItineraryPickerBottomSheet; class _ItineraryPickerBottomSheetState

### features/itinerary/presentation/widgets/my_itinerary_card.dart
- Khai báo: class MyItineraryCard

### features/itinerary/presentation/widgets/navigation_launcher_helper.dart
- Khai báo: typedef UrlLauncherFn; class NavigationLauncherHelper

### features/itinerary/presentation/widgets/reorder_activities_dialog.dart
- Khai báo: class _ReorderActivitiesBottomSheet; class _ReorderActivitiesBottomSheetState

### features/itinerary/presentation/widgets/save_place_to_itinerary_sheet.dart
- Khai báo: class SavePlaceToItinerarySheet; class _SavePlaceToItinerarySheetState

### features/location/data/location_repository.dart
- Khai báo: class LocationRepository

### features/location/data/models/location_search_result.dart
- Khai báo: class LocationSearchResult

### features/location/presentation/widgets/location_picker_sheet.dart
- Khai báo: class SimpleTokenAuthNotifier; class CustomLocationResult; class LocationPickerSheet; class _LocationPickerSheetState

### features/messaging/data/messaging_realtime_client.dart
- Khai báo: enum RealtimeStatus; class MessagingRealtimeClient

### features/messaging/data/messaging_repository.dart
- Khai báo: class MessagingRepository; class MessagePage; API message request list/count/accept/decline

### features/messaging/data/models/chat_event.dart
- Khai báo: class ChatEvent

### features/messaging/data/models/chat_message.dart
- Khai báo: class ChatMessage

### features/messaging/data/models/conversation_summary.dart
- Khai báo: class ConversationSummary

### features/messaging/data/models/friend_request.dart
- Khai báo: class FriendRequest

### features/messaging/data/models/messaging_settings.dart
- Khai báo: enum InboundMessagePolicy; class MessagingSettings

### features/messaging/presentation/screens/chat_screen.dart
- Khai báo: class ChatScreen; class _ChatScreenState

### features/messaging/presentation/screens/community_screen.dart
- Khai báo: class CommunityScreen; class _CommunityScreenState; inbox/friends/friend requests/Stranger Inbox

### features/messaging/presentation/screens/messaging_settings_screen.dart
- Khai báo: class MessagingSettingsScreen; class _MessagingSettingsScreenState

### features/notifications/presentation/screens/notifications_screen.dart
- Khai báo: class NotificationsScreen

### features/profile/data/models/public_profile.dart
- Khai báo: class PublicProfile

### features/profile/data/models/public_user_summary.dart
- Khai báo: class PublicUserSummary

### features/profile/data/profile_repository.dart
- Khai báo: class ProfileRepository

### features/profile/data/public_profile_repository.dart
- Khai báo: class PublicProfileRepository

### features/profile/presentation/screens/personal_info_screen.dart
- Khai báo: class PersonalInfoScreen; class _PersonalInfoScreenState

### features/profile/presentation/screens/profile_screen.dart
- Khai báo: class ProfileScreen; class _ProfileScreenState

### features/profile/presentation/screens/public_profile_screen.dart
- Khai báo: class PublicProfileScreen; class _PublicProfileScreenState

### features/profile/presentation/screens/public_user_list_screen.dart
- Khai báo: class PublicUserListScreen; class _PublicUserListScreenState

### features/saved_itineraries/presentation/screens/saved_itineraries_screen.dart
- Khai báo: class SavedItinerariesScreen

### features/social/data/community_post_repository.dart
- Khai báo: class CommunityPostRepository

### features/social/data/models/post_comment_model.dart
- Khai báo: class PostCommentModel

### features/social/data/models/post_model.dart
- Khai báo: class PostAuthorModel; class PostItineraryModel; class PostModel

### features/social/data/models/social_state_update.dart
- Khai báo: class SocialStateUpdate

### features/social/data/social_repository.dart
- Khai báo: class SocialRepository

### features/social/presentation/community_feed_notifier.dart
- Khai báo: class CommunityFeedNotifier

### features/social/presentation/screens/community_feed_screen.dart
- Khai báo: class CommunityFeedScreen; class _CommunityFeedScreenState

### features/social/presentation/screens/community_screen.dart
- Khai báo: class CommunityScreen

### features/social/presentation/screens/create_post_screen.dart
- Khai báo: class CreatePostScreen; class _CreatePostScreenState; class _UploadedMediaItem; class _ItinerarySelectionSheet; class _ItinerarySelectionSheetState

### features/social/presentation/widgets/post_card_widget.dart
- Khai báo: class PostCardWidget

### features/social/presentation/widgets/post_comments_sheet.dart
- Khai báo: class PostCommentsSheet; class _PostCommentsSheetState

### features/social/presentation/widgets/report_post_dialog.dart
- Khai báo: class ReportPostDialog; class _ReportPostDialogState

### main.dart
- Khai báo: class MyApp; class _MyAppState; class PlaceholderHomeScreen

### shared/navigation/main_navigation_shell.dart
- Khai báo: class MainNavigationShell; class _MainNavigationShellState

### shared/services/image_picker_service.dart
- Khai báo: abstract class ImagePickerService; class DeviceImagePickerService

### shared/widgets/app_base_map.dart
- Khai báo: class AppBaseMap

### shared/widgets/app_empty_state.dart
- Khai báo: class AppEmptyState

### shared/widgets/app_error_state.dart
- Khai báo: class AppErrorState

### shared/widgets/app_map_view.dart
- Khai báo: class AppMapView

### shared/widgets/app_page_title.dart
- Khai báo: class AppPageTitle

### shared/widgets/app_primary_button.dart
- Khai báo: class AppPrimaryButton

### shared/widgets/app_text_field.dart
- Khai báo: class AppTextField; class _AppTextFieldState

### shared/widgets/current_user_avatar_button.dart
- Khai báo: class CurrentUserAvatarButton

### shared/widgets/image_upload_preview.dart
- Khai báo: class ImageUploadPreview

### shared/widgets/map_api_key_missing_banner.dart
- Khai báo: class MapApiKeyMissingBanner; class _MapApiKeyMissingBannerState

### shared/widgets/map_marker_builder.dart
- Khai báo: class MapMarkerBuilder; class _StopMarkerWidget; class _PinTeardropPainter
