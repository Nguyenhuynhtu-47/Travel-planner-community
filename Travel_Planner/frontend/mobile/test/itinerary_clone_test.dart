import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/core/theme/app_theme.dart';

void main() {
  group('Phase 5 - Itinerary Clone Model & Serialization Tests', () {
    test('ItineraryDetail parses reuseCount and originalItineraryId correctly', () {
      final json = {
        'itineraryId': 260,
        'originalItineraryId': 259,
        'title': 'Fansipan & Săn Mây Sa Pa Cá Nhân Hóa (Bản sao)',
        'description': 'Lịch trình cá nhân hóa từ bản gốc',
        'location': 'Sa Pa, Lào Cai',
        'totalDays': 3,
        'budget': 3500000.0,
        'theme': 'Trekking',
        'visibility': 'PRIVATE',
        'status': 'ACTIVE',
        'viewCount': 0,
        'favoriteCount': 0,
        'ratingCount': 0,
        'reuseCount': 2,
        'averageRating': 0.0,
        'days': [],
      };

      final detail = ItineraryDetail.fromJson(json);

      expect(detail.itineraryId, 260);
      expect(detail.originalItineraryId, 259);
      expect(detail.reuseCount, 2);
      expect(detail.title, 'Fansipan & Săn Mây Sa Pa Cá Nhân Hóa (Bản sao)');
      expect(detail.visibility, 'PRIVATE');
      expect(detail.status, 'ACTIVE');
      expect(detail.viewCount, 0);
      expect(detail.favoriteCount, 0);
    });

    test('ItineraryDetail defaults reuseCount to 0 and originalItineraryId to null when omitted', () {
      final json = {
        'itineraryId': 100,
        'title': 'Tour Hà Nội',
        'location': 'Hà Nội',
        'totalDays': 1,
        'budget': 500000.0,
        'visibility': 'PUBLIC',
        'status': 'ACTIVE',
        'days': [],
      };

      final detail = ItineraryDetail.fromJson(json);

      expect(detail.itineraryId, 100);
      expect(detail.originalItineraryId, isNull);
      expect(detail.reuseCount, 0);
    });

    test('ItineraryDetail.copyWith preserves and updates reuseCount and originalItineraryId', () {
      const initial = ItineraryDetail(
        itineraryId: 10,
        title: 'Chuyến đi gốc',
        location: 'Đà Nẵng',
        totalDays: 2,
        budget: 1000000.0,
        viewCount: 5,
        favoriteCount: 2,
        ratingCount: 1,
        reuseCount: 4,
        originalItineraryId: 5,
        averageRating: 4.5,
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        days: [],
      );

      final copy1 = initial.copyWith(title: 'Chuyến đi cập nhật');
      expect(copy1.reuseCount, 4);
      expect(copy1.originalItineraryId, 5);

      final copy2 = initial.copyWith(reuseCount: 10, originalItineraryId: 99);
      expect(copy2.reuseCount, 10);
      expect(copy2.originalItineraryId, 99);
    });
  });

  group('Phase 5 - ItineraryCrudRepository.cloneItinerary Tests', () {
    test('sends POST to /api/itineraries/{id}/clone with Bearer token and parses response', () async {
      String? capturedMethod;
      String? capturedUrl;
      String? capturedAuthHeader;

      final mockClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedUrl = request.url.toString();
        capturedAuthHeader = request.headers['authorization'];

        final responseData = {
          'itineraryId': 200,
          'originalItineraryId': 50,
          'title': 'Khám phá Sa Pa (Bản sao)',
          'location': 'Sa Pa, Lào Cai',
          'totalDays': 2,
          'budget': 2000000.0,
          'visibility': 'PRIVATE',
          'status': 'ACTIVE',
          'viewCount': 0,
          'favoriteCount': 0,
          'ratingCount': 0,
          'reuseCount': 0,
          'averageRating': 0.0,
          'days': [],
        };

        return http.Response(
          jsonEncode(responseData),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      final cloned = await repository.cloneItinerary(50, token: 'test-jwt-token');

      expect(capturedMethod, 'POST');
      expect(capturedUrl, contains('/api/itineraries/50/clone'));
      expect(capturedAuthHeader, 'Bearer test-jwt-token');
      expect(cloned.itineraryId, 200);
      expect(cloned.originalItineraryId, 50);
      expect(cloned.title, 'Khám phá Sa Pa (Bản sao)');
      expect(cloned.visibility, 'PRIVATE');
      expect(cloned.status, 'ACTIVE');
    });

    test('propagates ApiException when backend rejects with 403 Forbidden', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 403,
            'message': 'Bạn không có quyền sao chép lịch trình riêng tư này',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      expect(
        () => repository.cloneItinerary(99, token: 'token'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Bạn không có quyền sao chép'),
        )),
      );
    });
  });

  group('Phase 5 - ItineraryDetailScreen Clone UI Widget Tests', () {
    testWidgets('displays clone action button in AppBar', (tester) async {
      const sampleItinerary = ItineraryDetail(
        itineraryId: 300,
        title: 'Hành trình Đà Lạt',
        location: 'Đà Lạt',
        totalDays: 2,
        budget: 1500000.0,
        viewCount: 10,
        favoriteCount: 2,
        ratingCount: 1,
        reuseCount: 0,
        averageRating: 5.0,
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        days: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ItineraryDetailScreen(
            itineraryId: 300,
            initialDetail: sampleItinerary,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check copy button in AppBar
      expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
      expect(find.byTooltip('Sao chép lịch trình'), findsOneWidget);
    });

    testWidgets('displays reuseCount in metadata badge when reuseCount > 0', (tester) async {
      const sampleWithReuse = ItineraryDetail(
        itineraryId: 301,
        title: 'Lịch trình được tái sử dụng nhiều',
        location: 'Hội An',
        totalDays: 1,
        budget: 500000.0,
        viewCount: 100,
        favoriteCount: 20,
        ratingCount: 5,
        reuseCount: 7,
        averageRating: 4.8,
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        days: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ItineraryDetailScreen(
            itineraryId: 301,
            initialDetail: sampleWithReuse,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('7 lượt sao chép'), findsOneWidget);
    });

    testWidgets('unauthenticated user tapping clone button prompts to login', (tester) async {
      const sampleItinerary = ItineraryDetail(
        itineraryId: 302,
        title: 'Lịch trình công khai',
        location: 'Huế',
        totalDays: 1,
        budget: 300000.0,
        viewCount: 1,
        favoriteCount: 0,
        ratingCount: 0,
        reuseCount: 0,
        averageRating: 0.0,
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        days: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ItineraryDetailScreen(
            itineraryId: 302,
            initialDetail: sampleItinerary,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the clone icon
      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await tester.pump();

      // SnackBar prompt should appear
      expect(find.text('Vui lòng đăng nhập để sao chép lịch trình'), findsOneWidget);
    });
  });
}
