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
import 'package:travel_planner_web/features/itineraries/data/itinerary_admin_repository.dart';
import 'package:travel_planner_web/features/itineraries/presentation/screens/admin_itineraries_screen.dart';

String _createMockJwt({required int expSeconds, String role = 'ADMIN'}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'admin_root', 'role': role, 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

Future<AuthNotifier> _buildAdminNotifier(
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

  group('Phase 3 Admin Itineraries Screen & Dialogs Tests', () {
    testWidgets('Loads server-side paged itineraries, filters, opens read-only detail, and hides/restores', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String currentStatus = 'ACTIVE';
      String? lastModerateBody;
      final queries = <Map<String, String>>[];

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/itineraries') {
          queries.add(request.url.queryParameters);
          final page = int.tryParse(request.url.queryParameters['page'] ?? '0') ?? 0;
          if (page == 1) {
            return http.Response(jsonEncode({
              'content': [
                {
                  'itineraryId': 202,
                  'title': 'Hành trình Trang 2',
                  'location': 'Phú Quốc',
                  'totalDays': 4,
                  'budget': 5000000,
                  'visibility': 'PUBLIC',
                  'status': 'HIDDEN',
                  'viewCount': 5,
                  'favoriteCount': 1,
                  'reuseCount': 0,
                  'createdAt': '2026-11-20T10:00:00',
                  'creator': {
                    'userId': 22,
                    'username': 'lan_travel',
                    'handle': 'lan.travel',
                    'fullName': 'Nguyễn Lan',
                  },
                },
              ],
              'pageNumber': 1,
              'pageSize': 20,
              'totalElements': 21,
              'totalPages': 2,
              'last': true,
            }), 200, headers: jsonHeaders);
          }

          return http.Response(jsonEncode({
            'content': [
              {
                'itineraryId': 101,
                'title': 'Khám phá Đà Lạt 3 ngày',
                'location': 'Đà Lạt',
                'totalDays': 3,
                'budget': 3500000,
                'visibility': 'PUBLIC',
                'status': currentStatus,
                'viewCount': 42,
                'favoriteCount': 9,
                'reuseCount': 3,
                'createdAt': '2026-11-22T09:00:00',
                'creator': {
                  'userId': 12,
                  'username': 'minh_trip',
                  'handle': 'minh.trip',
                  'fullName': 'Trần Minh',
                },
              },
            ],
            'pageNumber': 0,
            'pageSize': 20,
            'totalElements': 21,
            'totalPages': 2,
            'last': false,
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/itineraries/101') {
          return http.Response(jsonEncode({
            'itineraryId': 101,
            'title': 'Khám phá Đà Lạt 3 ngày',
            'description': 'Chuyến đi nghỉ dưỡng cuối tuần',
            'location': 'Đà Lạt',
            'totalDays': 3,
            'budget': 3500000,
            'theme': 'Nghỉ dưỡng',
            'visibility': 'PUBLIC',
            'status': currentStatus,
            'viewCount': 42,
            'favoriteCount': 9,
            'reuseCount': 3,
            'privateInspection': false,
            'creator': {
              'userId': 12,
              'username': 'minh_trip',
              'handle': 'minh.trip',
              'fullName': 'Trần Minh',
            },
            'days': [
              {
                'dayId': 1,
                'dayNumber': 1,
                'title': 'Check-in Hồ Xuân Hương',
                'activities': [
                  {
                    'activityId': 10,
                    'name': 'Dạo quanh Hồ Xuân Hương',
                    'startTime': '08:30:00',
                    'endTime': '10:00:00',
                    'displayOrder': 1,
                    'locationName': 'Hồ Xuân Hương',
                  },
                ],
              },
            ],
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/itineraries/101/moderate' && request.method == 'PATCH') {
          lastModerateBody = request.body;
          currentStatus = 'HIDDEN';
          return http.Response(jsonEncode({
            'itineraryId': 101,
            'title': 'Khám phá Đà Lạt 3 ngày',
            'location': 'Đà Lạt',
            'totalDays': 3,
            'budget': 3500000,
            'visibility': 'PUBLIC',
            'status': 'HIDDEN',
            'viewCount': 42,
            'favoriteCount': 9,
            'reuseCount': 3,
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not found', 404);
      });

      final notifier = await _buildAdminNotifier(mockClient);
      final repo = ItineraryAdminRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminItinerariesScreen(authNotifier: notifier, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý lịch trình'), findsOneWidget);
      expect(find.text('Tổng: 21 lịch trình'), findsOneWidget);
      expect(find.text('Khám phá Đà Lạt 3 ngày'), findsOneWidget);
      expect(find.text('Trần Minh'), findsOneWidget);

      // Search submit
      await tester.enterText(find.byType(TextField).first, 'Đà Lạt');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(queries.last['keyword'], 'Đà Lạt');

      // Open Read-Only detail dialog
      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết lịch trình (Chỉ đọc)'), findsOneWidget);
      expect(find.text('Dạo quanh Hồ Xuân Hương'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      // Open Moderate dialog and verify validation + submission
      await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('Ẩn lịch trình vi phạm'), findsOneWidget);

      await tester.tap(find.text('Xác nhận ẩn'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do từ 3 đến 255 ký tự.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Spam liên kết quảng cáo');
      await tester.tap(find.text('Xác nhận ẩn'));
      await tester.pumpAndSettle();
      expect(lastModerateBody, contains('HIDDEN'));
      expect(find.text('Đã ẩn'), findsWidgets);

      // Wait for moderation SnackBar to auto-dismiss before tapping bottom pagination
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Switch to page 2
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('Hành trình Trang 2'), findsOneWidget);
    });

    testWidgets('Supports PRIVATE inspection workflow with reportId and renders Strict Audit banner', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? capturedReportId;
      String? capturedReason;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/itineraries') {
          return http.Response(jsonEncode({
            'content': [],
            'pageNumber': 0,
            'pageSize': 20,
            'totalElements': 0,
            'totalPages': 0,
            'last': true,
          }), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/itineraries/305') {
          capturedReportId = request.url.queryParameters['reportId'];
          capturedReason = request.url.queryParameters['inspectionReason'];
          return http.Response(jsonEncode({
            'itineraryId': 305,
            'title': 'Lịch trình PRIVATE cần kiểm tra',
            'location': 'Hà Giang',
            'totalDays': 2,
            'budget': 2000000,
            'visibility': 'PRIVATE',
            'status': 'ACTIVE',
            'viewCount': 0,
            'favoriteCount': 0,
            'reuseCount': 0,
            'privateInspection': true,
            'inspectedReportId': 42,
            'days': [],
          }), 200, headers: jsonHeaders);
        }
        return http.Response('Not found', 404);
      });

      final notifier = await _buildAdminNotifier(mockClient);
      final repo = ItineraryAdminRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminItinerariesScreen(authNotifier: notifier, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kiểm tra PRIVATE'));
      await tester.pumpAndSettle();
      expect(find.text('Thanh tra lịch trình PRIVATE'), findsOneWidget);

      final fields = find.byType(TextField);
      // index 0 is toolbar search; index 1 itineraryId; index 2 reportId; index 3 reason
      await tester.enterText(fields.at(1), '305');
      await tester.enterText(fields.at(2), '42');
      await tester.enterText(fields.at(3), 'Thanh tra nội dung PRIVATE từ báo cáo #42');
      await tester.tap(find.text('Mở xem chỉ đọc'));
      await tester.pumpAndSettle();

      expect(capturedReportId, '42');
      expect(capturedReason, contains('báo cáo #42'));
      expect(find.text('Lịch trình PRIVATE cần kiểm tra'), findsOneWidget);
      expect(find.textContaining('Chế độ thanh tra lịch trình PRIVATE • Báo cáo #42'), findsOneWidget);
    });

    testWidgets('Displays error banner with retry, empty state, and blocks non-ADMIN users', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool shouldFail = true;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/itineraries') {
          if (shouldFail) {
            return http.Response(jsonEncode({'message': 'Lỗi tải danh sách lịch trình'}), 500, headers: jsonHeaders);
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

      final notifier = await _buildAdminNotifier(mockClient);
      final repo = ItineraryAdminRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminItinerariesScreen(authNotifier: notifier, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lỗi tải danh sách lịch trình'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy lịch trình nào phù hợp.'), findsOneWidget);

      final nonAdminClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'userId': 99, 'username': 'user_normal', 'role': 'USER'}), 200, headers: jsonHeaders);
        }
        return http.Response('Forbidden', 403);
      });
      final userNotifier = await _buildAdminNotifier(nonAdminClient, role: 'USER', userId: 99);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminItinerariesScreen(
            key: const ValueKey('non-admin-itineraries'),
            authNotifier: userNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bạn không có quyền truy cập chức năng Quản lý lịch trình.'), findsOneWidget);
    });
  });
}
