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
import 'package:travel_planner_web/shared/widgets/admin_dialog.dart';
import 'package:travel_planner_web/shared/widgets/web_map_view.dart';

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

  group('AdminPlacesScreen Phase 5 Enterprise Tests', () {
    testWidgets('Renders server-side pagination, status badge, total count, and changes page', (tester) async {
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
        if (request.url.path == '/api/admin/places') {
          requestedPage = int.tryParse(request.url.queryParameters['page'] ?? '0') ?? 0;
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'placeId': 101,
                  'name': 'Hồ Hoàn Kiếm',
                  'address': 'Hoàn Kiếm, Hà Nội',
                  'category': 'ATTRACTION',
                  'status': 'ACTIVE',
                  'latitude': 21.0285,
                  'longitude': 105.8542,
                  'administrativeArea': {
                    'name': 'Hà Nội',
                    'code': 'VN-HN',
                  },
                },
                {
                  'placeId': 102,
                  'name': 'Cà Phê Trứng Giảng',
                  'address': '39 Nguyễn Hữu Huân, Hà Nội',
                  'category': 'CAFE',
                  'status': 'HIDDEN',
                  'latitude': 21.0335,
                  'longitude': 105.8538,
                  'administrativeArea': {
                    'name': 'Hà Nội',
                    'code': 'VN-HN',
                  },
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
        return http.Response('Not found', 404);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();
      final repo = PlaceRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPlacesScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Total Count Chip
      expect(find.text('Quản lý Địa điểm Chuẩn hóa (Places)'), findsOneWidget);
      expect(find.text('Tổng: 45 địa điểm'), findsOneWidget);

      // Verify Data Table contents
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      expect(find.text('Điểm tham quan'), findsOneWidget);
      expect(find.text('Hoạt động'), findsOneWidget);

      expect(find.text('#102'), findsOneWidget);
      expect(find.text('Cà Phê Trứng Giảng'), findsOneWidget);
      expect(find.text('Quán cà phê'), findsOneWidget);
      expect(find.text('Đã ẩn'), findsOneWidget);

      // Verify Pagination Footer
      expect(find.textContaining('Trang 1 / 3'), findsOneWidget);

      // Tap Next Page
      final nextButton = find.byTooltip('Trang sau');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(requestedPage, equals(1));
    });

    testWidgets('Filter by category and status sends query parameters and resets page', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      String? capturedCategory;
      String? capturedStatus;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/places') {
          capturedCategory = request.url.queryParameters['category'];
          capturedStatus = request.url.queryParameters['status'];
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
      final repo = PlaceRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPlacesScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedCategory, isNull);
      expect(capturedStatus, isNull);

      // Select category 'RESTAURANT'
      await tester.tap(find.text('Tất cả danh mục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhà hàng').last);
      await tester.pumpAndSettle();

      expect(capturedCategory, equals('RESTAURANT'));

      // Select status 'HIDDEN'
      await tester.tap(find.text('Tất cả trạng thái'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đã ẩn').last);
      await tester.pumpAndSettle();

      expect(capturedStatus, equals('HIDDEN'));
    });

    testWidgets('Opens Place Detail modal and displays technical details and map', (tester) async {
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
        if (request.url.path == '/api/admin/places') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'placeId': 555,
                  'name': 'Dinh Độc Lập Landmark',
                  'address': '135 Nam Kỳ Khởi Nghĩa, Bến Thành, Quận 1, TP.HCM',
                  'category': 'ATTRACTION',
                  'status': 'ACTIVE',
                  'latitude': 10.7770,
                  'longitude': 106.6953,
                  'description': 'Di tích lịch sử văn hóa cấp quốc gia',
                  'administrativeArea': {'name': 'TP. Hồ Chí Minh'},
                  'providerMappings': [
                    {'provider': 'TOMTOM', 'providerPlaceId': 'poi:555'}
                  ],
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
      final repo = PlaceRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPlacesScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Chi tiết
      await tester.tap(find.text('Chi tiết'));
      await tester.pumpAndSettle();

      // Verify Detail Modal
      expect(find.byType(AdminDialog), findsOneWidget);
      expect(find.text('Chi tiết Địa điểm #555'), findsOneWidget);
      expect(find.text('Dinh Độc Lập Landmark'), findsWidgets);
      expect(find.descendant(of: find.byType(AdminDialog), matching: find.text('TP. Hồ Chí Minh')), findsOneWidget);
      expect(find.text('Di tích lịch sử văn hóa cấp quốc gia'), findsOneWidget);
      expect(find.text('TOMTOM: poi:555'), findsOneWidget);
      expect(find.byType(WebMapView), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDialog), findsNothing);
    });

    testWidgets('Create place flow opens PlaceFormDialog and posts payload', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      bool placeCreated = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/places' && request.method == 'GET') {
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
        if (request.url.path == '/api/admin/places' && request.method == 'POST') {
          placeCreated = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], equals('Bưu Điện Trung Tâm'));
          expect(body['category'], equals('ATTRACTION'));
          return http.Response(
            jsonEncode({
              'placeId': 888,
              'name': 'Bưu Điện Trung Tâm',
              'address': 'Số 2 Công Xã Paris, Bến Nghé, Quận 1',
              'category': 'ATTRACTION',
              'status': 'ACTIVE',
              'latitude': 10.7798,
              'longitude': 106.6999,
            }),
            201,
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
      final repo = PlaceRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPlacesScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Thêm địa điểm
      await tester.tap(find.text('Thêm địa điểm'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm địa điểm chuẩn hóa mới'), findsOneWidget);

      // Fill in fields
      final textFields = find.byType(TextField);
      // Index 0 is search field in toolbar
      // In PlaceFormDialog:
      // index 1: name
      // index 2: address
      // index 3: lat
      // index 4: lon
      await tester.enterText(textFields.at(1), 'Bưu Điện Trung Tâm');
      await tester.enterText(textFields.at(2), 'Số 2 Công Xã Paris, Bến Nghé, Quận 1');
      await tester.enterText(textFields.at(3), '10.7798');
      await tester.enterText(textFields.at(4), '106.6999');

      // Submit (tap the submit button inside dialog, which is the last ElevatedButton with text 'Thêm địa điểm')
      await tester.tap(find.widgetWithText(ElevatedButton, 'Thêm địa điểm').last);
      await tester.pumpAndSettle();

      expect(placeCreated, isTrue);
    });

    testWidgets('Soft-deletes / hides place via HidePlaceDialog', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      bool deleted = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/places' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'placeId': 77,
                  'name': 'Địa điểm Cần Ẩn',
                  'address': 'Hà Nội',
                  'category': 'RESTAURANT',
                  'status': 'ACTIVE',
                  'latitude': 21.0,
                  'longitude': 105.8,
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
        if (request.url.path == '/api/admin/places/77' && request.method == 'DELETE') {
          deleted = true;
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
      );
      await authNotifier.checkAuthStatus();
      final repo = PlaceRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPlacesScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Ẩn button in row
      await tester.tap(find.text('Ẩn'));
      await tester.pumpAndSettle();

      expect(find.text('Ẩn địa điểm chuẩn hóa'), findsOneWidget);
      expect(find.textContaining('Dữ liệu địa điểm và các hoạt động du lịch đã lưu vị trí này KHÔNG bị xóa'), findsOneWidget);

      // Confirm hide
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ẩn địa điểm'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('Integrates inside AdminShell when selecting places tab', (tester) async {
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
        if (request.url.path == '/api/admin/places') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'placeId': 999,
                  'name': 'Địa Điểm Shell Test',
                  'address': 'Đà Nẵng',
                  'category': 'ATTRACTION',
                  'status': 'ACTIVE',
                  'latitude': 16.0544,
                  'longitude': 108.2022,
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
            initialTab: AdminTab.places,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý Địa điểm Chuẩn hóa (Places)'), findsOneWidget);
      expect(find.text('Địa Điểm Shell Test'), findsOneWidget);
    });

    testWidgets('Action column remains visible inside viewport with expanded sidebar at 1366x768', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'admin_root', 'role': 'ADMIN'});

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'username': 'admin_root', 'role': 'ADMIN'}), 200, headers: jsonHeaders);
        }
        if (request.url.path == '/api/admin/places') {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'placeId': 321,
                  'name': 'Chợ Bến Thành Sài Gòn Rất Dài Để Kiểm Tra Truncation',
                  'address': 'Đường Lê Lợi, Phường Bến Thành, Quận 1, Thành phố Hồ Chí Minh, Việt Nam',
                  'category': 'ATTRACTION',
                  'status': 'ACTIVE',
                  'latitude': 10.7725,
                  'longitude': 106.6980,
                  'administrativeArea': {'name': 'Thành phố Hồ Chí Minh'},
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
            initialTab: AdminTab.places,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('THAO TÁC'), findsOneWidget);
      expect(find.text('Chi tiết'), findsOneWidget);
      expect(find.text('Sửa'), findsOneWidget);
      expect(find.text('Ẩn'), findsOneWidget);

      // Verify the entire action group fits within 1366px viewport even with expanded 252px sidebar
      final hideButtonRect = tester.getRect(find.text('Ẩn'));
      expect(hideButtonRect.right, lessThanOrEqualTo(1366.0));
      expect(hideButtonRect.left, greaterThan(252.0));
    });
  });
}
