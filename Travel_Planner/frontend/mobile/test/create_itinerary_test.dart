import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/create_itinerary_request.dart';
import 'package:mobile/features/itinerary/presentation/my_itineraries_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/create_itinerary_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/my_itineraries_screen.dart';

class MockAuthNotifier extends AuthNotifier {
  @override
  final Map<String, dynamic>? currentUser;

  @override
  final String? token;

  MockAuthNotifier({this.currentUser, this.token});

  @override
  bool get isAuthenticated => token != null;
}

void main() {
  group('CreateItineraryRequest Serialization Tests', () {
    test('serializes required and optional fields correctly', () {
      const request = CreateItineraryRequest(
        title: 'Chuyến đi Quy Nhơn 4N3Đ',
        description: 'Biển xanh cát trắng',
        location: 'Quy Nhơn, Bình Định',
        coverImage: 'https://example.com/quynhon.jpg',
        totalDays: 4,
        budget: 4500000.0,
        theme: 'Nghỉ dưỡng',
        visibility: 'PUBLIC',
      );

      final json = request.toJson();

      expect(json['title'], equals('Chuyến đi Quy Nhơn 4N3Đ'));
      expect(json['description'], equals('Biển xanh cát trắng'));
      expect(json['location'], equals('Quy Nhơn, Bình Định'));
      expect(json['coverImage'], equals('https://example.com/quynhon.jpg'));
      expect(json['totalDays'], equals(4));
      expect(json['budget'], equals(4500000.0));
      expect(json['theme'], equals('Nghỉ dưỡng'));
      expect(json['visibility'], equals('PUBLIC'));
    });

    test(
      'omits null or blank optional fields and defaults visibility to PRIVATE',
      () {
        const request = CreateItineraryRequest(
          title: 'Đi cắm trại hồ Trị An',
          location: 'Đồng Nai',
          totalDays: 2,
          budget: 1000000.0,
        );

        final json = request.toJson();

        expect(json['title'], equals('Đi cắm trại hồ Trị An'));
        expect(json['location'], equals('Đồng Nai'));
        expect(json['totalDays'], equals(2));
        expect(json['budget'], equals(1000000.0));
        expect(json['visibility'], equals('PRIVATE'));
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('coverImage'), isFalse);
        expect(json.containsKey('theme'), isFalse);
      },
    );
  });

  group('ItineraryCrudRepository.createItinerary Tests', () {
    test(
      'sends POST to /api/itineraries and parses ItineraryDetail response',
      () async {
        String? requestedMethod;
        String? requestedUrl;
        String? authHeader;
        Map<String, dynamic>? sentBody;

        final mockClient = MockClient((request) async {
          requestedMethod = request.method;
          requestedUrl = request.url.toString();
          authHeader = request.headers['authorization'];
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;

          final responseData = {
            'itineraryId': 99,
            'title': 'Chuyến đi Quy Nhơn 4N3Đ',
            'location': 'Quy Nhơn, Bình Định',
            'totalDays': 4,
            'budget': 4500000.0,
            'visibility': 'PUBLIC',
            'status': 'ACTIVE',
            'days': [
              {
                'dayId': 101,
                'dayNumber': 1,
                'title': 'Ngày 1',
                'activities': [],
              },
              {
                'dayId': 102,
                'dayNumber': 2,
                'title': 'Ngày 2',
                'activities': [],
              },
              {
                'dayId': 103,
                'dayNumber': 3,
                'title': 'Ngày 3',
                'activities': [],
              },
              {
                'dayId': 104,
                'dayNumber': 4,
                'title': 'Ngày 4',
                'activities': [],
              },
            ],
          };

          return http.Response(
            jsonEncode(responseData),
            201,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        const createReq = CreateItineraryRequest(
          title: 'Chuyến đi Quy Nhơn 4N3Đ',
          location: 'Quy Nhơn, Bình Định',
          totalDays: 4,
          budget: 4500000.0,
          visibility: 'PUBLIC',
        );

        final detail = await repo.createItinerary(
          createReq,
          token: 'jwt-auth-token',
        );

        expect(requestedMethod, equals('POST'));
        expect(requestedUrl, contains('/api/itineraries'));
        expect(authHeader, equals('Bearer jwt-auth-token'));
        expect(sentBody?['title'], equals('Chuyến đi Quy Nhơn 4N3Đ'));
        expect(sentBody?['totalDays'], equals(4));

        expect(detail.itineraryId, equals(99));
        expect(detail.title, equals('Chuyến đi Quy Nhơn 4N3Đ'));
        expect(detail.days.length, equals(4));
      },
    );

    test('propagates ApiException on 400 validation error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Dữ liệu gửi lên không hợp lệ',
            'validationErrors': {'title': 'Tiêu đề không được để trống'},
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      const createReq = CreateItineraryRequest(
        title: '',
        location: 'Đà Lạt',
        totalDays: 3,
        budget: 1000000.0,
      );

      expect(
        () => repo.createItinerary(createReq, token: 'token'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });

  group('CreateItineraryScreen Form & Validation Widget Tests', () {
    testWidgets('renders all form input fields and visibility options', (
      tester,
    ) async {
      final authNotifier = AuthNotifier();

      await tester.pumpWidget(
        MaterialApp(home: CreateItineraryScreen(authNotifier: authNotifier)),
      );

      expect(find.text('Tạo lịch trình mới'), findsOneWidget);
      expect(find.text('Tiêu đề lịch trình *'), findsOneWidget);
      expect(find.text('Điểm đến / Địa điểm *'), findsOneWidget);
      expect(find.text('Số ngày (1-30) *'), findsOneWidget);
      expect(find.text('Ngân sách (VNĐ) *'), findsOneWidget);
      expect(find.text('Chủ đề / Thể loại'), findsOneWidget);
      expect(find.text('Mô tả chuyến đi'), findsOneWidget);
      expect(find.text('Ảnh bìa (URL)'), findsOneWidget);
      expect(find.text('Quyền riêng tư'), findsOneWidget);
      expect(find.text('Riêng tư'), findsOneWidget);
      expect(find.text('Công khai'), findsOneWidget);
      expect(find.text('Tạo lịch trình'), findsOneWidget);
    });

    testWidgets(
      'shows validation errors when submitting empty required fields',
      (tester) async {
        final authNotifier = AuthNotifier();

        await tester.pumpWidget(
          MaterialApp(home: CreateItineraryScreen(authNotifier: authNotifier)),
        );

        // Clear default days and budget to test validation
        await tester.enterText(find.widgetWithText(TextField, '3'), '');
        await tester.enterText(find.widgetWithText(TextField, '3000000'), '');

        // Tap submit
        await tester.ensureVisible(find.text('Tạo lịch trình'));
        await tester.tap(find.text('Tạo lịch trình'));
        await tester.pumpAndSettle();

        expect(find.text('Tiêu đề không được để trống'), findsOneWidget);
        expect(find.text('Điểm đến không được để trống'), findsOneWidget);
        expect(find.text('Vui lòng nhập số ngày'), findsOneWidget);
        expect(find.text('Vui lòng nhập ngân sách'), findsOneWidget);
      },
    );

    testWidgets('validates day bounds and negative budget', (tester) async {
      final authNotifier = AuthNotifier();

      await tester.pumpWidget(
        MaterialApp(home: CreateItineraryScreen(authNotifier: authNotifier)),
      );

      // Enter invalid days (> 30)
      await tester.enterText(find.widgetWithText(TextField, '3'), '45');
      // Enter negative budget
      await tester.enterText(find.widgetWithText(TextField, '3000000'), '-100');

      await tester.ensureVisible(find.text('Tạo lịch trình'));
      await tester.tap(find.text('Tạo lịch trình'));
      await tester.pumpAndSettle();

      expect(find.text('Từ 1 đến 30 ngày'), findsOneWidget);
      expect(find.text('Không được âm'), findsOneWidget);
    });

    testWidgets(
      'Private and Public visibility options have identical widths and heights',
      (tester) async {
        // Test on standard mobile screen
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final authNotifier = AuthNotifier();

        await tester.pumpWidget(
          MaterialApp(home: CreateItineraryScreen(authNotifier: authNotifier)),
        );

        final privateFinder = find.widgetWithText(InkWell, 'Riêng tư');
        final publicFinder = find.widgetWithText(InkWell, 'Công khai');

        expect(privateFinder, findsOneWidget);
        expect(publicFinder, findsOneWidget);

        final privateSize = tester.getSize(privateFinder);
        final publicSize = tester.getSize(publicFinder);

        expect(privateSize.width, equals(publicSize.width));
        expect(privateSize.height, equals(publicSize.height));

        // Test on smaller mobile screen (360 width)
        tester.view.physicalSize = const Size(360, 640);
        await tester.pumpAndSettle();

        final privateSizeSmall = tester.getSize(privateFinder);
        final publicSizeSmall = tester.getSize(publicFinder);

        expect(privateSizeSmall.width, equals(publicSizeSmall.width));
        expect(privateSizeSmall.height, equals(publicSizeSmall.height));

        // Tapping Public selects it
        await tester.ensureVisible(publicFinder);
        await tester.tap(publicFinder);
        await tester.pumpAndSettle();

        // Tapping Private selects it
        await tester.ensureVisible(privateFinder);
        await tester.tap(privateFinder);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('submits form successfully and navigates to detail screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int createRequestCount = 0;
      int getDetailRequestCount = 0;
      final detailData = {
        'itineraryId': 888,
        'title': 'Chuyến đi Vũng Tàu',
        'location': 'Vũng Tàu',
        'totalDays': 2,
        'budget': 2000000.0,
        'visibility': 'PUBLIC',
        'status': 'ACTIVE',
        'creator': {
          'userId': 1,
          'username': 'traveler_vn',
          'fullName': 'Traveler VN',
        },
        'days': [
          {'dayId': 201, 'dayNumber': 1, 'title': 'Ngày 1', 'activities': []},
          {'dayId': 202, 'dayNumber': 2, 'title': 'Ngày 2', 'activities': []},
        ],
      };

      final mockClient = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/itineraries') {
          createRequestCount++;
          return http.Response(
            jsonEncode(detailData),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'GET' &&
            request.url.path == '/api/itineraries/888') {
          getDetailRequestCount++;
          return http.Response(
            jsonEncode(detailData),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = MockAuthNotifier(
        currentUser: {'username': 'traveler_vn'},
        token: 'sample_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CreateItineraryScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );

      // Fill in valid data
      await tester.enterText(
        find.widgetWithText(TextField, 'Ví dụ: Khám phá Đà Lạt 3 ngày 2 đêm'),
        'Chuyến đi Vũng Tàu',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Ví dụ: Đà Lạt, Lâm Đồng'),
        'Vũng Tàu',
      );

      // Tap 'Công khai' visibility option
      await tester.ensureVisible(find.text('Công khai'));
      await tester.tap(find.text('Công khai'));
      await tester.pumpAndSettle();

      // Tap submit
      await tester.ensureVisible(find.text('Tạo lịch trình'));
      await tester.tap(find.text('Tạo lịch trình'));
      await tester.pumpAndSettle();

      expect(createRequestCount, equals(1));
      expect(getDetailRequestCount, greaterThanOrEqualTo(1));
      // Navigates to detail screen
      expect(find.byType(ItineraryDetailScreen), findsOneWidget);
      expect(find.text('Chi tiết lịch trình'), findsOneWidget);
      // Valid detail data is shown immediately without false "not found"
      expect(find.text('Chuyến đi Vũng Tàu'), findsOneWidget);
      expect(find.text('Không tìm thấy lịch trình'), findsNothing);
      // Days and day-management are accessible
      expect(find.text('Ngày 1'), findsWidgets);
      expect(find.text('Ngày 2'), findsWidgets);
      expect(find.text('Thêm hoạt động đầu tiên'), findsWidgets);
      expect(find.text('Thêm ngày'), findsOneWidget);
    });

    testWidgets('handles API error on creation failure', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Tên lịch trình đã tồn tại trên tài khoản'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = AuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateItineraryScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Ví dụ: Khám phá Đà Lạt 3 ngày 2 đêm'),
        'Chuyến đi Vũng Tàu',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Ví dụ: Đà Lạt, Lâm Đồng'),
        'Vũng Tàu',
      );

      await tester.ensureVisible(find.text('Tạo lịch trình'));
      await tester.tap(find.text('Tạo lịch trình'));
      await tester.pumpAndSettle();

      expect(
        find.text('Tên lịch trình đã tồn tại trên tài khoản'),
        findsOneWidget,
      );
      // Still on create screen
      expect(find.byType(CreateItineraryScreen), findsOneWidget);
    });
  });

  group('MyItinerariesScreen Create Entry Point Tests', () {
    testWidgets(
      'MyItinerariesScreen renders FAB and empty state button for creation',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'content': [],
              'pageNumber': 0,
              'pageSize': 10,
              'totalElements': 0,
              'totalPages': 0,
              'last': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final notifier = MyItinerariesNotifier(repository: repo);
        final authNotifier = AuthNotifier();

        await tester.pumpWidget(
          MaterialApp(
            home: MyItinerariesScreen(
              authNotifier: authNotifier,
              notifier: notifier,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Floating action button
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Tạo lịch trình'), findsOneWidget);

        // Empty state action button
        expect(find.text('Tạo lịch trình ngay'), findsOneWidget);

        // Tap FAB opens CreateItineraryScreen
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.byType(CreateItineraryScreen), findsOneWidget);
      },
    );
  });
}
