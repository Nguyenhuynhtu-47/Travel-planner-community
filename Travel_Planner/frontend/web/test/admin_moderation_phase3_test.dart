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
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/features/layout/presentation/screens/admin_shell.dart';
import 'package:travel_planner_web/features/moderation/data/moderation_repository.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_posts_screen.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_reports_screen.dart';

String _createMockJwt({required int expSeconds}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'webadmin', 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  group('AdminPostsScreen Phase 3 Enterprise Tests', () {
    testWidgets('Renders server-side pagination, status badge, and changes page', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      int requestedPage = -1;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/community/posts') {
          requestedPage = int.tryParse(request.url.queryParameters['page'] ?? '0') ?? 0;
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'postId': 101,
                  'content': 'Bài viết số 1 nội dung du lịch',
                  'author': {'userId': 10, 'handle': 'traveler_1', 'displayName': 'Nguyễn Văn A'},
                  'mediaUrls': ['https://example.com/p1.jpg'],
                  'status': 'ACTIVE',
                  'likeCount': 5,
                  'commentCount': 2,
                  'createdAt': '2026-11-23T10:00:00Z',
                },
                {
                  'postId': 102,
                  'content': 'Bài viết số 2 vi phạm đã bị ẩn',
                  'author': {'userId': 11, 'handle': 'traveler_2', 'displayName': 'Trần Văn B'},
                  'mediaUrls': [],
                  'status': 'HIDDEN',
                  'likeCount': 0,
                  'commentCount': 0,
                  'createdAt': '2026-11-23T11:00:00Z',
                  'moderationReason': 'Quảng cáo sai sự thật',
                },
              ],
              'pageNumber': requestedPage,
              'pageSize': 20,
              'totalElements': 45,
              'totalPages': 3,
            }),
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

      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPostsScreen(
              authNotifier: authNotifier,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header and Summary chip
      expect(find.text('Kiểm duyệt bài viết'), findsNWidgets(2)); // AppBar / Header
      expect(find.text('Tổng: 45 bài viết'), findsOneWidget);

      // Verify Table Columns and Rows
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Bài viết số 1 nội dung du lịch'), findsOneWidget);
      expect(find.text('1 ảnh'), findsOneWidget);

      expect(find.text('#102'), findsOneWidget);
      expect(find.text('Trần Văn B'), findsOneWidget);
      expect(find.text('Bài viết số 2 vi phạm đã bị ẩn'), findsOneWidget);

      // Verify AdminStatusBadge widgets
      expect(find.text('Hoạt động'), findsOneWidget);
      expect(find.text('Đã ẩn'), findsOneWidget);

      // Verify Server-side Pagination Footer
      expect(find.text('Hiển thị 1 - 2 trong số 45 bản ghi'), findsOneWidget);
      expect(find.text('Trang 1 / 3'), findsOneWidget);

      // Click Next Page button
      await tester.tap(find.byTooltip('Trang sau'));
      await tester.pumpAndSettle();
      expect(requestedPage, 1);
    });

    testWidgets('Filters posts by status and restores a HIDDEN post', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      String? requestedStatus;
      bool restoreCalled = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/community/posts' && request.method == 'GET') {
          requestedStatus = request.url.queryParameters['status'];
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'postId': 205,
                  'content': 'Bài viết đã ẩn cần xem xét khôi phục',
                  'author': {'userId': 15, 'handle': 'traveler_hidden'},
                  'mediaUrls': [],
                  'status': 'HIDDEN',
                  'createdAt': '2026-11-23T10:00:00Z',
                }
              ],
              'totalElements': 1,
              'totalPages': 1,
              'pageNumber': 0,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/community/posts/205/moderate' && request.method == 'PATCH') {
          restoreCalled = true;
          return http.Response(
            jsonEncode({
              'postId': 205,
              'status': 'ACTIVE',
              'content': 'Bài viết đã ẩn cần xem xét khôi phục',
              'author': {'userId': 15, 'handle': 'traveler_hidden'},
              'createdAt': '2026-11-23T10:00:00Z',
            }),
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

      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPostsScreen(
              authNotifier: authNotifier,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap status dropdown and select HIDDEN
      await tester.tap(find.text('Tất cả trạng thái'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đã ẩn (HIDDEN)').last);
      await tester.pumpAndSettle();
      expect(requestedStatus, 'HIDDEN');

      // Tap Khôi phục
      expect(find.text('Khôi phục'), findsOneWidget);
      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();

      expect(find.text('Khôi phục bài viết'), findsOneWidget);
      expect(find.text('Xác nhận khôi phục'), findsOneWidget);
      await tester.tap(find.text('Xác nhận khôi phục'));
      await tester.pumpAndSettle();

      expect(restoreCalled, isTrue);
    });

    testWidgets('Shows error banner and retries on API failure', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      int callCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/community/posts') {
          callCount++;
          if (callCount == 1) {
            return http.Response(jsonEncode({'message': 'Internal Server Error'}), 500, headers: jsonHeaders);
          }
          return http.Response(
            jsonEncode({'content': [], 'totalElements': 0, 'totalPages': 0, 'pageNumber': 0}),
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

      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPostsScreen(
              authNotifier: authNotifier,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Internal Server Error'), findsWidgets);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });
  });

  group('AdminReportsScreen Phase 3 Enterprise Tests', () {
    testWidgets('Renders server-side pagination, details, and resolves/dismisses report', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      bool dismissCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/community/reports' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'reportId': 77,
                  'postId': 301,
                  'reason': 'Nội dung bạo lực hoặc ngôn từ thù địch',
                  'details': 'Người này dùng lời lẽ xúc phạm thành viên khác',
                  'status': 'PENDING',
                  'createdAt': '2026-11-23T14:00:00Z',
                  'reporter': {'userId': 40, 'handle': 'user_reporter', 'displayName': 'Người Báo Cáo'},
                }
              ],
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 28,
              'totalPages': 2,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/community/reports/77/resolve' && request.method == 'PATCH') {
          dismissCalled = true;
          return http.Response(
            jsonEncode({
              'reportId': 77,
              'postId': 301,
              'reason': 'Nội dung bạo lực hoặc ngôn từ thù địch',
              'status': 'DISMISSED',
              'createdAt': '2026-11-23T14:00:00Z',
            }),
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

      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminReportsScreen(
              authNotifier: authNotifier,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Summary chip
      expect(find.text('Quản lý báo cáo vi phạm'), findsNWidgets(2));
      expect(find.text('Tổng: 28 báo cáo'), findsOneWidget);

      // Verify Table Columns and Content
      expect(find.text('#77'), findsOneWidget);
      expect(find.text('#301'), findsOneWidget);
      expect(find.text('Người Báo Cáo'), findsOneWidget);
      expect(find.text('Nội dung bạo lực hoặc ngôn từ thù địch'), findsOneWidget);
      expect(find.text('Chờ xử lý'), findsWidgets);

      // Verify Pagination Footer
      expect(find.text('Hiển thị 1 - 1 trong số 28 bản ghi'), findsOneWidget);
      expect(find.text('Trang 1 / 2'), findsOneWidget);

      // Dismiss report action
      expect(find.text('Bỏ qua'), findsOneWidget);
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();

      expect(dismissCalled, isTrue);
    });
  });

  group('Independent Navigation & Route Mapping Tests', () {
    testWidgets('AdminShell renders Posts and Reports as independent tabs without nested tabs', (tester) async {
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
        if (request.url.path == '/api/admin/community/posts' || request.url.path == '/api/admin/community/reports') {
          return http.Response(
            jsonEncode({'content': [], 'totalElements': 0, 'totalPages': 0, 'pageNumber': 0}),
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

      // 1. Mount AdminShell with initialTab: AdminTab.posts
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            authNotifier: authNotifier,
            initialTab: AdminTab.posts,
            apiClient: ApiClient(client: mockClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AdminPostsScreen is active
      expect(find.byType(AdminPostsScreen), findsOneWidget);
      expect(find.byType(AdminReportsScreen), findsNothing);

      // 2. Click on "Quản lý báo cáo" on Sidebar
      await tester.tap(find.text('Quản lý báo cáo'));
      await tester.pumpAndSettle();

      // Verify AdminReportsScreen is now active
      expect(find.byType(AdminReportsScreen), findsOneWidget);
      expect(find.byType(AdminPostsScreen), findsNothing);
    });
  });
}
