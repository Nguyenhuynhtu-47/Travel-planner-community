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
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_media_screen.dart';
import 'package:travel_planner_web/shared/widgets/admin_dialog.dart';

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

  group('AdminMediaScreen Phase 4 Enterprise Tests', () {
    testWidgets('Renders server-side pagination, status badge, total elements chip, and changes page', (tester) async {
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
        if (request.url.path == '/api/admin/media-assets') {
          requestedPage = int.tryParse(request.url.queryParameters['page'] ?? '0') ?? 0;
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'mediaAssetId': 201,
                  'uploadedByUserId': 10,
                  'uploadedByUsername': 'uploader_alice',
                  'cloudinaryPublicId': 'tp/posts/asset_201',
                  'secureUrl': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
                  'status': 'ATTACHED',
                  'mediaType': 'image/jpeg',
                  'retryCount': 0,
                  'createdAt': '2026-11-23T10:00:00Z',
                },
                {
                  'mediaAssetId': 202,
                  'uploadedByUserId': 11,
                  'uploadedByUsername': 'uploader_bob',
                  'cloudinaryPublicId': 'tp/posts/asset_202',
                  'secureUrl': 'https://res.cloudinary.com/demo/image/upload/sample2.jpg',
                  'status': 'DELETING',
                  'mediaType': 'image/png',
                  'retryCount': 2,
                  'deadLetteredAt': '2026-11-23T11:00:00Z',
                  'lastError': 'Cloudinary deletion timeout 504',
                  'createdAt': '2026-11-23T09:00:00Z',
                },
              ],
              'pageNumber': requestedPage,
              'pageSize': 20,
              'totalElements': 52,
              'totalPages': 3,
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

      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminMediaScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Total elements badge
      expect(find.text('Quản lý tài nguyên Media'), findsOneWidget);
      expect(find.text('Tổng: 52 tài nguyên'), findsOneWidget);

      // Verify row items in AdminDataTable
      expect(find.text('#201'), findsOneWidget);
      expect(find.text('uploader_alice'), findsOneWidget);
      expect(find.text('tp/posts/asset_201'), findsOneWidget);
      expect(find.text('Đã gắn bài'), findsOneWidget);

      expect(find.text('#202'), findsOneWidget);
      expect(find.text('uploader_bob'), findsOneWidget);
      expect(find.text('tp/posts/asset_202'), findsOneWidget);
      expect(find.text('Đang xóa...'), findsOneWidget);
      expect(find.text('LỖI ĐÌNH TRỆ'), findsNWidgets(2)); // Column header and row badge
      expect(find.text('Thử lại xóa'), findsOneWidget);

      // Verify pagination bar
      expect(find.textContaining('Trang 1 / 3'), findsOneWidget);

      // Tap Next Page
      final nextButton = find.byTooltip('Trang sau');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(requestedPage, 1);
    });

    testWidgets('Filter by status and toggle deadLetterOnly filter', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      String? capturedStatus;
      String? capturedDeadLetter;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/media-assets') {
          capturedStatus = request.url.queryParameters['status'];
          capturedDeadLetter = request.url.queryParameters['deadLetterOnly'];
          return http.Response(
            jsonEncode({
              'content': [],
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 0,
              'totalPages': 0,
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
      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminMediaScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial call has status = null, deadLetterOnly = false (omitted from query params)
      expect(capturedStatus, isNull);
      expect(capturedDeadLetter, isNull);

      // Tap Dead-letter checkbox
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(capturedDeadLetter, 'true');

      // Change status dropdown to DELETING
      await tester.tap(find.text('Tất cả trạng thái'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đang xóa').last);
      await tester.pumpAndSettle();

      expect(capturedStatus, 'DELETING');
    });

    testWidgets('Detail dialog opens and Retry Deletion succeeds', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      bool retryCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/media-assets' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'mediaAssetId': 301,
                  'uploadedByUserId': 12,
                  'uploadedByUsername': 'uploader_12',
                  'cloudinaryPublicId': 'tp/posts/asset_301',
                  'secureUrl': 'https://example.com/asset_301.jpg',
                  'status': 'DELETING',
                  'mediaType': 'image/jpeg',
                  'retryCount': 3,
                  'deadLetteredAt': '2026-11-23T12:00:00Z',
                  'lastError': 'Cloudinary HTTP 500 error',
                  'createdAt': '2026-11-12T10:00:00Z',
                }
              ],
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 1,
              'totalPages': 1,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/media-assets/301/retry' && request.method == 'POST') {
          retryCalled = true;
          return http.Response('', 200);
        }
        return http.Response('Not found', 404);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();
      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminMediaScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open detail dialog
      await tester.tap(find.text('Chi tiết').first);
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết Media #301'), findsOneWidget);
      expect(find.text('Cloudinary Public ID:'), findsOneWidget);
      expect(find.text('tp/posts/asset_301'), findsWidgets);
      expect(find.descendant(of: find.byType(AdminDialog), matching: find.text('Cloudinary HTTP 500 error')), findsOneWidget);
      expect(find.text('Sao chép URL'), findsOneWidget);

      // Tap Thử lại xóa inside dialog
      final dialogRetryButton = find.descendant(
        of: find.byType(AdminDialog),
        matching: find.text('Thử lại xóa'),
      );
      expect(dialogRetryButton, findsOneWidget);
      await tester.tap(dialogRetryButton);
      await tester.pumpAndSettle();

      expect(retryCalled, true);
      expect(find.text('Đã gửi yêu cầu thử lại xóa media.'), findsOneWidget);
    });

    testWidgets('Toggles between Data Table and Gallery Grid views seamlessly', (tester) async {
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
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'mediaAssetId': 401,
                  'uploadedByUserId': 99,
                  'uploadedByUsername': 'gallery_user',
                  'cloudinaryPublicId': 'tp/posts/photo_401',
                  'secureUrl': 'https://example.com/p401.jpg',
                  'status': 'ATTACHED',
                  'retryCount': 0,
                  'createdAt': '2026-11-23T10:00:00Z',
                }
              ],
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 1,
              'totalPages': 1,
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
      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminMediaScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default in table view
      expect(find.byType(GridView), findsNothing);

      // Switch to Grid View
      final gridToggle = find.byTooltip('Xem dạng lưới ảnh');
      expect(gridToggle, findsOneWidget);
      await tester.tap(gridToggle);
      await tester.pumpAndSettle();

      // Now GridView is active
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('#401'), findsOneWidget);
      expect(find.text('tp/posts/photo_401'), findsOneWidget);

      // Switch back to Table View
      final tableToggle = find.byTooltip('Xem dạng bảng');
      expect(tableToggle, findsOneWidget);
      await tester.tap(tableToggle);
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('Non-admin user is denied access', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 2, 'username': 'normal_user', 'role': 'USER'});

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'username': 'normal_user', 'role': 'USER'}), 200, headers: jsonHeaders);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();
      final repo = ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminMediaScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý Media'), findsOneWidget);
      expect(
        find.text('Quyền truy cập bị từ chối: Chỉ tài khoản Quản trị viên (ADMIN) mới có quyền truy cập.'),
        findsOneWidget,
      );
    });

    testWidgets('Integrates inside AdminShell when selecting media tab', (tester) async {
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
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'mediaAssetId': 888,
                  'uploadedByUserId': 55,
                  'uploadedByUsername': 'shell_media_uploader',
                  'cloudinaryPublicId': 'tp/posts/shell_888',
                  'secureUrl': 'https://example.com/shell_888.jpg',
                  'status': 'ATTACHED',
                  'retryCount': 0,
                  'createdAt': '2026-11-23T10:00:00Z',
                }
              ],
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 1,
              'totalPages': 1,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        return http.Response(jsonEncode({'content': []}), 200, headers: jsonHeaders);
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
            initialTab: AdminTab.media,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý tài nguyên Media'), findsOneWidget);
      expect(find.text('shell_media_uploader'), findsOneWidget);
      expect(find.text('tp/posts/shell_888'), findsOneWidget);
    });
  });
}
