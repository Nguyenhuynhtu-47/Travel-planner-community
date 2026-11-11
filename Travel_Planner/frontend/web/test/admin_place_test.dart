import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/features/auth/data/auth_repository.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/locations/data/models/place_model.dart';
import 'package:travel_planner_web/features/locations/data/place_repository.dart';
import 'package:travel_planner_web/features/locations/presentation/screens/admin_places_screen.dart';
import 'package:travel_planner_web/features/locations/presentation/widgets/hide_place_dialog.dart';

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

  group('Place Model & Request DTO Tests', () {
    test('PlaceModel.fromJson parses complete active place with coordinates and category', () {
      final json = {
        'placeId': 201,
        'name': 'Hồ Gươm Canonical',
        'normalizedName': 'ho guom canonical',
        'address': 'Hoàn Kiếm, Hà Nội',
        'description': 'Trái tim của thủ đô Hà Nội',
        'imageUrl': 'https://example.com/hoguom.jpg',
        'latitude': 21.0285,
        'longitude': 105.8542,
        'category': 'ATTRACTION',
        'status': 'ACTIVE',
        'providerMappings': [
          {
            'mappingId': 1,
            'provider': 'TOMTOM',
            'providerPlaceId': 'pois:123',
            'providerType': 'poi',
          }
        ],
      };

      final place = PlaceModel.fromJson(json);

      expect(place.id, equals(201));
      expect(place.placeId, equals(201));
      expect(place.name, equals('Hồ Gươm Canonical'));
      expect(place.normalizedName, equals('ho guom canonical'));
      expect(place.address, equals('Hoàn Kiếm, Hà Nội'));
      expect(place.category, equals('ATTRACTION'));
      expect(place.categoryDisplay, equals('Điểm tham quan'));
      expect(place.status, equals('ACTIVE'));
      expect(place.isActive, isTrue);
      expect(place.isHidden, isFalse);
      expect(place.hasCoordinates, isTrue);
      expect(place.coordinate, equals(const LatLng(21.0285, 105.8542)));
      expect(place.providerMappings.length, equals(1));
      expect(place.providerMappings.first.provider, equals('TOMTOM'));
    });

    test('PlaceModel handles null coordinates and HIDDEN status', () {
      final json = {
        'placeId': 202,
        'name': 'Draft Hidden Place',
        'address': 'Chưa xác định',
        'category': 'RESTAURANT',
        'status': 'HIDDEN',
      };

      final place = PlaceModel.fromJson(json);

      expect(place.id, equals(202));
      expect(place.hasCoordinates, isFalse);
      expect(place.coordinate, isNull);
      expect(place.formattedCoordinates, equals('Chưa có tọa độ'));
      expect(place.isActive, isFalse);
      expect(place.isHidden, isTrue);
      expect(place.categoryDisplay, equals('Nhà hàng'));
    });

    test('CreatePlaceRequest.toJson serializes required and optional fields correctly', () {
      const req = CreatePlaceRequest(
        name: 'Quán Phở Thìn',
        address: '13 Lò Đúc, Hai Bà Trưng, Hà Nội',
        category: 'RESTAURANT',
        description: 'Phở bò tái lăn trứ danh',
        imageUrl: 'https://example.com/phothin.jpg',
        latitude: 21.0189,
        longitude: 105.8567,
      );

      final json = req.toJson();

      expect(json['name'], equals('Quán Phở Thìn'));
      expect(json['address'], equals('13 Lò Đúc, Hai Bà Trưng, Hà Nội'));
      expect(json['category'], equals('RESTAURANT'));
      expect(json['description'], equals('Phở bò tái lăn trứ danh'));
      expect(json['imageUrl'], equals('https://example.com/phothin.jpg'));
      expect(json['latitude'], equals(21.0189));
      expect(json['longitude'], equals(105.8567));
    });

    test('UpdatePlaceRequest.toJson serializes status and all fields properly', () {
      const req = UpdatePlaceRequest(
        name: 'Cà Phê Giảng',
        address: '39 Nguyễn Hữu Huân, Hoàn Kiếm, Hà Nội',
        category: 'CAFE',
        description: 'Cà phê trứng lâu đời',
        imageUrl: 'https://example.com/giang.jpg',
        latitude: 21.0335,
        longitude: 105.8538,
        status: 'HIDDEN',
      );

      final json = req.toJson();

      expect(json['name'], equals('Cà Phê Giảng'));
      expect(json['category'], equals('CAFE'));
      expect(json['status'], equals('HIDDEN'));
    });
  });

  group('PlaceRepository API Client Tests', () {
    test('getAdminPlaces sends keyword, category, status and parses content list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/admin/places'));
        expect(request.url.queryParameters['keyword'], equals('Hà Nội'));
        expect(request.url.queryParameters['category'], equals('ATTRACTION'));
        expect(request.url.queryParameters['status'], equals('ACTIVE'));
        expect(request.headers['Authorization'], equals('Bearer test-token'));

        final pageJson = {
          'content': [
            {
              'placeId': 1,
              'name': 'Hồ Hoàn Kiếm',
              'address': 'Hoàn Kiếm, Hà Nội',
              'category': 'ATTRACTION',
              'status': 'ACTIVE',
              'latitude': 21.0285,
              'longitude': 105.8542,
            }
          ],
          'totalElements': 1,
          'totalPages': 1,
        };

        return http.Response(
          jsonEncode(pageJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = PlaceRepository(apiClient: apiClient);

      final result = await repo.getAdminPlaces(
        keyword: 'Hà Nội',
        category: 'ATTRACTION',
        status: 'ACTIVE',
        token: 'test-token',
      );

      expect(result.length, equals(1));
      expect(result.first.name, equals('Hồ Hoàn Kiếm'));
      expect(result.first.category, equals('ATTRACTION'));
    });

    test('deletePlace sends DELETE request for soft deletion', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('DELETE'));
        expect(request.url.path, equals('/api/admin/places/42'));
        return http.Response('', 204);
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = PlaceRepository(apiClient: apiClient);

      await expectLater(
        repo.deletePlace(42, token: 'mock-token'),
        completes,
      );
    });
  });

  group('HidePlaceDialog Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'auth_token': 'test_admin_jwt'});
      ApiClient.globalOnUnauthorized = null;
    });

    testWidgets('Renders soft-delete warning and handles cancel / confirm', (tester) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'test_admin_jwt'});
      const place = PlaceModel(
        placeId: 99,
        name: 'Địa điểm Thử Nghiệm',
        address: 'Hà Nội',
        category: 'ATTRACTION',
        status: 'ACTIVE',
      );

      bool deleted = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' && request.url.path == '/api/admin/places/99') {
          deleted = true;
          return http.Response('', 204);
        }
        return http.Response('Not Found', 404);
      });

      final repo = PlaceRepository(apiClient: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => HidePlaceDialog.show(context, place: place, repository: repo),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Ẩn địa điểm chuẩn hóa'), findsOneWidget);
      expect(find.textContaining('Bạn có chắc chắn muốn ẩn địa điểm "Địa điểm Thử Nghiệm"'), findsOneWidget);

      // Confirm
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ẩn địa điểm'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });
  });

  group('AdminPlacesScreen Widget & Authorization Tests', () {
    testWidgets('Non-admin user (role: USER) sees Access Denied screen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 1, 'username': 'normal_user', 'role': 'USER'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'normal_user', 'role': 'USER'}),
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
          home: AdminPlacesScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Truy cập bị từ chối'), findsOneWidget);
      expect(find.textContaining('Bạn cần quyền Quản trị viên (ADMIN)'), findsOneWidget);
    });

    testWidgets('Admin user (role: ADMIN) renders place list and details', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final validToken = _createMockJwt(expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
      final authStorage = AuthStorage();
      await authStorage.saveToken(validToken);
      await authStorage.saveUser({'userId': 10, 'username': 'admin_user', 'role': 'ADMIN'});

      final mockAuthClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'username': 'admin_user', 'role': 'ADMIN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authNotifier = AuthNotifier(
        storage: authStorage,
        repository: AuthRepository(apiClient: ApiClient(client: mockAuthClient)),
      );
      await authNotifier.checkAuthStatus();

      final mockClient = MockClient((request) async {
        final pageJson = {
          'content': [
            {
              'placeId': 1,
              'name': 'Hồ Hoàn Kiếm',
              'address': 'Hoàn Kiếm, Hà Nội',
              'category': 'ATTRACTION',
              'status': 'ACTIVE',
              'latitude': 21.0285,
              'longitude': 105.8542,
              'description': 'Hồ Gươm lịch sử',
            },
            {
              'placeId': 2,
              'name': 'Quán Phở Thìn',
              'address': '13 Lò Đúc, Hà Nội',
              'category': 'RESTAURANT',
              'status': 'ACTIVE',
              'latitude': 21.0189,
              'longitude': 105.8567,
            }
          ],
          'totalElements': 2,
          'totalPages': 1,
        };

        return http.Response(jsonEncode(pageJson), 200, headers: {'content-type': 'application/json'});
      });

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

      expect(find.text('Quản lý Địa điểm Chuẩn hóa (Places)'), findsOneWidget);
      expect(find.text('Hồ Hoàn Kiếm'), findsWidgets);
      expect(find.text('Quán Phở Thìn'), findsOneWidget);
      expect(find.text('Thêm địa điểm'), findsOneWidget);
    });
  });
}
