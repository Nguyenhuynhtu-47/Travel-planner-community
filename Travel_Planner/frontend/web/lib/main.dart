import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/locations/presentation/screens/admin_places_screen.dart';
import 'features/moderation/presentation/screens/admin_moderation_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MyApp({super.key, this.authNotifier, this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GlobalKey<NavigatorState> _navigatorKey;
  late final AuthNotifier _authNotifier;

  @override
  void initState() {
    super.initState();
    _navigatorKey = widget.navigatorKey ?? GlobalKey<NavigatorState>();
    _authNotifier = widget.authNotifier ?? AuthNotifier();

    ApiClient.globalOnUnauthorized = () {
      _authNotifier.handleSessionExpired();
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    };

    _authNotifier.checkAuthStatus();
  }

  @override
  void dispose() {
    ApiClient.globalOnUnauthorized = null;
    if (widget.authNotifier == null) {
      _authNotifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Travel Planner Web Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ListenableBuilder(
        listenable: _authNotifier,
        builder: (context, _) {
          if (_authNotifier.status == AuthStatus.initial) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          if (_authNotifier.isAuthenticated) {
            return WebPlaceholderScreen(authNotifier: _authNotifier);
          }

          return LoginScreen(authNotifier: _authNotifier);
        },
      ),
    );
  }
}

class WebPlaceholderScreen extends StatelessWidget {
  final AuthNotifier authNotifier;

  const WebPlaceholderScreen({super.key, required this.authNotifier});

  @override
  Widget build(BuildContext context) {
    final user = authNotifier.currentUser;
    final fullName = user?['fullName'] ?? user?['username'] ?? 'Quản trị viên';
    final role = user?['role'] ?? 'USER';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Planner Web Portal'),
        actions: [
          if (role.toString().toUpperCase() == 'ADMIN') ...[
            TextButton.icon(
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Kiểm duyệt'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminModerationScreen(authNotifier: authNotifier),
                  ),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.place_outlined, size: 18),
              label: const Text('Địa điểm'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminPlacesScreen(authNotifier: authNotifier),
                  ),
                );
              },
            ),
          ],
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(authNotifier: authNotifier),
                  ),
                );
              } else if (value == 'places') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminPlacesScreen(authNotifier: authNotifier),
                  ),
                );
              } else if (value == 'moderation') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminModerationScreen(authNotifier: authNotifier),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              if (role.toString().toUpperCase() == 'ADMIN') ...[
                const PopupMenuItem<String>(
                  value: 'moderation',
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 8),
                      Text('Kiểm duyệt cộng đồng'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'places',
                  child: Row(
                    children: [
                      Icon(Icons.place_outlined),
                      SizedBox(width: 8),
                      Text('Quản lý địa điểm'),
                    ],
                  ),
                ),
              ],
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('Hồ sơ'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      'Xin chào, $fullName ($role)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => authNotifier.logout(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 40,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Chào mừng, $fullName!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Phân quyền tài khoản: $role',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Đăng nhập Web thành công. Các phân hệ quản trị, kiểm duyệt và dashboard sẽ tiếp tục được triển khai ở các giai đoạn tiếp theo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (role.toString().toUpperCase() == 'ADMIN') ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.place_outlined),
                        label: const Text('Quản lý Địa điểm Chuẩn hóa (Places)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(260, 44),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminPlacesScreen(authNotifier: authNotifier),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng xuất'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(180, 44),
                      ),
                      onPressed: () => authNotifier.logout(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
