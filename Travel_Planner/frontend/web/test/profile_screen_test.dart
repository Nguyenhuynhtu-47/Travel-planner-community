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
import 'package:travel_planner_web/features/profile/data/profile_repository.dart';
import 'package:travel_planner_web/features/profile/presentation/screens/profile_screen.dart';
import 'package:travel_planner_web/shared/widgets/app_text_field.dart';

String _createMockJwt({required int expSeconds}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'admin_root', 'role': 'ADMIN', 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  testWidgets('AppTextField safely handles multiline with TextInputAction.newline without assertion crash', (tester) async {
    final controller = TextEditingController(text: 'Dòng 1\nDòng 2');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            label: 'Giới thiệu',
            controller: controller,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Giới thiệu'), findsOneWidget);
    expect(find.text('Dòng 1\nDòng 2'), findsOneWidget);
  });

  testWidgets('ProfileScreen switches to 2-column Edit Mode without crash and saves updated profile', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
    final validToken = _createMockJwt(
      expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    );
    final authStorage = AuthStorage();
    await authStorage.saveToken(validToken);
    await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

    Map<String, dynamic>? savedPayload;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/user/profile' && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'userId': 1,
            'username': 'admin_root',
            'fullName': 'Quản Trị Viên',
            'email': 'admin@travelplanner.vn',
            'handle': 'admin.master',
            'role': 'ADMIN',
            'status': 'ACTIVE',
            'phone': '0901234567',
            'address': 'TP. Hồ Chí Minh',
            'bio': 'Quản trị hệ thống Travel Planner',
            'createdAt': '2026-01-01T00:00:00Z',
          }),
          200,
          headers: jsonHeaders,
        );
      }
      if (request.url.path == '/api/user/profile' && request.method == 'PUT') {
        savedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'userId': 1,
            'username': 'admin_root',
            'fullName': savedPayload!['fullName'],
            'email': 'admin@travelplanner.vn',
            'handle': savedPayload!['handle'],
            'role': 'ADMIN',
            'status': 'ACTIVE',
            'phone': savedPayload!['phone'],
            'address': savedPayload!['address'],
            'bio': savedPayload!['bio'],
            'avatar': savedPayload!['avatar'],
            'createdAt': '2026-01-01T00:00:00Z',
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

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          authNotifier: authNotifier,
          repository: ProfileRepository(apiClient: ApiClient(client: mockClient)),
          embedded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 2-column View Mode
    expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
    expect(find.text('Quản Trị Viên'), findsWidgets);
    expect(find.text('@admin.master'), findsNWidgets(2));
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Thông tin tài khoản'), findsOneWidget);

    // Enter Edit Mode (previously crashed at Giới thiệu TextField)
    await tester.tap(find.text('Chỉnh sửa hồ sơ').first);
    await tester.pumpAndSettle();

    expect(find.text('Hủy bỏ'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(3));

    // Edit bio and save
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quản trị hệ thống Travel Planner'),
      'Cập nhật giới thiệu mới',
    );
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(savedPayload, isNotNull);
    expect(savedPayload!['bio'], 'Cập nhật giới thiệu mới');
    expect(find.text('Đã cập nhật hồ sơ'), findsOneWidget);
  });
}
