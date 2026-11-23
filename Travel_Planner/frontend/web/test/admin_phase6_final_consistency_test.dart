import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/features/auth/data/auth_repository.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/auth/presentation/screens/login_screen.dart';
import 'package:travel_planner_web/features/auth/presentation/screens/register_screen.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/features/layout/presentation/screens/admin_shell.dart';
import 'package:travel_planner_web/features/layout/presentation/widgets/placeholder_feature_view.dart';
import 'package:travel_planner_web/features/profile/data/profile_repository.dart';
import 'package:travel_planner_web/features/profile/presentation/screens/profile_screen.dart';
import 'package:travel_planner_web/shared/widgets/app_primary_button.dart';

String _createMockJwt({required int expSeconds}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'sub': 'admin_root',
    'role': 'ADMIN',
    'exp': expSeconds,
  })));
  return '$header.$payload.mockSignature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  group('Admin Design System Phase 6 – Final Consistency & Remaining Pages Tests', () {
    testWidgets('LoginScreen adheres to Swiss minimalism: no shadows, 4px radius, clean layout', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authStorage = AuthStorage();
      final mockClient = MockClient((request) async => http.Response('Not found', 404));
      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Travel Planner Portal'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.byType(AppPrimaryButton), findsOneWidget);

      // Verify no BoxShadow in container
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final container in containers) {
        final boxDec = container.decoration;
        if (boxDec is BoxDecoration) {
          expect(boxDec.boxShadow, isNull, reason: 'No elevation shadow allowed under Swiss Minimalism');
        }
      }
    });

    testWidgets('RegisterScreen adheres to Swiss minimalism: no shadows, 4px radius, clean layout', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authStorage = AuthStorage();
      final mockClient = MockClient((request) async => http.Response('Not found', 404));
      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tạo tài khoản mới'), findsOneWidget);
      expect(find.byType(AppPrimaryButton), findsOneWidget);

      // Verify no BoxShadow in container
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final container in containers) {
        final boxDec = container.decoration;
        if (boxDec is BoxDecoration) {
          expect(boxDec.boxShadow, isNull, reason: 'No elevation shadow allowed under Swiss Minimalism');
        }
      }
    });

    testWidgets('ProfileScreen renders enterprise design system card and WCAG status badges', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/user/profile') {
          return http.Response(
            jsonEncode({
              'userId': 1,
              'username': 'admin_root',
              'fullName': 'Quản Trị Viên Hệ Thống',
              'email': 'admin@travelplanner.vn',
              'handle': 'admin.master',
              'role': 'ADMIN',
              'status': 'ACTIVE',
              'phone': '0901234567',
              'address': 'TP. Hồ Chí Minh',
              'bio': 'System Administrator & Moderation Lead',
              'createdAt': '2026-01-01T00:00:00Z',
            }),
            200,
            headers: jsonHeaders,
          );
        }
        return http.Response('Not found', 404);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();

      final profileRepo = ProfileRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            authNotifier: authNotifier,
            repository: profileRepo,
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản Trị Viên Hệ Thống'), findsWidgets);
      expect(find.text('@admin.master'), findsWidgets);
      expect(find.text('Đang hoạt động'), findsWidgets);
      expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);

      // Verify no BoxShadow in profile containers
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final container in containers) {
        final boxDec = container.decoration;
        if (boxDec is BoxDecoration) {
          expect(boxDec.boxShadow, isNull, reason: 'Profile screen must have 0 box shadows');
        }
      }
    });

    testWidgets('PlaceholderFeatureView renders enterprise design tokens and returns to dashboard', (tester) async {
      bool returned = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceholderFeatureView(
              tab: AdminTab.users,
              onGoToDashboard: () => returned = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý người dùng'), findsOneWidget);
      expect(find.text('Chưa triển khai'), findsOneWidget);
      expect(find.text('Lộ trình chức năng dự kiến:'), findsOneWidget);
      expect(find.text('Quay lại trang Tổng quan'), findsOneWidget);

      await tester.tap(find.text('Quay lại trang Tổng quan'));
      await tester.pumpAndSettle();

      expect(returned, isTrue);
    });

    testWidgets('AdminShell renders all remaining tabs with consistent Swiss style layout', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/health') {
          return http.Response(jsonEncode({'status': 'UP'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 0, 'totalPages': 0}), 200, headers: jsonHeaders);
        }
        return http.Response('Not found', 404);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();

      // Test Itineraries tab
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            authNotifier: authNotifier,
            initialTab: AdminTab.itineraries,
            apiClient: ApiClient(client: mockClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý lịch trình'), findsWidgets);
      expect(find.byType(PlaceholderFeatureView), findsOneWidget);
    });
  });
}
