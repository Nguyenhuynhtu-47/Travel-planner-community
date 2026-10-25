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
import 'package:mobile/features/itinerary/data/itinerary_repository.dart';
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
