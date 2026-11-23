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
import 'package:travel_planner_web/features/locations/data/place_repository.dart';
import 'package:travel_planner_web/features/locations/presentation/screens/admin_places_screen.dart';
import 'package:travel_planner_web/features/moderation/data/moderation_repository.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_media_screen.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_posts_screen.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_reports_screen.dart';

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

  group('Visual Redesign Verification for Admin Screens', () {
    late AuthNotifier authNotifier;
    late ApiClient apiClient;

    setUp(() async {
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
          return http.Response(jsonEncode({'status': 'UP', 'service': 'travel-planner-backend'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'reportId': 101,
                  'postId': 55,
                  'reason': 'Nội dung spam quảng cáo sai sự thật',
                  'status': 'PENDING',
                  'createdAt': '2026-11-23T10:00:00Z',
                  'reporter': {'userId': 2, 'handle': 'user_traveler', 'displayName': 'Nguyễn Văn A'},
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
        if (request.url.path == '/api/admin/community/posts') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'postId': 55,
                  'author': {'userId': 9, 'handle': 'spammer99', 'displayName': 'Dịch vụ Vé Rẻ'},
                  'content': 'Khuyến mãi tour Đà Lạt siêu ưu đãi cuối tuần!',
                  'status': 'ACTIVE',
                  'createdAt': '2026-11-23T09:30:00Z',
                  'mediaUrls': ['https://images.unsplash.com/photo-1506744038136-46273834b3fb'],
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
        if (request.url.path == '/api/admin/places') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'placeId': 501,
                  'name': 'Hồ Gươm Hoàn Kiếm',
                  'address': 'Quận Hoàn Kiếm, Hà Nội',
                  'category': 'ATTRACTION',
                  'status': 'ACTIVE',
                  'latitude': 21.0285,
                  'longitude': 105.8542,
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
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'assetId': 701,
                  'uploaderUserId': 9,
                  'uploaderUsername': 'spammer99',
                  'cloudinaryPublicId': 'tp/posts/55/photo_1',
                  'secureUrl': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
                  'status': 'UNATTACHED',
                  'retryCount': 0,
                  'deadLetter': false,
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

      apiClient = ApiClient(client: mockClient);
      authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: apiClient),
      );
      await authNotifier.checkAuthStatus();
    });

    testWidgets('Renders AdminShell, Sidebar & Header with Rausch brand accents', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            authNotifier: authNotifier,
            initialTab: AdminTab.dashboard,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Travel Planner'), findsOneWidget);
      expect(find.text('Cổng quản trị'), findsOneWidget);
      expect(find.text('Tổng quan'), findsWidgets);
    });

    testWidgets('Renders Posts Moderation screen with Rausch brand palette', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPostsScreen(
            authNotifier: authNotifier,
            repository: ModerationRepository(apiClient: apiClient),
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Khuyến mãi tour Đà Lạt siêu ưu đãi cuối tuần!'), findsOneWidget);
      expect(find.text('Chi tiết'), findsOneWidget);
      expect(find.text('Ẩn'), findsOneWidget);
    });

    testWidgets('Renders Reports screen with Rausch brand palette', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(
            authNotifier: authNotifier,
            repository: ModerationRepository(apiClient: apiClient),
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nội dung spam quảng cáo sai sự thật'), findsOneWidget);
      expect(find.text('Chi tiết'), findsOneWidget);
      expect(find.text('Xử lý vi phạm'), findsOneWidget);
    });

    testWidgets('Renders Media Management screen with Rausch brand palette', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AdminMediaScreen(
            authNotifier: authNotifier,
            repository: ModerationRepository(apiClient: apiClient),
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('tp/posts/55/photo_1'), findsOneWidget);
      expect(find.text('Chi tiết'), findsOneWidget);
    });

    testWidgets('Renders Places Management screen with Rausch brand palette', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPlacesScreen(
            authNotifier: authNotifier,
            repository: PlaceRepository(apiClient: apiClient),
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hồ Gươm Hoàn Kiếm'), findsOneWidget);
      expect(find.text('Thêm địa điểm'), findsOneWidget);
    });
  });
}
