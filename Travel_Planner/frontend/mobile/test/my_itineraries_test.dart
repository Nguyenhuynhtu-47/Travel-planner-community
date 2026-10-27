import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/presentation/my_itineraries_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/my_itineraries_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/my_itinerary_card.dart';
import 'package:mobile/shared/widgets/app_empty_state.dart';
import 'package:mobile/shared/widgets/app_error_state.dart';

void main() {
  group('My Itineraries Data Layer Tests', () {
    test(
      'ItinerarySummary deserializes visibility and status fields correctly',
      () {
        final json = {
          'itineraryId': 101,
          'title': 'Hành trình bí mật Đà Lạt',
          'description': 'Kỳ nghỉ lãng mạn',
          'location': 'Đà Lạt',
          'coverImage': 'https://example.com/dalat.jpg',
          'totalDays': 4,
          'budget': 5000000.0,
          'theme': 'Nghỉ dưỡng',
          'visibility': 'PRIVATE',
          'status': 'ACTIVE',
          'viewCount': 10,
          'favoriteCount': 2,
          'ratingCount': 0,
          'averageRating': 0.0,
          'createdAt': '2026-10-26T10:00:00',
        };

        final summary = ItinerarySummary.fromJson(json);

        expect(summary.itineraryId, equals(101));
        expect(summary.title, equals('Hành trình bí mật Đà Lạt'));
        expect(summary.visibility, equals('PRIVATE'));
        expect(summary.status, equals('ACTIVE'));
        expect(summary.totalDays, equals(4));
        expect(summary.budget, equals(5000000.0));
      },
    );

    test(
      'ItineraryCrudRepository encodes query parameters and parses PageResult',
      () async {
        String? requestedUrl;
        String? authHeader;

        final mockClient = MockClient((request) async {
          requestedUrl = request.url.toString();
          authHeader = request.headers['authorization'];

          final responseBody = {
            'content': [
              {
                'itineraryId': 1,
                'title': 'Trip 1',
                'location': 'Nha Trang',
                'totalDays': 3,
                'budget': 2000000,
                'visibility': 'PUBLIC',
                'status': 'ACTIVE',
                'viewCount': 5,
                'favoriteCount': 1,
                'ratingCount': 0,
                'averageRating': 0.0,
              },
            ],
            'pageNumber': 0,
            'pageSize': 10,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          };

          return http.Response(
            jsonEncode(responseBody),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        final result = await repo.getMyItineraries(
          token: 'test-jwt-token',
          page: 0,
          size: 10,
          status: 'ACTIVE',
          visibility: 'PUBLIC',
        );

        expect(requestedUrl, contains('/api/user/itineraries'));
        expect(requestedUrl, contains('page=0'));
        expect(requestedUrl, contains('size=10'));
        expect(requestedUrl, contains('status=ACTIVE'));
        expect(requestedUrl, contains('visibility=PUBLIC'));
        expect(authHeader, equals('Bearer test-jwt-token'));

        expect(result.content.length, equals(1));
        expect(result.content.first.itineraryId, equals(1));
        expect(result.content.first.visibility, equals('PUBLIC'));
        expect(result.isLast, isTrue);
      },
    );

    test(
      'ItineraryCrudRepository propagates ApiException on failure',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Phiên đăng nhập đã hết hạn'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        expect(
          () => repo.getMyItineraries(token: 'invalid-token'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      },
    );
  });

  group('MyItinerariesNotifier State & Logic Tests', () {
    test(
      'fetchItineraries transitions from initial to loading to success',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'itineraryId': 10,
                  'title': 'Chuyến đi Hà Giang',
                  'location': 'Hà Giang',
                  'totalDays': 4,
                  'budget': 3000000,
                  'visibility': 'PUBLIC',
                  'status': 'ACTIVE',
                  'viewCount': 10,
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
        });

        final notifier = MyItinerariesNotifier(
          repository: ItineraryCrudRepository(
            apiClient: ApiClient(client: mockClient),
          ),
        );

        expect(notifier.status, equals(MyItinerariesStatus.initial));

        final future = notifier.loadInitialItineraries(token: 'valid-token');
        expect(notifier.isLoading, isTrue);

        await future;

        expect(notifier.isSuccess, isTrue);
        expect(notifier.itineraries.length, equals(1));
        expect(notifier.itineraries.first.title, equals('Chuyến đi Hà Giang'));
        expect(notifier.isEmptyResults, isFalse);
      },
    );

    test('fetchItineraries handles error and sets errorMessage', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Lỗi kết nối máy chủ'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final notifier = MyItinerariesNotifier(
        repository: ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        ),
      );

      await notifier.loadInitialItineraries(token: 'valid-token');

      expect(notifier.isError, isTrue);
      expect(notifier.errorMessage, equals('Lỗi kết nối máy chủ'));
      expect(notifier.itineraries, isEmpty);
    });

    test(
      'setVisibilityFilter and setStatusFilter reset page and trigger reload',
      () async {
        String? lastUrl;
        final mockClient = MockClient((request) async {
          lastUrl = request.url.toString();
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

        final notifier = MyItinerariesNotifier(
          repository: ItineraryCrudRepository(
            apiClient: ApiClient(client: mockClient),
          ),
        );

        notifier.setVisibilityFilter('PRIVATE', token: 'token-123');
        await Future<void>.delayed(Duration.zero);

        expect(lastUrl, contains('visibility=PRIVATE'));
        expect(notifier.visibilityFilter, equals('PRIVATE'));

        notifier.setStatusFilter('DRAFT', token: 'token-123');
        await Future<void>.delayed(Duration.zero);

        expect(lastUrl, contains('status=DRAFT'));
        expect(notifier.statusFilter, equals('DRAFT'));
      },
    );
  });

  group('MyItinerariesScreen Widget Tests', () {
    testWidgets('Renders loading indicator initially', (tester) async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({'content': [], 'totalPages': 0, 'last': true}),
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

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('Renders AppErrorState with retry button on failure', (
      tester,
    ) async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({'message': 'Lỗi đường truyền'}),
          500,
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

      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.text('Lỗi đường truyền'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(requestCount, equals(2));
    });

    testWidgets('Renders AppEmptyState when itinerary list is empty', (
      tester,
    ) async {
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

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Chưa có lịch trình nào'), findsOneWidget);
    });

    testWidgets(
      'Renders MyItineraryCard items with badges and navigates to detail on tap',
      (tester) async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/api/user/itineraries')) {
            return http.Response(
              jsonEncode({
                'content': [
                  {
                    'itineraryId': 77,
                    'title': 'Chuyến phượt Tây Bắc',
                    'location': 'Tây Bắc',
                    'totalDays': 5,
                    'budget': 4500000,
                    'theme': 'Phượt',
                    'visibility': 'PRIVATE',
                    'status': 'DRAFT',
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

          // Mock detail endpoint
          return http.Response(
            jsonEncode({
              'itineraryId': 77,
              'title': 'Chuyến phượt Tây Bắc',
              'description': 'Mô tả chi tiết',
              'location': 'Tây Bắc',
              'coverImage': null,
              'totalDays': 5,
              'budget': 4500000,
              'theme': 'Phượt',
              'visibility': 'PRIVATE',
              'viewCount': 0,
              'favoriteCount': 0,
              'ratingCount': 0,
              'commentCount': 0,
              'reuseCount': 0,
              'averageRating': 0.0,
              'createdAt': '2026-10-26T12:00:00',
              'days': [],
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
              repository: repo,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(MyItineraryCard), findsOneWidget);
        expect(find.text('Chuyến phượt Tây Bắc'), findsOneWidget);
        expect(find.text('5 ngày'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(MyItineraryCard),
            matching: find.text('Riêng tư'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(MyItineraryCard),
            matching: find.text('Bản nháp'),
          ),
          findsOneWidget,
        );

        // Tap card to navigate to detail
        await tester.tap(find.byType(MyItineraryCard));
        await tester.pumpAndSettle();

        expect(find.byType(ItineraryDetailScreen), findsOneWidget);
        expect(find.text('Chi tiết lịch trình'), findsOneWidget);
        expect(find.text('Chuyến phượt Tây Bắc'), findsWidgets);
        expect(find.text('Tây Bắc'), findsWidgets);
        expect(find.text('5 ngày'), findsWidgets);
        // Owner actions are visible
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping MyItineraryCard immediately renders itinerary details using initialSummary before async load',
      (tester) async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/api/user/itineraries')) {
            return http.Response(
              jsonEncode({
                'content': [
                  {
                    'itineraryId': 88,
                    'title': 'Hành trình Miền Tây',
                    'location': 'Cần Thơ',
                    'totalDays': 2,
                    'budget': 1500000,
                    'theme': 'Sinh thái',
                    'visibility': 'PUBLIC',
                    'status': 'ACTIVE',
                    'viewCount': 10,
                    'favoriteCount': 2,
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

          // Slow detail endpoint response
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'itineraryId': 88,
              'title': 'Hành trình Miền Tây',
              'location': 'Cần Thơ',
              'totalDays': 2,
              'budget': 1500000,
              'theme': 'Sinh thái',
              'visibility': 'PUBLIC',
              'status': 'ACTIVE',
              'days': [],
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
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap card to navigate
        await tester.tap(find.byType(MyItineraryCard));
        await tester.pumpAndSettle();

        expect(find.byType(ItineraryDetailScreen), findsOneWidget);
        expect(find.text('Hành trình Miền Tây'), findsWidgets);
        expect(find.text('Cần Thơ'), findsWidgets);
        expect(find.text('2 ngày'), findsWidgets);
      },
    );

    testWidgets(
      'Tapping an itinerary with zero activities in My Itineraries renders days section and owner actions',
      (tester) async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/api/user/itineraries')) {
            return http.Response(
              jsonEncode({
                'content': [
                  {
                    'itineraryId': 99,
                    'title': 'Lịch trình Mới Tạo',
                    'location': 'Nha Trang',
                    'totalDays': 3,
                    'budget': 3000000,
                    'theme': 'Biển đảo',
                    'visibility': 'PUBLIC',
                    'status': 'ACTIVE',
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

          // Detail endpoint returning 3 days with empty activities
          return http.Response(
            jsonEncode({
              'itineraryId': 99,
              'title': 'Lịch trình Mới Tạo',
              'location': 'Nha Trang',
              'totalDays': 3,
              'budget': 3000000,
              'theme': 'Biển đảo',
              'visibility': 'PUBLIC',
              'status': 'ACTIVE',
              'days': [
                {
                  'dayId': 10,
                  'dayNumber': 1,
                  'title': 'Ngày 1: Đến Nha Trang',
                  'activities': [],
                },
                {
                  'dayId': 11,
                  'dayNumber': 2,
                  'title': 'Ngày 2: Tour 4 đảo',
                  'activities': [],
                },
                {
                  'dayId': 12,
                  'dayNumber': 3,
                  'title': 'Ngày 3: Mua sắm và về',
                  'activities': [],
                },
              ],
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
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(MyItineraryCard));
        await tester.pumpAndSettle();

        expect(find.byType(ItineraryDetailScreen), findsOneWidget);
        expect(find.text('Lịch trình Mới Tạo'), findsWidgets);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        // Days section is immediately accessible and visible near the top
        expect(find.text('Lịch trình theo ngày (3 ngày)'), findsOneWidget);
        expect(find.text('Thêm ngày'), findsOneWidget);

        // Day cards and empty activity state are accessible
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pumpAndSettle();

        expect(
          find.text('Chưa có hoạt động nào được lên kế hoạch cho ngày này.'),
          findsWidgets,
        );
        expect(find.text('Thêm hoạt động đầu tiên'), findsWidgets);
      },
    );
  });
}
