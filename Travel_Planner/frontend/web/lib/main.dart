import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/layout/domain/admin_tab.dart';
import 'features/layout/presentation/screens/admin_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final GlobalKey<NavigatorState>? navigatorKey;
  final ApiClient? apiClient;

  const MyApp({super.key, this.authNotifier, this.navigatorKey, this.apiClient});

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
            final routeTab = AdminTab.fromRoute(
              Uri.base.fragment.isNotEmpty ? Uri.base.fragment : Uri.base.path,
            );
            return AdminShell(
              authNotifier: _authNotifier,
              initialTab: routeTab,
              apiClient: widget.apiClient,
            );
          }

          return LoginScreen(authNotifier: _authNotifier);
        },
      ),
    );
  }
}

/// Backwards-compatible alias for existing tests or routes.
class WebPlaceholderScreen extends StatelessWidget {
  final AuthNotifier authNotifier;

  const WebPlaceholderScreen({super.key, required this.authNotifier});

  @override
  Widget build(BuildContext context) {
    return AdminShell(authNotifier: authNotifier);
  }
}
