import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/network/api_client.dart';
import 'core/sync/app_sync_bus.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/itinerary/presentation/screens/my_itineraries_screen.dart';
import 'features/messaging/data/messaging_push_registration.dart';
import 'features/messaging/data/messaging_realtime_client.dart';
import 'features/messaging/presentation/screens/community_screen.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {
      debugPrint(
        '[FCM] Firebase initialization unavailable; push is disabled.',
      );
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MyApp({super.key, this.authNotifier, this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final GlobalKey<NavigatorState> _navigatorKey;
  late final AuthNotifier _authNotifier;

  @override
  void initState() {
    super.initState();
    _navigatorKey = widget.navigatorKey ?? GlobalKey<NavigatorState>();
    _authNotifier = widget.authNotifier ?? AuthNotifier();
    _authNotifier.beforeLogout = _unregisterPushBeforeLogout;
    _authNotifier.addListener(_syncPushSession);
    WidgetsBinding.instance.addObserver(this);

    ApiClient.globalOnUnauthorized = () {
      _authNotifier.handleSessionExpired();
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/login'),
          builder: (_) => LoginScreen(authNotifier: _authNotifier),
        ),
        (route) => false,
      );
    };

    _authNotifier.checkAuthStatus();
  }

  Future<void> _unregisterPushBeforeLogout(String token) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await MessagingPushRegistration.shared.unregisterBeforeLogout(token);
  }

  void _syncPushSession() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        Firebase.apps.isEmpty) {
      return;
    }
    final token = _authNotifier.isAuthenticated ? _authNotifier.token : null;
    MessagingPushRegistration.shared
        .syncSession(
          token,
          onForegroundMessage: (message) {
            final pushType = message.data['type']?.toString();
            if (pushType != 'MESSAGE_PUSH') {
              AppSyncBus.requestRefresh(SyncDomain.notifications);
              final notification = message.notification;
              final text = notification?.body ?? notification?.title;
              final messenger = ScaffoldMessenger.maybeOf(
                _navigatorKey.currentState?.context ?? context,
              );
              if (text != null && text.isNotEmpty) {
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(text),
                    action: SnackBarAction(
                      label: 'Xem',
                      onPressed: () => _openNotificationCenter(),
                    ),
                  ),
                );
              }
              return;
            }
            final conversationId = int.tryParse(
              message.data['conversationId']?.toString() ?? '',
            );
            MessagingRealtimeClient.shared.signalPushRefresh(conversationId);
          },
          onNotificationTap: (message) {
            if (message.data['type']?.toString() == 'MESSAGE_PUSH') {
              final navigator = _navigatorKey.currentState;
              if (navigator == null) return;
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => CommunityScreen(
                    authNotifier: _authNotifier,
                    initialTab: 0,
                  ),
                ),
              );
            } else {
              _openNotificationCenter();
            }
          },
        )
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('[FCM] Device registration is unavailable: $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  void _openNotificationCenter() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !_authNotifier.isAuthenticated) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(authNotifier: _authNotifier),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncPushSession();
  }

  @override
  void dispose() {
    ApiClient.globalOnUnauthorized = null;
    _authNotifier.removeListener(_syncPushSession);
    WidgetsBinding.instance.removeObserver(this);
    _authNotifier.beforeLogout = null;
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
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        );
      },
      home: SplashScreen(authNotifier: _authNotifier),
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
