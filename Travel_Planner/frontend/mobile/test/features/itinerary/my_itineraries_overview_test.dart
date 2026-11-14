import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_place.dart';
import 'package:mobile/features/itinerary/data/models/place_summary.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/my_itineraries_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/my_itineraries_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/itinerary_day_card.dart';
import 'package:mobile/features/itinerary/presentation/widgets/my_itinerary_card.dart';
import 'package:mobile/features/itinerary/presentation/widgets/save_place_to_itinerary_sheet.dart';
import 'package:mobile/features/social/data/social_repository.dart';

class TestAuthNotifier extends AuthNotifier {
  final String? _fakeToken;
  final int? _fakeUserId;
  TestAuthNotifier([this._fakeToken = 'fake-jwt-token', this._fakeUserId = 1]);

  @override
  String? get token => _fakeToken;

  int? get userId => _fakeUserId;

  @override
  Map<String, dynamic>? get currentUser => {
    'userId': _fakeUserId,
    'username': 'testuser',
    'fullName': 'Test User',
  };

  @override
  bool get isAuthenticated => _fakeToken != null;
}

void main() {
  group('Screen A (MyItinerariesScreen) & Screen B (ItineraryDetailScreen) Navigation & Save Place Tests', () {
    late TestAuthNotifier authNotifier;
    int savedPlaceToItineraryId = 0;
    int savedPlaceId = 0;
    int deletedPlaceId = 0;
    int deletedFromItineraryId = 0;

    MockClient createMockClient({
      bool returnEmptyPlaces = false,
      bool placesApiFails = false,
      bool delayPlaces = false,
      int ownerUserId = 1,
      String ownerUsername = 'testuser',
    }) {
      savedPlaceToItineraryId = 0;
      savedPlaceId = 0;
      deletedPlaceId = 0;
      deletedFromItineraryId = 0;

      return MockClient((request) async {
        final uri = request.url;

        // User itineraries
        if (uri.path.contains('/api/user/itineraries')) {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'itineraryId': 10,
                  'title': 'Khám phá Hà Nội',
                  'location': 'Hà Nội',
                  'totalDays': 3,
                  'budget': 2000000,
                  'visibility': 'PUBLIC',
                  'status': 'ACTIVE',
                  'userId': ownerUserId,
                  'creator': {'userId': ownerUserId, 'username': ownerUsername, 'fullName': 'Nguyễn Văn A'},
                  'viewCount': 10,
                  'favoriteCount': 2,
                  'ratingCount': 0,
                  'averageRating': 0.0,
                  'createdAt': '2026-10-26T10:00:00',
                },
                {
                  'itineraryId': 20,
                  'title': 'Nghỉ dưỡng Đà Nẵng',
                  'location': 'Đà Nẵng',
                  'totalDays': 4,
                  'budget': 5000000,
                  'visibility': 'PRIVATE',
                  'status': 'ACTIVE',
                  'userId': ownerUserId,
                  'creator': {'userId': ownerUserId, 'username': ownerUsername, 'fullName': 'Nguyễn Văn A'},
                  'viewCount': 5,
                  'favoriteCount': 1,
                  'ratingCount': 0,
                  'averageRating': 0.0,
                  'createdAt': '2026-10-27T10:00:00',
                },
              ],
              'pageNumber': 0,
              'pageSize': 10,
              'totalElements': 2,
              'totalPages': 1,
              'last': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Places for Itinerary 10
        if (uri.path == '/api/itineraries/10/places/all') {
          if (delayPlaces) {
            await Future.delayed(const Duration(milliseconds: 150));
          }
          if (placesApiFails) {
            return http.Response(
              jsonEncode({'message': 'Lỗi máy chủ khi tải địa điểm đã lưu.'}),
              500,
              headers: {'content-type': 'application/json'},
            );
          }
          if (returnEmptyPlaces) {
            return http.Response(
              jsonEncode([]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode([
              {
                'id': 101,
                'itineraryId': 10,
                'place': {
                  'placeId': 1,
                  'name': 'Hồ Hoàn Kiếm',
                  'address': 'Hoàn Kiếm, Hà Nội',
                  'category': 'Tham quan',
                  'latitude': 21.0285,
                  'longitude': 105.8542,
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Delete place from itinerary
        if (request.method == 'DELETE' &&
            uri.path.contains('/api/itineraries/') &&
            uri.path.contains('/places/')) {
          final segments = uri.pathSegments;
          if (segments.length >= 5) {
            deletedFromItineraryId = int.tryParse(segments[2]) ?? 0;
            deletedPlaceId = int.tryParse(segments[4]) ?? 0;
          }
          return http.Response('', 204);
        }

        // Canonicalize Place (/api/places/resolve)
        if (uri.path == '/api/places/resolve') {
          return http.Response(
            jsonEncode({
              'placeId': 1,
              'name': 'Hồ Hoàn Kiếm',
              'latitude': 21.0285,
              'longitude': 105.8542,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Save place to itinerary
        if (request.method == 'POST' &&
            uri.path.contains('/api/itineraries/') &&
            uri.path.endsWith('/places')) {
          final segments = uri.pathSegments;
          savedPlaceToItineraryId = int.tryParse(segments[2]) ?? 0;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          savedPlaceId = body['placeId'] as int? ?? 0;
          return http.Response(
            jsonEncode({
              'id': 999,
              'itineraryId': savedPlaceToItineraryId,
              'place': {
                'placeId': savedPlaceId,
                'name': 'Hồ Hoàn Kiếm',
                'category': 'Tham quan',
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // Default detail / comments fallback
        return http.Response(
          jsonEncode({
            'itineraryId': 10,
            'title': 'Khám phá Hà Nội',
            'location': 'Hà Nội',
            'totalDays': 3,
            'budget': 2000000,
            'theme': 'Văn hóa',
            'visibility': 'PUBLIC',
            'status': 'ACTIVE',
            'userId': ownerUserId,
            'creator': {'userId': ownerUserId, 'username': ownerUsername, 'fullName': 'Nguyễn Văn A'},
            'viewCount': 10,
            'favoriteCount': 2,
            'ratingCount': 0,
            'averageRating': 0.0,
            'days': [
              {
                'dayId': 101,
                'dayNumber': 1,
                'title': 'Ngày 1: Phố Cổ',
                'activities': [
                  {
                    'activityId': 501,
                    'name': 'Tham quan Hồ Hoàn Kiếm',
                    'locationName': 'Hồ Hoàn Kiếm',
                    'locationAddress': 'Hoàn Kiếm, Hà Nội',
                    'startTime': '08:00',
                    'endTime': '10:00',
                    'cost': 0,
                    'latitude': 21.0285,
                    'longitude': 105.8542,
                    'place': {
                      'placeId': 1,
                      'name': 'Hồ Hoàn Kiếm',
                      'address': 'Hoàn Kiếm, Hà Nội',
                      'category': 'Tham quan',
                      'latitude': 21.0285,
                      'longitude': 105.8542,
                    },
                  },
                ],
              },
            ],
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
    }

    ItineraryDetail buildTestDetail({
      required int ownerUserId,
      required String ownerUsername,
    }) {
      return ItineraryDetail(
        itineraryId: 10,
        title: 'Khám phá Hà Nội',
        location: 'Hà Nội',
        totalDays: 3,
        budget: 2000000,
        theme: 'Văn hóa',
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        creator: CreatorSummary(
          userId: ownerUserId,
          username: ownerUsername,
          fullName: 'Nguyễn Văn A',
        ),
        viewCount: 10,
        favoriteCount: 2,
        ratingCount: 0,
        averageRating: 0.0,
        days: const [
          ItineraryDayDetail(
            dayId: 101,
            dayNumber: 1,
            title: 'Ngày 1: Phố Cổ',
            activities: [
              ActivityDetail(
                activityId: 501,
                name: 'Tham quan Hồ Hoàn Kiếm',
                locationName: 'Hồ Hoàn Kiếm',
                locationAddress: 'Hoàn Kiếm, Hà Nội',
                startTime: '08:00',
                endTime: '10:00',
                estimatedCost: 0,
                latitude: 21.0285,
                longitude: 105.8542,
                displayOrder: 1,
                place: PlaceSummary(
                  placeId: 1,
                  name: 'Hồ Hoàn Kiếm',
                  address: 'Hoàn Kiếm, Hà Nội',
                  category: 'Tham quan',
                  latitude: 21.0285,
                  longitude: 105.8542,
                ),
              ),
            ],
          ),
        ],
      );
    }

    setUp(() {
      authNotifier = TestAuthNotifier('fake-jwt-token', 1);
    });

    testWidgets(
      'Screen A: MyItinerariesScreen displays list directly, NO tabs, filter chips, FAB, and navigates to detail on tap',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: createMockClient()),
        );
        final notifier = MyItinerariesNotifier(repository: repo);

        await tester.pumpWidget(
          MaterialApp(
            home: MyItinerariesScreen(
              authNotifier: authNotifier,
              notifier: notifier,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Title is "Lịch trình của tôi"
        expect(find.text('Lịch trình của tôi'), findsOneWidget);

        // 2. STRICTLY NO tabs at this screen level
        expect(find.byType(TabBar), findsNothing);
        expect(find.byType(TabBarView), findsNothing);
        expect(find.text('Địa điểm đã lưu'), findsNothing);

        // 3. Filter chips are directly visible
        expect(find.widgetWithText(FilterChip, 'Tất cả'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Công khai'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Riêng tư'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Bản nháp'), findsOneWidget);

        // 4. FAB "Tạo lịch trình" is visible
        expect(find.text('Tạo lịch trình'), findsOneWidget);

        // 5. Renders itinerary cards
        expect(find.byType(MyItineraryCard), findsNWidgets(2));
        expect(find.text('Khám phá Hà Nội'), findsOneWidget);
        expect(find.text('Nghỉ dưỡng Đà Nẵng'), findsOneWidget);

        // 6. Tap itinerary card navigates to ItineraryDetailScreen
        await tester.tap(find.text('Khám phá Hà Nội'));
        await tester.pumpAndSettle();

        expect(find.byType(ItineraryDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Screen B: ItineraryDetailScreen renders 2 tabs (Tổng quan & Hoạt động), saved places in Tab 1, activities in Tab 2',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: createMockClient(ownerUserId: 1, ownerUsername: 'testuser')),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Both tabs exist at ItineraryDetailScreen level
        expect(find.text('Tổng quan'), findsOneWidget);
        expect(find.text('Hoạt động'), findsOneWidget);

        // 2. Tab 1 "Tổng quan" is active by default
        // Displays itinerary overview info
        expect(find.text('Hà Nội'), findsWidgets);
        expect(find.text('3 ngày'), findsWidgets);
        // Displays saved places section
        expect(find.textContaining('Địa điểm đã lưu'), findsWidgets);
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
        // Displays owner "Thêm địa điểm" button
        expect(find.text('Thêm địa điểm'), findsOneWidget);

        // 3. Switch to Tab 2 "Hoạt động"
        await tester.tap(find.text('Hoạt động'));
        await tester.pumpAndSettle();

        // Days and activities are displayed in Tab 2
        expect(find.text('Lịch trình theo ngày (1 ngày)'), findsOneWidget);
        expect(find.text('Ngày 1: Phố Cổ'), findsOneWidget);
        expect(find.text('Tham quan Hồ Hoàn Kiếm'), findsOneWidget);
      },
    );

    testWidgets(
      'Screen B: Owner can remove saved place from Itinerary in Tab 1',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: createMockClient(ownerUserId: 1, ownerUsername: 'testuser')),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);

        // Open popup menu on the saved place card
        final moreBtn = find.descendant(
          of: find.byType(ItineraryDetailScreen),
          matching: find.byIcon(Icons.more_vert),
        );
        expect(moreBtn, findsWidgets);
        await tester.tap(moreBtn.first);
        await tester.pumpAndSettle();

        // Tap "Xóa khỏi lịch trình"
        expect(find.text('Xóa khỏi lịch trình'), findsOneWidget);
        await tester.tap(find.text('Xóa khỏi lịch trình'));
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.text('Bỏ lưu địa điểm'), findsOneWidget);
        expect(
          find.textContaining('Các hoạt động trong lịch trình sẽ không bị ảnh hưởng.'),
          findsOneWidget,
        );

        // Confirm
        await tester.tap(find.text('Bỏ lưu'));
        await tester.pumpAndSettle();

        expect(deletedFromItineraryId, equals(10));
        expect(deletedPlaceId, equals(1));
      },
    );

    testWidgets(
      'Save Place from Other Users Itinerary: displays Lưu button and opens SavePlaceToItinerarySheet',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Logged-in user is userId = 1, but itinerary owner is userId = 999
        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: createMockClient(ownerUserId: 999, ownerUsername: 'otheruser')),
        );
        final detail = buildTestDetail(ownerUserId: 999, ownerUsername: 'otheruser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Since user is NOT owner:
        // Tab 1 (Saved Places) has a "Lưu" button (Icons.bookmark_add_outlined)
        expect(find.byIcon(Icons.bookmark_add_outlined), findsWidgets);

        // Tap "Lưu" button on the saved place card
        await tester.tap(find.byIcon(Icons.bookmark_add_outlined).first);
        await tester.pumpAndSettle();

        // SavePlaceToItinerarySheet opens
        expect(find.byType(SavePlaceToItinerarySheet), findsOneWidget);
        expect(find.text('Lưu địa điểm vào lịch trình'), findsOneWidget);
        expect(find.text('Chọn lịch trình của bạn để lưu:'), findsOneWidget);

        // Pick user's itinerary: 'Nghỉ dưỡng Đà Nẵng' (itineraryId: 20)
        expect(find.text('Nghỉ dưỡng Đà Nẵng'), findsOneWidget);
        await tester.tap(find.text('Nghỉ dưỡng Đà Nẵng'));
        await tester.pumpAndSettle();

        // Verified POST /api/itineraries/20/places was called with placeId = 1
        expect(savedPlaceToItineraryId, equals(20));
        expect(savedPlaceId, equals(1));
        expect(find.textContaining('Đã lưu "Hồ Hoàn Kiếm" vào lịch trình'), findsOneWidget);
        expect(find.text('Đã lưu'), findsOneWidget);
      },
    );

    testWidgets(
      'Save Place from Activity Timeline of Other User Itinerary works via Activity bookmark',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Logged-in user is userId = 1, itinerary owner is userId = 999
        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: createMockClient(ownerUserId: 999, ownerUsername: 'otheruser')),
        );
        final detail = buildTestDetail(ownerUserId: 999, ownerUsername: 'otheruser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Tab 2: Hoạt động
        await tester.tap(find.text('Hoạt động'));
        await tester.pumpAndSettle();

        // In Tab 2, activity card with location has bookmark button
        expect(find.byType(ItineraryDayCard), findsOneWidget);
        final bookmarkIcon = find.byIcon(Icons.bookmark_add_outlined);
        expect(bookmarkIcon, findsWidgets);

        await tester.tap(bookmarkIcon.first);
        await tester.pumpAndSettle();

        // Sheet opens
        expect(find.byType(SavePlaceToItinerarySheet), findsOneWidget);
        expect(find.text('Lưu địa điểm vào lịch trình'), findsOneWidget);

        // Save to itinerary 10
        await tester.tap(find.text('Khám phá Hà Nội'));
        await tester.pumpAndSettle();

        expect(savedPlaceToItineraryId, equals(10));
        expect(savedPlaceId, equals(1));
      },
    );

    testWidgets(
      'Owner opens itinerary with 0 places: displays "Địa điểm đã lưu (0)", empty state, and "Thêm địa điểm" button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              returnEmptyPlaces: true,
              ownerUserId: 1,
              ownerUsername: 'testuser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Both tabs are present
        expect(find.text('Tổng quan'), findsOneWidget);
        expect(find.text('Hoạt động'), findsOneWidget);

        // 2. Saved places section header is rendered with (0)
        expect(find.text('Địa điểm đã lưu (0)'), findsOneWidget);

        // 3. Empty state UI is rendered
        expect(find.text('Chưa có địa điểm đã lưu'), findsOneWidget);
        expect(
          find.textContaining('Lưu các địa điểm bạn muốn ghé thăm trong chuyến đi này'),
          findsOneWidget,
        );

        // 4. "Thêm địa điểm" button is rendered for owner (both in section header and empty state)
        expect(find.text('Thêm địa điểm'), findsWidgets);
      },
    );

    testWidgets(
      'Viewer opens PUBLIC itinerary with 0 places: displays "Địa điểm đã lưu (0)", viewer empty state, NO "Thêm địa điểm" button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Viewer is userId = 1, owner is userId = 999
        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              returnEmptyPlaces: true,
              ownerUserId: 999,
              ownerUsername: 'otheruser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 999, ownerUsername: 'otheruser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Saved places section header is rendered with (0)
        expect(find.text('Địa điểm đã lưu (0)'), findsOneWidget);

        // 2. Viewer empty state UI is rendered
        expect(find.text('Chưa có địa điểm đã lưu'), findsOneWidget);
        expect(
          find.text('Chưa có địa điểm nào được lưu trong lịch trình này.'),
          findsOneWidget,
        );

        // 3. "Thêm địa điểm" action button must NOT be rendered for viewer
        expect(find.text('Thêm địa điểm'), findsNothing);
      },
    );

    testWidgets(
      'Toggling between Overview and Activities tabs preserves saved places section without data loss',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              ownerUserId: 1,
              ownerUsername: 'testuser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: In Tab 1 "Tổng quan", verify saved place is visible
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
        expect(find.text('Địa điểm đã lưu (1)'), findsOneWidget);

        // Step 2: Switch to Tab 2 "Hoạt động"
        await tester.tap(find.text('Hoạt động'));
        await tester.pumpAndSettle();

        expect(find.text('Ngày 1: Phố Cổ'), findsOneWidget);

        // Step 3: Switch back to Tab 1 "Tổng quan"
        await tester.tap(find.text('Tổng quan'));
        await tester.pumpAndSettle();

        // Step 4: Verify saved place is still visible and intact
        expect(find.text('Địa điểm đã lưu (1)'), findsOneWidget);
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      },
    );

    testWidgets(
      'Viewer with saved places sees the list and bookmark button, NO owner management actions',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              ownerUserId: 999,
              ownerUsername: 'otheruser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 999, ownerUsername: 'otheruser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header shows count (1)
        expect(find.text('Địa điểm đã lưu (1)'), findsOneWidget);

        // 2. Place name and category/address are visible
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
        expect(find.text('Tham quan'), findsOneWidget);

        // 3. Viewer sees bookmark button to save place to own itineraries
        expect(find.byIcon(Icons.bookmark_add_outlined), findsWidgets);

        // 4. Viewer does NOT see owner "Thêm địa điểm" or owner more_vert popup menu
        expect(find.text('Thêm địa điểm'), findsNothing);
        expect(find.byIcon(Icons.more_vert), findsNothing);
      },
    );

    testWidgets(
      'Owner API failure does not hide the entire section: shows header, error card, retry button, and Add Place button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              placesApiFails: true,
              ownerUserId: 1,
              ownerUsername: 'testuser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Saved places section header is STILL RENDERED (never hidden on API error)
        expect(find.text('Địa điểm đã lưu (0)'), findsOneWidget);

        // 2. Error message card is rendered
        expect(find.text('Lỗi máy chủ khi tải địa điểm đã lưu.'), findsOneWidget);
        expect(find.text('Thử lại'), findsWidgets);

        // 3. Owner can still access "Thêm địa điểm" action in the header
        expect(find.text('Thêm địa điểm'), findsOneWidget);
      },
    );

    testWidgets(
      'Add Activity and Overview display consistent saved-place data',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              ownerUserId: 1,
              ownerUsername: 'testuser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Overview has saved place "Hồ Hoàn Kiếm"
        expect(find.text('Địa điểm đã lưu (1)'), findsOneWidget);
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);

        // 2. Switch to Tab 2 "Hoạt động"
        await tester.tap(find.text('Hoạt động'));
        await tester.pumpAndSettle();

        // 3. Tap "Thêm hoạt động" on Day 1
        final addActivityButton = find.text('Thêm hoạt động').first;
        await tester.tap(addActivityButton);
        await tester.pumpAndSettle();

        // 4. Verify Add Activity modal bottom sheet displays consistent saved places
        expect(find.text('Địa điểm đã lưu trong lịch trình:'), findsOneWidget);
        expect(find.text('Hồ Hoàn Kiếm'), findsWidgets);
      },
    );

    testWidgets(
      'Repeated tab switching between Overview and Activities retains all content and never becomes blank',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              ownerUserId: 1,
              ownerUsername: 'testuser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Perform 6 back-and-forth tab switches
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.text('Hoạt động'));
          await tester.pumpAndSettle();
          expect(find.text('Ngày 1: Phố Cổ'), findsOneWidget);

          await tester.tap(find.text('Tổng quan'));
          await tester.pumpAndSettle();
          expect(find.text('Khám phá Hà Nội'), findsOneWidget);
          expect(find.text('Địa điểm đã lưu (1)'), findsOneWidget);
          expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'Switching tabs while saved-place loading is in progress does not break layout or lose state',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              delayPlaces: true,
              ownerUserId: 1,
              ownerUsername: 'testuser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );

        // Initial pump before places async call completes
        await tester.pump();

        // Switch to Hoạt động while places call is pending
        await tester.tap(find.text('Hoạt động'));
        await tester.pump();

        // Settle all futures (places call completes)
        await tester.pumpAndSettle();
        expect(find.text('Ngày 1: Phố Cổ'), findsOneWidget);

        // Switch back to Tổng quan
        await tester.tap(find.text('Tổng quan'));
        await tester.pumpAndSettle();

        // Verify Overview is completely rendered and not blank
        expect(find.text('Khám phá Hà Nội'), findsOneWidget);
        expect(find.text('Địa điểm đã lưu (1)'), findsOneWidget);
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      },
    );

    testWidgets(
      'ItineraryDetailNotifier.savedPlaces is authoritative: direct notifier updates reflect immediately in Overview without stale state',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(
            client: createMockClient(
              ownerUserId: 1,
              ownerUsername: 'testuser',
            ),
          ),
        );
        final detail = buildTestDetail(ownerUserId: 1, ownerUsername: 'testuser');
        final notifier = ItineraryDetailNotifier(
          itineraryId: 10,
          initialDetail: detail,
          crudRepository: repo,
          initialSavedPlaces: [
            ItineraryPlace(
              id: 101,
              itineraryId: 10,
              place: const PlaceSummary(
                placeId: 1,
                name: 'Hồ Hoàn Kiếm',
                category: 'Tham quan',
                address: 'Hoàn Kiếm, Hà Nội',
              ),
              savedAt: DateTime.parse('2026-06-01T08:00:00Z'),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              initialDetail: detail,
              notifier: notifier,
              authNotifier: authNotifier,
              crudRepository: repo,
              socialRepository: SocialRepository(apiClient: repo.apiClient),
              isOwner: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial authoritative state: 1 place
        expect(find.text('Địa điểm đã lưu (1)'), findsOneWidget);
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);

        // 2. Authoritative addition via notifier: add a 2nd place
        notifier.addSavedPlace(
          ItineraryPlace(
            id: 102,
            itineraryId: 10,
            place: const PlaceSummary(
              placeId: 2,
              name: 'Văn Miếu Quốc Tử Giám',
              category: 'Di tích',
              address: 'Đống Đa, Hà Nội',
            ),
            savedAt: DateTime.parse('2026-06-01T09:00:00Z'),
          ),
        );
        await tester.pumpAndSettle();

        // Immediately reflected in Overview: count becomes 2, both places visible
        expect(find.text('Địa điểm đã lưu (2)'), findsOneWidget);
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
        expect(find.text('Văn Miếu Quốc Tử Giám'), findsOneWidget);

        // 3. Authoritative removal via notifier: remove place 1
        notifier.removeSavedPlace(1);
        await tester.pumpAndSettle();

        // Immediately reflected: count becomes 1, place 1 gone, place 2 remains
        expect(find.text('Địa điểm đã lưu (1)'), findsOneWidget);
        expect(find.text('Hồ Hoàn Kiếm'), findsNothing);
        expect(find.text('Văn Miếu Quốc Tử Giám'), findsOneWidget);

        // 4. Authoritative clear via notifier: empty state rendered
        notifier.updateSavedPlaces([]);
        await tester.pumpAndSettle();

        expect(find.text('Địa điểm đã lưu (0)'), findsOneWidget);
        expect(find.text('Chưa có địa điểm đã lưu'), findsOneWidget);
        expect(find.text('Văn Miếu Quốc Tử Giám'), findsNothing);
      },
    );
  });
}
