import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/explore_repository.dart';
import 'package:mobile/features/explore/presentation/explore_notifier.dart';
import 'package:mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/itinerary_repository.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';

void main() {
  test('ActivityDetail maps backend cost field', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(_detailResponse(42)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final detail = await ItineraryRepository(
      apiClient: ApiClient(client: client),
    ).getItineraryDetail(42);

    expect(detail.days.single.activities.single.estimatedCost, 1234000);
  });

  testWidgets('Explore card opens details for the selected itinerary ID', (
    tester,
  ) async {
    final requestedDetailPaths = <String>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/itineraries') {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'itineraryId': 42,
                'title': 'Hành trình Đà Nẵng',
                'location': 'Đà Nẵng',
                'totalDays': 2,
                'budget': 2500000,
                'viewCount': 9,
                'favoriteCount': 1,
                'ratingCount': 0,
                'averageRating': 0,
              },
            ],
            'pageNumber': 0,
            'pageSize': 10,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      requestedDetailPaths.add(request.url.path);
      return http.Response(
        jsonEncode(_detailResponse(42)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final apiClient = ApiClient(client: client);
    final authNotifier = AuthNotifier();
    final exploreNotifier = ExploreNotifier(
      repository: ExploreRepository(apiClient: apiClient),
    );
    ItineraryDetailNotifier? detailNotifier;

    await tester.pumpWidget(
      MaterialApp(
        home: ExploreScreen(
          authNotifier: authNotifier,
          exploreNotifier: exploreNotifier,
          itineraryDetailNotifierFactory: (id, token) =>
              detailNotifier = ItineraryDetailNotifier(
                itineraryId: id,
                repository: ItineraryRepository(apiClient: apiClient),
              ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Hành trình Đà Nẵng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hành trình Đà Nẵng'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(requestedDetailPaths, ['/api/itineraries/42']);
    expect(find.byType(ItineraryDetailScreen), findsOneWidget);
    expect(find.text('Lịch trình Đà Nẵng'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Bà Nà Hills'), findsNWidgets(2));
    expect(find.text('1.234.000 ₫'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    exploreNotifier.dispose();
    authNotifier.dispose();
    detailNotifier?.dispose();
  });

  testWidgets('detail screen provides retry after API failure', (tester) async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      if (requestCount == 1) {
        return http.Response(
          jsonEncode({'message': 'Máy chủ tạm thời không khả dụng'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(_detailResponse(7)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final notifier = ItineraryDetailNotifier(
      itineraryId: 7,
      repository: ItineraryRepository(apiClient: ApiClient(client: client)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ItineraryDetailScreen(itineraryId: 7, notifier: notifier),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(requestCount, 2);
    expect(find.text('Lịch trình Đà Nẵng'), findsOneWidget);
    notifier.dispose();
  });

  testWidgets(
    'detail screen renders body properly when owner views itinerary',
    (tester) async {
      final detail = ItineraryDetail.fromJson(_detailResponse(42));
      final mockAuth = MockAuthNotifier(
        currentUser: {'username': 'traveler'},
        token: 'valid-token',
      );
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_detailResponse(42)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final crudRepo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 42,
            initialDetail: detail,
            authNotifier: mockAuth,
            crudRepository: crudRepo,
          ),
        ),
      );

      // Initial frame
      await tester.pump();
      // Mid transition
      await tester.pump(const Duration(milliseconds: 90));
      // Final transition
      await tester.pump(const Duration(milliseconds: 200));

      // Verify AppBar
      expect(find.text('Chi tiết lịch trình'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Verify body content
      expect(find.text('Lịch trình Đà Nẵng'), findsOneWidget);
      expect(find.text('Đà Nẵng'), findsWidgets);

      // Scroll to see day cards
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Tham quan'), findsOneWidget);

      // Verify render object size of the CustomScrollView
      final csvFinder = find.byType(CustomScrollView);
      expect(csvFinder, findsOneWidget);
      final size = tester.getSize(csvFinder);
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    },
  );

  testWidgets(
    'detail screen loads from API when opened without initialDetail and renders properly for owner',
    (tester) async {
      final mockAuth = MockAuthNotifier(
        currentUser: {'username': 'traveler'},
        token: 'valid-token',
      );
      final responseCompleter = Completer<http.Response>();
      final mockClient = MockClient((request) async {
        return responseCompleter.future;
      });
      final crudRepo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 42,
            initialDetail: null,
            authNotifier: mockAuth,
            crudRepository: crudRepo,
          ),
        ),
      );

      // Frame 1: API request in flight, renders CircularProgressIndicator
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete API request
      responseCompleter.complete(
        http.Response(
          jsonEncode(_detailResponse(42)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar actions
      expect(find.text('Chi tiết lịch trình'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Verify body content
      expect(find.text('Lịch trình Đà Nẵng'), findsOneWidget);
      expect(find.text('Đà Nẵng'), findsWidgets);
    },
  );

  testWidgets(
    'detail screen displays empty state with action when itinerary has zero days',
    (tester) async {
      final data = _detailResponse(42);
      data['days'] = [];
      final detail = ItineraryDetail.fromJson(data);
      final mockAuth = MockAuthNotifier(
        currentUser: {'username': 'traveler'},
        token: 'valid-token',
      );
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final crudRepo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 42,
            initialDetail: detail,
            authNotifier: mockAuth,
            crudRepository: crudRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có lịch trình theo ngày'), findsOneWidget);
      expect(find.text('Thêm ngày đầu tiên'), findsOneWidget);
    },
  );

  testWidgets(
    'non-owner viewing itinerary does not see edit/delete or add day buttons',
    (tester) async {
      final detail = ItineraryDetail.fromJson(_detailResponse(42));
      final mockAuth = MockAuthNotifier(
        currentUser: {'username': 'other_user'},
        token: 'valid-token',
      );
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_detailResponse(42)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final crudRepo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 42,
            initialDetail: detail,
            authNotifier: mockAuth,
            crudRepository: crudRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chi tiết lịch trình'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('Thêm ngày'), findsNothing);
    },
  );

  testWidgets(
    'newly created private itinerary with null description and 0 days renders title, visibility badge, description placeholder, and owner empty state',
    (tester) async {
      final newItineraryData = {
        'itineraryId': 99,
        'title': 'Chuyến đi Măng Đen Tự Túc',
        'description': null,
        'location': 'Kon Tum',
        'coverImage': null,
        'totalDays': 2,
        'budget': 3000000.0,
        'theme': null,
        'visibility': 'PRIVATE',
        'viewCount': 0,
        'favoriteCount': 0,
        'ratingCount': 0,
        'averageRating': 0.0,
        'creator': {
          'userId': 1,
          'username': 'traveler',
          'fullName': 'Người đi du lịch',
        },
        'days': [],
      };
      final detail = ItineraryDetail.fromJson(newItineraryData);
      final mockAuth = MockAuthNotifier(
        currentUser: {'username': 'traveler'},
        token: 'valid-token',
      );
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(newItineraryData),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final crudRepo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 99,
            initialDetail: detail,
            authNotifier: mockAuth,
            crudRepository: crudRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title and location
      expect(find.text('Chuyến đi Măng Đen Tự Túc'), findsOneWidget);
      expect(find.text('Kon Tum'), findsWidgets);

      // Metadata: visibility badge
      expect(find.text('Riêng tư'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);

      // Description empty placeholder
      expect(find.text('Chưa có mô tả cho lịch trình này.'), findsOneWidget);

      // Budget
      expect(find.text('3.000.000 ₫'), findsOneWidget);

      // Owner controls in AppBar
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Scroll down to view days section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Empty days state and action
      expect(find.text('Chưa có lịch trình theo ngày'), findsOneWidget);
      expect(find.text('Thêm ngày đầu tiên'), findsOneWidget);
      expect(find.text('Thêm ngày'), findsOneWidget);
    },
  );

  testWidgets(
    'public sample itinerary with theme displays public visibility and theme tag',
    (tester) async {
      final sampleData = _detailResponse(10);
      sampleData['visibility'] = 'PUBLIC';
      sampleData['theme'] = 'Nghỉ dưỡng biển';
      final detail = ItineraryDetail.fromJson(sampleData);
      final mockAuth = MockAuthNotifier(
        currentUser: {'username': 'other_user'},
        token: 'valid-token',
      );
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(sampleData),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final crudRepo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 10,
            initialDetail: detail,
            authNotifier: mockAuth,
            crudRepository: crudRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Công khai'), findsOneWidget);
      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.text('Nghỉ dưỡng biển'), findsOneWidget);
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'newly created itinerary with 3 days, empty activities, and nullable fields renders detail completely without blanking or crashing',
    (tester) async {
      final itineraryData = <String, dynamic>{
        'itineraryId': 282,
        'title': 'neww',
        'location': 'đà lạt',
        'totalDays': 3,
        'budget': 3000000.00,
        'theme': 'Văn hóa',
        'visibility': 'PUBLIC',
        'creator': {
          'userId': 577,
          'username': 'creator577',
          'fullName': 'Người Tạo 577',
          'avatar': null,
        },
        'days': [
          {
            'dayId': 63,
            'dayNumber': 1,
            'title': 'Ngày 1',
            'date': null,
            'activities': <dynamic>[],
          },
          {
            'dayId': 64,
            'dayNumber': 2,
            'title': 'Ngày 2',
            'date': null,
            'activities': <dynamic>[],
          },
          {
            'dayId': 65,
            'dayNumber': 3,
            'title': 'Ngày 3',
            'date': null,
            'activities': <dynamic>[],
          },
        ],
        'description': null,
        'coverImage': null,
      };

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/itineraries/282') {
          return http.Response(
            jsonEncode(itineraryData),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final mockAuth = MockAuthNotifier(
        currentUser: {'userId': 577, 'username': 'creator577'},
        token: 'auth-token-577',
      );

      final crudRepo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 282,
            token: 'auth-token-577',
            authNotifier: mockAuth,
            crudRepository: crudRepo,
          ),
        ),
      );

      // Settle async fetch
      await tester.pumpAndSettle();

      // Title
      expect(find.text('neww'), findsOneWidget);

      // Location
      expect(find.text('đà lạt'), findsWidgets);

      // Duration
      expect(find.text('3 ngày'), findsOneWidget);

      // Budget
      expect(find.text('3.000.000 ₫'), findsOneWidget);

      // Theme
      expect(find.text('Văn hóa'), findsOneWidget);
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);

      // Visibility
      expect(find.text('Công khai'), findsOneWidget);
      expect(find.byIcon(Icons.public), findsOneWidget);

      // Nullable description placeholder
      expect(find.text('Chưa có mô tả cho lịch trình này.'), findsOneWidget);

      // Creator avatar fallback (person icon) and display name
      expect(find.byIcon(Icons.person_outline), findsWidgets);
      expect(find.text('Tạo bởi Người Tạo 577'), findsOneWidget);

      // Days section header
      await tester.scrollUntilVisible(
        find.text('Lịch trình theo ngày (3 ngày)'),
        200,
      );
      expect(find.text('Lịch trình theo ngày (3 ngày)'), findsOneWidget);

      // Days: Ngày 1, Ngày 2, Ngày 3 rendered
      await tester.scrollUntilVisible(find.text('Ngày 1'), 150);
      expect(find.text('Ngày 1'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Ngày 2'), 150);
      expect(find.text('Ngày 2'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Ngày 3'), 150);
      expect(find.text('Ngày 3'), findsOneWidget);

      // All 3 days have empty activities state
      expect(
        find.text('Chưa có hoạt động nào được lên kế hoạch cho ngày này.'),
        findsWidgets,
      );

      // Owner controls: Add first activity
      expect(find.text('Thêm hoạt động đầu tiên'), findsWidgets);

      // Owner buttons: Edit & Delete in AppBar
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    },
  );

  test('ItineraryDetail.fromJson handles generic Map, string numbers, and nullables', () {
    final raw = <dynamic, dynamic>{
      'itineraryId': '282',
      'title': 'neww',
      'location': 'đà lạt',
      'totalDays': '3',
      'budget': '3000000.00',
      'theme': 'Văn hóa',
      'visibility': 'PUBLIC',
      'creator': <dynamic, dynamic>{'userId': '577', 'username': 'creator577'},
      'days': [
        <dynamic, dynamic>{
          'dayId': '63',
          'dayNumber': '1',
          'title': null,
          'date': null,
          'activities': <dynamic>[],
        },
      ],
      'description': null,
      'coverImage': null,
    };

    final detail = ItineraryDetail.fromJson(Map<String, dynamic>.from(raw));
    expect(detail.itineraryId, 282);
    expect(detail.totalDays, 3);
    expect(detail.budget, 3000000.0);
    expect(detail.creator?.userId, 577);
    expect(detail.days.length, 1);
    expect(detail.days.first.dayId, 63);
    expect(detail.days.first.activities, isEmpty);
  });
}

class MockAuthNotifier extends AuthNotifier {
  @override
  final Map<String, dynamic>? currentUser;

  @override
  final String? token;

  MockAuthNotifier({this.currentUser, this.token});

  @override
  bool get isAuthenticated => token != null;
}

Map<String, dynamic> _detailResponse(int id) => {
  'itineraryId': id,
  'title': 'Lịch trình Đà Nẵng',
  'description': 'Khám phá thành phố và vùng núi gần đó.',
  'location': 'Đà Nẵng',
  'totalDays': 1,
  'budget': 2500000,
  'visibility': 'PUBLIC',
  'viewCount': 9,
  'favoriteCount': 1,
  'ratingCount': 0,
  'averageRating': 0,
  'creator': {
    'userId': 1,
    'username': 'traveler',
    'fullName': 'Người đi du lịch',
  },
  'days': [
    {
      'dayId': 1,
      'dayNumber': 1,
      'title': 'Tham quan',
      'activities': [
        {
          'activityId': 10,
          'name': 'Bà Nà Hills',
          'startTime': '08:00:00',
          'endTime': '12:00:00',
          'cost': 1234000,
          'displayOrder': 1,
          'destination': {
            'destinationId': 5,
            'name': 'Bà Nà Hills',
            'address': 'Đà Nẵng',
          },
        },
      ],
    },
  ],
};
