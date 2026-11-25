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

String _createMockJwt({required int expSeconds, String role = 'ADMIN'}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'admin_root', 'role': role, 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

Future<AuthNotifier> _buildAdminNotifier(MockClient mockClient) async {
  SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
  final storage = AuthStorage();
  final token = _createMockJwt(
    expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  );
  await storage.saveToken(token);
  await storage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});
  final notifier = AuthNotifier(
    storage: storage,
    repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
  );
  await notifier.checkAuthStatus();
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  group('Phase 7 Dashboard v2 Tests (IDs 7.7 - 7.8)', () {
    testWidgets('Loads unified summary & analytics in single summary call, switches time range, and navigates KPI cards', (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> requestedDays = [];
      int summaryCalls = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/dashboard/summary') {
          summaryCalls++;
          return http.Response(jsonEncode({
            'healthStatus': 'UP',
            'serverTimestamp': '2026-11-25T14:00:00',
            'totalUsers': 150,
            'activeUsers': 142,
            'bannedUsers': 8,
            'totalPlaces': 80,
            'activePlaces': 75,
            'linkedPlaces': 60,
            'placeAreaCoveragePercentage': 75.0,
            'totalItineraries': 45,
            'publicItineraries': 30,
            'privateItineraries': 12,
            'activeItineraries': 42,
            'hiddenItineraries': 3,
            'totalPosts': 110,
            'hiddenPosts': 4,
            'pendingReportsCount': 6,
            'totalMediaAssets': 240,
            'deadLetterMediaAssets': 2,
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/dashboard/analytics') {
          final days = int.tryParse(request.url.queryParameters['days'] ?? '30') ?? 30;
          requestedDays.add(days);
          return http.Response(jsonEncode({
            'days': days,
            'fromDate': '2026-11-01',
            'toDate': '2026-11-25',
            'userRegistrationsDaily': [
              {'label': '2026-11-24', 'count': 4},
              {'label': '2026-11-25', 'count': 7},
            ],
            'communityPostsWeekly': [
              {'label': '2026-W47', 'count': 12},
            ],
            'topPlaces': [
              {
                'placeId': 10,
                'name': 'Hồ Hoàn Kiếm',
                'category': 'ATTRACTION',
                'areaName': 'Phường Hoàn Kiếm',
                'itineraryCount': 18,
              },
            ],
            'recentAuditLogs': [
              {
                'logId': 501,
                'actorId': 1,
                'actorUsername': 'admin_root',
                'actionType': 'SETTING_UPDATE',
                'targetType': 'SYSTEM_SETTING',
                'targetId': 'MEDIA_MAX_IMAGE_SIZE_MB',
                'resultStatus': 'SUCCESS',
                'createdAt': '2026-11-25T13:50:00',
              },
            ],
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not Found', 404);
      });

      final authNotifier = await _buildAdminNotifier(mockClient);
      AdminTab? navigatedTab;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            authNotifier: authNotifier,
            repository: DashboardRepository(apiClient: ApiClient(client: mockClient)),
            onNavigateTab: (tab) => navigatedTab = tab,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Single summary API call
      expect(summaryCalls, 1);
      expect(requestedDays, [30]);

      // Verify all 6 core metric groups
      expect(find.text('Người dùng hệ thống'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('Địa điểm chuẩn hóa'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('Lịch trình du lịch'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('Bài viết cộng đồng'), findsOneWidget);
      expect(find.text('110'), findsOneWidget);
      expect(find.text('Báo cáo chờ xử lý'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Tài nguyên Media'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);

      // Verify charts, distribution, top places & recent audit log feed
      expect(find.text('Người dùng mới đăng ký theo ngày'), findsOneWidget);
      expect(find.textContaining('Tổng: 11'), findsOneWidget);
      expect(find.text('Bài viết cộng đồng chia sẻ theo tuần'), findsOneWidget);
      expect(find.textContaining('Tổng: 12'), findsOneWidget);
      expect(find.text('Phân bố lịch trình'), findsOneWidget);
      expect(find.text('Top địa điểm được đưa vào lịch trình'), findsOneWidget);
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      expect(find.text('Hoạt động quản trị gần đây'), findsOneWidget);
      expect(find.textContaining('admin_root • SETTING_UPDATE'), findsOneWidget);

      // Switch time range to 7 days -> both charts refresh with days=7
      await tester.tap(find.text('7 ngày'));
      await tester.pumpAndSettle();
      expect(requestedDays.last, 7);

      // Tap KPI card -> navigates to Users tab
      await tester.tap(find.text('Người dùng hệ thống'));
      await tester.pumpAndSettle();
      expect(navigatedTab, AdminTab.users);
    });

    testWidgets('Handles error + retry state cleanly on summary failure', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool failOnce = true;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/dashboard/summary') {
          if (failOnce) {
            failOnce = false;
            return http.Response(jsonEncode({'message': 'Summary error'}), 500, headers: jsonHeaders);
          }
          return http.Response(jsonEncode({
            'healthStatus': 'UP',
            'totalUsers': 0,
            'activeUsers': 0,
            'bannedUsers': 0,
            'totalPlaces': 0,
            'activePlaces': 0,
            'linkedPlaces': 0,
            'placeAreaCoveragePercentage': 0.0,
            'totalItineraries': 0,
            'publicItineraries': 0,
            'hiddenItineraries': 0,
            'totalPosts': 0,
            'hiddenPosts': 0,
            'pendingReportsCount': 0,
            'totalMediaAssets': 0,
            'deadLetterMediaAssets': 0,
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/dashboard/analytics') {
          return http.Response(jsonEncode({
            'days': 30,
            'userRegistrationsDaily': [],
            'communityPostsWeekly': [],
            'recentAuditLogs': [],
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not Found', 404);
      });

      final authNotifier = await _buildAdminNotifier(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            authNotifier: authNotifier,
            repository: DashboardRepository(apiClient: ApiClient(client: mockClient)),
            onNavigateTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      // Empty state messages for charts & audit logs
      expect(find.text('Chưa có lượt đăng ký mới trong khoảng thời gian này.'), findsOneWidget);
      expect(find.text('Chưa có bài viết mới trong khoảng thời gian này.'), findsOneWidget);
      expect(find.text('Chưa có nhật ký hoạt động quản trị nào.'), findsOneWidget);
    });
  });
}
