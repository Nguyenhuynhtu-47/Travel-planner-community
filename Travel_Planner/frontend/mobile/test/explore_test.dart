import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/explore_repository.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/explore/presentation/explore_notifier.dart';
import 'package:mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:mobile/features/explore/presentation/widgets/itinerary_card.dart';
import 'package:mobile/shared/widgets/app_empty_state.dart';
import 'package:mobile/shared/widgets/app_error_state.dart';

void main() {
  group('ApiClient Query Parameters Support Tests', () {
    test('ApiClient.get encodes query parameters correctly', () async {
      String? requestedUrl;
      final mockClient = MockClient((request) async {
        requestedUrl = request.url.toString();
        return http.Response(
          jsonEncode({'status': 'ok'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(client: mockClient);
      await client.get(
        '/api/itineraries',
        queryParameters: {
          'keyword': 'Đà Lạt',
          'minBudget': 1000000,
          'nullParam': null,
        },
      );

      expect(requestedUrl, isNotNull);
      expect(requestedUrl, contains('keyword=%C4%90%C3%A0+L%E1%BA%A1t'));
      expect(requestedUrl, contains('minBudget=1000000'));
      expect(requestedUrl, isNot(contains('nullParam')));
    });
  });

  group('Explore Data Models Tests', () {
    test('ItinerarySummary deserializes valid and nullable JSON fields', () {
      final json = {
        'itineraryId': 42,
        'title': 'Chuyến đi Phú Quốc',
        'description': '3 ngày 2 đêm thư giãn',
        'location': 'Phú Quốc',
        'coverImage': null,
        'totalDays': 3,
        'budget': 3500000.5,
        'theme': 'Nghỉ dưỡng',
        'viewCount': 120,
        'favoriteCount': 15,
        'ratingCount': 8,
        'averageRating': 4.75,
        'createdAt': '2026-10-23T10:15:30',
        'creator': {
          'userId': 7,
          'username': 'linh_travel',
          'fullName': 'Nguyễn Linh',
          'avatar': null,
        },
      };

      final itinerary = ItinerarySummary.fromJson(json);

      expect(itinerary.itineraryId, equals(42));
      expect(itinerary.title, equals('Chuyến đi Phú Quốc'));
      expect(itinerary.location, equals('Phú Quốc'));
      expect(itinerary.coverImage, isNull);
      expect(itinerary.totalDays, equals(3));
      expect(itinerary.budget, equals(3500000.5));
      expect(itinerary.theme, equals('Nghỉ dưỡng'));
      expect(itinerary.averageRating, equals(4.75));
      expect(itinerary.createdAt, isNotNull);
      expect(itinerary.creator, isNotNull);
      expect(itinerary.creator?.displayName, equals('Nguyễn Linh'));
    });

    test(
      'CreatorSummary falls back to username when fullName is null or empty',
      () {
        final c1 = CreatorSummary.fromJson({
          'userId': 1,
          'username': 'traveller_bob',
          'fullName': null,
        });
        expect(c1.displayName, equals('traveller_bob'));

        final c2 = CreatorSummary.fromJson({
          'userId': 2,
          'username': 'alice',
          'fullName': '   ',
        });
        expect(c2.displayName, equals('alice'));
      },
    );

    test('PageResult parses pageNumber/pageSize and page/size variants', () {
      final json1 = {
        'content': [
          {
            'itineraryId': 1,
            'title': 'Trip 1',
            'location': 'HN',
            'totalDays': 2,
            'budget': 100,
            'viewCount': 0,
            'favoriteCount': 0,
            'ratingCount': 0,
            'averageRating': 0.0,
          },
        ],
        'pageNumber': 1,
        'pageSize': 10,
        'totalElements': 25,
        'totalPages': 3,
        'last': false,
      };

      final page1 = PageResult.fromJson(
        json1,
        (item) => ItinerarySummary.fromJson(item as Map<String, dynamic>),
      );

      expect(page1.content.length, equals(1));
      expect(page1.pageNumber, equals(1));
      expect(page1.pageSize, equals(10));
      expect(page1.totalElements, equals(25));
      expect(page1.totalPages, equals(3));
      expect(page1.isLast, isFalse);
      expect(page1.hasMore, isTrue);

      final json2 = {
        'content': [],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 1,
        'last': true,
      };

      final page2 = PageResult.fromJson(
        json2,
        (item) => ItinerarySummary.fromJson(item as Map<String, dynamic>),
      );

      expect(page2.pageNumber, equals(0));
      expect(page2.pageSize, equals(20));
      expect(page2.hasMore, isFalse);
    });
  });

  group('ExploreRepository Tests', () {
    test(
      'getPublicItineraries sends correct query parameters to backend',
      () async {
        Map<String, String>? capturedParams;

        final mockClient = MockClient((request) async {
          capturedParams = request.url.queryParameters;
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

        final repo = ExploreRepository(
          apiClient: ApiClient(client: mockClient),
        );
        await repo.getPublicItineraries(
          keyword: 'Hà Giang',
          location: 'Hà Giang',
          theme: 'Phượt',
          minBudget: 2000000,
          maxBudget: 5000000,
          minDays: 3,
          maxDays: 5,
          minRating: 4.0,
          page: 0,
          size: 10,
          sort: 'budget,asc',
        );

        expect(capturedParams, isNotNull);
        expect(capturedParams!['keyword'], equals('Hà Giang'));
        expect(capturedParams!['location'], equals('Hà Giang'));
        expect(capturedParams!['theme'], equals('Phượt'));
        expect(capturedParams!['minBudget'], equals('2000000.0'));
        expect(capturedParams!['maxBudget'], equals('5000000.0'));
        expect(capturedParams!['minDays'], equals('3'));
        expect(capturedParams!['maxDays'], equals('5'));
        expect(capturedParams!['minRating'], equals('4.0'));
        expect(capturedParams!['sort'], equals('budget,asc'));
      },
    );
  });

  group('ExploreNotifier State and Pagination Tests', () {
    test('fetchItineraries transitions from loading to success', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'itineraryId': 101,
                'title': 'Khám phá Đà Lạt 3N2Đ',
                'location': 'Đà Lạt',
                'coverImage': null,
                'totalDays': 3,
                'budget': 2500000,
                'theme': 'Nghỉ dưỡng',
                'viewCount': 50,
                'favoriteCount': 10,
                'ratingCount': 5,
                'averageRating': 4.6,
                'creator': {
                  'userId': 1,
                  'username': 'alex',
                  'fullName': 'Alex',
                },
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
      });

      final notifier = ExploreNotifier(
        repository: ExploreRepository(apiClient: ApiClient(client: mockClient)),
      );

      expect(notifier.status, equals(ExploreStatus.initial));

      await notifier.fetchItineraries(resetPage: true);

      expect(notifier.status, equals(ExploreStatus.success));
      expect(notifier.itineraries.length, equals(1));
      expect(notifier.itineraries.first.title, equals('Khám phá Đà Lạt 3N2Đ'));
      expect(notifier.isEmptyResults, isFalse);
      expect(notifier.isLastPage, isTrue);
    });

    test(
      'fetchItineraries sets isEmptyResults when content is empty',
      () async {
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

        final notifier = ExploreNotifier(
          repository: ExploreRepository(
            apiClient: ApiClient(client: mockClient),
          ),
        );

        await notifier.fetchItineraries(resetPage: true);

        expect(notifier.status, equals(ExploreStatus.success));
        expect(notifier.itineraries.isEmpty, isTrue);
        expect(notifier.isEmptyResults, isTrue);
      },
    );

    test('fetchItineraries handles API error gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Lỗi kết nối máy chủ'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final notifier = ExploreNotifier(
        repository: ExploreRepository(apiClient: ApiClient(client: mockClient)),
      );

      await notifier.fetchItineraries(resetPage: true);

      expect(notifier.status, equals(ExploreStatus.error));
      expect(notifier.errorMessage, isNotNull);
      expect(notifier.isError, isTrue);
    });

    test('search resets pagination and triggers fetch', () async {
      int requestCount = 0;
      String? capturedKeyword;

      final mockClient = MockClient((request) async {
        requestCount++;
        capturedKeyword = request.url.queryParameters['keyword'];
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

      final notifier = ExploreNotifier(
        repository: ExploreRepository(apiClient: ApiClient(client: mockClient)),
      );

      notifier.search('Sapa');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(requestCount, equals(1));
      expect(capturedKeyword, equals('Sapa'));
      expect(notifier.searchKeyword, equals('Sapa'));
    });

    test(
      'loadMore appends items to existing list and increments page',
      () async {
        final mockClient = MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '0');
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'itineraryId': page == 0 ? 1 : 2,
                  'title': 'Trip $page',
                  'location': 'Loc',
                  'totalDays': 2,
                  'budget': 100,
                  'viewCount': 0,
                  'favoriteCount': 0,
                  'ratingCount': 0,
                  'averageRating': 0.0,
                },
              ],
              'pageNumber': page,
              'pageSize': 1,
              'totalElements': 2,
              'totalPages': 2,
              'last': page == 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final notifier = ExploreNotifier(
          repository: ExploreRepository(
            apiClient: ApiClient(client: mockClient),
          ),
        );

        await notifier.fetchItineraries(resetPage: true);
        expect(notifier.itineraries.length, equals(1));
        expect(notifier.currentPage, equals(0));
        expect(notifier.isLastPage, isFalse);

        await notifier.loadMore();
        expect(notifier.itineraries.length, equals(2));
        expect(notifier.currentPage, equals(1));
        expect(notifier.isLastPage, isTrue);
      },
    );

    test('older request cannot overwrite results from newer search', () async {
      final mockClient = MockClient((request) async {
        final keyword = request.url.queryParameters['keyword'];
        if (keyword == 'slow') {
          // Slow first request
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'itineraryId': 999,
                  'title': 'Stale Slow Result',
                  'location': 'Loc',
                  'totalDays': 1,
                  'budget': 100,
                  'viewCount': 0,
                  'favoriteCount': 0,
                  'ratingCount': 0,
                  'averageRating': 0.0,
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
        } else {
          // Fast second request
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'itineraryId': 888,
                  'title': 'Fresh Fast Result',
                  'location': 'Loc',
                  'totalDays': 1,
                  'budget': 200,
                  'viewCount': 0,
                  'favoriteCount': 0,
                  'ratingCount': 0,
                  'averageRating': 0.0,
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
      });

      final notifier = ExploreNotifier(
        repository: ExploreRepository(apiClient: ApiClient(client: mockClient)),
      );

      // Fire slow request first, then fast request
      notifier.search('slow');
      notifier.search('fast');

      // Wait for both to complete
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Result should be the fresh fast result, NOT the stale slow result
      expect(notifier.itineraries.length, equals(1));
      expect(notifier.itineraries.first.itineraryId, equals(888));
      expect(notifier.itineraries.first.title, equals('Fresh Fast Result'));
    });
  });

  group('ExploreScreen Widget Tests', () {
    testWidgets('ExploreScreen renders in guest mode with login button', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'itineraryId': 1,
                'title': 'Du lịch Đà Nẵng 4N3Đ',
                'location': 'Đà Nẵng',
                'totalDays': 4,
                'budget': 3000000,
                'theme': 'Khám phá',
                'viewCount': 20,
                'favoriteCount': 5,
                'ratingCount': 2,
                'averageRating': 4.5,
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
      });

      final authNotifier = AuthNotifier();
      final exploreNotifier = ExploreNotifier(
        repository: ExploreRepository(apiClient: ApiClient(client: mockClient)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExploreScreen(
            authNotifier: authNotifier,
            exploreNotifier: exploreNotifier,
          ),
        ),
      );

      // Trigger initial loading frame
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Travel Planner'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Du lịch Đà Nẵng 4N3Đ'), findsOneWidget);
      expect(find.byType(ItineraryCard), findsOneWidget);
    });

    testWidgets(
      'ExploreScreen renders AppEmptyState when no itineraries found',
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

        final authNotifier = AuthNotifier();
        final exploreNotifier = ExploreNotifier(
          repository: ExploreRepository(
            apiClient: ApiClient(client: mockClient),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExploreScreen(
              authNotifier: authNotifier,
              exploreNotifier: exploreNotifier,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AppEmptyState), findsOneWidget);
        expect(find.text('Không tìm thấy lịch trình'), findsOneWidget);
        expect(find.text('Đặt lại bộ lọc'), findsOneWidget);
      },
    );

    testWidgets(
      'ExploreScreen renders AppErrorState with retry button on failure',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Lỗi kết nối máy chủ'}),
            500,
            headers: {'content-type': 'application/json'},
          );
        });

        final authNotifier = AuthNotifier();
        final exploreNotifier = ExploreNotifier(
          repository: ExploreRepository(
            apiClient: ApiClient(client: mockClient),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExploreScreen(
              authNotifier: authNotifier,
              exploreNotifier: exploreNotifier,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AppErrorState), findsOneWidget);
        expect(find.text('Thử lại'), findsOneWidget);
      },
    );
  });

  group('Explore Category Filter UI and Selection Logic Tests', () {
    test('ExploreNotifier setQuickTheme selection and clearing logic', () async {
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

      final notifier = ExploreNotifier(
        repository: ExploreRepository(apiClient: ApiClient(client: mockClient)),
      );

      // 1. Initial state: theme is null ("Tất cả")
      expect(notifier.filter.theme, isNull);

      // Tapping "Tất cả" when already null does nothing
      notifier.setQuickTheme(null);
      expect(notifier.filter.theme, isNull);

      // 2. Select "Nghỉ dưỡng"
      notifier.setQuickTheme('Nghỉ dưỡng');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.filter.theme, equals('Nghỉ dưỡng'));

      // 3. Set other filters (search keyword and location)
      notifier.search('biển');
      notifier.applyFilter(notifier.filter.copyWith(location: 'Đà Nẵng'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.filter.theme, equals('Nghỉ dưỡng'));
      expect(notifier.searchKeyword, equals('biển'));
      expect(notifier.filter.location, equals('Đà Nẵng'));

      // 4. Tap "Tất cả": clears ONLY theme, preserves search text and location
      notifier.setQuickTheme(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.filter.theme, isNull);
      expect(notifier.searchKeyword, equals('biển'));
      expect(notifier.filter.location, equals('Đà Nẵng'));

      // 5. Select another category and toggle it off
      notifier.setQuickTheme('Khám phá');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.filter.theme, equals('Khám phá'));

      notifier.setQuickTheme('Khám phá');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.filter.theme, isNull);

      // 6. Reset all filters clears everything
      notifier.setQuickTheme('Ẩm thực');
      expect(notifier.filter.theme, equals('Ẩm thực'));
      notifier.resetAllFilters();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.filter.theme, isNull);
      expect(notifier.searchKeyword, isEmpty);
      expect(notifier.filter.location, isNull);
    });

    testWidgets(
      'ExploreScreen category chips display no checkmark and tapping Tất cả clears category filter while preserving unrelated filters',
      (tester) async {
        final capturedRequests = <Uri>[];
        final mockClient = MockClient((request) async {
          capturedRequests.add(request.url);
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'itineraryId': 1,
                  'title': 'Chuyến đi nghỉ dưỡng',
                  'location': 'Phú Quốc',
                  'totalDays': 3,
                  'budget': 3000000,
                  'theme': 'Nghỉ dưỡng',
                  'viewCount': 10,
                  'favoriteCount': 2,
                  'ratingCount': 1,
                  'averageRating': 4.5,
                  'createdAt': '2026-10-23T10:00:00',
                  'creator': {'userId': 1, 'username': 'user1'},
                }
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
        });

        final authNotifier = AuthNotifier();
        final exploreNotifier = ExploreNotifier(
          repository: ExploreRepository(apiClient: ApiClient(client: mockClient)),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExploreScreen(
              authNotifier: authNotifier,
              exploreNotifier: exploreNotifier,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        FilterChip getFilterChip(String text) {
          return tester.widget<FilterChip>(
            find.ancestor(
              of: find.text(text),
              matching: find.byType(FilterChip),
            ),
          );
        }

        // 1. Initially, "Tất cả" is selected, "Nghỉ dưỡng" is not selected.
        expect(getFilterChip('Tất cả').selected, isTrue);
        expect(getFilterChip('Nghỉ dưỡng').selected, isFalse);

        // 2. No checkmark is displayed on the chips.
        expect(getFilterChip('Tất cả').showCheckmark, isFalse);
        expect(getFilterChip('Nghỉ dưỡng').showCheckmark, isFalse);
        expect(find.byIcon(Icons.check), findsNothing);

        // 3. Tapping "Nghỉ dưỡng" activates that category filter.
        await tester.tap(find.widgetWithText(FilterChip, 'Nghỉ dưỡng'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 4. "Nghỉ dưỡng" is highlighted without a checkmark, "Tất cả" is unselected.
        expect(getFilterChip('Nghỉ dưỡng').selected, isTrue);
        expect(getFilterChip('Nghỉ dưỡng').showCheckmark, isFalse);
        expect(getFilterChip('Tất cả').selected, isFalse);
        expect(getFilterChip('Tất cả').showCheckmark, isFalse);
        expect(find.byIcon(Icons.check), findsNothing);
        expect(exploreNotifier.filter.theme, equals('Nghỉ dưỡng'));

        // 5. "Tất cả" remains enabled and tappable while "Nghỉ dưỡng" is selected.
        expect(getFilterChip('Tất cả').onSelected, isNotNull);

        // Add a search query to verify unrelated filter preservation.
        await tester.enterText(find.byType(TextField), 'Đà Lạt');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(exploreNotifier.searchKeyword, equals('Đà Lạt'));
        expect(exploreNotifier.filter.theme, equals('Nghỉ dưỡng'));

        // 6 & 7. Tapping "Tất cả" clears the category filter and restores its selected state,
        // preserving search text.
        await tester.tap(find.widgetWithText(FilterChip, 'Tất cả'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(getFilterChip('Tất cả').selected, isTrue);
        expect(getFilterChip('Tất cả').showCheckmark, isFalse);
        expect(getFilterChip('Nghỉ dưỡng').selected, isFalse);
        expect(find.byIcon(Icons.check), findsNothing);
        expect(exploreNotifier.filter.theme, isNull);
        expect(exploreNotifier.searchKeyword, equals('Đà Lạt'));

        // 8. Tapping "Xóa tất cả" clears all filters including search text.
        expect(find.text('Xóa tất cả'), findsOneWidget);
        await tester.tap(find.text('Xóa tất cả'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(getFilterChip('Tất cả').selected, isTrue);
        expect(exploreNotifier.filter.theme, isNull);
        expect(exploreNotifier.searchKeyword, isEmpty);
      },
    );
  });
}
