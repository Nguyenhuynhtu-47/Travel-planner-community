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
import 'package:travel_planner_web/features/moderation/data/models/admin_media_asset_model.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_model.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_report_model.dart';
import 'package:travel_planner_web/features/moderation/data/moderation_repository.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_moderation_screen.dart';

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

  group('Phase 6B.5 - Moderation Models Serialization', () {
    test('AdminPostModel.fromJson parses standard backend DTO with mediaUrls', () {
      final json = {
        'postId': 10,
        'content': 'Bài viết vi phạm cần kiểm duyệt',
        'author': {
          'userId': 5,
          'handle': 'user_spammer',
          'fullName': 'Spam User',
        },
        'mediaUrls': ['https://example.com/spam.jpg'],
        'mediaAssetIds': [100],
        'visibility': 'PUBLIC',
        'status': 'ACTIVE',
        'likeCount': 3,
        'commentCount': 1,
        'createdAt': '2026-11-12T10:00:00Z',
        'moderationReason': 'Vi phạm điều khoản',
      };

      final post = AdminPostModel.fromJson(json);

      expect(post.postId, 10);
      expect(post.content, 'Bài viết vi phạm cần kiểm duyệt');
      expect(post.author.handle, 'user_spammer');
      expect(post.author.displayName, 'Spam User');
      expect(post.mediaUrls.length, 1);
      expect(post.mediaUrls.first, 'https://example.com/spam.jpg');
      expect(post.mediaAssetIds.first, 100);
      expect(post.status, 'ACTIVE');
      expect(post.likeCount, 3);
      expect(post.moderationReason, 'Vi phạm điều khoản');
    });

    test('AdminPostModel.fromJson parses legacy media list format', () {
      final json = {
        'postId': 11,
        'content': 'Legacy post format',
        'author': {'userId': 6, 'handle': 'user6'},
        'media': [
          {'mediaAssetId': 200, 'secureUrl': 'https://example.com/leg.jpg'}
        ],
        'status': 'HIDDEN',
        'createdAt': '2026-11-12T10:00:00Z',
      };

      final post = AdminPostModel.fromJson(json);
      expect(post.postId, 11);
      expect(post.mediaUrls.first, 'https://example.com/leg.jpg');
      expect(post.mediaAssetIds.first, 200);
    });

    test('AdminPostReportModel.fromJson parses report correctly', () {
      final json = {
        'reportId': 50,
        'postId': 10,
        'reporter': {
          'userId': 9,
          'handle': 'good_citizen',
          'fullName': 'Good Citizen',
        },
        'reason': 'Spam hoặc quảng cáo sai sự thật',
        'details': 'Người này spam liên tục trong group',
        'status': 'PENDING',
        'createdAt': '2026-11-12T11:00:00Z',
      };

      final report = AdminPostReportModel.fromJson(json);

      expect(report.reportId, 50);
      expect(report.postId, 10);
      expect(report.reporter?.displayName, 'Good Citizen');
      expect(report.reason, 'Spam hoặc quảng cáo sai sự thật');
      expect(report.status, 'PENDING');
    });

    test('AdminMediaAssetModel.fromJson parses media asset correctly', () {
      final json = {
        'mediaAssetId': 88,
        'uploadedByUserId': 5,
        'uploadedByUsername': 'user_spammer',
        'cloudinaryPublicId': 'tp/posts/asset_88',
        'secureUrl': 'https://cloudinary.com/tp/posts/asset_88.jpg',
        'status': 'DELETING',
        'retryCount': 3,
        'deadLetteredAt': '2026-11-12T12:00:00Z',
        'lastError': 'Cloudinary HTTP 500 error',
        'createdAt': '2026-11-12T09:00:00Z',
      };

      final asset = AdminMediaAssetModel.fromJson(json);

      expect(asset.mediaAssetId, 88);
      expect(asset.cloudinaryPublicId, 'tp/posts/asset_88');
      expect(asset.status, 'DELETING');
      expect(asset.retryCount, 3);
      expect(asset.isDeadLettered, true);
      expect(asset.lastError, 'Cloudinary HTTP 500 error');
    });
  });

  group('Phase 6B.5 - ModerationRepository API Client Tests', () {
    test('getPosts sends status param and parses page content', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/admin/community/posts');
        expect(request.url.queryParameters['status'], 'ACTIVE');
        expect(request.headers['Authorization'], 'Bearer admin-token');

        final responseBody = {
          'content': [
            {
              'postId': 1,
              'content': 'Test post 1',
              'author': {
                'userId': 1,
                'handle': 'admin',
                'fullName': 'Admin User'
              },
              'mediaUrls': ['https://example.com/p1.jpg'],
              'mediaAssetIds': [10],
              'status': 'ACTIVE',
              'visibility': 'PUBLIC',
              'likeCount': 0,
              'commentCount': 0,
              'createdAt': '2026-11-12T10:00:00Z',
            }
          ]
        };
        return http.Response(jsonEncode(responseBody), 200,
            headers: {'content-type': 'application/json'});
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));
      final posts = await repo.getPosts(status: 'ACTIVE', token: 'admin-token');

      expect(posts.length, 1);
      expect(posts.first.postId, 1);
      expect(posts.first.status, 'ACTIVE');
      expect(posts.first.mediaUrls.first, 'https://example.com/p1.jpg');
    });

    test('getPostById sends GET request and parses post detail', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/admin/community/posts/1');
        expect(request.headers['Authorization'], 'Bearer admin-token');

        final responseBody = {
          'postId': 1,
          'content': 'Detail post 1',
          'author': {'userId': 1, 'handle': 'admin'},
          'mediaUrls': [],
          'status': 'ACTIVE',
          'visibility': 'PUBLIC',
          'createdAt': '2026-11-12T10:00:00Z',
        };
        return http.Response(jsonEncode(responseBody), 200,
            headers: {'content-type': 'application/json'});
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));
      final post = await repo.getPostById(1, token: 'admin-token');

      expect(post.postId, 1);
      expect(post.content, 'Detail post 1');
    });

    test('moderatePost sends PATCH request to /moderate with moderationReason', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/admin/community/posts/1/moderate');
        final body = jsonDecode(request.body) as Map;
        expect(body['status'], 'HIDDEN');
        expect(body['moderationReason'], 'Spam violation');

        final responseBody = {
          'postId': 1,
          'content': 'Test post 1',
          'author': {'userId': 1, 'handle': 'admin'},
          'mediaUrls': [],
          'status': 'HIDDEN',
          'visibility': 'PUBLIC',
          'createdAt': '2026-11-12T10:00:00Z',
          'moderationReason': 'Spam violation',
        };
        return http.Response(jsonEncode(responseBody), 200,
            headers: {'content-type': 'application/json'});
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));
      final post = await repo.moderatePost(1,
          status: 'HIDDEN', reason: 'Spam violation', token: 'admin-token');

      expect(post.status, 'HIDDEN');
      expect(post.moderationReason, 'Spam violation');
    });

    test('purgePost sends DELETE request to purge endpoint', () async {
      bool purged = false;
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/admin/community/posts/1/purge');
        purged = true;
        return http.Response('', 204);
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));
      await repo.purgePost(1, token: 'admin-token');

      expect(purged, true);
    });

    test('resolveReport sends PATCH request to /resolve with resolution query param and body', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/admin/community/reports/50/resolve');
        expect(request.url.queryParameters['resolution'], 'RESOLVED');
        final body = jsonDecode(request.body) as Map;
        expect(body['resolution'], 'RESOLVED');

        final responseBody = {
          'reportId': 50,
          'postId': 1,
          'reason': 'Spam',
          'status': 'RESOLVED',
          'createdAt': '2026-11-12T10:00:00Z',
        };
        return http.Response(jsonEncode(responseBody), 200,
            headers: {'content-type': 'application/json'});
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));
      final report =
          await repo.resolveReport(50, status: 'RESOLVED', token: 'admin-token');

      expect(report.status, 'RESOLVED');
    });

    test('getMediaAssets sends GET request to /api/admin/media-assets', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/admin/media-assets');

        final responseBody = {
          'content': [
            {
              'mediaAssetId': 88,
              'uploadedByUserId': 5,
              'uploadedByUsername': 'user_spammer',
              'cloudinaryPublicId': 'tp/posts/asset_88',
              'secureUrl': 'https://cloudinary.com/tp/posts/asset_88.jpg',
              'status': 'DELETING',
              'retryCount': 1,
              'createdAt': '2026-11-12T09:00:00Z',
            }
          ]
        };
        return http.Response(jsonEncode(responseBody), 200,
            headers: {'content-type': 'application/json'});
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));
      final assets = await repo.getMediaAssets(token: 'admin-token');

      expect(assets.length, 1);
      expect(assets.first.mediaAssetId, 88);
    });

    test('retryMediaAsset sends POST request to /api/admin/media-assets/{id}/retry', () async {
      bool retryCalled = false;
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/admin/media-assets/88/retry');
        retryCalled = true;
        return http.Response('', 200);
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));
      await repo.retryMediaAsset(88, token: 'admin-token');

      expect(retryCalled, true);
    });
  });

  group('Phase 6B.5 - AdminModerationScreen Widget Tests', () {
    testWidgets('Non-admin user (role: USER) sees Access Denied screen',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(
          expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage
          .saveUser({'userId': 1, 'username': 'user1', 'role': 'USER'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'user1', 'role': 'USER'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository:
            AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminModerationScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Quyền truy cập bị từ chối: Chỉ tài khoản Quản trị viên (ADMIN) mới có quyền truy cập.'),
          findsOneWidget);
    });

    testWidgets('Admin user renders 3 tabs, post row, and handles hide post action',
        (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(
          expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage
          .saveUser({'userId': 99, 'username': 'admin', 'role': 'ADMIN'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'admin', 'role': 'ADMIN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository:
            AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      bool hideCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/community/posts' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'postId': 101,
                  'content': 'Bài viết quảng cáo đánh bạc',
                  'author': {
                    'userId': 20,
                    'handle': 'bad_actor',
                    'fullName': 'Bad Actor'
                  },
                  'mediaUrls': ['https://example.com/ad.jpg'],
                  'mediaAssetIds': [101],
                  'status': 'ACTIVE',
                  'visibility': 'PUBLIC',
                  'likeCount': 0,
                  'commentCount': 0,
                  'createdAt': '2026-11-12T10:00:00Z',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/community/posts/101/moderate' &&
            request.method == 'PATCH') {
          hideCalled = true;
          return http.Response(
            jsonEncode({
              'postId': 101,
              'content': 'Bài viết quảng cáo đánh bạc',
              'author': {'userId': 20, 'handle': 'bad_actor'},
              'mediaUrls': [],
              'status': 'HIDDEN',
              'visibility': 'PUBLIC',
              'createdAt': '2026-11-12T10:00:00Z',
              'moderationReason': 'Vi phạm quy định',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(
            jsonEncode({'content': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(
            jsonEncode({'content': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminModerationScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản trị & Kiểm duyệt Cộng đồng'), findsOneWidget);
      expect(find.text('Bài viết'), findsOneWidget);
      expect(find.text('Báo cáo vi phạm'), findsOneWidget);
      expect(find.text('Tài nguyên Media'), findsOneWidget);
      expect(find.text('Bài viết quảng cáo đánh bạc'), findsOneWidget);
      expect(find.text('Bad Actor'), findsOneWidget);

      // Tap Ẩn
      await tester.ensureVisible(find.text('Ẩn'));
      await tester.tap(find.text('Ẩn'));
      await tester.pumpAndSettle();

      expect(find.text('Ẩn bài viết vi phạm'), findsOneWidget);
      await tester.tap(find.text('Xác nhận ẩn'));
      await tester.pumpAndSettle();

      expect(hideCalled, true);
    });

    testWidgets('Admin user opens Post Detail dialog and closes it',
        (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(
          expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage
          .saveUser({'userId': 99, 'username': 'admin', 'role': 'ADMIN'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'admin', 'role': 'ADMIN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository:
            AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/community/posts' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'postId': 202,
                  'content': 'Chi tiết bài viết đặc sắc',
                  'author': {
                    'userId': 30,
                    'handle': 'traveler_vn',
                    'fullName': 'Nguyễn Du Khách'
                  },
                  'mediaUrls': [],
                  'status': 'ACTIVE',
                  'visibility': 'PUBLIC',
                  'likeCount': 10,
                  'commentCount': 5,
                  'createdAt': '2026-11-12T10:00:00Z',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(jsonEncode({'content': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(jsonEncode({'content': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminModerationScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết'), findsOneWidget);
      await tester.ensureVisible(find.text('Chi tiết'));
      await tester.tap(find.text('Chi tiết'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết bài viết #202'), findsOneWidget);
      expect(find.text('Nguyễn Du Khách'), findsNWidgets(2)); // Row & dialog
      expect(find.text('Lượt thích: 10'), findsOneWidget);
      expect(find.text('Bình luận: 5'), findsOneWidget);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết bài viết #202'), findsNothing);
    });

    testWidgets('Admin user opens Hard Purge warning dialog', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(
          expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage
          .saveUser({'userId': 99, 'username': 'admin', 'role': 'ADMIN'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'admin', 'role': 'ADMIN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository:
            AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      bool purgeCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/community/posts' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'postId': 102,
                  'content': 'Bài viết độc hại cần xóa vĩnh viễn',
                  'author': {'userId': 21, 'handle': 'malicious'},
                  'media': [],
                  'status': 'HIDDEN',
                  'visibility': 'PUBLIC',
                  'likeCount': 0,
                  'commentCount': 0,
                  'createdAt': '2026-11-12T10:00:00Z',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/community/posts/102/purge' &&
            request.method == 'DELETE') {
          purgeCalled = true;
          return http.Response('', 204);
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(jsonEncode({'content': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(jsonEncode({'content': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminModerationScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xóa vĩnh viễn'), findsOneWidget);
      await tester.ensureVisible(find.text('Xóa vĩnh viễn'));
      await tester.tap(find.text('Xóa vĩnh viễn'));
      await tester.pumpAndSettle();

      expect(find.text('CẢNH BÁO: XÓA VĨNH VIỄN'), findsOneWidget);
      expect(
          find.textContaining(
              'Hành động này sẽ xóa vĩnh viễn bài viết khỏi hệ thống'),
          findsOneWidget);

      await tester.tap(find.text('Xóa vĩnh viễn').last);
      await tester.pumpAndSettle();

      expect(purgeCalled, true);
    });

    testWidgets('Admin user switches to Reports tab, views report and resolves it',
        (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(
          expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage
          .saveUser({'userId': 99, 'username': 'admin', 'role': 'ADMIN'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'admin', 'role': 'ADMIN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository:
            AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      bool resolvedCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/community/posts') {
          return http.Response(jsonEncode({'content': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/admin/community/reports' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'reportId': 77,
                  'postId': 105,
                  'reporter': {
                    'userId': 40,
                    'handle': 'reporter1',
                    'fullName': 'Người Báo Cáo'
                  },
                  'reason': 'Nội dung phản cảm',
                  'details': 'Hình ảnh không phù hợp',
                  'status': 'PENDING',
                  'createdAt': '2026-11-12T10:00:00Z',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/community/reports/77/resolve' &&
            request.method == 'PATCH') {
          resolvedCalled = true;
          return http.Response(
            jsonEncode({
              'reportId': 77,
              'postId': 105,
              'reason': 'Nội dung phản cảm',
              'status': 'RESOLVED',
              'createdAt': '2026-11-12T10:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(jsonEncode({'content': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminModerationScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch tab to Reports
      await tester.tap(find.text('Báo cáo vi phạm'));
      await tester.pumpAndSettle();

      expect(find.text('Nội dung phản cảm'), findsOneWidget);
      expect(find.text('Người Báo Cáo'), findsOneWidget);

      // Tap Xử lý vi phạm
      await tester.ensureVisible(find.text('Xử lý vi phạm'));
      await tester.tap(find.text('Xử lý vi phạm'));
      await tester.pumpAndSettle();

      expect(resolvedCalled, true);
    });

    testWidgets('Admin user switches to Media tab and triggers retry',
        (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(
          expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage
          .saveUser({'userId': 99, 'username': 'admin', 'role': 'ADMIN'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'admin', 'role': 'ADMIN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository:
            AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      bool retryCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/community/posts') {
          return http.Response(jsonEncode({'content': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(jsonEncode({'content': []}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/admin/media-assets' &&
            request.method == 'GET') {
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
                  'retryCount': 2,
                  'createdAt': '2026-11-12T10:00:00Z',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/media-assets/301/retry' &&
            request.method == 'POST') {
          retryCalled = true;
          return http.Response('', 200);
        }
        return http.Response('Not Found', 404);
      });

      final repo =
          ModerationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminModerationScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Media tab
      await tester.tap(find.text('Tài nguyên Media'));
      await tester.pumpAndSettle();

      expect(find.text('uploader_12'), findsOneWidget);
      expect(find.text('tp/posts/asset_301'), findsOneWidget);
      expect(find.text('Thử lại xóa'), findsOneWidget);

      await tester.ensureVisible(find.text('Thử lại xóa'));
      await tester.tap(find.text('Thử lại xóa'));
      await tester.pumpAndSettle();

      expect(retryCalled, true);
    });
  });
}
