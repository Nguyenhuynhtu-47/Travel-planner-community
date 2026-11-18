# 04 — Backend: danh mục file và cách lần theo

Request điển hình: Controller → service interface/implementation → repository → entity. DTO định nghĩa hợp đồng HTTP; security/config điều khiển xác thực và startup. Source tree được kiểm kê ngày 2026-11-16. Mỗi mục ghi class/interface/enum/record được trích từ khai báo; Lombok members và quan hệ gọi không được suy diễn. Không thấy controller Destination độc lập trong source hiện tại.

## Package
- `controller`: REST API và ranh giới HTTP.
- `service`, `service.impl`: nghiệp vụ, provider orchestration, quyền/scope.
- `repository`: truy vấn persistence.
- `model`, `model.enums`: entity và kiểu domain.
- `dto`: request/response và kiểu trao đổi nội bộ.
- `security`, `config`, `exception`: auth, cấu hình/startup runners, lỗi.
- `resolver`, `seeder`, `util`: phân giải dữ liệu, seed và helper.

## File source

### Travel_Planner/Travel_Planner/config/ActivityLocationMigrationRunner.java
- Khai báo: public class ActivityLocationMigrationRunner

### Travel_Planner/Travel_Planner/config/AdministrativeAreaMigrationRunner.java
- Khai báo: public class AdministrativeAreaMigrationRunner; public static class ProvinceSourceDto; public static class CommuneSourceDto

### Travel_Planner/Travel_Planner/config/AdministrativeAreaValidator.java
- Khai báo: public class AdministrativeAreaValidator; public static class ValidationResult; public static class DatabaseAuditResult

### Travel_Planner/Travel_Planner/config/ChatStompAuthInterceptor.java
- Khai báo: public class ChatStompAuthInterceptor

### Travel_Planner/Travel_Planner/config/ChatWebSocketConfig.java
- Khai báo: public class ChatWebSocketConfig

### Travel_Planner/Travel_Planner/config/ChatWebSocketSessionRegistry.java
- Khai báo: public class ChatWebSocketSessionRegistry

### Travel_Planner/Travel_Planner/config/DestinationConsolidationMigrationRunner.java
- Khai báo: public class DestinationConsolidationMigrationRunner

### Travel_Planner/Travel_Planner/config/MapProperties.java
- Khai báo: public class MapProperties; public static class Geocoding; public static class TomTom; public static class Routing

### Travel_Planner/Travel_Planner/config/PlaceAdministrativeAreaMigrationRunner.java
- Khai báo: public class PlaceAdministrativeAreaMigrationRunner

### Travel_Planner/Travel_Planner/config/UserHandleBackfillRunner.java
- Khai báo: public class UserHandleBackfillRunner

### Travel_Planner/Travel_Planner/controller/ActivityCommentController.java
- Khai báo: public class ActivityCommentController

### Travel_Planner/Travel_Planner/controller/AdminCommunityController.java
- Khai báo: public class AdminCommunityController

### Travel_Planner/Travel_Planner/controller/AdministrativeAreaController.java
- Khai báo: public class AdministrativeAreaController

### Travel_Planner/Travel_Planner/controller/AdminPlaceAdministrativeAreaController.java
- Khai báo: public class AdminPlaceAdministrativeAreaController

### Travel_Planner/Travel_Planner/controller/AdminPlaceController.java
- Khai báo: public class AdminPlaceController

### Travel_Planner/Travel_Planner/controller/AuthController.java
- Khai báo: public class AuthController

### Travel_Planner/Travel_Planner/controller/CommentController.java
- Khai báo: public class CommentController

### Travel_Planner/Travel_Planner/controller/CommentThreadController.java
- Khai báo: public class CommentThreadController

### Travel_Planner/Travel_Planner/controller/CommunityPostController.java
- Khai báo: public class CommunityPostController

### Travel_Planner/Travel_Planner/controller/ConversationController.java
- Khai báo: public class ConversationController

### Travel_Planner/Travel_Planner/controller/FavoriteController.java
- Khai báo: public class FavoriteController

### Travel_Planner/Travel_Planner/controller/FriendshipController.java
- Khai báo: public class FriendshipController

### Travel_Planner/Travel_Planner/controller/HealthController.java
- Khai báo: public class HealthController

### Travel_Planner/Travel_Planner/controller/ImageUploadController.java
- Khai báo: public class ImageUploadController

### Travel_Planner/Travel_Planner/controller/ItineraryController.java
- Khai báo: public class ItineraryController

### Travel_Planner/Travel_Planner/controller/ItineraryPlaceController.java
- Khai báo: public class ItineraryPlaceController

### Travel_Planner/Travel_Planner/controller/LocationController.java
- Khai báo: public class LocationController

### Travel_Planner/Travel_Planner/controller/MessagingSettingsController.java
- Khai báo: public class MessagingSettingsController

### Travel_Planner/Travel_Planner/controller/PlaceController.java
- Khai báo: public class PlaceController

### Travel_Planner/Travel_Planner/controller/ProfileController.java
- Khai báo: public class ProfileController

### Travel_Planner/Travel_Planner/controller/PublicUserController.java
- Khai báo: public class PublicUserController

### Travel_Planner/Travel_Planner/controller/RatingController.java
- Khai báo: public class RatingController

### Travel_Planner/Travel_Planner/controller/RouteController.java
- Khai báo: public class RouteController

### Travel_Planner/Travel_Planner/controller/SavedItineraryController.java
- Khai báo: public class SavedItineraryController

### Travel_Planner/Travel_Planner/controller/UserItineraryController.java
- Khai báo: public class UserItineraryController

### Travel_Planner/Travel_Planner/dto/location/GeographicTargetArea.java
- Khai báo: public class GeographicTargetArea

### Travel_Planner/Travel_Planner/dto/location/ParsedLocationQuery.java
- Khai báo: public class ParsedLocationQuery

### Travel_Planner/Travel_Planner/dto/location/SearchIntent.java
- Khai báo: public enum SearchIntent

### Travel_Planner/Travel_Planner/dto/request/BatchResolvePlacesRequest.java
- Khai báo: public class BatchResolvePlacesRequest

### Travel_Planner/Travel_Planner/dto/request/CreateActivityRequest.java
- Khai báo: public class CreateActivityRequest

### Travel_Planner/Travel_Planner/dto/request/CreateCommentRequest.java
- Khai báo: public class CreateCommentRequest

### Travel_Planner/Travel_Planner/dto/request/CreateDayRequest.java
- Khai báo: public class CreateDayRequest

### Travel_Planner/Travel_Planner/dto/request/CreateItineraryRequest.java
- Khai báo: public class CreateItineraryRequest

### Travel_Planner/Travel_Planner/dto/request/CreatePlaceRequest.java
- Khai báo: public class CreatePlaceRequest

### Travel_Planner/Travel_Planner/dto/request/CreatePostCommentRequest.java
- Khai báo: public class CreatePostCommentRequest

### Travel_Planner/Travel_Planner/dto/request/CreatePostReportRequest.java
- Khai báo: public class CreatePostReportRequest

### Travel_Planner/Travel_Planner/dto/request/CreatePostRequest.java
- Khai báo: public class CreatePostRequest

### Travel_Planner/Travel_Planner/dto/request/LoginRequest.java
- Khai báo: public class LoginRequest

### Travel_Planner/Travel_Planner/dto/request/ManualLinkAdministrativeAreaRequest.java
- Khai báo: public class ManualLinkAdministrativeAreaRequest

### Travel_Planner/Travel_Planner/dto/request/MarkConversationReadRequest.java
- Khai báo: public class MarkConversationReadRequest

### Travel_Planner/Travel_Planner/dto/request/ModeratePostRequest.java
- Khai báo: public class ModeratePostRequest

### Travel_Planner/Travel_Planner/dto/request/OpenConversationRequest.java
- Khai báo: public class OpenConversationRequest

### Travel_Planner/Travel_Planner/dto/request/RateItineraryRequest.java
- Khai báo: public class RateItineraryRequest

### Travel_Planner/Travel_Planner/dto/request/RegisterRequest.java
- Khai báo: public class RegisterRequest

### Travel_Planner/Travel_Planner/dto/request/ReorderActivityItem.java
- Khai báo: public class ReorderActivityItem

### Travel_Planner/Travel_Planner/dto/request/ResolvePlaceRequest.java
- Khai báo: public class ResolvePlaceRequest

### Travel_Planner/Travel_Planner/dto/request/SavePlaceToItineraryRequest.java
- Khai báo: public class SavePlaceToItineraryRequest

### Travel_Planner/Travel_Planner/dto/request/SendMessageRequest.java
- Khai báo: public class SendMessageRequest

### Travel_Planner/Travel_Planner/dto/request/UpdateActivityRequest.java
- Khai báo: public class UpdateActivityRequest

### Travel_Planner/Travel_Planner/dto/request/UpdateDayRequest.java
- Khai báo: public class UpdateDayRequest

### Travel_Planner/Travel_Planner/dto/request/UpdateItineraryRequest.java
- Khai báo: public class UpdateItineraryRequest

### Travel_Planner/Travel_Planner/dto/request/UpdateMessagingSettingsRequest.java
- Khai báo: public class UpdateMessagingSettingsRequest

### Travel_Planner/Travel_Planner/dto/request/UpdatePlaceRequest.java
- Khai báo: public class UpdatePlaceRequest

### Travel_Planner/Travel_Planner/dto/request/UpdatePostCommentRequest.java
- Khai báo: public class UpdatePostCommentRequest

### Travel_Planner/Travel_Planner/dto/request/UpdatePostRequest.java
- Khai báo: public class UpdatePostRequest

### Travel_Planner/Travel_Planner/dto/request/UpdateProfileRequest.java
- Khai báo: public class UpdateProfileRequest

### Travel_Planner/Travel_Planner/dto/response/ActivityResponse.java
- Khai báo: public class ActivityResponse

### Travel_Planner/Travel_Planner/dto/response/AdministrativeAreaResponse.java
- Khai báo: public class AdministrativeAreaResponse

### Travel_Planner/Travel_Planner/dto/response/AdministrativeAreaSearchResultResponse.java
- Khai báo: public class AdministrativeAreaSearchResultResponse

### Travel_Planner/Travel_Planner/dto/response/AdministrativeAreaSummaryResponse.java
- Khai báo: public class AdministrativeAreaSummaryResponse

### Travel_Planner/Travel_Planner/dto/response/AuthResponse.java
- Khai báo: public class AuthResponse

### Travel_Planner/Travel_Planner/dto/response/BatchLinkingReportResponse.java
- Khai báo: public class BatchLinkingReportResponse

### Travel_Planner/Travel_Planner/dto/response/ChatEventResponse.java
- Khai báo: public class ChatEventResponse

### Travel_Planner/Travel_Planner/dto/response/CommentResponse.java
- Khai báo: public class CommentResponse

### Travel_Planner/Travel_Planner/dto/response/ConversationSummaryResponse.java
- Khai báo: public class ConversationSummaryResponse

### Travel_Planner/Travel_Planner/dto/response/MessageRequestCountResponse.java
- Khai báo: public record MessageRequestCountResponse

### Travel_Planner/Travel_Planner/dto/response/CreatorSummaryResponse.java
- Khai báo: public class CreatorSummaryResponse

### Travel_Planner/Travel_Planner/dto/response/DeleteRatingResponse.java
- Khai báo: public class DeleteRatingResponse

### Travel_Planner/Travel_Planner/dto/response/ErrorResponse.java
- Khai báo: public class ErrorResponse

### Travel_Planner/Travel_Planner/dto/response/FavoriteResponse.java
- Khai báo: public class FavoriteResponse

### Travel_Planner/Travel_Planner/dto/response/FriendRequestResponse.java
- Khai báo: public class FriendRequestResponse

### Travel_Planner/Travel_Planner/dto/response/ImageUploadResponse.java
- Khai báo: public record ImageUploadResponse

### Travel_Planner/Travel_Planner/dto/response/ItineraryDayResponse.java
- Khai báo: public class ItineraryDayResponse

### Travel_Planner/Travel_Planner/dto/response/ItineraryDetailResponse.java
- Khai báo: public class ItineraryDetailResponse

### Travel_Planner/Travel_Planner/dto/response/ItineraryPlaceResponse.java
- Khai báo: public class ItineraryPlaceResponse

### Travel_Planner/Travel_Planner/dto/response/ItinerarySummaryResponse.java
- Khai báo: public class ItinerarySummaryResponse

### Travel_Planner/Travel_Planner/dto/response/LocationSearchResultResponse.java
- Khai báo: public class LocationSearchResultResponse

### Travel_Planner/Travel_Planner/dto/response/MediaAssetResponse.java
- Khai báo: public class MediaAssetResponse

### Travel_Planner/Travel_Planner/dto/response/MessagePageResponse.java
- Khai báo: public class MessagePageResponse

### Travel_Planner/Travel_Planner/dto/response/MessageResponse.java
- Khai báo: public class MessageResponse

### Travel_Planner/Travel_Planner/dto/response/MessagingSettingsResponse.java
- Khai báo: public class MessagingSettingsResponse

### Travel_Planner/Travel_Planner/dto/response/PageResponse.java
- Khai báo: public class PageResponse

### Travel_Planner/Travel_Planner/dto/response/PlaceDetailResponse.java
- Khai báo: public class PlaceDetailResponse

### Travel_Planner/Travel_Planner/dto/response/PlaceProviderMappingResponse.java
- Khai báo: public class PlaceProviderMappingResponse

### Travel_Planner/Travel_Planner/dto/response/PlaceResolutionResultResponse.java
- Khai báo: public class PlaceResolutionResultResponse

### Travel_Planner/Travel_Planner/dto/response/PlaceResponse.java
- Khai báo: public class PlaceResponse

### Travel_Planner/Travel_Planner/dto/response/PostAuthorResponse.java
- Khai báo: public class PostAuthorResponse

### Travel_Planner/Travel_Planner/dto/response/PostCommentResponse.java
- Khai báo: public class PostCommentResponse

### Travel_Planner/Travel_Planner/dto/response/PostItineraryAttachmentResponse.java
- Khai báo: public class PostItineraryAttachmentResponse

### Travel_Planner/Travel_Planner/dto/response/PostReportResponse.java
- Khai báo: public class PostReportResponse

### Travel_Planner/Travel_Planner/dto/response/PostResponse.java
- Khai báo: public class PostResponse

### Travel_Planner/Travel_Planner/dto/response/PublicProfileResponse.java
- Khai báo: public class PublicProfileResponse

### Travel_Planner/Travel_Planner/dto/response/PublicUserSummaryResponse.java
- Khai báo: public class PublicUserSummaryResponse

### Travel_Planner/Travel_Planner/dto/response/RatingResponse.java
- Khai báo: public class RatingResponse

### Travel_Planner/Travel_Planner/dto/response/RatingSummaryResponse.java
- Khai báo: public class RatingSummaryResponse

### Travel_Planner/Travel_Planner/dto/response/RelationshipContextResponse.java
- Khai báo: public class RelationshipContextResponse

### Travel_Planner/Travel_Planner/dto/response/RouteResponse.java
- Khai báo: public class RouteResponse

### Travel_Planner/Travel_Planner/dto/response/RouteWaypointResponse.java
- Khai báo: public class RouteWaypointResponse

### Travel_Planner/Travel_Planner/dto/response/SavedItineraryResponse.java
- Khai báo: public class SavedItineraryResponse

### Travel_Planner/Travel_Planner/dto/response/TotalUnreadResponse.java
- Khai báo: public record TotalUnreadResponse

### Travel_Planner/Travel_Planner/dto/response/UserRatingStatusResponse.java
- Khai báo: public class UserRatingStatusResponse

### Travel_Planner/Travel_Planner/dto/response/UserResponse.java
- Khai báo: public class UserResponse

### Travel_Planner/Travel_Planner/exception/AppException.java
- Khai báo: public class AppException

### Travel_Planner/Travel_Planner/exception/BadRequestException.java
- Khai báo: public class BadRequestException

### Travel_Planner/Travel_Planner/exception/ConflictException.java
- Khai báo: public class ConflictException

### Travel_Planner/Travel_Planner/exception/ForbiddenException.java
- Khai báo: public class ForbiddenException

### Travel_Planner/Travel_Planner/exception/GlobalExceptionHandler.java
- Khai báo: public class GlobalExceptionHandler

### Travel_Planner/Travel_Planner/exception/RateLimitExceededException.java
- Khai báo: public class RateLimitExceededException

### Travel_Planner/Travel_Planner/exception/ResourceNotFoundException.java
- Khai báo: public class ResourceNotFoundException

### Travel_Planner/Travel_Planner/exception/RoutingProviderException.java
- Khai báo: public class RoutingProviderException

### Travel_Planner/Travel_Planner/exception/UnauthorizedException.java
- Khai báo: public class UnauthorizedException

### Travel_Planner/Travel_Planner/model/Activity.java
- Khai báo: public class Activity

### Travel_Planner/Travel_Planner/model/AdministrativeArea.java
- Khai báo: public class AdministrativeArea

### Travel_Planner/Travel_Planner/model/CachedRouteResult.java
- Khai báo: public record CachedRouteResult

### Travel_Planner/Travel_Planner/model/Comment.java
- Khai báo: public class Comment

### Travel_Planner/Travel_Planner/model/Conversation.java
- Khai báo: public class Conversation

### Travel_Planner/Travel_Planner/model/ConversationReadState.java
- Khai báo: public class ConversationReadState

### Travel_Planner/Travel_Planner/model/ConversationReadStateId.java
- Khai báo: public class ConversationReadStateId

### Travel_Planner/Travel_Planner/model/enums/AdministrativeAreaStatus.java
- Khai báo: public enum AdministrativeAreaStatus

### Travel_Planner/Travel_Planner/model/enums/AdministrativeAreaTrustClassification.java
- Khai báo: public enum AdministrativeAreaTrustClassification

### Travel_Planner/Travel_Planner/model/enums/AdministrativeAreaType.java
- Khai báo: public enum AdministrativeAreaType

### Travel_Planner/Travel_Planner/model/enums/CommentStatus.java
- Khai báo: public enum CommentStatus

### Travel_Planner/Travel_Planner/model/enums/ConfidenceClassification.java
- Khai báo: public enum ConfidenceClassification

### Travel_Planner/Travel_Planner/model/enums/FriendshipStatus.java
- Khai báo: public enum FriendshipStatus

### Travel_Planner/Travel_Planner/model/enums/InboundMessagePolicy.java
- Khai báo: public enum InboundMessagePolicy

### Travel_Planner/Travel_Planner/model/enums/ConversationStatus.java
- Khai báo: public enum ConversationStatus

### Travel_Planner/Travel_Planner/model/enums/ItineraryStatus.java
- Khai báo: public enum ItineraryStatus

### Travel_Planner/Travel_Planner/model/enums/MediaAssetStatus.java
- Khai báo: public enum MediaAssetStatus

### Travel_Planner/Travel_Planner/model/enums/PlaceCategory.java
- Khai báo: public enum PlaceCategory

### Travel_Planner/Travel_Planner/model/enums/PlaceStatus.java
- Khai báo: public enum PlaceStatus

### Travel_Planner/Travel_Planner/model/enums/PostStatus.java
- Khai báo: public enum PostStatus

### Travel_Planner/Travel_Planner/model/enums/PostVisibility.java
- Khai báo: public enum PostVisibility

### Travel_Planner/Travel_Planner/model/enums/ReportStatus.java
- Khai báo: public enum ReportStatus

### Travel_Planner/Travel_Planner/model/enums/Role.java
- Khai báo: public enum Role

### Travel_Planner/Travel_Planner/model/enums/UserStatus.java
- Khai báo: public enum UserStatus

### Travel_Planner/Travel_Planner/model/enums/Visibility.java
- Khai báo: public enum Visibility

### Travel_Planner/Travel_Planner/model/Favorite.java
- Khai báo: public class Favorite

### Travel_Planner/Travel_Planner/model/Follow.java
- Khai báo: public class Follow

### Travel_Planner/Travel_Planner/model/Friendship.java
- Khai báo: public class Friendship

### Travel_Planner/Travel_Planner/model/Itinerary.java
- Khai báo: public class Itinerary

### Travel_Planner/Travel_Planner/model/ItineraryDay.java
- Khai báo: public class ItineraryDay

### Travel_Planner/Travel_Planner/model/ItineraryPlace.java
- Khai báo: public class ItineraryPlace

### Travel_Planner/Travel_Planner/model/ItineraryShare.java
- Khai báo: public class ItineraryShare

### Travel_Planner/Travel_Planner/model/MediaAsset.java
- Khai báo: public class MediaAsset

### Travel_Planner/Travel_Planner/model/Message.java
- Khai báo: public class Message

### Travel_Planner/Travel_Planner/model/OfflineDownload.java
- Khai báo: public class OfflineDownload

### Travel_Planner/Travel_Planner/model/Place.java
- Khai báo: public class Place

### Travel_Planner/Travel_Planner/model/PlaceProviderMapping.java
- Khai báo: public class PlaceProviderMapping

### Travel_Planner/Travel_Planner/model/Post.java
- Khai báo: public class Post

### Travel_Planner/Travel_Planner/model/PostComment.java
- Khai báo: public class PostComment

### Travel_Planner/Travel_Planner/model/PostLike.java
- Khai báo: public class PostLike

### Travel_Planner/Travel_Planner/model/PostMedia.java
- Khai báo: public class PostMedia

### Travel_Planner/Travel_Planner/model/PostReport.java
- Khai báo: public class PostReport

### Travel_Planner/Travel_Planner/model/Rating.java
- Khai báo: public class Rating

### Travel_Planner/Travel_Planner/model/SavedItinerary.java
- Khai báo: public class SavedItinerary

### Travel_Planner/Travel_Planner/model/User.java
- Khai báo: public class User

### Travel_Planner/Travel_Planner/model/UserBlock.java
- Khai báo: public class UserBlock

### Travel_Planner/Travel_Planner/model/UserMessagingSettings.java
- Khai báo: public class UserMessagingSettings

### Travel_Planner/Travel_Planner/model/WaypointCoordinate.java
- Khai báo: public record WaypointCoordinate

### Travel_Planner/Travel_Planner/repository/ActivityRepository.java
- Khai báo: public interface ActivityRepository

### Travel_Planner/Travel_Planner/repository/AdministrativeAreaRepository.java
- Khai báo: public interface AdministrativeAreaRepository

### Travel_Planner/Travel_Planner/repository/CommentRepository.java
- Khai báo: public interface CommentRepository

### Travel_Planner/Travel_Planner/repository/ConversationReadStateRepository.java
- Khai báo: public interface ConversationReadStateRepository

### Travel_Planner/Travel_Planner/repository/ConversationRepository.java
- Khai báo: public interface ConversationRepository

### Travel_Planner/Travel_Planner/repository/FavoriteRepository.java
- Khai báo: public interface FavoriteRepository

### Travel_Planner/Travel_Planner/repository/FollowRepository.java
- Khai báo: public interface FollowRepository

### Travel_Planner/Travel_Planner/repository/FriendshipRepository.java
- Khai báo: public interface FriendshipRepository

### Travel_Planner/Travel_Planner/repository/ItineraryDayRepository.java
- Khai báo: public interface ItineraryDayRepository

### Travel_Planner/Travel_Planner/repository/ItineraryPlaceRepository.java
- Khai báo: public interface ItineraryPlaceRepository

### Travel_Planner/Travel_Planner/repository/ItineraryRepository.java
- Khai báo: public interface ItineraryRepository

### Travel_Planner/Travel_Planner/repository/ItineraryShareRepository.java
- Khai báo: public interface ItineraryShareRepository

### Travel_Planner/Travel_Planner/repository/MediaAssetRepository.java
- Khai báo: public interface MediaAssetRepository

### Travel_Planner/Travel_Planner/repository/MessageRepository.java
- Khai báo: public interface MessageRepository

### Travel_Planner/Travel_Planner/repository/OfflineDownloadRepository.java
- Khai báo: public interface OfflineDownloadRepository

### Travel_Planner/Travel_Planner/repository/PlaceProviderMappingRepository.java
- Khai báo: public interface PlaceProviderMappingRepository

### Travel_Planner/Travel_Planner/repository/PlaceRepository.java
- Khai báo: public interface PlaceRepository

### Travel_Planner/Travel_Planner/repository/PostCommentRepository.java
- Khai báo: public interface PostCommentRepository

### Travel_Planner/Travel_Planner/repository/PostLikeRepository.java
- Khai báo: public interface PostLikeRepository

### Travel_Planner/Travel_Planner/repository/PostMediaRepository.java
- Khai báo: public interface PostMediaRepository

### Travel_Planner/Travel_Planner/repository/PostReportRepository.java
- Khai báo: public interface PostReportRepository

### Travel_Planner/Travel_Planner/repository/PostRepository.java
- Khai báo: public interface PostRepository

### Travel_Planner/Travel_Planner/repository/RatingRepository.java
- Khai báo: public interface RatingRepository

### Travel_Planner/Travel_Planner/repository/SavedItineraryRepository.java
- Khai báo: public interface SavedItineraryRepository

### Travel_Planner/Travel_Planner/repository/specification/ItinerarySpecification.java
- Khai báo: public class ItinerarySpecification

### Travel_Planner/Travel_Planner/repository/UserBlockRepository.java
- Khai báo: public interface UserBlockRepository

### Travel_Planner/Travel_Planner/repository/UserMessagingSettingsRepository.java
- Khai báo: public interface UserMessagingSettingsRepository

### Travel_Planner/Travel_Planner/repository/UserRepository.java
- Khai báo: public interface UserRepository

### Travel_Planner/Travel_Planner/resolver/AdministrativeAreaResolver.java
- Khai báo: public interface AdministrativeAreaResolver

### Travel_Planner/Travel_Planner/resolver/impl/AdministrativeAreaResolverImpl.java
- Khai báo: public class AdministrativeAreaResolverImpl

### Travel_Planner/Travel_Planner/security/ClientIpResolver.java
- Khai báo: public class ClientIpResolver

### Travel_Planner/Travel_Planner/security/JwtAuthenticationFilter.java
- Khai báo: public class JwtAuthenticationFilter

### Travel_Planner/Travel_Planner/security/JwtTokenProvider.java
- Khai báo: public class JwtTokenProvider

### Travel_Planner/Travel_Planner/security/SecurityConfig.java
- Khai báo: public class SecurityConfig

### Travel_Planner/Travel_Planner/security/UserDetailsServiceImpl.java
- Khai báo: public class UserDetailsServiceImpl

### Travel_Planner/Travel_Planner/seeder/DataSeeder.java
- Khai báo: public class DataSeeder

### Travel_Planner/Travel_Planner/seeder/SeedResult.java
- Khai báo: public class SeedResult

### Travel_Planner/Travel_Planner/service/AdministrativeAreaService.java
- Khai báo: public interface AdministrativeAreaService

### Travel_Planner/Travel_Planner/service/AuthService.java
- Khai báo: public interface AuthService

### Travel_Planner/Travel_Planner/service/ChatEventListener.java
- Khai báo: public class ChatEventListener

### Travel_Planner/Travel_Planner/service/ChatRateLimiter.java
- Khai báo: public class ChatRateLimiter

### Travel_Planner/Travel_Planner/service/CommentService.java
- Khai báo: public interface CommentService

### Travel_Planner/Travel_Planner/service/CommittedChatEvent.java
- Khai báo: public record CommittedChatEvent

### Travel_Planner/Travel_Planner/service/FavoriteService.java
- Khai báo: public interface FavoriteService

### Travel_Planner/Travel_Planner/service/FriendshipService.java
- Khai báo: public interface FriendshipService

### Travel_Planner/Travel_Planner/service/GeocodingProvider.java
- Khai báo: public interface GeocodingProvider

### Travel_Planner/Travel_Planner/service/GeographicFilterService.java
- Khai báo: public interface GeographicFilterService

### Travel_Planner/Travel_Planner/service/ImageUploadService.java
- Khai báo: public interface ImageUploadService

### Travel_Planner/Travel_Planner/service/impl/AdministrativeAreaServiceImpl.java
- Khai báo: public class AdministrativeAreaServiceImpl

### Travel_Planner/Travel_Planner/service/impl/AuthServiceImpl.java
- Khai báo: public class AuthServiceImpl

### Travel_Planner/Travel_Planner/service/impl/CloudinaryImageUploadService.java
- Khai báo: public class CloudinaryImageUploadService; public record CloudinaryUploadResult

### Travel_Planner/Travel_Planner/service/impl/CommentServiceImpl.java
- Khai báo: public class CommentServiceImpl

### Travel_Planner/Travel_Planner/service/impl/FavoriteServiceImpl.java
- Khai báo: public class FavoriteServiceImpl

### Travel_Planner/Travel_Planner/service/impl/FriendshipServiceImpl.java
- Khai báo: public class FriendshipServiceImpl; private record Pair

### Travel_Planner/Travel_Planner/service/impl/GeographicFilterServiceImpl.java
- Khai báo: public class GeographicFilterServiceImpl

### Travel_Planner/Travel_Planner/service/impl/HereGeocodingProvider.java
- Khai báo: public class HereGeocodingProvider

### Travel_Planner/Travel_Planner/service/impl/ItineraryPlaceServiceImpl.java
- Khai báo: public class ItineraryPlaceServiceImpl

### Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java
- Khai báo: public class ItineraryServiceImpl

### Travel_Planner/Travel_Planner/service/impl/LocationIqGeocodingProvider.java
- Khai báo: public class LocationIqGeocodingProvider

### Travel_Planner/Travel_Planner/service/impl/LocationRankingServiceImpl.java
- Khai báo: public class LocationRankingServiceImpl; private record ScoredResult

### Travel_Planner/Travel_Planner/service/impl/LocationServiceImpl.java
- Khai báo: public class LocationServiceImpl

### Travel_Planner/Travel_Planner/service/impl/MediaCleanupService.java
- Khai báo: public class MediaCleanupService; public record ClaimResult

### Travel_Planner/Travel_Planner/service/impl/MessagingServiceImpl.java
- Khai báo: public class MessagingServiceImpl

### Travel_Planner/Travel_Planner/service/impl/MessagingSettingsServiceImpl.java
- Khai báo: public class MessagingSettingsServiceImpl

### Travel_Planner/Travel_Planner/service/impl/OpenRouteServiceRoutingProvider.java
- Khai báo: public class OpenRouteServiceRoutingProvider

### Travel_Planner/Travel_Planner/service/impl/PlaceAdministrativeAreaServiceImpl.java
- Khai báo: public class PlaceAdministrativeAreaServiceImpl

### Travel_Planner/Travel_Planner/service/impl/PlaceNormalizationServiceImpl.java
- Khai báo: public class PlaceNormalizationServiceImpl

### Travel_Planner/Travel_Planner/service/impl/PlaceServiceImpl.java
- Khai báo: public class PlaceServiceImpl

### Travel_Planner/Travel_Planner/service/impl/PostServiceImpl.java
- Khai báo: public class PostServiceImpl; private record PostItineraryAttachmentResult

### Travel_Planner/Travel_Planner/service/impl/ProfileServiceImpl.java
- Khai báo: public class ProfileServiceImpl

### Travel_Planner/Travel_Planner/service/impl/PublicUserServiceImpl.java
- Khai báo: public class PublicUserServiceImpl

### Travel_Planner/Travel_Planner/service/impl/QueryUnderstandingServiceImpl.java
- Khai báo: public class QueryUnderstandingServiceImpl; private record CategoryPrefix

### Travel_Planner/Travel_Planner/service/impl/RatingServiceImpl.java
- Khai báo: public class RatingServiceImpl

### Travel_Planner/Travel_Planner/service/impl/RouteServiceImpl.java
- Khai báo: public class RouteServiceImpl

### Travel_Planner/Travel_Planner/service/impl/SavedItineraryServiceImpl.java
- Khai báo: public class SavedItineraryServiceImpl

### Travel_Planner/Travel_Planner/service/impl/TomTomPlacesProvider.java
- Khai báo: public class TomTomPlacesProvider

### Travel_Planner/Travel_Planner/service/impl/UserHandleServiceImpl.java
- Khai báo: public class UserHandleServiceImpl

### Travel_Planner/Travel_Planner/service/ItineraryPlaceService.java
- Khai báo: public interface ItineraryPlaceService

### Travel_Planner/Travel_Planner/service/ItineraryService.java
- Khai báo: public interface ItineraryService

### Travel_Planner/Travel_Planner/service/LocationRankingService.java
- Khai báo: public interface LocationRankingService

### Travel_Planner/Travel_Planner/service/LocationRateLimiter.java
- Khai báo: public class LocationRateLimiter

### Travel_Planner/Travel_Planner/service/LocationService.java
- Khai báo: public interface LocationService

### Travel_Planner/Travel_Planner/service/MessagingService.java
- Khai báo: public interface MessagingService

### Travel_Planner/Travel_Planner/service/MessagingSettingsService.java
- Khai báo: public interface MessagingSettingsService

### Travel_Planner/Travel_Planner/service/PlaceAdministrativeAreaService.java
- Khai báo: public interface PlaceAdministrativeAreaService

### Travel_Planner/Travel_Planner/service/PlaceNormalizationService.java
- Khai báo: public interface PlaceNormalizationService

### Travel_Planner/Travel_Planner/service/PlaceService.java
- Khai báo: public interface PlaceService

### Travel_Planner/Travel_Planner/service/PostService.java
- Khai báo: public interface PostService

### Travel_Planner/Travel_Planner/service/ProfileService.java
- Khai báo: public interface ProfileService

### Travel_Planner/Travel_Planner/service/PublicUserService.java
- Khai báo: public interface PublicUserService

### Travel_Planner/Travel_Planner/service/QueryUnderstandingService.java
- Khai báo: public interface QueryUnderstandingService

### Travel_Planner/Travel_Planner/service/RatingService.java
- Khai báo: public interface RatingService

### Travel_Planner/Travel_Planner/service/RouteService.java
- Khai báo: public interface RouteService

### Travel_Planner/Travel_Planner/service/RoutingProvider.java
- Khai báo: public interface RoutingProvider

### Travel_Planner/Travel_Planner/service/SavedItineraryService.java
- Khai báo: public interface SavedItineraryService

### Travel_Planner/Travel_Planner/service/UserHandleService.java
- Khai báo: public interface UserHandleService

### Travel_Planner/Travel_Planner/TravelPlannerApplication.java
- Khai báo: public class TravelPlannerApplication

### Travel_Planner/Travel_Planner/util/HaversineUtil.java
- Khai báo: public final class HaversineUtil
