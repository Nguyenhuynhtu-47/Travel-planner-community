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
import 'package:travel_planner_web/features/layout/presentation/widgets/admin_header.dart';
import 'package:travel_planner_web/features/layout/presentation/widgets/admin_sidebar.dart';
import 'package:travel_planner_web/features/layout/presentation/widgets/placeholder_feature_view.dart';

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

  group('AdminTab Domain & Grouping Tests', () {
    test('Verifies tab categories and labels conform to specification', () {
      expect(AdminTabGroup.overview.label, 'TỔNG QUAN');
      expect(AdminTabGroup.community.label, 'QUẢN LÝ CỘNG ĐỒNG');
      expect(AdminTabGroup.travel.label, 'QUẢN LÝ DU LỊCH');
      expect(AdminTabGroup.content.label, 'QUẢN LÝ NỘI DUNG');
      expect(AdminTabGroup.system.label, 'HỆ THỐNG');

      expect(AdminTab.dashboard.group, AdminTabGroup.overview);
      expect(AdminTab.posts.group, AdminTabGroup.community);
      expect(AdminTab.reports.group, AdminTabGroup.community);
      expect(AdminTab.users.group, AdminTabGroup.community);
      expect(AdminTab.places.group, AdminTabGroup.travel);
      expect(AdminTab.itineraries.group, AdminTabGroup.travel);
      expect(AdminTab.media.group, AdminTabGroup.content);
      expect(AdminTab.administrativeAreas.group, AdminTabGroup.content);
      expect(AdminTab.auditLogs.group, AdminTabGroup.system);
      expect(AdminTab.settings.group, AdminTabGroup.system);
    });

    test('Verifies implementation status of tabs', () {
      expect(AdminTab.dashboard.isImplemented, isTrue);
      expect(AdminTab.posts.isImplemented, isTrue);
      expect(AdminTab.reports.isImplemented, isTrue);
      expect(AdminTab.places.isImplemented, isTrue);
      expect(AdminTab.media.isImplemented, isTrue);
      expect(AdminTab.profile.isImplemented, isTrue);

      expect(AdminTab.users.isImplemented, isFalse);
      expect(AdminTab.itineraries.isImplemented, isFalse);
      expect(AdminTab.administrativeAreas.isImplemented, isFalse);
      expect(AdminTab.auditLogs.isImplemented, isFalse);
      expect(AdminTab.settings.isImplemented, isFalse);
    });
  });

  group('DashboardRepository Unit Tests', () {
    test('fetchDashboardData returns real statistics when APIs succeed', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response(
            jsonEncode({'status': 'UP', 'service': 'travel-planner-backend', 'timestamp': '2026-11-23T00:00:00'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/places') {
          return http.Response(
            jsonEncode({'content': [{'placeId': 1}], 'totalElements': 42}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/community/posts') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'postId': 100,
                  'content': 'Test post',
                  'author': {'userId': 1, 'handle': 'tester', 'fullName': 'Tester'},
                  'mediaUrls': [],
                  'status': 'ACTIVE',
                }
              ],
              'totalElements': 15,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'reportId': 10,
                  'postId': 100,
                  'reason': 'Spam test',
                  'status': 'PENDING',
                  'createdAt': '2026-11-23T00:00:00',
                  'reporter': {'userId': 2, 'handle': 'reporter1'},
                }
              ],
              'totalElements': 3,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(
            jsonEncode({'content': [], 'totalElements': 8}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = DashboardRepository(apiClient: ApiClient(client: mockClient));
      final data = await repo.fetchDashboardData('valid_jwt_token');

      expect(data.healthStatus, 'UP');
      expect(data.serviceName, 'travel-planner-backend');
      expect(data.placesCount, 42);
      expect(data.postsCount, 15);
      expect(data.pendingReportsCount, 3);
      expect(data.mediaAssetsCount, 8);
      expect(data.recentPendingReports.length, 1);
      expect(data.recentPosts.length, 1);
    });

    test('fetchDashboardData handles unauthenticated or null token gracefully', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/health') {
          return http.Response(jsonEncode({'status': 'UP'}), 200);
        }
        return http.Response('Unauthorized', 401);
      });

      final repo = DashboardRepository(apiClient: ApiClient(client: mockClient));
      final data = await repo.fetchDashboardData(null);

      expect(data.healthStatus, 'UP');
      expect(data.errorMessage, contains('Chưa có phiên đăng nhập'));
      expect(data.placesCount, 0);
    });
  });

  group('PlaceholderFeatureView Widget Tests', () {
    testWidgets('Renders planned features roadmap and back button', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool wentBack = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceholderFeatureView(
              tab: AdminTab.users,
              onGoToDashboard: () => wentBack = true,
            ),
          ),
        ),
      );

      expect(find.text('Quản lý người dùng'), findsOneWidget);
      expect(find.text('Chưa triển khai'), findsOneWidget);
      expect(find.textContaining('Nhóm: QUẢN LÝ CỘNG ĐỒNG'), findsOneWidget);
      expect(find.textContaining('Lộ trình chức năng dự kiến:'), findsOneWidget);
      expect(find.text('Quay lại trang Tổng quan'), findsOneWidget);

      await tester.tap(find.text('Quay lại trang Tổng quan'));
      await tester.pump();
      expect(wentBack, isTrue);
    });
  });

  group('AdminSidebar Widget Tests', () {
    testWidgets('Renders all navigation groups and triggers selection', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      AdminTab selected = AdminTab.dashboard;
      bool collapsed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSidebar(
              currentTab: selected,
              onSelectTab: (tab) => selected = tab,
              isCollapsed: false,
              onToggleCollapse: () => collapsed = true,
              currentUser: const {'username': 'admin_john', 'role': 'ADMIN'},
              onLogout: () {},
              pendingReportsCount: 5,
            ),
          ),
        ),
      );

      expect(find.text('Travel Planner'), findsOneWidget);
      expect(find.text('Cổng quản trị'), findsOneWidget);
      expect(find.text('TỔNG QUAN'), findsOneWidget);
      expect(find.text('QUẢN LÝ CỘNG ĐỒNG'), findsOneWidget);
      expect(find.text('QUẢN LÝ DU LỊCH'), findsOneWidget);
      expect(find.text('QUẢN LÝ NỘI DUNG'), findsOneWidget);
      expect(find.text('HỆ THỐNG'), findsOneWidget);

      expect(find.text('Kiểm duyệt bài viết'), findsOneWidget);
      expect(find.text('Quản lý báo cáo'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // Pending reports badge
      expect(find.text('Quản lý địa điểm'), findsOneWidget);
      expect(find.text('Quản lý Media'), findsOneWidget);

      // Verify SaaS icons are rendered next to items
      expect(find.byIcon(AdminTab.dashboard.activeIcon), findsOneWidget);
      expect(find.byIcon(AdminTab.posts.icon), findsOneWidget);
      expect(find.byIcon(AdminTab.places.icon), findsOneWidget);

      // Tap on a tab
      await tester.tap(find.text('Quản lý địa điểm'));
      await tester.pump();
      expect(selected, AdminTab.places);

      // Tap on Collapse
      await tester.tap(find.text('Thu gọn menu'));
      await tester.pump();
      expect(collapsed, isTrue);
    });

    testWidgets('Sidebar in collapsed mode renders centered icons with tooltips and badge', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSidebar(
              currentTab: AdminTab.dashboard,
              onSelectTab: (_) {},
              isCollapsed: true,
              onToggleCollapse: () {},
              currentUser: const {'username': 'admin_john', 'role': 'ADMIN'},
              onLogout: () {},
              pendingReportsCount: 2,
            ),
          ),
        ),
      );

      // Collapsed icons
      expect(find.byIcon(AdminTab.dashboard.activeIcon), findsOneWidget);
      expect(find.byIcon(AdminTab.posts.icon), findsOneWidget);
      expect(find.byIcon(AdminTab.places.icon), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Pending reports badge
    });

    test('AdminTab routePath and fromRoute resolution', () {
      expect(AdminTab.fromRoute('/reports'), AdminTab.reports);
      expect(AdminTab.fromRoute('/posts'), AdminTab.posts);
      expect(AdminTab.fromRoute('/places'), AdminTab.places);
      expect(AdminTab.fromRoute('/media'), AdminTab.media);
      expect(AdminTab.fromRoute('/dashboard'), AdminTab.dashboard);
      expect(AdminTab.fromRoute('/'), AdminTab.dashboard);
      expect(AdminTab.fromRoute(null), AdminTab.dashboard);
      expect(AdminTab.fromRoute('#/reports'), AdminTab.reports);
      expect(AdminTab.fromRoute('#/places'), AdminTab.places);

      expect(AdminTab.reports.routePath, '/reports');
      expect(AdminTab.posts.routePath, '/posts');
      expect(AdminTab.places.routePath, '/places');
      expect(AdminTab.media.routePath, '/media');
    });
  });

  group('AdminHeader Widget Tests', () {
    testWidgets('Renders breadcrumbs, title, online status and profile button', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool sidebarToggled = false;
      bool wentToProfile = false;
      bool loggedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminHeader(
              currentTab: AdminTab.posts,
              currentUser: const {'fullName': 'Admin User', 'username': 'admin1', 'role': 'ADMIN'},
              onToggleSidebar: () => sidebarToggled = true,
              onGoToProfile: () => wentToProfile = true,
              onLogout: () => loggedOut = true,
              healthStatus: 'UP',
            ),
          ),
        ),
      );

      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('QUẢN LÝ CỘNG ĐỒNG'), findsOneWidget);
      expect(find.text('Kiểm duyệt bài viết'), findsOneWidget); // Breadcrumb only (page title moved to PageHeader)
      expect(find.text('Hệ thống: Trực tuyến'), findsOneWidget);
      expect(find.text('Admin User'), findsOneWidget);

      // Toggle sidebar
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      expect(sidebarToggled, isTrue);

      // Profile tap
      await tester.tap(find.text('Admin User'));
      await tester.pump();
      expect(wentToProfile, isTrue);

      // Logout tap
      await tester.tap(find.byTooltip('Đăng xuất'));
      await tester.pump();
      expect(loggedOut, isTrue);
    });
  });

  group('AdminDashboardScreen Widget Tests', () {
    testWidgets('Renders metric cards and handles quick navigation', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({'auth_token': 'admin_jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin', 'role': 'ADMIN'});

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response(jsonEncode({'status': 'UP', 'service': 'travel-planner-backend'}), 200);
        }
        if (request.url.path == '/api/admin/places') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 50}), 200);
        }
        if (request.url.path == '/api/admin/community/posts') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 25}), 200);
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 4}), 200);
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 12}), 200);
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

      expect(find.text('Xin chào, admin!'), findsOneWidget);
      expect(find.text('Địa điểm chuẩn hóa'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Bài viết cộng đồng'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('Báo cáo chờ xử lý'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Tài nguyên Media'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      // Metric card navigation
      await tester.tap(find.text('Bài viết cộng đồng'));
      await tester.pump();
      expect(targetTab, AdminTab.posts);
    });
  });

  group('AdminShell Full Navigation & RBAC Tests', () {
    testWidgets('Non-admin user (role: USER) sees Access Denied screen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authStorage = AuthStorage();
      await authStorage.saveUser({'userId': 2, 'username': 'user2', 'role': 'USER'});

      final mockClient = MockClient((request) async => http.Response('{}', 200));
      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Truy cập bị từ chối'), findsOneWidget);
      expect(find.textContaining('Bạn cần tài khoản có vai trò Quản trị viên (ADMIN)'), findsOneWidget);
    });

    testWidgets('Admin user mounts AdminShell and switches between tabs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/health') {
          return http.Response(jsonEncode({'status': 'UP'}), 200);
        }
        if (request.url.path == '/api/admin/places') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 10}), 200);
        }
        if (request.url.path == '/api/admin/community/posts') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 5}), 200);
        }
        if (request.url.path == '/api/admin/community/reports') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 1}), 200);
        }
        if (request.url.path == '/api/admin/media-assets') {
          return http.Response(jsonEncode({'content': [], 'totalElements': 2}), 200);
        }
        return http.Response('{}', 200);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      // Dashboard is default
      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Xin chào, admin_root!'), findsOneWidget);

      // Switch to Places
      await tester.tap(find.text('Quản lý địa điểm'));
      await tester.pumpAndSettle();
      expect(find.text('Quản lý Địa điểm Chuẩn hóa (Places)'), findsWidgets);

      // Switch to Standalone Post Moderation Screen
      await tester.tap(find.text('Kiểm duyệt bài viết'));
      await tester.pumpAndSettle();
      expect(find.text('Quản lý, rà soát và kiểm duyệt nội dung bài đăng cộng đồng vi phạm tiêu chuẩn.'), findsOneWidget);

      // Switch to Standalone Reports Screen
      await tester.tap(find.text('Quản lý báo cáo'));
      await tester.pumpAndSettle();
      expect(find.text('Xử lý, phân giải và rà soát các báo cáo vi phạm tiêu chuẩn từ cộng đồng người dùng.'), findsOneWidget);

      // Switch to Standalone Media Screen
      await tester.tap(find.text('Quản lý Media'));
      await tester.pumpAndSettle();
      expect(find.text('Giám sát tài nguyên tải lên Cloudinary, xử lý dead-letter và retry dọn dẹp file rác.'), findsOneWidget);

      // Switch to Coming Soon tab: Users
      await tester.tap(find.text('Quản lý người dùng'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa triển khai'), findsOneWidget);
    });
  });
}
