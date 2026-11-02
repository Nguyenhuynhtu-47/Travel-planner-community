import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/features/auth/data/auth_repository.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/locations/data/destination_repository.dart';
import 'package:travel_planner_web/features/locations/data/models/destination_model.dart';
import 'package:travel_planner_web/features/locations/presentation/screens/admin_destinations_screen.dart';
import 'package:travel_planner_web/features/locations/presentation/widgets/destination_form_dialog.dart';
import 'package:travel_planner_web/features/locations/presentation/widgets/hide_destination_dialog.dart';
import 'package:travel_planner_web/shared/widgets/app_text_field.dart';

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

  Finder textFieldByLabel(String label) {
    return find.descendant(
      of: find.widgetWithText(AppTextField, label),
      matching: find.byType(TextFormField),
    );
  }

  group('Destination Model & Request DTO Tests', () {
    test('Destination.fromJson parses complete active destination with coordinates', () {
      final json = {
        'destinationId': 101,
        'name': 'Hồ Gươm',
        'address': 'Hoàn Kiếm, Hà Nội',
        'description': 'Trái tim của thủ đô Hà Nội',
        'imageUrl': 'https://example.com/hoguom.jpg',
        'latitude': 21.0285,
        'longitude': 105.8542,
        'status': 'ACTIVE',
      };

      final dest = Destination.fromJson(json);

      expect(dest.id, equals(101));
      expect(dest.destinationId, equals(101));
      expect(dest.name, equals('Hồ Gươm'));
      expect(dest.address, equals('Hoàn Kiếm, Hà Nội'));
      expect(dest.description, equals('Trái tim của thủ đô Hà Nội'));
      expect(dest.imageUrl, equals('https://example.com/hoguom.jpg'));
      expect(dest.latitude, equals(21.0285));
      expect(dest.longitude, equals(105.8542));
      expect(dest.status, equals('ACTIVE'));
      expect(dest.isActive, isTrue);
      expect(dest.isHidden, isFalse);
      expect(dest.hasCoordinates, isTrue);
      expect(dest.coordinate, equals(const LatLng(21.0285, 105.8542)));
      expect(dest.formattedCoordinates, contains('21.02850, 105.85420'));
    });

    test('Destination.fromJson handles null coordinates and HIDDEN status', () {
      final json = {
        'destinationId': 102,
        'name': 'Điểm du lịch cũ',
        'address': 'Quận 1, TP. Hồ Chí Minh',
        'description': null,
        'imageUrl': null,
        'latitude': null,
        'longitude': null,
        'status': 'HIDDEN',
      };

      final dest = Destination.fromJson(json);

      expect(dest.id, equals(102));
      expect(dest.name, equals('Điểm du lịch cũ'));
      expect(dest.status, equals('HIDDEN'));
      expect(dest.isActive, isFalse);
      expect(dest.isHidden, isTrue);
      expect(dest.hasCoordinates, isFalse);
      expect(dest.coordinate, isNull);
      expect(dest.formattedCoordinates, equals('Chưa có tọa độ'));
    });

    test('CreateDestinationRequest.toJson serializes required and optional fields correctly', () {
      const req = CreateDestinationRequest(
        name: 'Bảo tàng Chứng tích Chiến tranh',
        address: '28 Võ Văn Tần, Quận 3, TP. Hồ Chí Minh',
        description: 'Bảo tàng lịch sử chiến tranh',
        imageUrl: 'https://example.com/museum.jpg',
        latitude: 10.7794,
        longitude: 106.6922,
        status: 'ACTIVE',
      );

      final json = req.toJson();

      expect(json['name'], equals('Bảo tàng Chứng tích Chiến tranh'));
      expect(json['address'], equals('28 Võ Văn Tần, Quận 3, TP. Hồ Chí Minh'));
      expect(json['description'], equals('Bảo tàng lịch sử chiến tranh'));
      expect(json['imageUrl'], equals('https://example.com/museum.jpg'));
      expect(json['latitude'], equals(10.7794));
      expect(json['longitude'], equals(106.6922));
      expect(json['status'], equals('ACTIVE'));
    });

    test('UpdateDestinationRequest.toJson serializes all fields properly', () {
      const req = UpdateDestinationRequest(
        name: 'Tên mới',
        address: 'Địa chỉ mới',
        status: 'HIDDEN',
      );

      final json = req.toJson();

      expect(json['name'], equals('Tên mới'));
      expect(json['address'], equals('Địa chỉ mới'));
      expect(json['description'], isNull);
      expect(json['imageUrl'], isNull);
      expect(json['latitude'], isNull);
      expect(json['longitude'], isNull);
      expect(json['status'], equals('HIDDEN'));
    });
  });

  group('DestinationRepository API Client Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'auth_token': 'test_admin_jwt'});
      ApiClient.globalOnUnauthorized = null;
    });

    test('getAdminDestinations sends keyword and status query parameters', () async {
      String? requestedUrl;
      String? authHeader;

      final mockClient = MockClient((request) async {
        requestedUrl = request.url.toString();
        authHeader = request.headers['Authorization'];

        final list = [
          {
            'destinationId': 1,
            'name': 'Chợ Bến Thành',
            'address': 'Quận 1, TP. Hồ Chí Minh',
            'latitude': 10.7725,
            'longitude': 106.6980,
            'status': 'ACTIVE',
          }
        ];

        return http.Response(jsonEncode(list), 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = DestinationRepository(apiClient: apiClient);

      final result = await repo.getAdminDestinations(keyword: 'Bến Thành', status: 'ACTIVE');

      expect(result.length, equals(1));
      expect(result.first.name, equals('Chợ Bến Thành'));
      expect(requestedUrl, contains('keyword=B%E1%BA%BFn%20Th%C3%A0nh'));
      expect(requestedUrl, contains('status=ACTIVE'));
      expect(authHeader, equals('Bearer test_admin_jwt'));
    });

    test('createDestination sends POST request with correct payload', () async {
      String? requestBody;
      String? method;

      final mockClient = MockClient((request) async {
        method = request.method;
        requestBody = request.body;

        final created = {
          'destinationId': 99,
          'name': 'Cầu Rồng',
          'address': 'Đà Nẵng',
          'latitude': 16.0610,
          'longitude': 108.2272,
          'status': 'ACTIVE',
        };

        return http.Response(jsonEncode(created), 201, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = DestinationRepository(apiClient: apiClient);

      final result = await repo.createDestination(
        const CreateDestinationRequest(
          name: 'Cầu Rồng',
          address: 'Đà Nẵng',
          latitude: 16.0610,
          longitude: 108.2272,
        ),
      );

      expect(method, equals('POST'));
      expect(result.id, equals(99));
      expect(result.name, equals('Cầu Rồng'));
      final decoded = jsonDecode(requestBody!);
      expect(decoded['name'], equals('Cầu Rồng'));
      expect(decoded['latitude'], equals(16.0610));
    });

    test('updateDestination sends PUT request to /api/admin/destinations/{id}', () async {
      String? requestedPath;
      String? method;

      final mockClient = MockClient((request) async {
        method = request.method;
        requestedPath = request.url.path;

        final updated = {
          'destinationId': 99,
          'name': 'Cầu Rồng (Đã sửa)',
          'address': 'Đà Nẵng',
          'latitude': 16.0610,
          'longitude': 108.2272,
          'status': 'ACTIVE',
        };

        return http.Response(jsonEncode(updated), 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = DestinationRepository(apiClient: apiClient);

      final result = await repo.updateDestination(
        99,
        const UpdateDestinationRequest(
          name: 'Cầu Rồng (Đã sửa)',
          address: 'Đà Nẵng',
        ),
      );

      expect(method, equals('PUT'));
      expect(requestedPath, equals('/api/admin/destinations/99'));
      expect(result.name, equals('Cầu Rồng (Đã sửa)'));
    });

    test('deleteDestination sends DELETE request for soft deletion', () async {
      String? requestedPath;
      String? method;

      final mockClient = MockClient((request) async {
        method = request.method;
        requestedPath = request.url.path;
        return http.Response('', 204);
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = DestinationRepository(apiClient: apiClient);

      await repo.deleteDestination(42);

      expect(method, equals('DELETE'));
      expect(requestedPath, equals('/api/admin/destinations/42'));
    });

    test('API errors propagate as ApiException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 404, 'message': 'Destination not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = DestinationRepository(apiClient: apiClient);

      expect(
        () => repo.getAdminDestinationById(999),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('HideDestinationDialog Widget Tests', () {
    testWidgets('Renders soft-delete warning and handles cancel / confirm', (WidgetTester tester) async {
      final dest = Destination.fromJson({
        'destinationId': 10,
        'name': 'Địa đạo Củ Chi',
        'address': 'Củ Chi, TP. Hồ Chí Minh',
        'status': 'ACTIVE',
      });

      int deleteCalledId = -1;
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' && request.url.path == '/api/admin/destinations/10') {
          deleteCalledId = 10;
          return http.Response('', 204);
        }
        return http.Response('Not Found', 404);
      });

      final repo = DestinationRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => HideDestinationDialog.show(
                  context,
                  destination: dest,
                  repository: repo,
                ),
                child: const Text('Open Hide Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Hide Dialog'));
      await tester.pumpAndSettle();

      // Check dialog elements
      expect(find.text('Ẩn điểm đến khỏi danh mục?'), findsOneWidget);
      expect(find.textContaining('Địa đạo Củ Chi'), findsOneWidget);
      expect(find.textContaining('Cơ chế xóa mềm (Soft-delete):'), findsOneWidget);
      expect(find.textContaining('Dữ liệu không bị xóa vĩnh viễn khỏi hệ thống.'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Ẩn điểm đến'), findsOneWidget);

      // Confirm hide
      await tester.tap(find.text('Ẩn điểm đến'));
      await tester.pumpAndSettle();

      expect(deleteCalledId, equals(10));
    });
  });

  group('DestinationFormDialog Widget Tests', () {
    testWidgets('Validates required fields: Name and Address cannot be empty', (WidgetTester tester) async {
      bool submitCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DestinationFormDialog.show(
                  context,
                  onSubmit: ({
                    required String name,
                    required String address,
                    String? description,
                    String? imageUrl,
                    double? latitude,
                    double? longitude,
                    String? status,
                  }) async {
                    submitCalled = true;
                  },
                ),
                child: const Text('Open Create Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Create Dialog'));
      await tester.pumpAndSettle();

      // Tap submit with empty form
      final submitButton = find.widgetWithText(ElevatedButton, 'Tạo điểm đến');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Tên điểm đến không được để trống'), findsOneWidget);
      expect(find.text('Địa chỉ không được để trống'), findsOneWidget);
      expect(submitCalled, isFalse);
    });

    testWidgets('Validates coordinate range and coordinates pair rule', (WidgetTester tester) async {
      bool submitCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DestinationFormDialog.show(
                  context,
                  onSubmit: ({
                    required String name,
                    required String address,
                    String? description,
                    String? imageUrl,
                    double? latitude,
                    double? longitude,
                    String? status,
                  }) async {
                    submitCalled = true;
                  },
                ),
                child: const Text('Open Create Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Create Dialog'));
      await tester.pumpAndSettle();

      // Fill name & address
      await tester.enterText(
        textFieldByLabel('Tên điểm đến *'),
        'Đỉnh Fansipan',
      );
      await tester.enterText(
        textFieldByLabel('Địa chỉ *'),
        'Sa Pa, Lào Cai',
      );

      // Provide latitude without longitude
      await tester.enterText(
        textFieldByLabel('Vĩ độ (Latitude)'),
        '22.3033',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo điểm đến'));
      await tester.pumpAndSettle();

      // Pair rule triggers
      expect(
        find.text('Tọa độ phải bao gồm cả vĩ độ (latitude) và kinh độ (longitude).'),
        findsOneWidget,
      );
      expect(submitCalled, isFalse);

      // Enter invalid latitude > 90
      await tester.enterText(
        textFieldByLabel('Vĩ độ (Latitude)'),
        '105.0',
      );
      await tester.enterText(
        textFieldByLabel('Kinh độ (Longitude)'),
        '103.7753',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo điểm đến'));
      await tester.pumpAndSettle();

      expect(
        find.text('Vĩ độ phải nằm trong khoảng -90.0 đến 90.0'),
        findsOneWidget,
      );
      expect(submitCalled, isFalse);
    });

    testWidgets('Prepopulates data in edit mode and submits successfully', (WidgetTester tester) async {
      final initialDest = Destination.fromJson({
        'destinationId': 5,
        'name': 'Vịnh Hạ Long',
        'address': 'Quảng Ninh',
        'description': 'Kỳ quan thiên nhiên thế giới',
        'imageUrl': 'https://example.com/halong.jpg',
        'latitude': 20.9101,
        'longitude': 107.1839,
        'status': 'ACTIVE',
      });

      String? submittedName;
      double? submittedLat;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DestinationFormDialog.show(
                  context,
                  destination: initialDest,
                  onSubmit: ({
                    required String name,
                    required String address,
                    String? description,
                    String? imageUrl,
                    double? latitude,
                    double? longitude,
                    String? status,
                  }) async {
                    submittedName = name;
                    submittedLat = latitude;
                  },
                ),
                child: const Text('Open Edit Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Edit Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa điểm đến'), findsOneWidget);
      expect(find.text('Vịnh Hạ Long'), findsOneWidget);
      expect(find.text('Quảng Ninh'), findsOneWidget);
      expect(find.text('20.9101'), findsOneWidget);
      expect(find.text('107.1839'), findsOneWidget);

      // Change name and submit
      await tester.enterText(
        textFieldByLabel('Tên điểm đến *'),
        'Vịnh Hạ Long - Di sản Thế giới',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(submittedName, equals('Vịnh Hạ Long - Di sản Thế giới'));
      expect(submittedLat, equals(20.9101));
    });
  });

  group('AdminDestinationsScreen Widget & Authorization Tests', () {
    testWidgets('Non-admin user (role: USER) sees Access Denied screen', (WidgetTester tester) async {
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'username': 'normaluser', 'role': 'USER'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'normaluser', 'role': 'USER'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDestinationsScreen(
            authNotifier: authNotifier,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Truy cập bị từ chối'), findsOneWidget);
      expect(
        find.text('Bạn cần quyền Quản trị viên (ADMIN) để xem và quản lý danh mục điểm đến.'),
        findsOneWidget,
      );
      expect(find.text('Quản lý Điểm đến (Destinations)'), findsNothing);
    });

    testWidgets('Admin user (role: ADMIN) renders destination list and details', (WidgetTester tester) async {
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'username': 'adminuser', 'role': 'ADMIN'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'adminuser', 'role': 'ADMIN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      final mockDestinations = [
        {
          'destinationId': 1,
          'name': 'Chùa Một Cột',
          'address': 'Đội Cấn, Ba Đình, Hà Nội',
          'description': 'Ngôi chùa có kiến trúc độc đáo',
          'imageUrl': 'https://example.com/chuamotcot.jpg',
          'latitude': 21.0358,
          'longitude': 105.8336,
          'status': 'ACTIVE',
        },
        {
          'destinationId': 2,
          'name': 'Điểm du lịch đóng cửa',
          'address': 'Đà Lạt, Lâm Đồng',
          'description': null,
          'imageUrl': null,
          'latitude': null,
          'longitude': null,
          'status': 'HIDDEN',
        },
      ];

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockDestinations), 200, headers: {'content-type': 'application/json'});
      });

      final repo = DestinationRepository(apiClient: ApiClient(client: mockClient));

      // Use a fixed wide size (1200x800) to test the wide layout
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDestinationsScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and actions
      expect(find.text('Quản lý Điểm đến (Destinations)'), findsOneWidget);
      expect(find.text('Thêm điểm đến'), findsOneWidget);

      // Check destinations rendered in list
      expect(find.text('Chùa Một Cột'), findsWidgets);
      expect(find.text('Điểm du lịch đóng cửa'), findsOneWidget);

      // Status badges
      expect(find.text('Đang hoạt động'), findsWidgets);
      expect(find.text('Đã ẩn'), findsOneWidget);

      // Coordinates text
      expect(find.textContaining('21.0358, 105.8336'), findsWidgets);
      expect(find.text('Chưa có tọa độ'), findsOneWidget);

      // Map attribution visible in detail map panel
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
      expect(find.textContaining('CARTO'), findsOneWidget);
    });
  });
}
