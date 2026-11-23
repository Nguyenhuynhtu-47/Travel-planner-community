import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/data/auth_repository.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/features/layout/presentation/screens/admin_shell.dart';
import 'package:travel_planner_web/features/layout/presentation/widgets/admin_header.dart';
import 'package:travel_planner_web/features/locations/data/place_repository.dart';
import 'package:travel_planner_web/features/locations/presentation/screens/admin_places_screen.dart';
import 'package:travel_planner_web/features/moderation/data/moderation_repository.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_media_screen.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_posts_screen.dart';
import 'package:travel_planner_web/shared/widgets/admin_data_table.dart';
import 'package:travel_planner_web/shared/widgets/admin_page_header.dart';

String _createMockJwt() {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'sub': 'admin_root',
    'role': 'ADMIN',
    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 7200,
  })));
  return '$header.$payload.mockSig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  const targetViewports = [
    Size(1440, 900),
    Size(1366, 768),
    Size(1024, 768),
    Size(768, 1024),
  ];

  group('Admin UI Refinement & Overflow Verification Suite', () {
    late AuthNotifier authNotifier;
    late ApiClient apiClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt();
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'fullName': 'Quản trị viên', 'role': 'ADMIN'});

      // Mock 20 Places (previously caused 553px bottom overflow)
      final mockPlaces = List.generate(20, (i) => {
        'placeId': i + 1,
        'name': 'Địa điểm du lịch số #${i + 1} tại Việt Nam',
        'address': 'Số ${i + 1} Đường Lê Lợi, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
        'category': i % 2 == 0 ? 'ATTRACTION' : 'RESTAURANT',
        'status': i % 4 == 0 ? 'HIDDEN' : 'ACTIVE',
        'latitude': 10.7769 + (i * 0.001),
        'longitude': 106.7009 + (i * 0.001),
        'administrativeArea': {
          'name': 'Hồ Chí Minh',
          'code': 'VN-SG',
        },
      });

      // Mock 20 Media Assets (previously caused 495px bottom overflow)
      final mockMedia = List.generate(20, (i) => {
        'mediaAssetId': 200 + i,
        'uploadedByUserId': 10 + i,
        'uploadedByUsername': 'traveler_${i + 1}',
        'cloudinaryPublicId': 'tp/posts/photo_asset_2026_${i + 1}',
        'secureUrl': 'https://res.cloudinary.com/demo/image/upload/sample_${i + 1}.jpg',
        'status': i % 3 == 0 ? 'UNATTACHED' : 'ATTACHED',
        'mediaType': 'image/jpeg',
        'retryCount': i % 5 == 0 ? 3 : 0,
        'deadLetteredAt': i % 5 == 0 ? '2026-11-23T11:00:00Z' : null,
        'lastError': i % 5 == 0 ? 'Cloudinary 404 resource not found' : null,
        'createdAt': '2026-11-23T10:00:00Z',
      });

      // Mock 20 Community Posts
      final mockPosts = List.generate(20, (i) => {
        'postId': 100 + i,
        'author': {'userId': 10 + i, 'handle': 'user_${i + 1}', 'displayName': 'Thành viên ${i + 1}'},
        'content': 'Bài viết chia sẻ kinh nghiệm du lịch lịch trình ngày ${i + 1} cực kỳ thú vị và bổ ích cho cộng đồng phượt thủ...',
        'status': i % 4 == 0 ? 'HIDDEN' : 'ACTIVE',
        'createdAt': '2026-11-23T08:00:00Z',
        'mediaUrls': ['https://images.unsplash.com/sample_${i + 1}.jpg'],
        'likeCount': 10 + i,
        'commentCount': 2 + i,
      });

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/health') {
          return http.Response(jsonEncode({'status': 'UP'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/places') {
          return http.Response(
            jsonEncode({
              'content': mockPlaces,
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 20,
              'totalPages': 1,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(
            jsonEncode({
              'content': mockMedia,
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 20,
              'totalPages': 1,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/community/posts') {
          return http.Response(
            jsonEncode({
              'content': mockPosts,
              'pageNumber': 0,
              'pageSize': 20,
              'totalElements': 20,
              'totalPages': 1,
            }),
            200,
            headers: jsonHeaders,
          );
        }
        if (request.url.path == '/api/admin/dashboard') {
          return http.Response(
            jsonEncode({
              'healthStatus': 'UP',
              'placesCount': 20,
              'postsCount': 20,
              'pendingReportsCount': 0,
              'mediaAssetsCount': 20,
              'recentPendingReports': [],
              'recentPosts': mockPosts.take(5).toList(),
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

    test('1. Verified Micro-radius Design Tokens', () {
      expect(AppRadius.input, 6.0, reason: 'Inputs / selects must have 6px micro-radius');
      expect(AppRadius.button, 6.0, reason: 'Buttons must have 6px micro-radius');
      expect(AppRadius.sidebarItem, 6.0, reason: 'Sidebar items must have 6px micro-radius');
      expect(AppRadius.card, 8.0, reason: 'Cards / panels must have 8px micro-radius');
      expect(AppRadius.dialog, 8.0, reason: 'Dialogs must have 8px micro-radius');
      expect(AppRadius.table, 8.0, reason: 'Table containers must have 8px micro-radius');
      expect(AppRadius.badge, 4.0, reason: 'Status badges must have 4px micro-radius');
    });

    testWidgets('2. Header Eliminates Duplicate Page Title', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminHeader(
              currentTab: AdminTab.places,
              currentUser: const {'fullName': 'Quản trị viên', 'role': 'ADMIN'},
              onToggleSidebar: () {},
              onGoToProfile: () {},
              onLogout: () {},
              healthStatus: 'UP',
            ),
          ),
        ),
      );

      // Verify breadcrumb is rendered cleanly
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('QUẢN LÝ DU LỊCH'), findsOneWidget);
      expect(find.text('Quản lý địa điểm'), findsOneWidget); // ShortTitle in breadcrumb

      // CRITICAL: Ensure independent duplicate page title "Quản lý địa điểm chuẩn hóa" is NOT in AdminHeader
      expect(find.text('Quản lý địa điểm chuẩn hóa'), findsNothing);
    });

    for (final vp in targetViewports) {
      testWidgets('3. Places Management has ZERO RenderFlex overflow at ${vp.width.toInt()}x${vp.height.toInt()} with 20 rows', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

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

        // Verify zero overflow errors
        expect(tester.takeException(), isNull);

        // Verify Header and PageHeader rendered correctly
        expect(find.byType(AdminPageHeader), findsOneWidget);
        expect(find.text('Quản lý Địa điểm Chuẩn hóa (Places)'), findsOneWidget);

        // Verify Table and Pagination are mounted and visible
        expect(find.byType(AdminDataTable), findsOneWidget);
        expect(find.text('Hiển thị 1 - 20 trong số 20 bản ghi'), findsOneWidget);
        expect(find.text('Trang 1 / 1'), findsOneWidget);

        // Verify places data rendered
        expect(find.text('#1'), findsOneWidget);
        expect(find.text('#20'), findsOneWidget);
      });

      testWidgets('4. Media Management has ZERO RenderFlex overflow at ${vp.width.toInt()}x${vp.height.toInt()} with 20 rows', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

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

        // Verify zero overflow errors
        expect(tester.takeException(), isNull);

        // Verify Header and Table
        expect(find.byType(AdminPageHeader), findsOneWidget);
        expect(find.byType(AdminDataTable), findsOneWidget);
        expect(find.text('Hiển thị 1 - 20 trong số 20 bản ghi'), findsOneWidget);
        expect(find.text('#200'), findsOneWidget);
      });

      testWidgets('5. Post Moderation has ZERO RenderFlex overflow at ${vp.width.toInt()}x${vp.height.toInt()} with 20 rows', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

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

        // Verify zero overflow errors
        expect(tester.takeException(), isNull);

        // Verify Header and Table
        expect(find.byType(AdminPageHeader), findsOneWidget);
        expect(find.byType(AdminDataTable), findsOneWidget);
        expect(find.text('Hiển thị 1 - 20 trong số 20 bản ghi'), findsOneWidget);
        expect(find.text('#100'), findsOneWidget);
      });

      testWidgets('6. Dashboard has ZERO RenderFlex overflow at ${vp.width.toInt()}x${vp.height.toInt()}', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminDashboardScreen(
              authNotifier: authNotifier,
              onNavigateTab: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify zero overflow errors
        expect(tester.takeException(), isNull);
        expect(find.byType(AdminPageHeader), findsOneWidget);
        expect(find.text('Tổng quan'), findsOneWidget);
      });
    }

    testWidgets('7. AdminShell mounts smoothly across viewports without duplicate headers', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            authNotifier: authNotifier,
            initialTab: AdminTab.places,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Header has breadcrumb "Quản lý địa điểm"
      expect(
        find.descendant(of: find.byType(AdminHeader), matching: find.text('Quản lý địa điểm')),
        findsOneWidget,
      );
      // Header must NOT contain duplicate page title
      expect(
        find.descendant(of: find.byType(AdminHeader), matching: find.text('Quản lý Địa điểm Chuẩn hóa (Places)')),
        findsNothing,
      );
      // PageHeader has main title "Quản lý Địa điểm Chuẩn hóa (Places)"
      expect(
        find.descendant(of: find.byType(AdminPageHeader), matching: find.text('Quản lý Địa điểm Chuẩn hóa (Places)')),
        findsOneWidget,
      );
    });
  });
}
