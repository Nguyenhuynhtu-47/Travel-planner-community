# 04 — Backend: danh mục file và cách lần theo

Request điển hình: Controller → service interface/implementation → repository → JPA entity. DTO định nghĩa biên HTTP; security filter/config áp dụng xác thực; GlobalExceptionHandler chuẩn hóa lỗi. Tích hợp bản đồ, routing và upload được tách qua provider/service. Danh mục tự trích dưới đây giúp định vị khai báo; chữ ký đa dòng, Lombok-generated members và quan hệ gọi runtime có thể không đầy đủ.

## Package
- controller: REST API.
- service, service.impl: hợp đồng và quy tắc nghiệp vụ/tích hợp.
- repository: truy vấn Spring Data/JPA.
- model, model.enums: entity và enum.
- dto: request/response và cấu trúc nội bộ tìm kiếm.
- security: JWT, principal, quyền, IP client.
- config: cấu hình và runner.
- seeder: dữ liệu mẫu.
- exception: lỗi nghiệp vụ và ánh xạ phản hồi.
- util: tiện ích thuần.

## File source

### Travel_Planner/Travel_Planner/config/MapProperties.java
- Types: public class MapProperties {; public static class Geocoding {; public static class TomTom {; public static class Routing {

### Travel_Planner/Travel_Planner/config/UserHandleBackfillRunner.java
- Types: public class UserHandleBackfillRunner implements ApplicationRunner {
- Method declarations (excerpt): public void run(ApplicationArguments args) {; public void ensureSchemaAndBackfill() {; private void ensureColumnExists() {; private void backfillUsers() {; private void ensureConstraints() {

### Travel_Planner/Travel_Planner/controller/ActivityCommentController.java
- Types: public class ActivityCommentController {
- HTTP annotations: @RequestMapping("/api/activities/{activityId}/comments"), @GetMapping, @PostMapping

### Travel_Planner/Travel_Planner/controller/AdminDestinationController.java
- Types: public class AdminDestinationController {
- Method declarations (excerpt): public ResponseEntity<DestinationResponse> getDestinationById(@PathVariable Integer id) {; public ResponseEntity<Void> deleteDestination(@PathVariable Integer id) {
- HTTP annotations: @RequestMapping("/api/admin/destinations"), @GetMapping, @GetMapping("/{id}"), @PostMapping, @PutMapping("/{id}"), @DeleteMapping("/{id}")

### Travel_Planner/Travel_Planner/controller/AuthController.java
- Types: public class AuthController {
- Method declarations (excerpt): public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {; public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {; public ResponseEntity<UserResponse> getCurrentUser(@AuthenticationPrincipal UserDetails userDetails) {
- HTTP annotations: @RequestMapping("/api/auth"), @PostMapping("/register"), @PostMapping("/login"), @GetMapping("/me")

### Travel_Planner/Travel_Planner/controller/CommentController.java
- Types: public class CommentController {
- HTTP annotations: @RequestMapping("/api/itineraries/{itineraryId}/comments"), @GetMapping, @PostMapping

### Travel_Planner/Travel_Planner/controller/CommentThreadController.java
- Types: public class CommentThreadController {
- HTTP annotations: @RequestMapping("/api/comments"), @GetMapping("/{commentId}/replies"), @PostMapping("/{commentId}/replies"), @PutMapping("/{commentId}"), @DeleteMapping("/{commentId}")

### Travel_Planner/Travel_Planner/controller/DestinationController.java
- Types: public class DestinationController {
- Method declarations (excerpt): public ResponseEntity<DestinationResponse> getDestinationById(@PathVariable Integer id) {
- HTTP annotations: @RequestMapping("/api/destinations"), @GetMapping, @GetMapping("/{id}")

### Travel_Planner/Travel_Planner/controller/FavoriteController.java
- Types: public class FavoriteController {
- HTTP annotations: @PostMapping("/api/itineraries/{itineraryId}/favorites"), @DeleteMapping("/api/itineraries/{itineraryId}/favorites"), @GetMapping("/api/user/favorites")

### Travel_Planner/Travel_Planner/controller/HealthController.java
- Types: public class HealthController {
- Method declarations (excerpt): public ResponseEntity<Map<String, Object>> getHealth() {
- HTTP annotations: @RequestMapping("/api"), @GetMapping("/health")

### Travel_Planner/Travel_Planner/controller/ImageUploadController.java
- Types: public class ImageUploadController {
- Method declarations (excerpt): public ResponseEntity<ImageUploadResponse> uploadImage(@RequestPart("file") MultipartFile file) {
- HTTP annotations: @RequestMapping("/api/media"), @PostMapping(path = "/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)

### Travel_Planner/Travel_Planner/controller/ItineraryController.java
- Types: public class ItineraryController {
- HTTP annotations: @RequestMapping("/api/itineraries"), @GetMapping, @GetMapping("/recommendations"), @GetMapping("/{id}"), @PostMapping, @PutMapping("/{id}"), @DeleteMapping("/{id}"), @PostMapping("/{id}/days"), @PutMapping("/{id}/days/{dayId}"), @DeleteMapping("/{id}/days/{dayId}"), @PostMapping("/{id}/days/{dayId}/activities"), @PutMapping("/{id}/days/{dayId}/activities/{activityId}"), @DeleteMapping("/{id}/days/{dayId}/activities/{activityId}"), @PutMapping("/{id}/days/{dayId}/activities/reorder")

### Travel_Planner/Travel_Planner/controller/LocationController.java
- Types: public class LocationController {
- Method declarations (excerpt): private void enforceRateLimit(HttpServletRequest request, Authentication authentication) {
- HTTP annotations: @RequestMapping("/api/locations"), @GetMapping("/search"), @GetMapping("/providers/tomtom/details"), @GetMapping("/reverse-geocode"), @GetMapping("/nearby")

### Travel_Planner/Travel_Planner/controller/ProfileController.java
- Types: public class ProfileController {
- Method declarations (excerpt): public UserResponse getProfile(@AuthenticationPrincipal UserDetails userDetails) {
- HTTP annotations: @RequestMapping("/api/user/profile"), @GetMapping, @PutMapping

### Travel_Planner/Travel_Planner/controller/PublicUserController.java
- Types: public class PublicUserController {
- Method declarations (excerpt): public ResponseEntity<Void> follow(@PathVariable Integer userId, @AuthenticationPrincipal UserDetails viewer) {; public ResponseEntity<Void> unfollow(@PathVariable Integer userId, @AuthenticationPrincipal UserDetails viewer) {
- HTTP annotations: @RequestMapping("/api/users"), @GetMapping("/{userId:[0-9]+}/public-profile"), @GetMapping(value = {"/by-handle/{handle}", "/by-handle/{handle}/public-profile"}), @GetMapping("/{userId:[0-9]+}/itineraries"), @PostMapping("/{userId:[0-9]+}/follow"), @DeleteMapping("/{userId:[0-9]+}/follow"), @GetMapping("/{userId:[0-9]+}/followers"), @GetMapping("/{userId:[0-9]+}/following")

### Travel_Planner/Travel_Planner/controller/RatingController.java
- Types: public class RatingController {
- Method declarations (excerpt): public ResponseEntity<RatingSummaryResponse> getRatingSummary(@PathVariable Integer itineraryId) {
- HTTP annotations: @RequestMapping("/api/itineraries/{itineraryId}/ratings"), @PostMapping, @GetMapping, @GetMapping("/me"), @DeleteMapping

### Travel_Planner/Travel_Planner/controller/RouteController.java
- Types: public class RouteController {
- HTTP annotations: @RequestMapping("/api/itineraries/{itineraryId}/days/{dayId}/route"), @GetMapping

### Travel_Planner/Travel_Planner/controller/SavedItineraryController.java
- Types: public class SavedItineraryController {
- HTTP annotations: @PostMapping("/api/itineraries/{itineraryId}/save"), @DeleteMapping("/api/itineraries/{itineraryId}/save"), @GetMapping("/api/user/saved-itineraries")

### Travel_Planner/Travel_Planner/controller/UserItineraryController.java
- Types: public class UserItineraryController {
- HTTP annotations: @RequestMapping("/api/user/itineraries"), @GetMapping

### Travel_Planner/Travel_Planner/dto/location/GeographicTargetArea.java
- Types: public class GeographicTargetArea {

### Travel_Planner/Travel_Planner/dto/location/ParsedLocationQuery.java
- Types: public class ParsedLocationQuery {
- Method declarations (excerpt): public boolean hasExplicitLocation() {

### Travel_Planner/Travel_Planner/dto/location/SearchIntent.java
- Types: public enum SearchIntent {

### Travel_Planner/Travel_Planner/dto/request/CreateActivityRequest.java
- Types: public class CreateActivityRequest {

### Travel_Planner/Travel_Planner/dto/request/CreateCommentRequest.java
- Types: public class CreateCommentRequest {

### Travel_Planner/Travel_Planner/dto/request/CreateDayRequest.java
- Types: public class CreateDayRequest {

### Travel_Planner/Travel_Planner/dto/request/CreateDestinationRequest.java
- Types: public class CreateDestinationRequest {

### Travel_Planner/Travel_Planner/dto/request/CreateItineraryRequest.java
- Types: public class CreateItineraryRequest {

### Travel_Planner/Travel_Planner/dto/request/LoginRequest.java
- Types: public class LoginRequest {

### Travel_Planner/Travel_Planner/dto/request/RateItineraryRequest.java
- Types: public class RateItineraryRequest {

### Travel_Planner/Travel_Planner/dto/request/RegisterRequest.java
- Types: public class RegisterRequest {

### Travel_Planner/Travel_Planner/dto/request/ReorderActivityItem.java
- Types: public class ReorderActivityItem {

### Travel_Planner/Travel_Planner/dto/request/UpdateActivityRequest.java
- Types: public class UpdateActivityRequest {

### Travel_Planner/Travel_Planner/dto/request/UpdateDayRequest.java
- Types: public class UpdateDayRequest {

### Travel_Planner/Travel_Planner/dto/request/UpdateDestinationRequest.java
- Types: public class UpdateDestinationRequest {

### Travel_Planner/Travel_Planner/dto/request/UpdateItineraryRequest.java
- Types: public class UpdateItineraryRequest {

### Travel_Planner/Travel_Planner/dto/request/UpdateProfileRequest.java
- Types: public class UpdateProfileRequest {

### Travel_Planner/Travel_Planner/dto/response/ActivityResponse.java
- Types: public class ActivityResponse {

### Travel_Planner/Travel_Planner/dto/response/AuthResponse.java
- Types: public class AuthResponse {

### Travel_Planner/Travel_Planner/dto/response/CommentResponse.java
- Types: public class CommentResponse {

### Travel_Planner/Travel_Planner/dto/response/CreatorSummaryResponse.java
- Types: public class CreatorSummaryResponse {

### Travel_Planner/Travel_Planner/dto/response/DeleteRatingResponse.java
- Types: public class DeleteRatingResponse {

### Travel_Planner/Travel_Planner/dto/response/DestinationResponse.java
- Types: public class DestinationResponse {

### Travel_Planner/Travel_Planner/dto/response/ErrorResponse.java
- Types: public class ErrorResponse {

### Travel_Planner/Travel_Planner/dto/response/FavoriteResponse.java
- Types: public class FavoriteResponse {

### Travel_Planner/Travel_Planner/dto/response/ImageUploadResponse.java
- Types: public record ImageUploadResponse(String secureUrl) {
- Method declarations (excerpt): public record ImageUploadResponse(String secureUrl) {

### Travel_Planner/Travel_Planner/dto/response/ItineraryDayResponse.java
- Types: public class ItineraryDayResponse {

### Travel_Planner/Travel_Planner/dto/response/ItineraryDetailResponse.java
- Types: public class ItineraryDetailResponse {

### Travel_Planner/Travel_Planner/dto/response/ItinerarySummaryResponse.java
- Types: public class ItinerarySummaryResponse {

### Travel_Planner/Travel_Planner/dto/response/LocationSearchResultResponse.java
- Types: public class LocationSearchResultResponse {

### Travel_Planner/Travel_Planner/dto/response/PageResponse.java
- Types: public class PageResponse<T> {
- Method declarations (excerpt): public static <T> PageResponse<T> from(Page<T> page) {

### Travel_Planner/Travel_Planner/dto/response/PublicProfileResponse.java
- Types: public class PublicProfileResponse {

### Travel_Planner/Travel_Planner/dto/response/PublicUserSummaryResponse.java
- Types: public class PublicUserSummaryResponse {

### Travel_Planner/Travel_Planner/dto/response/RatingResponse.java
- Types: public class RatingResponse {

### Travel_Planner/Travel_Planner/dto/response/RatingSummaryResponse.java
- Types: public class RatingSummaryResponse {

### Travel_Planner/Travel_Planner/dto/response/RouteResponse.java
- Types: public class RouteResponse {

### Travel_Planner/Travel_Planner/dto/response/RouteWaypointResponse.java
- Types: public class RouteWaypointResponse {

### Travel_Planner/Travel_Planner/dto/response/SavedItineraryResponse.java
- Types: public class SavedItineraryResponse {

### Travel_Planner/Travel_Planner/dto/response/UserRatingStatusResponse.java
- Types: public class UserRatingStatusResponse {

### Travel_Planner/Travel_Planner/dto/response/UserResponse.java
- Types: public class UserResponse {

### Travel_Planner/Travel_Planner/exception/AppException.java
- Types: public class AppException extends RuntimeException {
- Method declarations (excerpt): public HttpStatus getStatus() {

### Travel_Planner/Travel_Planner/exception/BadRequestException.java
- Types: public class BadRequestException extends AppException {

### Travel_Planner/Travel_Planner/exception/ConflictException.java
- Types: public class ConflictException extends AppException {

### Travel_Planner/Travel_Planner/exception/ForbiddenException.java
- Types: public class ForbiddenException extends AppException {

### Travel_Planner/Travel_Planner/exception/GlobalExceptionHandler.java
- Types: public class GlobalExceptionHandler {
- Method declarations (excerpt): public ResponseEntity<ErrorResponse> handleValidationException(MethodArgumentNotValidException ex, HttpServletRequest request) {; public ResponseEntity<ErrorResponse> handleAppException(AppException ex, HttpServletRequest request) {; public ResponseEntity<ErrorResponse> handleBadCredentials(BadCredentialsException ex, HttpServletRequest request) {; public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {; public ResponseEntity<ErrorResponse> handleNoResourceFound(org.springframework.web.servlet.resource.NoResourceFoundException ex, HttpServletRequest request) {; public ResponseEntity<ErrorResponse> handleGeneralException(Exception ex, HttpServletRequest request) {

### Travel_Planner/Travel_Planner/exception/RateLimitExceededException.java
- Types: public class RateLimitExceededException extends AppException {

### Travel_Planner/Travel_Planner/exception/ResourceNotFoundException.java
- Types: public class ResourceNotFoundException extends AppException {

### Travel_Planner/Travel_Planner/exception/RoutingProviderException.java
- Types: public class RoutingProviderException extends RuntimeException {
- Method declarations (excerpt): public HttpStatus getStatus() {; public boolean isTimeout() {; public boolean isRateLimit() {

### Travel_Planner/Travel_Planner/exception/UnauthorizedException.java
- Types: public class UnauthorizedException extends AppException {

### Travel_Planner/Travel_Planner/model/Activity.java
- Types: public class Activity {
- Method declarations (excerpt): protected void onCreate() {; protected void onUpdate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn

### Travel_Planner/Travel_Planner/model/CachedRouteResult.java
- Types: public record CachedRouteResult(

### Travel_Planner/Travel_Planner/model/Comment.java
- Types: public class Comment {
- Method declarations (excerpt): protected void onCreate() {; protected void onUpdate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn, Enumerated

### Travel_Planner/Travel_Planner/model/Destination.java
- Types: public class Destination {
- Method declarations (excerpt): protected void onCreate() {; protected void onUpdate() {
- JPA annotations: Entity, Table, Id, Column, Enumerated

### Travel_Planner/Travel_Planner/model/enums/CommentStatus.java
- Types: public enum CommentStatus {

### Travel_Planner/Travel_Planner/model/enums/DestinationStatus.java
- Types: public enum DestinationStatus {

### Travel_Planner/Travel_Planner/model/enums/ItineraryStatus.java
- Types: public enum ItineraryStatus {

### Travel_Planner/Travel_Planner/model/enums/Role.java
- Types: public enum Role {

### Travel_Planner/Travel_Planner/model/enums/UserStatus.java
- Types: public enum UserStatus {

### Travel_Planner/Travel_Planner/model/enums/Visibility.java
- Types: public enum Visibility {

### Travel_Planner/Travel_Planner/model/Favorite.java
- Types: public class Favorite {
- Method declarations (excerpt): protected void onCreate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn

### Travel_Planner/Travel_Planner/model/Follow.java
- Types: public class Follow {
- Method declarations (excerpt): protected void onCreate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn

### Travel_Planner/Travel_Planner/model/Itinerary.java
- Types: public class Itinerary {
- Method declarations (excerpt): protected void onCreate() {; protected void onUpdate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn, Enumerated

### Travel_Planner/Travel_Planner/model/ItineraryDay.java
- Types: public class ItineraryDay {
- Method declarations (excerpt): protected void onCreate() {; protected void onUpdate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn

### Travel_Planner/Travel_Planner/model/ItineraryShare.java
- Types: public class ItineraryShare {
- Method declarations (excerpt): protected void onCreate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn

### Travel_Planner/Travel_Planner/model/OfflineDownload.java
- Types: public class OfflineDownload {
- Method declarations (excerpt): protected void onCreate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn

### Travel_Planner/Travel_Planner/model/Rating.java
- Types: public class Rating {
- Method declarations (excerpt): protected void onCreate() {; protected void onUpdate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn

### Travel_Planner/Travel_Planner/model/SavedItinerary.java
- Types: public class SavedItinerary {
- Method declarations (excerpt): protected void onCreate() {
- JPA annotations: Entity, Table, Id, Column, ManyToOne, JoinColumn

### Travel_Planner/Travel_Planner/model/User.java
- Types: public class User {
- Method declarations (excerpt): protected void onCreate() {; protected void onUpdate() {
- JPA annotations: Entity, Table, Id, Column, Enumerated

### Travel_Planner/Travel_Planner/model/WaypointCoordinate.java
- Types: public record WaypointCoordinate(double latitude, double longitude) {}
- Method declarations (excerpt): public record WaypointCoordinate(double latitude, double longitude) {

### Travel_Planner/Travel_Planner/repository/ActivityRepository.java
- Types: public interface ActivityRepository extends JpaRepository<Activity, Integer> {

### Travel_Planner/Travel_Planner/repository/CommentRepository.java
- Types: public interface CommentRepository extends JpaRepository<Comment, Integer> {

### Travel_Planner/Travel_Planner/repository/DestinationRepository.java
- Types: public interface DestinationRepository extends JpaRepository<Destination, Integer> {

### Travel_Planner/Travel_Planner/repository/FavoriteRepository.java
- Types: public interface FavoriteRepository extends JpaRepository<Favorite, Integer> {

### Travel_Planner/Travel_Planner/repository/FollowRepository.java
- Types: public interface FollowRepository extends JpaRepository<Follow, Integer> {

### Travel_Planner/Travel_Planner/repository/ItineraryDayRepository.java
- Types: public interface ItineraryDayRepository extends JpaRepository<ItineraryDay, Integer> {

### Travel_Planner/Travel_Planner/repository/ItineraryRepository.java
- Types: public interface ItineraryRepository extends JpaRepository<Itinerary, Integer>, JpaSpecificationExecutor<Itinerary> {

### Travel_Planner/Travel_Planner/repository/ItineraryShareRepository.java
- Types: public interface ItineraryShareRepository extends JpaRepository<ItineraryShare, Integer> {

### Travel_Planner/Travel_Planner/repository/OfflineDownloadRepository.java
- Types: public interface OfflineDownloadRepository extends JpaRepository<OfflineDownload, Integer> {

### Travel_Planner/Travel_Planner/repository/RatingRepository.java
- Types: public interface RatingRepository extends JpaRepository<Rating, Integer> {

### Travel_Planner/Travel_Planner/repository/SavedItineraryRepository.java
- Types: public interface SavedItineraryRepository extends JpaRepository<SavedItinerary, Integer> {

### Travel_Planner/Travel_Planner/repository/specification/ItinerarySpecification.java
- Types: public class ItinerarySpecification {
- Method declarations (excerpt): private static String escapeLike(String input) {

### Travel_Planner/Travel_Planner/repository/UserRepository.java
- Types: public interface UserRepository extends JpaRepository<User, Integer> {

### Travel_Planner/Travel_Planner/security/ClientIpResolver.java
- Types: public class ClientIpResolver {
- Method declarations (excerpt): public String resolveClientIp(HttpServletRequest request) {; public boolean isTrustedProxy(String ip) {; public String cleanIp(String raw) {

### Travel_Planner/Travel_Planner/security/JwtAuthenticationFilter.java
- Types: public class JwtAuthenticationFilter extends OncePerRequestFilter {
- Method declarations (excerpt): private String getJwtFromRequest(HttpServletRequest request) {

### Travel_Planner/Travel_Planner/security/JwtTokenProvider.java
- Types: public class JwtTokenProvider {
- Method declarations (excerpt): private void validateJwtSecretForEnvironment(String secret, Environment environment) {; public String generateToken(User user) {; public String getUsernameFromToken(String token) {; public boolean validateToken(String token) {; public Claims getClaimsFromToken(String token) {

### Travel_Planner/Travel_Planner/security/SecurityConfig.java
- Types: public class SecurityConfig {
- Method declarations (excerpt): public ObjectMapper objectMapper() {; public PasswordEncoder passwordEncoder() {; public AuthenticationManager authenticationManager(AuthenticationConfiguration configuration) throws; public SecurityFilterChain securityFilterChain(HttpSecurity http) throws; public CorsConfigurationSource corsConfigurationSource() {; private List<String> parseCommaSeparatedList(String input) {; public AuthenticationEntryPoint authenticationEntryPoint() {; public AccessDeniedHandler accessDeniedHandler() {

### Travel_Planner/Travel_Planner/security/UserDetailsServiceImpl.java
- Types: public class UserDetailsServiceImpl implements UserDetailsService {
- Method declarations (excerpt): public UserDetails loadUserByUsername(String usernameOrEmail) throws

### Travel_Planner/Travel_Planner/seeder/DataSeeder.java
- Types: public class DataSeeder implements CommandLineRunner {
- Method declarations (excerpt): public void run(String... args) {; public SeedResult seedData() {; private Map<String, User> seedUsers() {; private Map<String, Destination> seedDestinations() {; private Map<String, Itinerary> seedItineraries(Map<String, User> userMap) {; private Itinerary saveOrGetItinerary(Itinerary itin) {; private void seedDaysAndActivities(Map<String, Itinerary> itineraryMap, Map<String, Destination> destinationMap) {; private void seedActivitiesForDay(ItineraryDay day, String location, int dayNum, Map<String, Destination> destinationMap) {; private void seedSocialInteractions(Map<String, User> userMap, Map<String, Itinerary> itineraryMap) {; private void saveCommentIfNotExists(User user, Itinerary itinerary, String content, CommentStatus status) {; private void saveRatingIfNotExists(User user, Itinerary itinerary, int score) {; private void saveFavoriteIfNotExists(User user, Itinerary itinerary) {; private void saveSavedItineraryIfNotExists(User user, Itinerary itinerary) {; private void saveFollowIfNotExists(User follower, User following) {; private void saveShareIfNotExists(Itinerary itinerary, String shareToken, LocalDateTime expiresAt) {

### Travel_Planner/Travel_Planner/seeder/SeedResult.java
- Types: public class SeedResult {

### Travel_Planner/Travel_Planner/service/AuthService.java
- Types: public interface AuthService {

### Travel_Planner/Travel_Planner/service/CommentService.java
- Types: public interface CommentService {

### Travel_Planner/Travel_Planner/service/DestinationService.java
- Types: public interface DestinationService {

### Travel_Planner/Travel_Planner/service/FavoriteService.java
- Types: public interface FavoriteService {

### Travel_Planner/Travel_Planner/service/GeocodingProvider.java
- Types: public interface GeocodingProvider {

### Travel_Planner/Travel_Planner/service/GeographicFilterService.java
- Types: public interface GeographicFilterService {

### Travel_Planner/Travel_Planner/service/ImageUploadService.java
- Types: public interface ImageUploadService {

### Travel_Planner/Travel_Planner/service/impl/AuthServiceImpl.java
- Types: public class AuthServiceImpl implements AuthService {
- Method declarations (excerpt): public AuthResponse register(RegisterRequest request) {; public AuthResponse login(LoginRequest request) {; public UserResponse getCurrentUser(String username) {; private UserResponse mapToUserResponse(User user) {

### Travel_Planner/Travel_Planner/service/impl/CloudinaryImageUploadService.java
- Types: public class CloudinaryImageUploadService implements ImageUploadService {
- Method declarations (excerpt): public String uploadImage(MultipartFile file) {; private String uploadValidatedImage(byte[] bytes) {; public String getFilename() {; private byte[] validateAndRead(MultipartFile file) {; private String imageExtension(byte[] bytes) {; private void validateConfiguration() {; private String createSignature(long timestamp) {

### Travel_Planner/Travel_Planner/service/impl/CommentServiceImpl.java
- Types: public class CommentServiceImpl implements CommentService {
- Method declarations (excerpt): public PageResponse<CommentResponse> getComments(Integer itineraryId, int page, int size) {; public CommentResponse createComment(Integer itineraryId, CreateCommentRequest request, String username) {; public PageResponse<CommentResponse> getActivityComments(Integer activityId, int page, int size) {; public CommentResponse createActivityComment(Integer activityId, CreateCommentRequest request, String username) {; public PageResponse<CommentResponse> getReplies(Integer commentId, int page, int size) {; public CommentResponse createReply(Integer commentId, CreateCommentRequest request, String username) {; public CommentResponse updateComment(Integer commentId, CreateCommentRequest request, String username) {; public void deleteComment(Integer commentId, String username) {; private Itinerary requirePublicItinerary(Integer id) {; private Activity requirePublicActivity(Integer id) {; private Itinerary requireTargetPublic(Comment comment) {; private Itinerary requireTargetExists(Comment comment) {; private User requireActiveUser(String username) {; private Comment findComment(Integer id) {; private Comment resolveRoot(Comment comment) {

### Travel_Planner/Travel_Planner/service/impl/DestinationServiceImpl.java
- Types: public class DestinationServiceImpl implements DestinationService {
- Method declarations (excerpt): public List<DestinationResponse> getPublicDestinations(String keyword) {; public DestinationResponse getPublicDestinationById(Integer id) {; public List<DestinationResponse> getAdminDestinations(String keyword, DestinationStatus status) {; public DestinationResponse getAdminDestinationById(Integer id) {; public DestinationResponse createDestination(CreateDestinationRequest request) {; public DestinationResponse updateDestination(Integer id, UpdateDestinationRequest request) {; public void deleteDestination(Integer id) {; private void validateCoordinates(BigDecimal lat, BigDecimal lon) {; private BigDecimal normalizeCoordinate(BigDecimal coord) {; private DestinationResponse toResponse(Destination destination) {

### Travel_Planner/Travel_Planner/service/impl/FavoriteServiceImpl.java
- Types: public class FavoriteServiceImpl implements FavoriteService {
- Method declarations (excerpt): public FavoriteResponse addFavorite(Integer itineraryId, String currentUsername) {; public FavoriteResponse removeFavorite(Integer itineraryId, String currentUsername) {; public PageResponse<ItinerarySummaryResponse> getUserFavorites(String currentUsername, int page, int size) {; private Map<Integer, Double> fetchAverageRatings(List<Integer> itineraryIds) {; private ItinerarySummaryResponse mapToSummaryResponse(Itinerary item, Double averageRating) {; private User getAuthenticatedUser(String currentUsername) {; private Itinerary getPublicActiveItinerary(Integer itineraryId) {

### Travel_Planner/Travel_Planner/service/impl/GeographicFilterServiceImpl.java
- Types: public class GeographicFilterServiceImpl implements GeographicFilterService {
- Method declarations (excerpt): public List<LocationSearchResultResponse> filter(List<LocationSearchResultResponse> candidates, GeographicTargetArea targetArea) {; private boolean isCrossProvinceMismatch(LocationSearchResultResponse candidate, String targetContextNorm, double distanceKm) {; private String buildTargetContextNormalized(GeographicTargetArea targetArea) {; public static double haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {

### Travel_Planner/Travel_Planner/service/impl/HereGeocodingProvider.java
- Types: public class HereGeocodingProvider implements GeocodingProvider {
- Method declarations (excerpt): public String getProviderName() {; public boolean isConfigured() {; public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {; public List<LocationSearchResultResponse> searchInArea(String query, int limit, Double latitude, Double longitude, List<Double> boundingBox, Integer radiusMeters) {; private List<LocationSearchResultResponse> executeHereQuery(URI uri, String query) {; public List<LocationSearchResultResponse> searchNearby(double latitude, double longitude, String category, int radiusMeters, int limit) {; public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {; private LocationSearchResultResponse parseHereItem(JsonNode node) {

### Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java
- Types: public class ItineraryServiceImpl implements ItineraryService {
- Method declarations (excerpt): public PageResponse<ItinerarySummaryResponse> getRecommendations(String currentUsername, int page, int size) {; private void validateFilters(BigDecimal minBudget, BigDecimal maxBudget, Integer minDays, Integer maxDays, Double minRating) {; private Sort parseSort(String sort) {; private Map<Integer, Double> fetchAverageRatings(List<Integer> itineraryIds) {; private ItinerarySummaryResponse mapToSummaryResponse(Itinerary item, Double averageRating) {; public ItineraryDetailResponse getItineraryDetail(Integer id, String currentUsername) {; public ItineraryDetailResponse createItinerary(CreateItineraryRequest request, String currentUsername) {; public ItineraryDetailResponse updateItinerary(Integer id, UpdateItineraryRequest request, String currentUsername) {; public void deleteItinerary(Integer id, String currentUsername) {; public ItineraryDayResponse addDay(Integer itineraryId, CreateDayRequest request, String currentUsername) {; public ItineraryDayResponse updateDay(Integer itineraryId, Integer dayId, UpdateDayRequest request, String currentUsername) {; public void deleteDay(Integer itineraryId, Integer dayId, String currentUsername) {; public ActivityResponse addActivity(Integer itineraryId, Integer dayId, CreateActivityRequest request, String currentUsername) {; public ActivityResponse updateActivity(Integer itineraryId, Integer dayId, Integer activityId, UpdateActivityRequest request, String currentUsername) {; public void deleteActivity(Integer itineraryId, Integer dayId, Integer activityId, String currentUsername) {

### Travel_Planner/Travel_Planner/service/impl/LocationIqGeocodingProvider.java
- Types: public class LocationIqGeocodingProvider implements GeocodingProvider {
- Method declarations (excerpt): public String getProviderName() {; public boolean isConfigured() {; public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {; public List<LocationSearchResultResponse> searchInArea(String query, int limit, Double latitude, Double longitude, List<Double> boundingBox, Integer radiusMeters) {; private boolean isLocalityOrRegionalQuery(String query) {; public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {; private String getPreferredLanguage() {; private LocationSearchResultResponse parseLocationItem(JsonNode node) {; private double parseCoordinate(JsonNode value) {

### Travel_Planner/Travel_Planner/service/impl/LocationRankingServiceImpl.java
- Types: public class LocationRankingServiceImpl implements LocationRankingService {; private record ScoredResult(LocationSearchResultResponse item, double score) {
- Method declarations (excerpt): private boolean isAdministrativeOrCityQuery(String normQuery) {; private boolean isAdministrativePlace(String type, String category) {; private boolean isFoodOrCommercialPlace(String type, String category) {; private boolean matchesServiceIntent(String normQuery, String type, String category) {; private boolean isFoodIntent(String normQuery) {; private boolean isIncompatibleFoodType(String type, String category) {; private String extractSpecifiedRegion(String query) {; public static String normalizeText(String input) {; private boolean isGenericServiceWord(String norm) {; private String stripAdministrativePrefix(String norm) {; private double haversineDistance(double lat1, double lon1, double lat2, double lon2) {; private record ScoredResult(LocationSearchResultResponse item, double score) {

### Travel_Planner/Travel_Planner/service/impl/LocationServiceImpl.java
- Types: public class LocationServiceImpl implements LocationService {
- Method declarations (excerpt): public List<LocationSearchResultResponse> searchLocations(String query, Integer limit, Double latitude, Double longitude) {; public List<LocationSearchResultResponse> searchLocationsUnified(String query, Integer limit, String mode, String sessionId) {; public List<LocationSearchResultResponse> searchLocations(String query, Integer limit, Double latitude, Double longitude, String provider, String sessionId) {; private GeographicTargetArea resolveTargetArea(String locationQuery) {; private boolean isIncompatibleFoodCandidate(LocationSearchResultResponse candidate) {; private String extractProvince(String formattedAddress) {; public LocationSearchResultResponse resolveTomTomPlace(String type, String id, String sessionId) {; private void validateOptionalCoordinates(Double latitude, Double longitude) {; public LocationSearchResultResponse reverseGeocode(Double latitude, Double longitude) {; public void clearCaches() {; public long getSearchCacheSize() {; public long getReverseCacheSize() {; private String buildSearchCacheKey(String query, int limit, Double latitude, Double longitude) {

### Travel_Planner/Travel_Planner/service/impl/OpenRouteServiceRoutingProvider.java
- Types: public class OpenRouteServiceRoutingProvider implements RoutingProvider {
- Method declarations (excerpt): public String getProviderName() {; public boolean isConfigured() {; public static String mapModeToProfile(String mode) {; public CachedRouteResult calculateRoute(String mode, List<WaypointCoordinate> waypoints) {

### Travel_Planner/Travel_Planner/service/impl/ProfileServiceImpl.java
- Types: public class ProfileServiceImpl implements ProfileService {
- Method declarations (excerpt): public UserResponse getCurrentProfile(String username) {; public UserResponse updateCurrentProfile(String username, UpdateProfileRequest request) {; private User findUser(String username) {; private String normalize(String value) {; private UserResponse toResponse(User user) {

### Travel_Planner/Travel_Planner/service/impl/PublicUserServiceImpl.java
- Types: public class PublicUserServiceImpl implements PublicUserService {
- Method declarations (excerpt): public PublicProfileResponse getProfile(Integer userId, String viewerUsername) {; public PublicProfileResponse getProfileByHandle(String handle, String viewerUsername) {; public PageResponse<ItinerarySummaryResponse> getItineraries(Integer userId, int page, int size) {; public void follow(Integer targetId, String username) {; public void unfollow(Integer targetId, String username) {; public PageResponse<PublicUserSummaryResponse> getFollowers(Integer userId, int page, int size) {; public PageResponse<PublicUserSummaryResponse> getFollowing(Integer userId, int page, int size) {; private User activeTarget(Integer id) {; private User activeViewer(String username) {; private int safePage(int page) {; private int safeSize(int size) {; private Pageable itineraryPage(int page, int size) {; private Pageable followPage(int page, int size) {; private CreatorSummaryResponse creator(User user) {; private PublicUserSummaryResponse userSummary(User user) {

### Travel_Planner/Travel_Planner/service/impl/QueryUnderstandingServiceImpl.java
- Types: public class QueryUnderstandingServiceImpl implements QueryUnderstandingService {; private record CategoryPrefix(String normalizedPrefix, String category) {}
- Method declarations (excerpt): private record CategoryPrefix(String normalizedPrefix, String category) {; public ParsedLocationQuery parseQuery(String rawQuery) {; private boolean isAdministrativeLocality(String raw, String normalized) {; private String resolveCategoryFromText(String normalizedText) {; private boolean isGenericCategoryWord(String normalized) {; private boolean isLikelyLocalityOrLandmark(String normalized) {; private boolean isFoodModifier(String normalized) {; public static String normalize(String input) {

### Travel_Planner/Travel_Planner/service/impl/RatingServiceImpl.java
- Types: public class RatingServiceImpl implements RatingService {
- Method declarations (excerpt): public RatingResponse rateItinerary(Integer itineraryId, RateItineraryRequest request, String currentUsername) {; public UserRatingStatusResponse getUserRating(Integer itineraryId, String currentUsername) {; public RatingSummaryResponse getRatingSummary(Integer itineraryId) {; public DeleteRatingResponse deleteRating(Integer itineraryId, String currentUsername) {; private User getAuthenticatedUser(String currentUsername) {; private Itinerary getPublicActiveItinerary(Integer itineraryId) {

### Travel_Planner/Travel_Planner/service/impl/RouteServiceImpl.java
- Types: public class RouteServiceImpl implements RouteService {
- Method declarations (excerpt): public Cache<String, CachedRouteResult> getRouteCache() {; public RouteResponse calculateDayRoute(Integer itineraryId, Integer dayId, String mode, String currentUsername) {; private String normalizeAndValidateMode(String mode) {; private boolean isValidCoordinate(BigDecimal lat, BigDecimal lon) {; public static String buildRouteCacheKey(String mode, List<WaypointCoordinate> coordinates) {; public static String sha256Hex(String input) {

### Travel_Planner/Travel_Planner/service/impl/SavedItineraryServiceImpl.java
- Types: public class SavedItineraryServiceImpl implements SavedItineraryService {
- Method declarations (excerpt): public SavedItineraryResponse saveItinerary(Integer itineraryId, String currentUsername) {; public SavedItineraryResponse removeSavedItinerary(Integer itineraryId, String currentUsername) {; public PageResponse<ItinerarySummaryResponse> getUserSavedItineraries(String currentUsername, int page, int size) {; private Itinerary validateAndGetItineraryForSave(Integer itineraryId, User user) {; private Map<Integer, Double> fetchAverageRatings(List<Integer> itineraryIds) {; private ItinerarySummaryResponse mapToSummaryResponse(Itinerary item, Double averageRating) {; private User getAuthenticatedUser(String currentUsername) {

### Travel_Planner/Travel_Planner/service/impl/TomTomPlacesProvider.java
- Types: public class TomTomPlacesProvider {
- Method declarations (excerpt): public boolean isEnabled() {; public List<LocationSearchResultResponse> suggest(String query, int limit, Double latitude, Double longitude, String sessionId) {; public LocationSearchResultResponse details(String type, String id, String sessionId) {; public List<LocationSearchResultResponse> discover(String query, String poiType, Double latitude, Double longitude, String sessionId) {; private Map<String, Object> point(double longitude, double latitude) {; private JsonNode post(String path, Map<String, Object> body, String sessionId, String attributes) {; private JsonNode request(String path, String sessionId, String attributes) {; private void headers(org.springframework.http.HttpHeaders headers, String sessionId, String attributes) {; private String baseUrl() {; private RuntimeException upstreamError(RestClientResponseException ex) {; private List<LocationSearchResultResponse> mapResults(JsonNode response, String sessionId) {; private LocationSearchResultResponse mapResult(JsonNode node, String sessionId, boolean suggestion) {; private void validateType(String type) {

### Travel_Planner/Travel_Planner/service/impl/UserHandleServiceImpl.java
- Types: public class UserHandleServiceImpl implements UserHandleService {
- Method declarations (excerpt): public String normalize(String handle) {; public boolean isValidFormat(String handle) {; public String generateUniqueHandle(String fullName, Integer userId) {; private String sanitizeFullNameToBase(String fullName) {

### Travel_Planner/Travel_Planner/service/ItineraryService.java
- Types: public interface ItineraryService {

### Travel_Planner/Travel_Planner/service/LocationRankingService.java
- Types: public interface LocationRankingService {

### Travel_Planner/Travel_Planner/service/LocationRateLimiter.java
- Types: public class LocationRateLimiter {
- Method declarations (excerpt): public boolean tryConsume(String key, boolean isAuthenticated) {; public long getAvailableTokens(String key, boolean isAuthenticated) {; public void reset(String key) {; public void clear() {; private Bucket createNewBucket(boolean isAuthenticated) {

### Travel_Planner/Travel_Planner/service/LocationService.java
- Types: public interface LocationService {

### Travel_Planner/Travel_Planner/service/ProfileService.java
- Types: public interface ProfileService {

### Travel_Planner/Travel_Planner/service/PublicUserService.java
- Types: public interface PublicUserService {

### Travel_Planner/Travel_Planner/service/QueryUnderstandingService.java
- Types: public interface QueryUnderstandingService {

### Travel_Planner/Travel_Planner/service/RatingService.java
- Types: public interface RatingService {

### Travel_Planner/Travel_Planner/service/RouteService.java
- Types: public interface RouteService {

### Travel_Planner/Travel_Planner/service/RoutingProvider.java
- Types: public interface RoutingProvider {

### Travel_Planner/Travel_Planner/service/SavedItineraryService.java
- Types: public interface SavedItineraryService {

### Travel_Planner/Travel_Planner/service/UserHandleService.java
- Types: public interface UserHandleService {

### Travel_Planner/Travel_Planner/TravelPlannerApplication.java
- Types: public class TravelPlannerApplication {
- Method declarations (excerpt): public static void main(String[] args) {

### Travel_Planner/Travel_Planner/util/HaversineUtil.java
- Types: public final class HaversineUtil {
- Method declarations (excerpt): public static double calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {; public static double calculateTotalDirectDistanceMeters(List<WaypointCoordinate> waypoints) {
