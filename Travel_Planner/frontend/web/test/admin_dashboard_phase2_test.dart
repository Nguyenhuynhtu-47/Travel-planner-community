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
import 'package:travel_planner_web/features/dashboard/data/dashboard_repository.dart';
import 'package:travel_planner_web/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/features/layout/presentation/screens/admin_shell.dart';

String _createMockJwt({required int expSeconds}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'webadmin', 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

class _FailOnceDashboardRepository extends DashboardRepository {
  int callCount = 0;
  final DashboardRepository fallbackRepo;

  _FailOnceDashboardRepository(this.fallbackRepo);

  @override
  Future<AdminDashboardData> fetchDashboardData(String? token, {int days = 30}) async {
    callCount++;
    if (callCount == 1) {
      throw Exception('Connection reset by peer');
    }
    return fallbackRepo.fetchDashboardData(token, days: days);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Dashboard Phase 2 – Operational Workspaces & Real Data Tests', () {
    testWidgets('Renders real pending reports and recent posts with operational actions', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response(
            jsonEncode({
              'status': 'UP',
              'service': 'travel-planner-backend',
              'timestamp': '2026-11-23T18:45:00',
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/places') {
          return http.Response(
            jsonEncode({'content': [], 'totalElements': 88}),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/community/posts') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'postId': 201,
                  'content': 'Khám phá Đà Lạt 3 ngày 2 đêm cùng bạn bè',
                  'author': {'userId': 15, 'handle': 'dalat_traveler', 'displayName': 'Dalat Lover'},
                  'mediaUrls': ['https://example.com/img1.jpg', 'https://example.com/img2.jpg'],
                  'status': 'ACTIVE',
                  'createdAt': '2026-11-23T10:00:00',
                }
              ],
              'totalElements': 64,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'reportId': 45,
                  'postId': 201,
                  'reason': 'Nội dung quảng cáo spam liên kết ngoài',
                  'status': 'PENDING',
                  'createdAt': '2026-11-23T14:30:00',
                  'reporter': {'userId': 32, 'handle': 'vigilant_user'},
                }
              ],
              'totalElements': 7,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(
            jsonEncode({'content': [], 'totalElements': 310}),
            200,
            headers: jsonHeaders,
          );
        }
        return http.Response('Not Found', 404);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();

      AdminTab? targetTab;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(
              authNotifier: authNotifier,
              repository: DashboardRepository(apiClient: ApiClient(client: mockClient)),
              onNavigateTab: (tab) => targetTab = tab,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify KPI Metrics
      expect(find.text('Địa điểm chuẩn hóa'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('Bài viết cộng đồng'), findsOneWidget);
      expect(find.text('64'), findsOneWidget);
      expect(find.text('Báo cáo chờ xử lý'), findsOneWidget);
      expect(find.text('7'), findsWidgets); // metric count + badge count
      expect(find.text('Tài nguyên Media'), findsOneWidget);
      expect(find.text('310'), findsOneWidget);

      // Verify Real Pending Reports
      expect(find.text('Báo cáo vi phạm đang chờ xử lý'), findsOneWidget);
      expect(find.text('#45'), findsOneWidget);
      expect(find.text('Nội dung quảng cáo spam liên kết ngoài'), findsOneWidget);
      expect(find.textContaining('Bài viết #201'), findsOneWidget);
      expect(find.textContaining('Người báo: @vigilant_user'), findsOneWidget);

      // Verify Real Recent Posts
      expect(find.text('Bài viết cộng đồng gần đây'), findsOneWidget);
      expect(find.text('Khám phá Đà Lạt 3 ngày 2 đêm cùng bạn bè'), findsOneWidget);
      expect(find.textContaining('@dalat_traveler'), findsOneWidget);
      expect(find.textContaining('2 ảnh'), findsOneWidget);

      // Verify System Telemetry Bar
      expect(find.text('Dịch vụ: travel-planner-backend (UP)'), findsOneWidget);
      expect(find.text('Thời gian máy chủ: 2026-11-23T18:45:00'), findsOneWidget);

      // Test Action Button: Xử lý -> Navigates to Reports
      await tester.tap(find.text('Xử lý'));
      await tester.pump();
      expect(targetTab, AdminTab.reports);

      // Test All Posts -> Navigates to Posts
      await tester.tap(find.text('Xem tất cả →'));
      await tester.pump();
      expect(targetTab, AdminTab.posts);
    });

    testWidgets('Dashboard renders clean error banner with retry button on failure', (tester) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/health') {
          return http.Response(jsonEncode({'status': 'UP'}), 200, headers: jsonHeaders);
        }
        return http.Response(jsonEncode({'content': [], 'totalElements': 0}), 200, headers: jsonHeaders);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();

      final failOnceRepo = _FailOnceDashboardRepository(
        DashboardRepository(apiClient: ApiClient(client: mockClient)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(
              authNotifier: authNotifier,
              repository: failOnceRepo,
              onNavigateTab: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('Không thể tải số liệu bảng điều khiển'), findsOneWidget);

      // Click retry
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(failOnceRepo.callCount, 2);
      expect(find.text('Địa điểm chuẩn hóa'), findsOneWidget);
    });
  });

  group('Admin Shell Responsive Viewport Tests', () {
    testWidgets('Auto-collapses sidebar on narrow screens (< 960px) and maintains expanded on desktop', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_responsive', 'role': 'ADMIN'});

      final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({'userId': 1, 'username': 'admin_responsive', 'role': 'ADMIN'}),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/health') {
          return http.Response(jsonEncode({'status': 'UP'}), 200, headers: jsonHeaders);
        }
        return http.Response(jsonEncode({'content': [], 'totalElements': 0}), 200, headers: jsonHeaders);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            authNotifier: authNotifier,
            apiClient: ApiClient(client: mockClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On narrow screen (< 960px), collapsed mode displays tooltip button
      expect(find.byTooltip('Mở rộng menu'), findsOneWidget);

      // Resize to desktop (1440px)
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();

      // On desktop, expanded mode displays text
      expect(find.text('Thu gọn menu'), findsOneWidget);
    });
  });
}
