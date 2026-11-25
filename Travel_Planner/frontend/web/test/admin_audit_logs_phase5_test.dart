import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/features/audit_logs/data/audit_log_repository.dart';
import 'package:travel_planner_web/features/audit_logs/presentation/screens/admin_audit_logs_screen.dart';
import 'package:travel_planner_web/features/auth/data/auth_repository.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';

String _createMockJwt({required int expSeconds, String role = 'ADMIN'}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'admin_root', 'role': role, 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

Future<AuthNotifier> _buildNotifier(
  MockClient mockClient, {
  String role = 'ADMIN',
}) async {
  SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
  final storage = AuthStorage();
  final token = _createMockJwt(
    expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    role: role,
  );
  await storage.saveToken(token);
  await storage.saveUser({'userId': 1, 'username': 'admin_root', 'role': role});
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

  group('Phase 5 Audit Logs UI Tests', () {
    testWidgets('Renders audit logs table, preserves filters across pagination, and displays masked detail modal', (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<Map<String, String>> capturedQueries = [];

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/audit-logs') {
          capturedQueries.add(request.url.queryParameters);
          final page = int.tryParse(request.url.queryParameters['page'] ?? '0') ?? 0;

          if (page == 1) {
            return http.Response(jsonEncode({
              'content': [
                {
                  'logId': 90,
                  'actorId': 1,
                  'actorUsername': 'admin_root',
                  'actionType': 'USER_BAN',
                  'targetType': 'USER',
                  'targetId': '205',
                  'reason': 'Spam page 2',
                  'resultStatus': 'SUCCESS',
                  'ipAddress': '10.0.0.5',
                  'correlationId': 'corr-p2',
                  'createdAt': '2026-11-20T09:00:00',
                },
              ],
              'pageNumber': 1,
              'pageSize': 20,
              'totalElements': 21,
              'totalPages': 2,
              'last': true,
            }), 200, headers: jsonHeaders);
          }

          return http.Response(jsonEncode({
            'content': [
              {
                'logId': 101,
                'actorId': 1,
                'actorUsername': 'admin_root',
                'actionType': 'ITINERARY_MODERATE',
                'targetType': 'ITINERARY',
                'targetId': '305',
                'reason': 'Vi phạm nội dung',
                'resultStatus': 'SUCCESS',
                'ipAddress': '127.0.0.1',
                'correlationId': 'corr-101',
                'createdAt': '2026-11-25T10:30:00',
              },
            ],
            'pageNumber': 0,
            'pageSize': 20,
            'totalElements': 21,
            'totalPages': 2,
            'last': false,
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/audit-logs/101') {
          return http.Response(jsonEncode({
            'logId': 101,
            'actorId': 1,
            'actorUsername': 'admin_root',
            'actionType': 'ITINERARY_MODERATE',
            'targetType': 'ITINERARY',
            'targetId': '305',
            'reason': 'Vi phạm nội dung',
            'resultStatus': 'SUCCESS',
            'ipAddress': '127.0.0.1',
            'userAgent': 'Chrome-Test-Agent',
            'correlationId': 'corr-101',
            'createdAt': '2026-11-25T10:30:00',
            'beforeDataJson': '{"status":"ACTIVE","password":"***MASKED***"}',
            'afterDataJson': '{"status":"HIDDEN","token":"***MASKED***"}',
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final authNotifier = await _buildNotifier(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAuditLogsScreen(
            authNotifier: authNotifier,
            repository: AuditLogRepository(apiClient: apiClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify table row
      expect(find.text('admin_root'), findsOneWidget);
      expect(find.text('ITINERARY_MODERATE'), findsOneWidget);
      expect(find.text('ITINERARY #305'), findsOneWidget);

      // Apply keyword filter
      await tester.enterText(find.byType(TextField).first, 'corr-101');
      await tester.tap(find.text('Lọc'));
      await tester.pumpAndSettle();
      expect(capturedQueries.last['keyword'], 'corr-101');

      // Switch to page 2 and verify keyword filter is preserved
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(capturedQueries.last['page'], '1');
      expect(capturedQueries.last['keyword'], 'corr-101');
      expect(find.text('USER #205'), findsOneWidget);

      // Switch back to page 1 and open detail dialog
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chi tiết').first);
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết Nhật ký Kiểm toán #101 (Chỉ đọc)'), findsOneWidget);
      expect(find.text('Chrome-Test-Agent'), findsOneWidget);
      expect(find.text('corr-101'), findsWidgets);
      expect(find.textContaining('***MASKED***'), findsWidgets);
      expect(find.text('Snapshot Trước (Before)'), findsOneWidget);
      expect(find.text('Snapshot Sau (After)'), findsOneWidget);

      // Read-only: no edit/delete buttons
      expect(find.text('Xóa'), findsNothing);
      expect(find.text('Sửa'), findsNothing);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
    });

    testWidgets('Handles error + retry, empty state, and blocks non-ADMIN users', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool failOnce = true;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/audit-logs') {
          if (failOnce) {
            failOnce = false;
            return http.Response(jsonEncode({'message': 'Lỗi kết nối Audit DB'}), 500, headers: jsonHeaders);
          }
          return http.Response(jsonEncode({
            'content': [],
            'pageNumber': 0,
            'pageSize': 20,
            'totalElements': 0,
            'totalPages': 0,
            'last': true,
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final adminNotifier = await _buildNotifier(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAuditLogsScreen(
            authNotifier: adminNotifier,
            repository: AuditLogRepository(apiClient: apiClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error state + Retry -> Empty state
      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy bản ghi nhật ký kiểm toán nào.'), findsOneWidget);

      // Non-ADMIN block
      final userMockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 2, 'username': 'normal_user', 'role': 'USER'}), 200, headers: jsonHeaders);
        }
        return http.Response('Forbidden', 403);
      });
      final userNotifier = await _buildNotifier(userMockClient, role: 'USER');
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAuditLogsScreen(
            key: const ValueKey('non-admin'),
            authNotifier: userNotifier,
            repository: AuditLogRepository(apiClient: ApiClient(client: userMockClient)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Truy cập bị từ chối'), findsOneWidget);
    });
  });
}
