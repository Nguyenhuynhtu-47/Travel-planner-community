import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/splash/presentation/screens/splash_screen.dart';

class MockAuthNotifier extends AuthNotifier {
  AuthStatus _mockStatus;
  bool _mockIsAuthenticated;

  MockAuthNotifier({
    AuthStatus status = AuthStatus.authenticated,
    bool isAuthenticated = true,
  })  : _mockStatus = status,
        _mockIsAuthenticated = isAuthenticated;

  @override
  AuthStatus get status => _mockStatus;

  @override
  bool get isAuthenticated => _mockIsAuthenticated;

  void setMockStatus(AuthStatus status, bool isAuthenticated) {
    _mockStatus = status;
    _mockIsAuthenticated = isAuthenticated;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen UI & Layout Tests', () {
    testWidgets('Renders brand logo, title, slogan, description and travel illustration', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 200),
          ),
        ),
      );

      // Fast-forward animation to completion
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Travel Planner'), findsOneWidget);
      expect(find.text('Hành trình vạn dặm · Khám phá đam mê'), findsOneWidget);
      expect(
        find.textContaining('Lập kế hoạch thông minh, quản lý lịch trình chi tiết'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.travel_explore_rounded), findsOneWidget);
      expect(find.text('Đà Lạt Mộng Mơ'), findsOneWidget);
      expect(find.byIcon(Icons.flight_takeoff_rounded), findsOneWidget);
    });

    testWidgets('Does NOT contain Continue, Login, or Register buttons', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 100),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tiếp tục'), findsNothing);
      expect(find.text('Đăng nhập'), findsNothing);
      expect(find.text('Đăng ký'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('Back navigation is disabled via PopScope(canPop: false)', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 100),
          ),
        ),
      );

      final popScopeFinder = find.byWidgetPredicate(
        (w) => w is PopScope && w.canPop == false,
      );
      expect(popScopeFinder, findsOneWidget);
    });

    testWidgets('Responsive on small screen (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 100),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Travel Planner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SplashScreen Synchronization & Navigation Logic', () {
    testWidgets('Navigates to Home (isAuthenticated = true) when animation completes and auth is ready', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.authenticated,
        isAuthenticated: true,
      );

      bool? navigatedTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 300),
            onNavigate: (isAuth) {
              navigatedTarget = isAuth;
            },
          ),
        ),
      );

      // Mid-animation: should NOT navigate yet
      await tester.pump(const Duration(milliseconds: 150));
      expect(navigatedTarget, isNull);

      // Animation complete: should navigate with true
      await tester.pump(const Duration(milliseconds: 200));
      expect(navigatedTarget, isTrue);
    });

    testWidgets('Navigates to Login (isAuthenticated = false) when animation completes and unauthenticated', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.unauthenticated,
        isAuthenticated: false,
      );

      bool? navigatedTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 300),
            onNavigate: (isAuth) {
              navigatedTarget = isAuth;
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      expect(navigatedTarget, isFalse);
    });

    testWidgets('Waits for Auth initialization if Auth is slower than animation', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      bool? navigatedTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 200),
            onNavigate: (isAuth) {
              navigatedTarget = isAuth;
            },
          ),
        ),
      );

      // Animation completed at 200ms, but Auth is still initial
      await tester.pump(const Duration(milliseconds: 250));
      expect(navigatedTarget, isNull);

      // Now Auth resolves at 500ms
      auth.setMockStatus(AuthStatus.authenticated, true);
      await tester.pump();

      expect(navigatedTarget, isTrue);
    });

    testWidgets('Waits for animation if Auth resolves faster than animation', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      bool? navigatedTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 500),
            onNavigate: (isAuth) {
              navigatedTarget = isAuth;
            },
          ),
        ),
      );

      // Auth resolves quickly at 100ms
      auth.setMockStatus(AuthStatus.authenticated, true);
      await tester.pump(const Duration(milliseconds: 100));

      // Animation is only at 200ms of 500ms -> MUST NOT navigate yet
      expect(navigatedTarget, isNull);

      // Animation completes at 500ms
      await tester.pump(const Duration(milliseconds: 450));
      expect(navigatedTarget, isTrue);
    });
  });
}
