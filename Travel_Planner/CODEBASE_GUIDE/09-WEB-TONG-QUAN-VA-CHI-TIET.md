# 09 — Flutter Web

Web là app riêng ở frontend/web, hiện tập trung auth, profile, quản trị destination, core network/theme/map constants và shared widgets. Auth notifier/repository/storage quản lý đăng nhập; destination model/repository/dialog/screen gọi API quản trị; profile repository/screen hiển thị hồ sơ. Backend có admin destination endpoints tương ứng.

WebMapView hiển thị bản đồ web, có yêu cầu cấu hình nền tảng riêng. Admin destination là danh mục điểm đến, khác activity cá nhân trong itinerary. Có 22 Dart source và 5 test ở lần kiểm kê.

## Danh mục Dart

### core/constants/api_constants.dart
- Types: class ApiConstants {

### core/constants/map_constants.dart
- Types: class MapConstants {

### core/network/api_client.dart
- Types: class ApiClient {

### core/network/api_exception.dart
- Types: class ApiException implements Exception {

### core/theme/app_colors.dart
- Types: class AppColors {

### core/theme/app_theme.dart
- Types: class AppTheme {

### features/auth/data/auth_repository.dart
- Types: class AuthRepository {

### features/auth/data/auth_storage.dart
- Types: class AuthStorage {

### features/auth/presentation/auth_notifier.dart
- Types: enum AuthStatus { initial, loading, authenticated, unauthenticated, error }; class AuthNotifier extends ChangeNotifier {

### features/auth/presentation/screens/login_screen.dart
- Types: class LoginScreen extends StatefulWidget {; class _LoginScreenState extends State<LoginScreen> {

### features/auth/presentation/screens/register_screen.dart
- Types: class RegisterScreen extends StatefulWidget {; class _RegisterScreenState extends State<RegisterScreen> {

### features/locations/data/destination_repository.dart
- Types: class DestinationRepository {

### features/locations/data/models/destination_model.dart
- Types: class Destination {; class CreateDestinationRequest {; class UpdateDestinationRequest {

### features/locations/presentation/screens/admin_destinations_screen.dart
- Types: class AdminDestinationsScreen extends StatefulWidget {; class _AdminDestinationsScreenState extends State<AdminDestinationsScreen> {

### features/locations/presentation/widgets/destination_form_dialog.dart
- Types: class DestinationFormDialog extends StatefulWidget {; class _DestinationFormDialogState extends State<DestinationFormDialog> {

### features/locations/presentation/widgets/hide_destination_dialog.dart
- Types: class HideDestinationDialog extends StatefulWidget {; class _HideDestinationDialogState extends State<HideDestinationDialog> {

### features/profile/data/profile_repository.dart
- Types: class ProfileRepository {

### features/profile/presentation/screens/profile_screen.dart
- Types: class ProfileScreen extends StatefulWidget {; class _ProfileScreenState extends State<ProfileScreen> {

### main.dart
- Types: class MyApp extends StatefulWidget {; class _MyAppState extends State<MyApp> {; class WebPlaceholderScreen extends StatelessWidget {

### shared/widgets/app_primary_button.dart
- Types: class AppPrimaryButton extends StatelessWidget {

### shared/widgets/app_text_field.dart
- Types: class AppTextField extends StatefulWidget {; class _AppTextFieldState extends State<AppTextField> {

### shared/widgets/web_map_view.dart
- Types: class WebMapView extends StatefulWidget {; class _WebMapViewState extends State<WebMapView> {
