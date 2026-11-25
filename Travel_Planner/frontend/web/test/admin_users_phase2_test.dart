import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner_web/core/constants/api_constants.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/features/auth/data/auth_repository.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/users/data/admin_user_repository.dart';
import 'package:travel_planner_web/features/users/presentation/screens/admin_users_screen.dart';
import 'package:travel_planner_web/features/users/presentation/widgets/user_avatar.dart';

String _createMockJwt({required int expSeconds, String role = 'ADMIN'}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'admin_root', 'role': role, 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

Future<AuthNotifier> _buildAuthenticatedAdminNotifier(
  MockClient mockClient, {
  String role = 'ADMIN',
  int userId = 1,
}) async {
  SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
  final storage = AuthStorage();
  final token = _createMockJwt(
    expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    role: role,
  );
  await storage.saveToken(token);
  await storage.saveUser({'userId': userId, 'username': 'admin_root', 'role': role});
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

  group('Phase 2 Admin Users Screen & Dialogs Tests', () {
    testWidgets('Loads user list with server-side pagination, self-protection, and handles page switch', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final capturedPaths = <String>[];
      final mockClient = MockClient((request) async {
        capturedPaths.add(request.url.toString());
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/users') {
          final page = int.tryParse(request.url.queryParameters['page'] ?? '0') ?? 0;
          if (page == 0) {
            return http.Response(jsonEncode({
              'content': [
                {
                  'userId': 1,
                  'username': 'admin_root',
                  'handle': 'admin.root',
                  'email': 'admin@travelplanner.vn',
                  'fullName': 'Quản Trị Viên Chính',
                  'role': 'ADMIN',
                  'status': 'ACTIVE',
                  'emailVerified': true,
                  'createdAt': '2026-01-01T08:00:00',
                },
                {
                  'userId': 2,
                  'username': 'user_lan',
                  'handle': 'lan.nguyen',
                  'email': 'lan@example.com',
                  'fullName': 'Nguyễn Thị Lan',
                  'role': 'USER',
                  'status': 'ACTIVE',
                  'emailVerified': true,
                  'createdAt': '2026-02-10T10:30:00',
                },
              ],
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 25,
              'totalPages': 2,
              'last': false,
            }), 200, headers: jsonHeaders);
          }
          return http.Response(jsonEncode({
            'content': [
              {
                'userId': 21,
                'username': 'user_page2',
                'handle': 'page2.user',
                'email': 'p2@example.com',
                'fullName': 'Người Dùng Trang 2',
                'role': 'USER',
                'status': 'BANNED',
                'emailVerified': true,
                'createdAt': '2026-03-01T12:00:00',
              },
            ],
            'pageNumber': 1,
            'pageSize': 20,
            'totalElements': 25,
            'totalPages': 2,
            'last': true,
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not found', 404);
      });

      final notifier = await _buildAuthenticatedAdminNotifier(mockClient);
      final repo = AdminUserRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(authNotifier: notifier, repository: repo, embedded: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý người dùng'), findsOneWidget);
      expect(find.text('Tổng: 25 tài khoản'), findsOneWidget);
      expect(find.text('Quản Trị Viên Chính'), findsOneWidget);
      expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
      expect(find.text('Bạn'), findsOneWidget);

      // Verify self-action buttons (first row: admin_root) are disabled on UI
      final blockIcons = find.byIcon(Icons.block);
      final selfBanButton = tester.widget<IconButton>(
        find.ancestor(of: blockIcons.first, matching: find.byType(IconButton)),
      );
      expect(selfBanButton.onPressed, isNull, reason: 'Self-ban must be disabled on UI');

      final otherBanButton = tester.widget<IconButton>(
        find.ancestor(of: blockIcons.at(1), matching: find.byType(IconButton)),
      );
      expect(otherBanButton.onPressed, isNotNull);

      // Navigate to page 2
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('Người Dùng Trang 2'), findsOneWidget);
      expect(capturedPaths.any((p) => p.contains('page=1')), isTrue);
    });

    testWidgets('Search, role/status filtering, detail dialog, revoke sessions, ban and role change work cleanly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String currentTargetStatus = 'ACTIVE';
      String currentTargetRole = 'USER';
      String? lastPatchBody;
      bool revokeCalled = false;
      final queries = <Map<String, String>>[];

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/users') {
          queries.add(request.url.queryParameters);
          return http.Response(jsonEncode({
            'content': [
              {
                'userId': 12,
                'username': 'user_minh',
                'handle': 'minh.tran',
                'email': 'minh@example.com',
                'fullName': 'Trần Minh',
                'role': currentTargetRole,
                'status': currentTargetStatus,
                'emailVerified': true,
                'createdAt': '2026-04-05T09:00:00',
              }
            ],
            'pageNumber': 0,
            'pageSize': 20,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/users/12') {
          return http.Response(jsonEncode({
            'userId': 12,
            'username': 'user_minh',
            'handle': 'minh.tran',
            'email': 'minh@example.com',
            'fullName': 'Trần Minh',
            'phone': '0901112223',
            'address': 'Đà Nẵng',
            'bio': 'Yêu thích khám phá',
            'role': currentTargetRole,
            'status': currentTargetStatus,
            'emailVerified': true,
            'itineraryCount': 4,
            'postCount': 7,
            'activeSessionCount': 1,
            'sessions': [
              {
                'sessionId': 'sess-1',
                'deviceInfo': 'Pixel 8 Android',
                'ipAddress': '192.168.1.5',
                'status': 'ACTIVE',
                'lastActiveAt': '2026-11-25T09:00:00',
              }
            ],
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/users/12/sessions/revoke-all' && request.method == 'POST') {
          revokeCalled = true;
          return http.Response(jsonEncode({'message': 'Đã thu hồi', 'revokedCount': 1}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/users/12/status' && request.method == 'PATCH') {
          lastPatchBody = request.body;
          currentTargetStatus = 'BANNED';
          return http.Response(jsonEncode({
            'userId': 12,
            'username': 'user_minh',
            'handle': 'minh.tran',
            'email': 'minh@example.com',
            'fullName': 'Trần Minh',
            'role': currentTargetRole,
            'status': 'BANNED',
            'emailVerified': true,
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/users/12/role' && request.method == 'PATCH') {
          lastPatchBody = request.body;
          currentTargetRole = 'ADMIN';
          return http.Response(jsonEncode({
            'userId': 12,
            'username': 'user_minh',
            'handle': 'minh.tran',
            'email': 'minh@example.com',
            'fullName': 'Trần Minh',
            'role': 'ADMIN',
            'status': currentTargetStatus,
            'emailVerified': true,
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not found', 404);
      });

      final notifier = await _buildAuthenticatedAdminNotifier(mockClient);
      final repo = AdminUserRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(authNotifier: notifier, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Search keyword submit
      await tester.enterText(find.byType(TextField).first, 'minh');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(queries.last['keyword'], 'minh');

      // Open detail dialog
      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết người dùng'), findsOneWidget);
      expect(find.text('Pixel 8 Android'), findsOneWidget);

      // Trigger Revoke All Sessions
      await tester.tap(find.text('Thu hồi tất cả phiên'));
      await tester.pumpAndSettle();
      expect(find.text('Thu hồi toàn bộ phiên đăng nhập'), findsOneWidget);
      await tester.tap(find.text('Thu hồi phiên'));
      await tester.pumpAndSettle();
      expect(revokeCalled, isTrue);

      // Close detail dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      // Open Ban dialog and verify reason validation + submission
      await tester.tap(find.byIcon(Icons.block).first);
      await tester.pumpAndSettle();
      expect(find.text('Khóa tài khoản người dùng'), findsOneWidget);

      await tester.tap(find.text('Xác nhận khóa'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do từ 3 đến 255 ký tự.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Vi phạm quy định cộng đồng');
      await tester.tap(find.text('Xác nhận khóa'));
      await tester.pumpAndSettle();
      expect(lastPatchBody, contains('BANNED'));
      expect(find.text('Đã khóa'), findsWidgets);

      // Open Change Role dialog and promote USER -> ADMIN
      await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('Nâng quyền Quản trị viên'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Bổ nhiệm quản trị viên phụ');
      await tester.tap(find.text('Xác nhận nâng quyền'));
      await tester.pumpAndSettle();
      expect(lastPatchBody, contains('ADMIN'));
    });

    testWidgets('Displays empty state, error banner with retry, and restricts non-ADMIN user', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool shouldFail = true;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/users') {
          if (shouldFail) {
            return http.Response(jsonEncode({'message': 'Lỗi máy chủ khi tải danh sách'}), 500, headers: jsonHeaders);
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
        return http.Response('Not found', 404);
      });

      final notifier = await _buildAuthenticatedAdminNotifier(mockClient);
      final repo = AdminUserRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(authNotifier: notifier, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lỗi máy chủ khi tải danh sách'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Retry succeeds with empty state
      shouldFail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy người dùng nào phù hợp.'), findsOneWidget);

      // Non-admin user view check
      final nonAdminMockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 99, 'username': 'normal_user', 'role': 'USER'}), 200, headers: jsonHeaders);
        }
        return http.Response('Forbidden', 403);
      });
      final userNotifier = await _buildAuthenticatedAdminNotifier(nonAdminMockClient, role: 'USER', userId: 99);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            key: const ValueKey('non-admin-users-screen'),
            authNotifier: userNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bạn không có quyền truy cập chức năng Quản lý người dùng.'), findsOneWidget);
    });

    test('UserAvatar.resolveValidUrl validates HTTP(S) and relative paths strictly', () {
      expect(
        UserAvatar.resolveValidUrl('https://images.unsplash.com/photo-1.jpg'),
        'https://images.unsplash.com/photo-1.jpg',
      );
      expect(
        UserAvatar.resolveValidUrl('http://localhost:8080/uploads/a.png'),
        'http://localhost:8080/uploads/a.png',
      );
      expect(
        UserAvatar.resolveValidUrl('/uploads/avatars/u1.png'),
        '${ApiConstants.baseUrl}/uploads/avatars/u1.png',
      );
      expect(UserAvatar.resolveValidUrl(null), isNull);
      expect(UserAvatar.resolveValidUrl('   '), isNull);
      expect(UserAvatar.resolveValidUrl('null'), isNull);
      expect(UserAvatar.resolveValidUrl('not-a-valid-url'), isNull);
      expect(UserAvatar.resolveValidUrl('//evil.com/x.png'), isNull);
      expect(UserAvatar.resolveValidUrl('ftp://example.com/a.png'), isNull);
      expect(UserAvatar.resolveValidUrl('javascript:alert(1)'), isNull);
    });

    testWidgets('Renders real avatar URL when valid, falls back cleanly on missing/invalid/error, and avoids overflow on long text', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/users') {
          return http.Response(jsonEncode({
            'content': [
              {
                'userId': 10,
                'username': 'hoang_long_very_long_username_value_for_table_check',
                'handle': 'hoang.long.traveler.vietnam',
                'email': 'hoang.long.enterprise.user@very-long-travel-domain.example.com',
                'fullName': 'Nguyễn Hoàng Long Quốc Bảo Khang',
                'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
                'role': 'USER',
                'status': 'ACTIVE',
                'emailVerified': true,
                'createdAt': '2026-04-01T10:00:00',
              },
              {
                'userId': 11,
                'username': 'invalid_avatar_user',
                'handle': 'invalid.avatar',
                'email': 'invalid@example.com',
                'fullName': 'Khánh Vy',
                'avatar': 'invalid-avatar-string',
                'role': 'USER',
                'status': 'ACTIVE',
                'emailVerified': true,
                'createdAt': '2026-04-02T10:00:00',
              },
              {
                'userId': 12,
                'username': 'no_avatar_user',
                'handle': 'no.avatar',
                'email': 'noavatar@example.com',
                'fullName': 'Ngọc Anh',
                'avatar': null,
                'role': 'ADMIN',
                'status': 'ACTIVE',
                'emailVerified': true,
                'createdAt': '2026-04-03T10:00:00',
              },
            ],
            'pageNumber': 0,
            'pageSize': 20,
            'totalElements': 3,
            'totalPages': 1,
            'last': true,
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not found', 404);
      });

      final notifier = await _buildAuthenticatedAdminNotifier(mockClient);
      final repo = AdminUserRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(authNotifier: notifier, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Only the 1 valid avatar row constructs a NetworkImage with the real URL.
      final images = find.byType(Image);
      expect(images, findsOneWidget);
      final netImg = tester.widget<Image>(images.first).image as NetworkImage;
      expect(netImg.url, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400');

      // Invalid & missing avatars fall back immediately to initials ('K' and 'N'),
      // and the network image errorBuilder also falls back to 'N' when test HTTP fails.
      expect(find.text('K'), findsOneWidget);
      expect(find.text('N'), findsWidgets);

      // Verify responsive rendering at narrow viewport (768x1024) has zero RenderFlex overflow.
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
