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
import 'package:mobile/features/explore/presentation/explore_notifier.dart';
import 'package:mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:mobile/features/explore/presentation/widgets/compact_itinerary_card.dart';
import 'package:mobile/features/explore/presentation/widgets/featured_itinerary_card.dart';
import 'package:mobile/features/explore/presentation/widgets/section_error_view.dart';
import 'package:mobile/features/explore/presentation/widgets/section_header.dart';
import 'package:mobile/features/explore/presentation/widgets/section_skeleton_loader.dart';
import 'package:mobile/features/explore/presentation/widgets/theme_category_card.dart';

void main() {
  ItinerarySummary createSampleItinerary({
    int id = 1,
    String title = 'Hà Nội mùa thu 3N2Đ',
    String location = 'Hà Nội, Việt Nam',
    String? coverImage,
    int totalDays = 3,
    double budget = 2500000.0,
    String? theme = 'Văn hóa',
    int viewCount = 100,
    int favoriteCount = 25,
    int ratingCount = 10,
    double averageRating = 4.8,
  }) {
    return ItinerarySummary(
      itineraryId: id,
      title: title,
      location: location,
      coverImage: coverImage,
      totalDays: totalDays,
      budget: budget,
      theme: theme,
      viewCount: viewCount,
      favoriteCount: favoriteCount,
      ratingCount: ratingCount,
      averageRating: averageRating,
      creator: const CreatorSummary(
        userId: 10,
        username: 'traveler_vn',
        fullName: 'Nguyễn Văn A',
      ),
    );
  }

  Map<String, dynamic> sampleItineraryJson({
    int id = 1,
    String title = 'Hà Nội mùa thu 3N2Đ',
    String location = 'Hà Nội, Việt Nam',
    String? theme = 'Văn hóa',
    int viewCount = 100,
    int favoriteCount = 25,
    int ratingCount = 10,
    double averageRating = 4.8,
  }) {
    return {
      'itineraryId': id,
      'title': title,
      'description': 'Lịch trình khám phá mùa thu',
      'location': location,
      'coverImage': null,
      'totalDays': 3,
      'budget': 2500000.0,
      'theme': theme,
      'visibility': 'PUBLIC',
      'status': 'ACTIVE',
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'ratingCount': ratingCount,
      'averageRating': averageRating,
      'createdAt': '2026-10-25T14:30:00',
      'creator': {
        'userId': 10,
        'username': 'traveler_vn',
        'fullName': 'Nguyễn Văn A',
      },
    };
  }

  group('Section Header Widget Tests', () {
    testWidgets('Renders title, subtitle and action button', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Lịch trình nổi bật',
              subtitle: 'Những hành trình được xem nhiều nhất',
              actionText: 'Xem tất cả',
              onActionTap: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Lịch trình nổi bật'), findsOneWidget);
      expect(find.text('Những hành trình được xem nhiều nhất'), findsOneWidget);
      expect(find.text('Xem tất cả'), findsOneWidget);

      await tester.tap(find.text('Xem tất cả'));
      expect(actionTapped, isTrue);
    });

    testWidgets('Hides action button when onActionTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Khám phá theo chủ đề',
            ),
          ),
        ),
      );

      expect(find.text('Khám phá theo chủ đề'), findsOneWidget);
      expect(find.text('Xem tất cả'), findsNothing);
    });
  });

  group('Featured Itinerary Card Widget Tests', () {
    testWidgets('Renders itinerary details and handles tap events', (tester) async {
      bool cardTapped = false;
      bool favTapped = false;

      final item = createSampleItinerary(
        id: 101,
        title: 'Khám phá Sa Pa 4N3Đ',
        location: 'Sa Pa, Lào Cai',
        totalDays: 4,
        averageRating: 4.9,
        ratingCount: 15,
        theme: 'Khám phá',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeaturedItineraryCard(
              itinerary: item,
              isFavorited: false,
              onTap: () => cardTapped = true,
              onFavoriteTap: () => favTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Khám phá Sa Pa 4N3Đ'), findsOneWidget);
      expect(find.text('Sa Pa, Lào Cai'), findsOneWidget);
      expect(find.text('4 ngày'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text(' (15)'), findsOneWidget);
      expect(find.text('Khám phá'), findsOneWidget);

      await tester.tap(find.text('Khám phá Sa Pa 4N3Đ'));
      expect(cardTapped, isTrue);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(favTapped, isTrue);
    });
  });

  group('Compact Itinerary Card Widget Tests', () {
    testWidgets('Renders rating highlight', (tester) async {
      final item = createSampleItinerary(
        averageRating: 4.8,
        ratingCount: 12,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactItineraryCard(
              itinerary: item,
              highlight: CompactCardHighlight.rating,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('4.8'), findsOneWidget);
      expect(find.text(' (12)'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('Renders popular highlight', (tester) async {
      final item = createSampleItinerary(favoriteCount: 42);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactItineraryCard(
              itinerary: item,
              highlight: CompactCardHighlight.popular,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('42 yêu thích'), findsOneWidget);
    });

    testWidgets('Renders theme highlight', (tester) async {
      final item = createSampleItinerary(theme: 'Biển đảo');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactItineraryCard(
              itinerary: item,
              highlight: CompactCardHighlight.theme,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Biển đảo'), findsOneWidget);
    });
  });

  group('Theme Category Card Widget Tests', () {
    testWidgets('Renders theme item and handles selection', (tester) async {
      bool tapped = false;
      const themeItem = ThemeCategoryItem(
        title: 'Nghỉ dưỡng',
        icon: Icons.beach_access_rounded,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeCategoryCard(
              item: themeItem,
              isSelected: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Nghỉ dưỡng'), findsOneWidget);
      expect(find.byIcon(Icons.beach_access_rounded), findsOneWidget);

      await tester.tap(find.text('Nghỉ dưỡng'));
      expect(tapped, isTrue);
    });
  });

  group('Section Error View and Skeleton Loader Tests', () {
    testWidgets('SectionErrorView displays message and retries on tap', (tester) async {
      bool retryCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionErrorView(
              message: 'Không thể kết nối đến máy chủ',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Không thể kết nối đến máy chủ'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retryCalled, isTrue);
    });

    testWidgets('SectionSkeletonLoader renders placeholders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionSkeletonLoader(count: 3),
          ),
        ),
      );

      expect(find.byType(SectionSkeletonLoader), findsOneWidget);
    });
  });

  group('ExploreNotifier Section Management Unit Tests', () {
    test('loadHomeSections populates sections independently', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        final query = request.url.queryParameters;

        List<Map<String, dynamic>> items = [];

        if (path.contains('/recommendations')) {
          items = [
            sampleItineraryJson(id: 10, title: 'Gợi ý Phú Quốc', theme: 'Nghỉ dưỡng'),
          ];
        } else if (query['sort'] == 'viewCount,desc') {
          items = [
            sampleItineraryJson(id: 1, title: 'Nổi bật Đà Nẵng', viewCount: 500),
          ];
        } else if (query['minRating'] == '4.0' || query['sort'] == 'rating,desc') {
          items = [
            sampleItineraryJson(id: 2, title: 'Top Đánh giá Quy Nhơn', averageRating: 4.9),
          ];
        } else if (query['sort'] == 'favoriteCount,desc') {
          items = [
            sampleItineraryJson(id: 3, title: 'Phổ biến Nha Trang', favoriteCount: 150),
          ];
        } else {
          items = [
            sampleItineraryJson(id: 4, title: 'Mới chia sẻ Ninh Bình'),
          ];
        }

        return http.Response(
          jsonEncode({
            'content': items,
            'pageNumber': 0,
            'pageSize': 6,
            'totalElements': items.length,
            'totalPages': 1,
            'last': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ExploreRepository(apiClient: ApiClient(client: mockClient));
      final notifier = ExploreNotifier(repository: repo);

      await notifier.loadHomeSections();

      expect(notifier.featuredSection.status, equals(SectionStatus.success));
      expect(notifier.featuredSection.items.first.title, equals('Nổi bật Đà Nẵng'));

      expect(notifier.recommendedSection.status, equals(SectionStatus.success));
      expect(notifier.recommendedSection.items.first.title, equals('Gợi ý Phú Quốc'));

      expect(notifier.topRatedSection.status, equals(SectionStatus.success));
      expect(notifier.topRatedSection.items.first.title, equals('Top Đánh giá Quy Nhơn'));

      expect(notifier.popularSection.status, equals(SectionStatus.success));
      expect(notifier.popularSection.items.first.title, equals('Phổ biến Nha Trang'));

      expect(notifier.recentSection.status, equals(SectionStatus.success));
      expect(notifier.recentSection.items.first.title, equals('Mới chia sẻ Ninh Bình'));
    });

    test('showAllForSection and closeViewingAll toggle section view mode', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [sampleItineraryJson(id: 1, title: 'Lịch trình 1')],
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

      final repo = ExploreRepository(apiClient: ApiClient(client: mockClient));
      final notifier = ExploreNotifier(repository: repo);

      notifier.showAllForSection(HomeSectionType.topRated);
      expect(notifier.viewingAllSection, equals(HomeSectionType.topRated));
      expect(notifier.isViewingAll, isTrue);
      expect(notifier.filter.minRating, equals(4.0));
      expect(notifier.sort, equals('rating,desc'));

      notifier.closeViewingAll();
      expect(notifier.viewingAllSection, isNull);
      expect(notifier.isViewingAll, isFalse);
    });
  });

  group('ExploreScreen Discovery Homepage Integration Tests', () {
    testWidgets('Renders all homepage sections when loaded with multiple items', (tester) async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        final query = request.url.queryParameters;

        List<Map<String, dynamic>> items = [];

        if (path.contains('/recommendations')) {
          items = [
            sampleItineraryJson(id: 101, title: 'Gợi ý Hội An'),
          ];
        } else if (query['sort'] == 'viewCount,desc') {
          items = [
            sampleItineraryJson(id: 102, title: 'Nổi bật Hạ Long'),
          ];
        } else if (query['minRating'] == '4.0' || query['sort'] == 'rating,desc') {
          items = [
            sampleItineraryJson(id: 103, title: 'Đánh giá cao Huế'),
          ];
        } else if (query['sort'] == 'favoriteCount,desc') {
          items = [
            sampleItineraryJson(id: 104, title: 'Yêu thích nhất Đà Lạt'),
          ];
        } else {
          items = [
            sampleItineraryJson(id: 105, title: 'Mới đăng Cần Thơ'),
            sampleItineraryJson(id: 106, title: 'Mới đăng Vũng Tàu'),
          ];
        }

        return http.Response(
          jsonEncode({
            'content': items,
            'pageNumber': 0,
            'pageSize': 6,
            'totalElements': items.length,
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
      await exploreNotifier.loadInitialItineraries();

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

      // Verifying sections
      expect(find.text('Chuyến đi nổi bật'), findsOneWidget);
      expect(find.text('Nổi bật Hạ Long'), findsOneWidget);

      expect(find.text('Gợi ý cho bạn'), findsOneWidget);
      expect(find.text('Gợi ý Hội An'), findsOneWidget);

      expect(find.text('Khám phá theo chủ đề'), findsOneWidget);
      expect(find.text('Nghỉ dưỡng'), findsWidgets);

      expect(find.text('Đánh giá cao nhất'), findsOneWidget);
      expect(find.text('Đánh giá cao Huế'), findsOneWidget);

      expect(find.text('Phổ biến nhất'), findsOneWidget);
      expect(find.text('Yêu thích nhất Đà Lạt'), findsOneWidget);

      expect(find.text('Mới chia sẻ gần đây'), findsOneWidget);
      expect(find.text('Mới đăng Cần Thơ'), findsOneWidget);
    });

    testWidgets('Tapping See All switches to paginated view with back button', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              sampleItineraryJson(id: 201, title: 'Đánh giá cao Huế'),
              sampleItineraryJson(id: 202, title: 'Đánh giá cao Đà Nẵng'),
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
      });

      final authNotifier = AuthNotifier();
      final exploreNotifier = ExploreNotifier(
        repository: ExploreRepository(apiClient: ApiClient(client: mockClient)),
      );
      await exploreNotifier.loadInitialItineraries();

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

      final seeAllButtons = find.text('Xem tất cả');
      expect(seeAllButtons, findsWidgets);

      // Tap on the first "Xem tất cả"
      await tester.tap(seeAllButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Now viewing all header should be visible with back button
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Tapping back should restore discovery view
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Khám phá theo chủ đề'), findsOneWidget);
    });
  });
}
