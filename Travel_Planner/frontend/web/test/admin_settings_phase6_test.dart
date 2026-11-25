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
import 'package:travel_planner_web/features/settings/data/settings_repository.dart';
import 'package:travel_planner_web/features/settings/presentation/screens/admin_settings_screen.dart';

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

  group('Phase 6 System Settings UI Tests (IDs 7.4 - 7.6)', () {
    testWidgets('Loads grouped settings, validates >5MB upload, updates setting, and toggles maintenance with confirmation', (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String currentUploadMb = '2';
      bool maintenanceMode = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/settings' && request.method == 'GET') {
          return http.Response(jsonEncode([
            {
              'settingKey': 'MODERATION_AUTO_HIDE_THRESHOLD',
              'settingValue': '5',
              'settingGroup': 'MODERATION',
              'description': 'Ngưỡng báo cáo tự động ẩn (1 - 50)',
              'valueType': 'INT',
              'updatedBy': 'SYSTEM',
            },
            {
              'settingKey': 'GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD',
              'settingValue': '0.85',
              'settingGroup': 'GEO',
              'description': 'Ngưỡng tin cậy địa lý (0.50 - 1.00)',
              'valueType': 'DOUBLE',
              'updatedBy': 'SYSTEM',
            },
            {
              'settingKey': 'MEDIA_MAX_IMAGE_SIZE_MB',
              'settingValue': currentUploadMb,
              'settingGroup': 'MEDIA',
              'description': 'Dung lượng ảnh tối đa (1 - 5 MB)',
              'valueType': 'INT',
              'updatedBy': 'SYSTEM',
            },
            {
              'settingKey': 'SYSTEM_MAINTENANCE_MODE',
              'settingValue': maintenanceMode.toString(),
              'settingGroup': 'MAINTENANCE',
              'description': 'Bật/tắt chế độ bảo trì',
              'valueType': 'BOOLEAN',
              'updatedBy': 'SYSTEM',
            },
            {
              'settingKey': 'SYSTEM_MAINTENANCE_MESSAGE',
              'settingValue': 'Hệ thống đang bảo trì định kỳ.',
              'settingGroup': 'MAINTENANCE',
              'description': 'Thông điệp bảo trì',
              'valueType': 'STRING',
              'updatedBy': 'SYSTEM',
            },
          ]), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/settings/MEDIA_MAX_IMAGE_SIZE_MB' && request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          currentUploadMb = body['settingValue'].toString();
          return http.Response(jsonEncode({
            'settingKey': 'MEDIA_MAX_IMAGE_SIZE_MB',
            'settingValue': currentUploadMb,
            'settingGroup': 'MEDIA',
            'description': 'Dung lượng ảnh tối đa (1 - 5 MB)',
            'valueType': 'INT',
            'updatedBy': 'admin_root',
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/settings/SYSTEM_MAINTENANCE_MODE' && request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          maintenanceMode = body['settingValue'].toString() == 'true';
          return http.Response(jsonEncode({
            'settingKey': 'SYSTEM_MAINTENANCE_MODE',
            'settingValue': maintenanceMode.toString(),
            'settingGroup': 'MAINTENANCE',
            'description': 'Bật/tắt chế độ bảo trì',
            'valueType': 'BOOLEAN',
            'updatedBy': 'admin_root',
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final authNotifier = await _buildNotifier(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            authNotifier: authNotifier,
            repository: SettingsRepository(apiClient: apiClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify grouped headings and static 5MB Servlet notice
      expect(find.text('Chính sách Kiểm duyệt Cộng đồng'), findsOneWidget);
      expect(find.text('Chuẩn hóa Địa lý'), findsOneWidget);
      expect(find.text('Giới hạn Tài nguyên Nghiệp vụ'), findsOneWidget);
      expect(find.text('Chế độ Bảo trì Toàn hệ thống'), findsOneWidget);
      expect(find.textContaining('Servlet Multipart tối đa là 5MB'), findsOneWidget);

      // Client-side validation: > 5MB rejected
      final mediaInput = find.byKey(const ValueKey('setting_input_MEDIA_MAX_IMAGE_SIZE_MB'));
      final mediaSave = find.byKey(const ValueKey('setting_save_MEDIA_MAX_IMAGE_SIZE_MB'));
      await tester.enterText(mediaInput, '7');
      await tester.tap(mediaSave);
      await tester.pumpAndSettle();
      expect(find.textContaining('từ 1 đến 5 MB'), findsOneWidget);
      expect(currentUploadMb, '2');

      // Valid update: 4MB
      await tester.enterText(mediaInput, '4');
      await tester.tap(mediaSave);
      await tester.pumpAndSettle();
      expect(currentUploadMb, '4');
      expect(find.text('Đã lưu cấu hình MEDIA_MAX_IMAGE_SIZE_MB.'), findsOneWidget);

      // Toggle maintenance mode -> confirmation dialog -> confirm
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận bật Chế độ Bảo trì'), findsOneWidget);

      await tester.tap(find.text('Xác nhận bật bảo trì'));
      await tester.pumpAndSettle();
      expect(maintenanceMode, isTrue);
      expect(find.text('Đang bảo trì'), findsOneWidget);
    });

    testWidgets('Handles error + retry state and blocks non-ADMIN users', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool failOnce = true;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/settings') {
          if (failOnce) {
            failOnce = false;
            return http.Response(jsonEncode({'message': 'Settings DB error'}), 500, headers: jsonHeaders);
          }
          return http.Response(jsonEncode([]), 200, headers: jsonHeaders);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final adminNotifier = await _buildNotifier(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            authNotifier: adminNotifier,
            repository: SettingsRepository(apiClient: apiClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có cấu hình hệ thống nào.'), findsOneWidget);

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
          home: AdminSettingsScreen(
            key: const ValueKey('non-admin-settings'),
            authNotifier: userNotifier,
            repository: SettingsRepository(apiClient: ApiClient(client: userMockClient)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Truy cập bị từ chối'), findsOneWidget);
    });
  });
}
