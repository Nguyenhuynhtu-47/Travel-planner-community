import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/features/auth/data/auth_repository.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/auth/presentation/screens/login_screen.dart';
import 'package:travel_planner_web/features/layout/presentation/screens/admin_shell.dart';
import 'package:travel_planner_web/main.dart';

String _createMockJwt({required int expSeconds}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'admin', 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

class MockInMemoryStorage extends Fake implements AuthStorage {
  String? _token;
  Map<String, dynamic>? _user;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<Map<String, dynamic>?> getUser() async => _user;

  @override
  Future<void> saveUser(Map<String, dynamic> user) async {
    _user = user;
  }

  @override
  Future<void> clear() async {
    _token = null;
    _user = null;
  }
}

http.Client createMockHttpClient(String validAdminJwt) {
  return MockClient((request) async {
    final path = request.url.path;

    if (path.contains('/api/auth/login')) {
      final body = json.decode(request.body) as Map<String, dynamic>;
      final username = body['usernameOrEmail'];
      final password = body['password'];

      if (username == 'admin' && password == '123456') {
        final resBody = json.encode({
          'token': validAdminJwt,
          'tokenType': 'Bearer',
          'user': {
            'userId': 578,
            'username': 'admin',
            'fullName': 'Nguyễn Hoàng Nam (Admin)',
            'role': 'ADMIN',
            'email': 'admin@gmail.com',
            'status': 'ACTIVE',
          }
        });
        return http.Response(
          resBody,
          200,
          headers: {'content-type': 'application/json'},
        );
      } else if (username == 'user' && password == '123456') {
        final resBody = json.encode({
          'token': 'mock-user-jwt-token',
          'tokenType': 'Bearer',
          'user': {
            'userId': 577,
            'username': 'user',
            'fullName': 'Normal User',
            'role': 'USER',
            'email': 'user@gmail.com',
            'status': 'ACTIVE',
          }
        });
        return http.Response(
          resBody,
          200,
          headers: {'content-type': 'application/json'},
        );
      } else {
        final resBody = json.encode({
          'status': 401,
          'message': 'Tên đăng nhập hoặc mật khẩu không chính xác',
        });
        return http.Response(
          resBody,
          401,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    if (path.contains('/api/auth/me') || path.contains('/api/users/me')) {
      final token = request.headers['authorization'];
      if (token == 'Bearer $validAdminJwt') {
        final resBody = json.encode({
          'userId': 578,
          'username': 'admin',
          'fullName': 'Nguyễn Hoàng Nam (Admin)',
          'role': 'ADMIN',
          'email': 'admin@gmail.com',
          'status': 'ACTIVE',
        });
        return http.Response(
          resBody,
          200,
          headers: {'content-type': 'application/json'},
        );
      } else {
        return http.Response(
          '{"status": 401}',
          401,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    if (path.contains('/api/health')) {
      return http.Response(
        json.encode({'status': 'UP', 'service': 'travel-planner-backend'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/admin/places')) {
      return http.Response(
        json.encode({'content': [], 'totalElements': 12}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/admin/community/posts')) {
      return http.Response(
        json.encode({'content': [], 'totalElements': 8}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/admin/community/reports')) {
      return http.Response(
        json.encode({'content': [], 'totalElements': 2}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/admin/media-assets')) {
      return http.Response(
        json.encode({'content': [], 'totalElements': 5}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.Response(
      '{"content": [], "totalElements": 0}',
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  final validAdminJwt = _createMockJwt(
    expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400,
  );

  testWidgets('1. Empty submission shows validation errors', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storage = MockInMemoryStorage();
    final mockClient = createMockHttpClient(validAdminJwt);
    final apiClient = ApiClient(client: mockClient);
    final notifier = AuthNotifier(
      repository: AuthRepository(apiClient: apiClient),
      storage: storage,
    );

    await tester.pumpWidget(MyApp(authNotifier: notifier, apiClient: apiClient));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Travel Planner Portal'), findsOneWidget);

    // Tap "Đăng nhập" button without filling inputs
    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();

    expect(find.text('Vui lòng nhập tên đăng nhập hoặc email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
  });

  testWidgets('2. Invalid credentials show error SnackBar without crash', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storage = MockInMemoryStorage();
    final mockClient = createMockHttpClient(validAdminJwt);
    final apiClient = ApiClient(client: mockClient);
    final notifier = AuthNotifier(
      repository: AuthRepository(apiClient: apiClient),
      storage: storage,
    );

    await tester.pumpWidget(MyApp(authNotifier: notifier, apiClient: apiClient));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Fill wrong credentials
    await tester.enterText(find.byType(TextFormField).first, 'admin');
    await tester.enterText(find.byType(TextFormField).last, 'wrongpwd');
    await tester.pump();

    // Tap "Đăng nhập"
    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tên đăng nhập hoặc mật khẩu không chính xác'), findsOneWidget);
    expect(notifier.isAuthenticated, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('3. ADMIN login transitions to AdminShell with active sidebar', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storage = MockInMemoryStorage();
    final mockClient = createMockHttpClient(validAdminJwt);
    final apiClient = ApiClient(client: mockClient);
    final notifier = AuthNotifier(
      repository: AuthRepository(apiClient: apiClient),
      storage: storage,
    );

    await tester.pumpWidget(MyApp(authNotifier: notifier, apiClient: apiClient));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Fill valid admin credentials
    await tester.enterText(find.byType(TextFormField).first, 'admin');
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tester.pump();

    // Tap "Đăng nhập"
    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(notifier.isAuthenticated, isTrue);
    expect(notifier.currentUser?['role'], 'ADMIN');
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('Admin Portal'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.textContaining('Trung tâm Quản trị Travel Planner'), findsOneWidget);
  });

  testWidgets('4. Non-ADMIN user is rejected with permission error and remains unauthenticated', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storage = MockInMemoryStorage();
    final mockClient = createMockHttpClient(validAdminJwt);
    final apiClient = ApiClient(client: mockClient);
    final notifier = AuthNotifier(
      repository: AuthRepository(apiClient: apiClient),
      storage: storage,
    );

    await tester.pumpWidget(MyApp(authNotifier: notifier, apiClient: apiClient));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Fill USER credentials
    await tester.enterText(find.byType(TextFormField).first, 'user');
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tester.pump();

    // Tap "Đăng nhập"
    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // RBAC: login rejects non-ADMIN with error
    expect(notifier.isAuthenticated, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Tài khoản không có quyền truy cập trang quản trị'), findsOneWidget);
  });

  testWidgets('5. Session restore on app launch preserves authenticated ADMIN state', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storage = MockInMemoryStorage();
    await storage.saveToken(validAdminJwt);
    await storage.saveUser({
      'userId': 578,
      'username': 'admin',
      'role': 'ADMIN',
    });

    final mockClient = createMockHttpClient(validAdminJwt);
    final apiClient = ApiClient(client: mockClient);
    final notifier = AuthNotifier(
      repository: AuthRepository(apiClient: apiClient),
      storage: storage,
    );

    await tester.pumpWidget(MyApp(authNotifier: notifier, apiClient: apiClient));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(notifier.isAuthenticated, isTrue);
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('Admin Portal'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.textContaining('Trung tâm Quản trị Travel Planner'), findsOneWidget);
  });
}
