import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'features/explore/presentation/screens/explore_screen.dart';
import 'features/itinerary/presentation/screens/my_itineraries_screen.dart';
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
      title: 'Travel Planner',
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

          return ExploreScreen(authNotifier: _authNotifier);
        },
      ),
    );
  }
}

class PlaceholderHomeScreen extends StatelessWidget {
  final AuthNotifier authNotifier;

  const PlaceholderHomeScreen({super.key, required this.authNotifier});

  @override
  Widget build(BuildContext context) {
    final user = authNotifier.currentUser;
    final fullName = user?['fullName'] ?? user?['username'] ?? 'Người dùng';
    final role = user?['role'] ?? 'USER';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Planner'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            onSelected: (value) {
              if (value == 'my_itineraries') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MyItinerariesScreen(authNotifier: authNotifier),
                  ),
                );
              } else if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(authNotifier: authNotifier),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('Hồ sơ'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'my_itineraries',
                child: Row(
                  children: [
                    Icon(Icons.map_outlined),
                    SizedBox(width: 8),
                    Text('Lịch trình của tôi'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 128),
                    child: Text(fullName, overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.person,
                  size: 44,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Xin chào, $fullName!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Vai trò: $role',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn đã đăng nhập thành công. Các tính năng khám phá lịch trình sẽ tiếp tục được phát triển.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(160, 44),
                ),
                onPressed: () => authNotifier.logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
