import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/collection/data/collection_repository.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/explore/presentation/explore_notifier.dart';
import 'package:mobile/features/explore/presentation/widgets/itinerary_card.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/social/data/models/social_state_update.dart';
import 'package:mobile/features/social/data/social_repository.dart';

class MockSocialRepository extends SocialRepository {
  bool shouldThrow = false;
  int addFavoriteCalls = 0;
  int removeFavoriteCalls = 0;
  int saveCalls = 0;
  int removeSaveCalls = 0;

  @override
  Future<void> addFavorite(int itineraryId, {String? token}) async {
    if (shouldThrow) throw ApiException(message: 'Error', statusCode: 500);
    addFavoriteCalls++;
  }

  @override
  Future<void> removeFavorite(int itineraryId, {String? token}) async {
    if (shouldThrow) throw ApiException(message: 'Error', statusCode: 500);
    removeFavoriteCalls++;
  }

  @override
  Future<void> saveItinerary(int itineraryId, {String? token}) async {
    if (shouldThrow) throw ApiException(message: 'Error', statusCode: 500);
    saveCalls++;
  }

  @override
  Future<void> removeSavedItinerary(int itineraryId, {String? token}) async {
    if (shouldThrow) throw ApiException(message: 'Error', statusCode: 500);
    removeSaveCalls++;
  }
}

class MockCollectionRepository extends CollectionRepository {
  List<ItinerarySummary> favorites = [];

  @override
  Future<PageResult<ItinerarySummary>> getFavoriteItineraries({
    int page = 0,
    int size = 10,
    String? token,
  }) async {
    return PageResult(
      content: favorites,
      pageNumber: page,
      pageSize: size,
      totalElements: favorites.length,
      totalPages: 1,
      isLast: true,
    );
  }
}

class MockCrudRepository extends ItineraryCrudRepository {
  ItineraryDetail? detailToReturn;

  Future<ItineraryDetail> getItineraryDetail(int id, {String? token}) async {
    if (detailToReturn != null) return detailToReturn!;
    return ItineraryDetail(
      itineraryId: id,
      title: 'Chi tiết $id',
      location: 'Hà Nội',
      totalDays: 3,
      budget: 1000000,
      viewCount: 10,
      favoriteCount: 0,
      ratingCount: 0,
      averageRating: 0.0,
      visibility: 'PUBLIC',
      status: 'PUBLISHED',
      days: [],
      isFavorited: false,
      isSaved: false,
    );
  }
}

class MockAuthNotifier extends AuthNotifier {
  @override
  String? get token => 'valid_token';
  @override
  bool get isAuthenticated => true;
  @override
  Map<String, dynamic>? get currentUser => {'userId': 99, 'username': 'test_user'};
}

ItinerarySummary makeSummary({
  int id = 1,
  String title = 'Test Itinerary',
  int favoriteCount = 5,
  int creatorUserId = 10,
}) {
  return ItinerarySummary(
    itineraryId: id,
    title: title,
    location: 'Đà Nẵng',
    totalDays: 2,
    budget: 500000,
    viewCount: 10,
    favoriteCount: favoriteCount,
    ratingCount: 0,
    averageRating: 0.0,
    creator: CreatorSummary(userId: creatorUserId, username: 'Author Name'),
  );
}

void main() {
  group('1. ItineraryCard - Saved & Favorite UI State', () {
    testWidgets('Renders heart icon with white border when isFavorited is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryCard(
                itinerary: makeSummary(id: 10),
                isFavorited: false,
                onFavoriteTap: () {},
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.favorite_border_rounded);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, Colors.white);
    });

    testWidgets('Renders filled red heart icon when isFavorited is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryCard(
                itinerary: makeSummary(id: 10),
                isFavorited: true,
                onFavoriteTap: () {},
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.favorite_rounded);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, Colors.redAccent);
    });

    testWidgets('Tapping favorite heart button triggers onFavoriteTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryCard(
                itinerary: makeSummary(id: 10),
                isFavorited: false,
                onFavoriteTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(tapped, isTrue);
    });
  });

  group('2. ItineraryDetailScreen - Initial State & Amber Bookmark Color', () {
    testWidgets('Renders amber/yellow bookmark icon when initialIsSaved is true', (tester) async {
      final mockCrud = MockCrudRepository();
      final mockSocial = MockSocialRepository();
      final summary = makeSummary(id: 42);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ItineraryDetailScreen(
            itineraryId: 42,
            initialSummary: summary,
            initialIsSaved: true,
            initialIsFavorited: false,
            crudRepository: mockCrud,
            socialRepository: mockSocial,
            authNotifier: MockAuthNotifier(),
          ),
        ),
      );

      // On initial frame before async detail finishes, the saved icon should be active and amber
      final bookmarkFinder = find.byIcon(Icons.bookmark);
      expect(bookmarkFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(bookmarkFinder);
      expect(iconWidget.color, AppColors.savedActive);
      expect(iconWidget.color, const Color(0xFFF59E0B));
    });

    testWidgets('Renders red heart icon when initialIsFavorited is true', (tester) async {
      final mockCrud = MockCrudRepository();
      final mockSocial = MockSocialRepository();
      final summary = makeSummary(id: 42);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ItineraryDetailScreen(
            itineraryId: 42,
            initialSummary: summary,
            initialIsSaved: false,
            initialIsFavorited: true,
            crudRepository: mockCrud,
            socialRepository: mockSocial,
            authNotifier: MockAuthNotifier(),
          ),
        ),
      );

      final heartFinder = find.byIcon(Icons.favorite);
      expect(heartFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(heartFinder);
      expect(iconWidget.color, Colors.redAccent);
    });

    test('ItineraryDetailNotifier preserves initialIsFavorited and initialIsSaved', () {
      final summary = makeSummary(id: 55);
      final notifier = ItineraryDetailNotifier(
        itineraryId: 55,
        initialSummary: summary,
        initialIsFavorited: true,
        initialIsSaved: true,
      );

      expect(notifier.itineraryDetail, isNotNull);
      expect(notifier.itineraryDetail!.isFavorited, isTrue);
      expect(notifier.itineraryDetail!.isSaved, isTrue);
    });
  });

  group('3. ExploreNotifier - Favorite State & Optimistic Toggle', () {
    test('Optimistically flips favorite and updates favoriteCount', () async {
      final mockSocial = MockSocialRepository();
      final notifier = ExploreNotifier();

      // Seed items
      notifier.applySocialUpdate(
        SocialStateUpdate(
          itineraryId: 100,
          isFavorited: false,
          favoriteCount: 5,
        ),
      );

      expect(notifier.isFavorited(100), isFalse);

      // Toggle favorite ON
      final future = notifier.toggleFavorite(
        itineraryId: 100,
        token: 'token',
        socialRepository: mockSocial,
      );

      // Immediately optimistic
      expect(notifier.isFavorited(100), isTrue);

      final nextFav = await future;
      expect(nextFav, isTrue);
      expect(notifier.isFavorited(100), isTrue);
      expect(mockSocial.addFavoriteCalls, 1);

      // Toggle favorite OFF
      final futureOff = notifier.toggleFavorite(
        itineraryId: 100,
        token: 'token',
        socialRepository: mockSocial,
      );

      expect(notifier.isFavorited(100), isFalse);
      final nextFavOff = await futureOff;
      expect(nextFavOff, isFalse);
      expect(notifier.isFavorited(100), isFalse);
      expect(mockSocial.removeFavoriteCalls, 1);
    });

    test('Rolls back favorite state when API call fails', () async {
      final mockSocial = MockSocialRepository()..shouldThrow = true;
      final notifier = ExploreNotifier();

      expect(notifier.isFavorited(200), isFalse);

      await expectLater(
        () => notifier.toggleFavorite(
          itineraryId: 200,
          token: 'token',
          socialRepository: mockSocial,
        ),
        throwsA(isA<ApiException>()),
      );

      // Rolled back to false
      expect(notifier.isFavorited(200), isFalse);
    });

    test('Loads user favorites from CollectionRepository', () async {
      final mockCollection = MockCollectionRepository();
      mockCollection.favorites = [
        makeSummary(id: 301),
        makeSummary(id: 302),
      ];

      final notifier = ExploreNotifier();
      await notifier.loadUserFavorites(
        token: 'test_token',
        collectionRepository: mockCollection,
      );

      expect(notifier.isFavorited(301), isTrue);
      expect(notifier.isFavorited(302), isTrue);
      expect(notifier.isFavorited(303), isFalse);
    });
  });
}
