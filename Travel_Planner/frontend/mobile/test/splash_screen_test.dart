import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/splash/presentation/screens/splash_screen.dart';
import 'package:mobile/features/splash/presentation/widgets/landmark_painters.dart';

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

  group('Minimalist SplashScreen UI & Wanderlog Style Tests', () {
    testWidgets('Renders brand logo, greeting lines and enlarged travel landmark vector graphics', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 4800),
          ),
        ),
      );

      // Fast-forward animation partially
      await tester.pump(const Duration(milliseconds: 2500));

      // Brand Logo & Icon
      expect(find.byIcon(Icons.travel_explore_rounded), findsOneWidget);

      // Minimalist greeting & brand typography
      expect(find.text('Xin chào!'), findsOneWidget);
      expect(find.text('Cùng khám phá thế giới'), findsOneWidget);
      expect(find.text('Travel Planner'), findsOneWidget);

      // Landmark CustomPaint widgets (Eiffel, Airplane, Pisa, Liberty, Balloon, Pin)
      expect(find.byType(CustomPaint), findsWidgets);

      // Check enlarged sizes (25-30% enlarged from previous dimensions)
      expect(find.byWidgetPredicate((w) => w is SizedBox && w.width == 54 && w.height == 74), findsOneWidget); // Eiffel
      expect(find.byWidgetPredicate((w) => w is SizedBox && w.width == 66 && w.height == 58), findsOneWidget); // Airplane
      expect(find.byWidgetPredicate((w) => w is SizedBox && w.width == 48 && w.height == 72), findsOneWidget); // Pisa
      expect(find.byWidgetPredicate((w) => w is SizedBox && w.width == 52 && w.height == 74), findsOneWidget); // Liberty
      expect(find.byWidgetPredicate((w) => w is SizedBox && w.width == 52 && w.height == 70), findsOneWidget); // Balloon
      expect(find.byWidgetPredicate((w) => w is SizedBox && w.width == 48 && w.height == 62), findsOneWidget); // Pin
    });

    testWidgets('Landmark icons never overlap the logo or greeting text throughout animation', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SplashScreen(
            authNotifier: auth,
            animationDuration: const Duration(milliseconds: 4800),
          ),
        ),
      );

      // Check at multiple key frames of the animation (2.5s, 3.5s, 4.2s)
      for (final ms in [2500, 3500, 4200]) {
        await tester.pump(Duration(milliseconds: ms == 2500 ? 2500 : 1000));

        final greetingRect = tester.getRect(find.text('Xin chào!'));
        final mottoRect = tester.getRect(find.text('Cùng khám phá thế giới'));
        final brandRect = tester.getRect(find.text('Travel Planner'));
        final logoRect = tester.getRect(find.byIcon(Icons.travel_explore_rounded));

        final landmarkFinders = [
          find.byWidgetPredicate((w) => w is CustomPaint && w.painter is EiffelTowerPainter),
          find.byWidgetPredicate((w) => w is CustomPaint && w.painter is AirplanePainter),
          find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PisaTowerPainter),
          find.byWidgetPredicate((w) => w is CustomPaint && w.painter is StatueOfLibertyPainter),
          find.byWidgetPredicate((w) => w is CustomPaint && w.painter is HotAirBalloonPainter),
          find.byWidgetPredicate((w) => w is CustomPaint && w.painter is LocationPinPainter),
        ];

        for (final finder in landmarkFinders) {
          final element = finder.evaluate().first;
          final box = element.renderObject as RenderBox?;
          if (box == null || !box.hasSize) continue;
          final position = box.localToGlobal(Offset.zero);
          final landmarkRect = Rect.fromLTWH(position.dx, position.dy, box.size.width, box.size.height);

          // Verify zero intersection with text and logo
          expect(landmarkRect.overlaps(greetingRect), isFalse, reason: 'Landmark at $position overlaps "Xin chào!"');
          expect(landmarkRect.overlaps(mottoRect), isFalse, reason: 'Landmark at $position overlaps "Cùng khám phá thế giới"');
          expect(landmarkRect.overlaps(brandRect), isFalse, reason: 'Landmark at $position overlaps "Travel Planner"');
          expect(landmarkRect.overlaps(logoRect), isFalse, reason: 'Landmark at $position overlaps Logo');
        }
      }
    });

    testWidgets('Default animationDuration is 4800ms (+2.0s increase over previous 2800ms)', (tester) async {
      final auth = MockAuthNotifier(
        status: AuthStatus.initial,
        isAuthenticated: false,
      );

      final splash = SplashScreen(authNotifier: auth);
      expect(splash.animationDuration, const Duration(milliseconds: 4800));
    });

    testWidgets('Does NOT contain old ticket cards, long paragraph, or interactive buttons', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 80));

      // Removed legacy elements
      expect(find.text('Đà Lạt Mộng Mơ'), findsNothing);
      expect(find.text('3 ngày 2 đêm · 8 địa điểm'), findsNothing);
      expect(find.text('Hành trình vạn dặm · Khám phá đam mê'), findsNothing);
      expect(find.textContaining('Lập kế hoạch thông minh'), findsNothing);

      // No interactive buttons
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
      await tester.pump(const Duration(milliseconds: 80));

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

      // Now Auth resolves
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
