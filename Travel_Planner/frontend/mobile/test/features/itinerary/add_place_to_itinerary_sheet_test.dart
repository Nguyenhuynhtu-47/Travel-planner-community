import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/presentation/widgets/add_place_to_itinerary_sheet.dart';

class TestAuthNotifier extends AuthNotifier {
  final String? _fakeToken;
  TestAuthNotifier([this._fakeToken = 'fake-jwt-token']);

  @override
  String? get token => _fakeToken;

  @override
  bool get isAuthenticated => _fakeToken != null;
}

void main() {
  group('AddPlaceToItinerarySheet Widget Tests', () {
    late TestAuthNotifier authNotifier;
    int bulkSavedPlaceId = 0;
    int targetItineraryId = 0;

    final targetItin = ItinerarySummary(
      itineraryId: 10,
      title: 'Hành trình Hà Nội',
      location: 'Hà Nội',
      totalDays: 3,
      budget: 2000000,
      visibility: 'PUBLIC',
      status: 'ACTIVE',
      viewCount: 0,
      favoriteCount: 0,
      ratingCount: 0,
      averageRating: 0.0,
    );

    final sourceItin = ItinerarySummary(
      itineraryId: 20,
      title: 'Hành trình Đà Nẵng',
      location: 'Đà Nẵng',
      totalDays: 4,
      budget: 4000000,
      visibility: 'PUBLIC',
      status: 'ACTIVE',
      viewCount: 0,
      favoriteCount: 0,
      ratingCount: 0,
      averageRating: 0.0,
    );

    MockClient createMockClient() {
      bulkSavedPlaceId = 0;
      targetItineraryId = 0;

      return MockClient((request) async {
        final uri = request.url;

        // Target itinerary places (already saved placeId: 1)
        if (uri.path == '/api/itineraries/10/places/all') {
          return http.Response(
            jsonEncode([
              {
                'id': 101,
                'itineraryId': 10,
                'place': {
                  'placeId': 1,
                  'name': 'Hồ Gươm',
                  'category': 'Tham quan',
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Source itinerary places (has placeId: 1 and placeId: 2)
        if (uri.path == '/api/itineraries/20/places/all') {
          return http.Response(
            jsonEncode([
              {
                'id': 201,
                'itineraryId': 20,
                'place': {
                  'placeId': 1,
                  'name': 'Hồ Gươm (Trùng)',
                  'category': 'Tham quan',
                },
              },
              {
                'id': 202,
                'itineraryId': 20,
                'place': {
                  'placeId': 2,
                  'name': 'Bà Nà Hills (Mới)',
                  'category': 'Giải trí',
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Save place to itinerary
        if (request.method == 'POST' &&
            uri.path.contains('/api/itineraries/') &&
            uri.path.endsWith('/places')) {
          targetItineraryId = int.tryParse(uri.pathSegments[2]) ?? 0;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bulkSavedPlaceId = body['placeId'] as int? ?? 0;
          return http.Response(
            jsonEncode({
              'id': 301,
              'itineraryId': targetItineraryId,
              'place': {
                'placeId': bulkSavedPlaceId,
                'name': 'Bà Nà Hills (Mới)',
                'category': 'Giải trí',
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });
    }

    setUp(() {
      authNotifier = TestAuthNotifier();
    });

    Future<void> openSheet(
      WidgetTester tester, {
      required ItineraryCrudRepository repo,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddPlaceToItinerarySheet(
              authNotifier: authNotifier,
              repository: repo,
              initialItinerary: targetItin,
              availableItineraries: [targetItin, sourceItin],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Renders AddPlaceToItinerarySheet with target selector and 2 tabs',
      (tester) async {
        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: createMockClient()),
        );

        await openSheet(tester, repo: repo);

        expect(find.text('Thêm địa điểm vào lịch trình'), findsOneWidget);
        expect(find.text('Từ lịch trình khác'), findsOneWidget);
        expect(find.text('Tìm địa điểm mới'), findsOneWidget);
      },
    );

    testWidgets(
      'Way 1: Pick places from source itinerary, disables existing duplicates and saves selected',
      (tester) async {
        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: createMockClient()),
        );

        await openSheet(tester, repo: repo);

        // Select source itinerary from dropdown: 'Hành trình Đà Nẵng'
        await tester.tap(find.byKey(const Key('dropdown_source_itinerary')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Hành trình Đà Nẵng (4 ngày)').last);
        await tester.pumpAndSettle();

        // Source places loaded
        expect(find.text('Hồ Gươm (Trùng)'), findsOneWidget);
        expect(find.text('Bà Nà Hills (Mới)'), findsOneWidget);

        // Place 1 is already saved -> shows badge "✓ Đã có trong lịch trình nhận"
        expect(find.text('✓ Đã có trong lịch trình nhận'), findsOneWidget);

        // Select Place 2 (Bà Nà Hills)
        await tester.tap(find.text('Bà Nà Hills (Mới)'));
        await tester.pumpAndSettle();

        // Tap Save button
        expect(find.text('Thêm 1 địa điểm vào lịch trình'), findsOneWidget);
        await tester.tap(find.text('Thêm 1 địa điểm vào lịch trình'));
        await tester.pumpAndSettle();

        // Verified backend was called with destination itinerary 10 and place 2
        expect(targetItineraryId, equals(10));
        expect(bulkSavedPlaceId, equals(2));
      },
    );

    testWidgets(
      'Way 2: Tab "Tìm địa điểm mới" renders map search CTA and instruction',
      (tester) async {
        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: createMockClient()),
        );

        await openSheet(tester, repo: repo);

        // Switch to Tab 2
        await tester.tap(find.text('Tìm địa điểm mới'));
        await tester.pumpAndSettle();

        expect(find.text('Tìm kiếm địa điểm mới trên bản đồ'), findsOneWidget);
        expect(
          find.text(
            'Tìm địa danh, quán ăn, khách sạn hoặc điểm tham quan bất kỳ để lưu vào lịch trình.',
          ),
          findsOneWidget,
        );
        expect(find.text('Mở tìm kiếm địa điểm'), findsOneWidget);
      },
    );
  });
}
