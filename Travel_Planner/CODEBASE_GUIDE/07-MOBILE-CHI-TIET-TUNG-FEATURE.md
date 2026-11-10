# 07 — Mobile: feature catalogue và bản đồ file

Ứng dụng chia core (nền tảng), shared (thành phần tái sử dụng), features (nghiệp vụ). Mỗi feature thường có data (repository/model) và presentation (screen/notifier/widget); không phải module nào cũng có đủ cả hai.

| Feature | Trách nhiệm chính |
|---|---|
| auth | đăng nhập, đăng ký, quản lý phiên |
| explore | khám phá, lọc, phân trang itinerary công khai |
| itinerary | chuyến đi, ngày, hoạt động, bản đồ và tuyến |
| location | tìm địa điểm, resolve, reverse-geocode, chọn pin |
| comments | bình luận/reply theo thread |
| profile | hồ sơ cá nhân và công khai |
| social | cộng đồng và đánh giá |
| collection | bộ sưu tập |
| saved_itineraries | itinerary đã lưu |
| notifications | màn hình thông báo |

Luồng sửa màn hình thường đi screen → notifier → repository → model → API. Phụ lục 07A–07F giải thích nghiệp vụ và các ranh giới quan trọng.

## Danh mục file Dart

### auth/data/auth_repository.dart
- Types: class AuthRepository {

### auth/data/auth_storage.dart
- Types: class AuthStorage {

### auth/presentation/auth_notifier.dart
- Types: enum AuthStatus { initial, loading, authenticated, unauthenticated, error }; class AuthNotifier extends ChangeNotifier {

### auth/presentation/screens/login_screen.dart
- Types: class LoginScreen extends StatefulWidget {; class _LoginScreenState extends State<LoginScreen> {

### auth/presentation/screens/register_screen.dart
- Types: class RegisterScreen extends StatefulWidget {; class _RegisterScreenState extends State<RegisterScreen> {

### collection/data/collection_repository.dart
- Types: class CollectionRepository {

### collection/presentation/collection_notifier.dart
- Types: class SubListState {; class CollectionNotifier extends ChangeNotifier {

### collection/presentation/screens/collection_screen.dart
- Types: class CollectionScreen extends StatefulWidget {; class _CollectionScreenState extends State<CollectionScreen>

### comments/data/comments_repository.dart
- Types: class CommentsRepository {

### comments/data/models/itinerary_comment.dart
- Types: class ItineraryComment {

### comments/presentation/comments_notifier.dart
- Types: class CommentsNotifier extends ChangeNotifier {

### comments/presentation/widgets/itinerary_comments_section.dart
- Types: class ItineraryCommentsSection extends StatefulWidget {; class _ItineraryCommentsSectionState extends State<ItineraryCommentsSection> {; class _CommentTile extends StatelessWidget {; class _CommentThread extends StatefulWidget {; class _CommentThreadState extends State<_CommentThread> {; class ActivityCommentsSection extends StatelessWidget {

### explore/data/explore_repository.dart
- Types: class ExploreRepository {

### explore/data/models/creator_summary.dart
- Types: class CreatorSummary {

### explore/data/models/itinerary_summary.dart
- Types: class ItinerarySummary {

### explore/data/models/page_result.dart
- Types: class PageResult<T> {

### explore/presentation/explore_notifier.dart
- Types: enum ExploreStatus { initial, loading, success, error }; enum SectionStatus { initial, loading, success, error }; enum HomeSectionType { featured, recommended, topRated, popular, recent }; class SectionState<T> {; class ExploreFilter {; class ExploreNotifier extends ChangeNotifier {

### explore/presentation/screens/explore_screen.dart
- Types: class ExploreScreen extends StatefulWidget {; class _ExploreScreenState extends State<ExploreScreen> {

### explore/presentation/widgets/compact_itinerary_card.dart
- Types: enum CompactCardHighlight { rating, popular, theme }; class CompactItineraryCard extends StatelessWidget {

### explore/presentation/widgets/featured_itinerary_card.dart
- Types: class FeaturedItineraryCard extends StatelessWidget {

### explore/presentation/widgets/filter_bottom_sheet.dart
- Types: class FilterBottomSheet extends StatefulWidget {; class _FilterBottomSheetState extends State<FilterBottomSheet> {

### explore/presentation/widgets/itinerary_card.dart
- Types: class ItineraryCard extends StatelessWidget {; class _FavoriteHeartButton extends StatefulWidget {; class _FavoriteHeartButtonState extends State<_FavoriteHeartButton> {; class _CustomCardActionButton extends StatefulWidget {; class _CustomCardActionButtonState extends State<_CustomCardActionButton> {

### explore/presentation/widgets/search_bar_pill.dart
- Types: class SearchBarPill extends StatelessWidget {

### explore/presentation/widgets/section_error_view.dart
- Types: class SectionErrorView extends StatelessWidget {

### explore/presentation/widgets/section_header.dart
- Types: class SectionHeader extends StatelessWidget {

### explore/presentation/widgets/section_skeleton_loader.dart
- Types: class SectionSkeletonLoader extends StatefulWidget {; class _SectionSkeletonLoaderState extends State<SectionSkeletonLoader>

### explore/presentation/widgets/theme_category_card.dart
- Types: class ThemeCategoryItem {; class ThemeCategoryCard extends StatelessWidget {

### itinerary/data/itinerary_crud_repository.dart
- Types: class ItineraryCrudRepository {

### itinerary/data/itinerary_repository.dart
- Types: class ItineraryRepository {

### itinerary/data/models/activity_detail.dart
- Types: class ActivityDetail {

### itinerary/data/models/create_activity_request.dart
- Types: class CreateActivityRequest {

### itinerary/data/models/create_day_request.dart
- Types: class CreateDayRequest {

### itinerary/data/models/create_itinerary_request.dart
- Types: class CreateItineraryRequest {

### itinerary/data/models/destination_summary.dart
- Types: class DestinationSummary {

### itinerary/data/models/itinerary_day_detail.dart
- Types: class ItineraryDayDetail {

### itinerary/data/models/itinerary_detail.dart
- Types: class ItineraryDetail {

### itinerary/data/models/reorder_activity_item.dart
- Types: class ReorderActivityItem {

### itinerary/data/models/route_models.dart
- Types: class RouteWaypoint {; class RouteResponse {

### itinerary/data/models/update_activity_request.dart
- Types: class UpdateActivityRequest {

### itinerary/data/models/update_day_request.dart
- Types: class UpdateDayRequest {

### itinerary/data/models/update_itinerary_request.dart
- Types: class UpdateItineraryRequest {

### itinerary/data/route_repository.dart
- Types: class RouteRepository {

### itinerary/presentation/itinerary_detail_notifier.dart
- Types: class ItineraryDetailNotifier extends ChangeNotifier {

### itinerary/presentation/my_itineraries_notifier.dart
- Types: enum MyItinerariesStatus { initial, loading, success, error }; class MyItinerariesNotifier extends ChangeNotifier {

### itinerary/presentation/screens/activity_detail_screen.dart
- Types: class ActivityDetailScreen extends StatelessWidget {

### itinerary/presentation/screens/create_itinerary_screen.dart
- Types: class CreateItineraryScreen extends StatefulWidget {; class _CreateItineraryScreenState extends State<CreateItineraryScreen> {

### itinerary/presentation/screens/edit_itinerary_screen.dart
- Types: class EditItineraryScreen extends StatefulWidget {; class _EditItineraryScreenState extends State<EditItineraryScreen> {

### itinerary/presentation/screens/itinerary_detail_screen.dart
- Types: class ItineraryDetailScreen extends StatefulWidget {; class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {

### itinerary/presentation/screens/itinerary_map_screen.dart
- Types: class ItineraryMapScreen extends StatefulWidget {; class _ItineraryMapScreenState extends State<ItineraryMapScreen> {

### itinerary/presentation/screens/my_itineraries_screen.dart
- Types: class MyItinerariesScreen extends StatefulWidget {; class _MyItinerariesScreenState extends State<MyItinerariesScreen> {

### itinerary/presentation/widgets/activity_form_dialog.dart
- Types: class ActivityFormBottomSheet extends StatefulWidget {; class _ActivityFormBottomSheetState extends State<ActivityFormBottomSheet> {

### itinerary/presentation/widgets/activity_timeline_item.dart
- Types: class ActivityTimelineItem extends StatelessWidget {

### itinerary/presentation/widgets/day_form_dialog.dart
- Types: class DayFormDialog extends StatefulWidget {; class _DayFormDialogState extends State<DayFormDialog> {

### itinerary/presentation/widgets/delete_activity_dialog.dart

### itinerary/presentation/widgets/delete_day_dialog.dart

### itinerary/presentation/widgets/delete_itinerary_dialog.dart

### itinerary/presentation/widgets/itinerary_day_card.dart
- Types: class ItineraryDayCard extends StatefulWidget {; class _ItineraryDayCardState extends State<ItineraryDayCard> {

### itinerary/presentation/widgets/itinerary_location_search_field.dart
- Types: class ItineraryLocationSearchField extends StatefulWidget {; class _ItineraryLocationSearchFieldState

### itinerary/presentation/widgets/itinerary_map_helper.dart
- Types: class MappedActivityStop {; class ItineraryMapHelper {

### itinerary/presentation/widgets/itinerary_map_preview_card.dart
- Types: class ItineraryMapPreviewCard extends StatefulWidget {; class _ItineraryMapPreviewCardState extends State<ItineraryMapPreviewCard> {

### itinerary/presentation/widgets/my_itinerary_card.dart
- Types: class MyItineraryCard extends StatelessWidget {

### itinerary/presentation/widgets/navigation_launcher_helper.dart
- Types: typedef UrlLauncherFn = Future<bool> Function(Uri uri, {LaunchMode mode});; class NavigationLauncherHelper {

### itinerary/presentation/widgets/reorder_activities_dialog.dart
- Types: class _ReorderActivitiesBottomSheet extends StatefulWidget {; class _ReorderActivitiesBottomSheetState

### location/data/location_repository.dart
- Types: class LocationRepository {

### location/data/models/location_search_result.dart
- Types: class LocationSearchResult {

### location/presentation/widgets/location_picker_sheet.dart
- Types: class CustomLocationResult {; class LocationPickerSheet extends StatefulWidget {; class _LocationPickerSheetState extends State<LocationPickerSheet> {

### notifications/presentation/screens/notifications_screen.dart
- Types: class NotificationsScreen extends StatelessWidget {

### profile/data/models/public_profile.dart
- Types: class PublicProfile {

### profile/data/models/public_user_summary.dart
- Types: class PublicUserSummary {

### profile/data/profile_repository.dart
- Types: class ProfileRepository {

### profile/data/public_profile_repository.dart
- Types: class PublicProfileRepository {

### profile/presentation/screens/profile_screen.dart
- Types: class ProfileScreen extends StatefulWidget {; class _ProfileScreenState extends State<ProfileScreen> {

### profile/presentation/screens/public_profile_screen.dart
- Types: class PublicProfileScreen extends StatefulWidget {; class _PublicProfileScreenState extends State<PublicProfileScreen> {

### profile/presentation/screens/public_user_list_screen.dart
- Types: class PublicUserListScreen extends StatefulWidget {; class _PublicUserListScreenState extends State<PublicUserListScreen> {

### saved_itineraries/presentation/screens/saved_itineraries_screen.dart
- Types: class SavedItinerariesScreen extends StatelessWidget {

### social/data/models/social_state_update.dart
- Types: class SocialStateUpdate {

### social/data/social_repository.dart
- Types: class SocialRepository {

### social/presentation/screens/community_screen.dart
- Types: class CommunityScreen extends StatelessWidget {
