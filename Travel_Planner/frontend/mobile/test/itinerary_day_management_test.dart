import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/create_day_request.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/data/models/update_day_request.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/day_form_dialog.dart';
import 'package:mobile/features/itinerary/presentation/widgets/delete_day_dialog.dart';

class MockAuthNotifier extends AuthNotifier {
  final Map<String, dynamic>? _user;
  final String? _token;

  MockAuthNotifier({
    Map<String, dynamic>? user,
    String? token,
    Map<String, dynamic>? mockUser,
    String? mockToken,
  }) : _user = user ?? mockUser,
       _token = token ?? mockToken;

  @override
  Map<String, dynamic>? get currentUser => _user;

  @override
  String? get token => _token;

  @override
  bool get isAuthenticated => _token != null;
}

class FakeItineraryDetailNotifier extends ItineraryDetailNotifier {
  ItineraryDetail? _detail;

  FakeItineraryDetailNotifier({
    required super.itineraryId,
    ItineraryDetail? presetDetail,
    ItineraryDetail? detail,
  }) : _detail = presetDetail ?? detail;

  void updateDetail(ItineraryDetail newDetail) {
    _detail = newDetail;
    itineraryDetail = newDetail;
    notifyListeners();
  }

  @override
  Future<void> loadDetail({String? token}) async {
    itineraryDetail = _detail;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}

void main() {
  group('CreateDayRequest & UpdateDayRequest Serialization Tests', () {
    test('CreateDayRequest serializes title and formatted date correctly', () {
      final request = CreateDayRequest(
        title: 'Khám phá Đảo Ngọc',
        date: DateTime(2026, 10, 27),
      );

      final json = request.toJson();

      expect(json['title'], equals('Khám phá Đảo Ngọc'));
      expect(json['date'], equals('2026-10-27'));
    });

    test('CreateDayRequest omits null or blank fields', () {
      const request = CreateDayRequest(title: '   ', date: null);

      final json = request.toJson();

      expect(json.containsKey('title'), isFalse);
      expect(json.containsKey('date'), isFalse);
    });

    test(
      'UpdateDayRequest serializes title and date and handles null values',
      () {
        final request = UpdateDayRequest(
          title: 'Nghỉ dưỡng Sunset Sanato',
          date: DateTime(2026, 10, 28),
        );

        final json = request.toJson();

        expect(json['title'], equals('Nghỉ dưỡng Sunset Sanato'));
        expect(json['date'], equals('2026-10-28'));

        const clearRequest = UpdateDayRequest(title: null, date: null);

        final clearJson = clearRequest.toJson();
        expect(clearJson['title'], isNull);
        expect(clearJson['date'], isNull);
      },
    );
  });

  group('ItineraryCrudRepository Day CRUD Network Tests', () {
    test(
      'addDay sends POST to /api/itineraries/{id}/days with Bearer token',
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

          return http.Response(
            jsonEncode({
              'dayId': 101,
              'dayNumber': 3,
              'title': 'Ngày 3: Khám phá chợ đêm',
              'date': '2026-10-29',
              'activities': [],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        final day = await repo.addDay(
          42,
          CreateDayRequest(
            title: 'Ngày 3: Khám phá chợ đêm',
            date: DateTime(2026, 10, 29),
          ),
          token: 'auth-jwt-token',
        );

        expect(requestedMethod, equals('POST'));
        expect(requestedUrl, contains('/api/itineraries/42/days'));
        expect(authHeader, equals('Bearer auth-jwt-token'));
        expect(sentBody?['title'], equals('Ngày 3: Khám phá chợ đêm'));
        expect(sentBody?['date'], equals('2026-10-29'));
        expect(day.dayId, equals(101));
        expect(day.dayNumber, equals(3));
        expect(day.title, equals('Ngày 3: Khám phá chợ đêm'));
      },
    );

    test('updateDay sends PUT to /api/itineraries/{id}/days/{dayId}', () async {
      String? requestedMethod;
      String? requestedUrl;
      String? authHeader;
      Map<String, dynamic>? sentBody;

      final mockClient = MockClient((request) async {
        requestedMethod = request.method;
        requestedUrl = request.url.toString();
        authHeader = request.headers['authorization'];
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'dayId': 101,
            'dayNumber': 3,
            'title': 'Tiêu đề ngày mới',
            'date': '2026-10-30',
            'activities': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      final day = await repo.updateDay(
        42,
        101,
        UpdateDayRequest(
          title: 'Tiêu đề ngày mới',
          date: DateTime(2026, 10, 30),
        ),
        token: 'auth-jwt-token',
      );

      expect(requestedMethod, equals('PUT'));
      expect(requestedUrl, contains('/api/itineraries/42/days/101'));
      expect(authHeader, equals('Bearer auth-jwt-token'));
      expect(sentBody?['title'], equals('Tiêu đề ngày mới'));
      expect(day.title, equals('Tiêu đề ngày mới'));
    });

    test(
      'deleteDay sends DELETE to /api/itineraries/{id}/days/{dayId}',
      () async {
        String? requestedMethod;
        String? requestedUrl;
        String? authHeader;

        final mockClient = MockClient((request) async {
          requestedMethod = request.method;
          requestedUrl = request.url.toString();
          authHeader = request.headers['authorization'];

          return http.Response(
            jsonEncode({'message': 'Đã xóa ngày thành công'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        await repo.deleteDay(42, 101, token: 'auth-jwt-token');

        expect(requestedMethod, equals('DELETE'));
        expect(requestedUrl, contains('/api/itineraries/42/days/101'));
        expect(authHeader, equals('Bearer auth-jwt-token'));
      },
    );

    test(
      'deleteDay propagates ApiException when deleting the last remaining day',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'message': 'Lịch trình phải có ít nhất 1 ngày. Không thể xóa ngày cuối cùng',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        expect(
          () => repo.deleteDay(42, 101, token: 'auth-jwt-token'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having(
                  (e) => e.message,
                  'message',
                  contains('ít nhất 1 ngày'),
                ),
          ),
        );
      },
    );
  });

  group('DayFormDialog Add and Edit Widget Tests', () {
    testWidgets('renders DayFormDialog for adding a day with next day number', (
      tester,
    ) async {
      final authNotifier = MockAuthNotifier(mockToken: 'valid-token');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDayFormDialog(
                  context,
                  itineraryId: 10,
                  nextDayNumber: 4,
                  authNotifier: authNotifier,
                ),
                child: const Text('Mở dialog thêm ngày'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở dialog thêm ngày'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm Ngày 4'), findsOneWidget);
      expect(find.text('Tiêu đề ngày (tùy chọn)'), findsOneWidget);
      expect(find.text('Chọn ngày thực hiện'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Thêm ngày'), findsOneWidget);
    });

    testWidgets('submits add day successfully and pops true', (tester) async {
      final authNotifier = MockAuthNotifier(mockToken: 'valid-token');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'dayId': 202,
            'dayNumber': 4,
            'title': 'Ngày 4: Mua sắm đặc sản',
            'date': null,
            'activities': [],
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showDayFormDialog(
                    context,
                    itineraryId: 10,
                    nextDayNumber: 4,
                    authNotifier: authNotifier,
                    repository: repo,
                  );
                },
                child: const Text('Mở dialog thêm ngày'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở dialog thêm ngày'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, ''),
        'Ngày 4: Mua sắm đặc sản',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm ngày'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm Ngày 4 thành công!'), findsOneWidget);
      expect(dialogResult, isTrue);
    });

    testWidgets('renders DayFormDialog for editing prefilled values', (
      tester,
    ) async {
      final authNotifier = MockAuthNotifier(mockToken: 'valid-token');

      const existingDay = ItineraryDayDetail(
        dayId: 50,
        dayNumber: 2,
        title: 'Ngoạn cảnh hồ Tuyền Lâm',
        activities: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDayFormDialog(
                  context,
                  itineraryId: 10,
                  initialDay: existingDay,
                  authNotifier: authNotifier,
                ),
                child: const Text('Mở dialog sửa ngày'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở dialog sửa ngày'));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa Ngày 2'), findsOneWidget);
      expect(find.text('Ngoạn cảnh hồ Tuyền Lâm'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Lưu thay đổi'), findsOneWidget);
    });
  });

  group('Delete Day Confirmation Dialog Tests', () {
    testWidgets(
      'shows confirmation dialog without activity warning when activities empty',
      (tester) async {
        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteDayConfirmationDialog(
                    context,
                    dayNumber: 2,
                    dayTitle: 'Đi bộ đường dài',
                    hasActivities: false,
                  );
                },
                child: const Text('Xóa ngày'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Xóa ngày'));
        await tester.pumpAndSettle();

        expect(find.text('Xác nhận xóa Ngày 2'), findsOneWidget);
        expect(find.textContaining('Đi bộ đường dài'), findsOneWidget);
        expect(
          find.textContaining(
            'Các ngày tiếp theo sẽ được tự động đánh số lại.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Tất cả các hoạt động thuộc ngày này cũng sẽ bị xóa',
          ),
          findsNothing,
        );

        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
      },
    );

    testWidgets('shows activity deletion warning when day has activities', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDeleteDayConfirmationDialog(
                  context,
                  dayNumber: 2,
                  dayTitle: 'Tắm biển Bãi Sao',
                  hasActivities: true,
                );
              },
              child: const Text('Xóa ngày'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Xóa ngày'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Tất cả các hoạt động thuộc ngày này cũng sẽ bị xóa',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Xóa ngày'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  group('ItineraryDetailScreen Day Management Integration Tests', () {
    final sampleItinerary = ItineraryDetail(
      itineraryId: 88,
      title: 'Hành Trình Đà Lạt 2N1Đ',
      location: 'Đà Lạt',
      totalDays: 2,
      budget: 3000000,
      viewCount: 15,
      favoriteCount: 3,
      ratingCount: 2,
      averageRating: 4.5,
      visibility: 'PUBLIC',
      status: 'ACTIVE',
      creator: const CreatorSummary(
        userId: 1,
        username: 'viet_traveler',
        fullName: 'Việt Traveler',
      ),
      days: const [
        ItineraryDayDetail(
          dayId: 10,
          dayNumber: 1,
          title: 'Ngày 1: Check-in & Cà phê',
          activities: [
            ActivityDetail(
              activityId: 1,
              activityType: 'CAFE',
              name: 'Cà phê Đà Lạt',
              displayOrder: 1,
            ),
          ],
        ),
        ItineraryDayDetail(
          dayId: 11,
          dayNumber: 2,
          title: 'Ngày 2: Chợ đêm Đà Lạt',
          activities: [],
        ),
      ],
    );

    testWidgets(
      'shows Add Day buttons and Day Card popup menu when viewer is owner',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ownerAuth = MockAuthNotifier(
          token: 'owner-token',
          user: {'username': 'viet_traveler'},
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 88,
          presetDetail: sampleItinerary,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 88,
              authNotifier: ownerAuth,
              notifier: notifier,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Owner sees "Thêm ngày" in section header
        expect(
          find.widgetWithText(OutlinedButton, 'Thêm ngày'),
          findsOneWidget,
        );

        // Owner sees "Thêm Ngày 3" at the bottom of the list
        final bottomAddBtn = find.text('Thêm Ngày 3');
        await tester.ensureVisible(bottomAddBtn);
        expect(bottomAddBtn, findsOneWidget);

        // Day cards have more_horiz action button
        expect(find.byIcon(Icons.more_horiz), findsWidgets);
      },
    );

    testWidgets(
      'hides Add Day buttons and Day Card popup menu when viewer is NOT owner',
      (tester) async {
        final guestAuth = MockAuthNotifier(
          token: 'guest-token',
          user: {'username': 'stranger'},
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 88,
          presetDetail: sampleItinerary,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 88,
              authNotifier: guestAuth,
              notifier: notifier,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.widgetWithText(OutlinedButton, 'Thêm ngày'), findsNothing);
        expect(find.text('Thêm Ngày 3'), findsNothing);
        expect(find.byIcon(Icons.more_horiz), findsNothing);
      },
    );

    testWidgets(
      'deleting day in ItineraryDetailScreen calls DELETE and reloads detail',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ownerAuth = MockAuthNotifier(
          token: 'owner-token',
          user: {'username': 'viet_traveler'},
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 88,
          presetDetail: sampleItinerary,
        );

        bool deleteDayCalled = false;
        final mockClient = MockClient((request) async {
          if (request.method == 'DELETE' &&
              request.url.path.contains('/api/itineraries/88/days/11')) {
            deleteDayCalled = true;
            return http.Response(
              jsonEncode({'message': 'Đã xóa ngày thành công'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 88,
              authNotifier: ownerAuth,
              notifier: notifier,
              crudRepository: repo,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find more_horiz on Day 2
        final moreButtons = find.byIcon(Icons.more_horiz);
        expect(moreButtons, findsWidgets);

        await tester.tap(moreButtons.last);
        await tester.pumpAndSettle();

        expect(find.text('Xóa ngày'), findsOneWidget);

        await tester.tap(find.text('Xóa ngày'));
        await tester.pumpAndSettle();

        expect(find.text('Xác nhận xóa Ngày 2'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Xóa ngày'));
        await tester.pumpAndSettle();

        expect(deleteDayCalled, isTrue);
        expect(find.text('Đã xóa Ngày 2 thành công.'), findsOneWidget);
      },
    );

    testWidgets('prevents deleting day when itinerary only has 1 day', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final oneDayItinerary = ItineraryDetail(
        itineraryId: 89,
        title: 'Chuyến đi 1 ngày',
        location: 'Hà Nội',
        totalDays: 1,
        budget: 500000,
        viewCount: 1,
        favoriteCount: 0,
        ratingCount: 0,
        averageRating: 0.0,
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        creator: const CreatorSummary(
          userId: 1,
          username: 'viet_traveler',
          fullName: 'Việt Traveler',
        ),
        days: const [
          ItineraryDayDetail(
            dayId: 10,
            dayNumber: 1,
            title: 'Hà Nội 1 ngày duy nhất',
            activities: [],
          ),
        ],
      );

      final ownerAuth = MockAuthNotifier(
        token: 'owner-token',
        user: {'username': 'viet_traveler'},
      );

      final notifier = FakeItineraryDetailNotifier(
        itineraryId: 89,
        presetDetail: oneDayItinerary,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 89,
            authNotifier: ownerAuth,
            notifier: notifier,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xóa ngày'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Lịch trình phải có ít nhất 1 ngày. Không thể xóa ngày cuối cùng.',
        ),
        findsOneWidget,
      );
      expect(find.text('Xác nhận xóa Ngày 1'), findsNothing);
    });

    testWidgets(
      'displays empty state with Add First Day action when days list is empty',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final emptyDaysItinerary = ItineraryDetail(
          itineraryId: 90,
          title: 'Lịch trình chưa có ngày',
          location: 'Huế',
          totalDays: 0,
          budget: 2000000,
          viewCount: 0,
          favoriteCount: 0,
          ratingCount: 0,
          averageRating: 0.0,
          visibility: 'PUBLIC',
          status: 'ACTIVE',
          creator: const CreatorSummary(
            userId: 1,
            username: 'viet_traveler',
            fullName: 'Việt Traveler',
          ),
          days: const [],
        );

        final ownerAuth = MockAuthNotifier(
          token: 'owner-token',
          user: {'username': 'viet_traveler'},
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 90,
          presetDetail: emptyDaysItinerary,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 90,
              authNotifier: ownerAuth,
              notifier: notifier,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Chưa có lịch trình theo ngày'), findsOneWidget);
        expect(find.text('Thêm ngày đầu tiên'), findsOneWidget);
      },
    );
  });
}
