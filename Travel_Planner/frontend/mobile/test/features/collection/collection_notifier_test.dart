import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/collection/data/collection_repository.dart';
import 'package:mobile/features/collection/presentation/collection_notifier.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/social/data/models/social_state_update.dart';

class FakeCollectionRepository extends CollectionRepository {
  List<ItinerarySummary> savedResponse = [];
  List<ItinerarySummary> favoriteResponse = [];
  bool hasMoreSaved = false;
  bool hasMoreFavorite = false;
  bool shouldThrow = false;
  int removeSavedCallCount = 0;
  int removeFavoriteCallCount = 0;

  @override
  Future<PageResult<ItinerarySummary>> getSavedItineraries({
    int page = 0,
    int size = 10,
    String? token,
  }) async {
    if (shouldThrow) {
      throw ApiException(message: 'Network failure', statusCode: 500);
    }
    return PageResult<ItinerarySummary>(
      content: savedResponse,
      pageNumber: page,
      pageSize: size,
      totalElements: savedResponse.length,
      totalPages: hasMoreSaved ? page + 2 : page + 1,
      isLast: !hasMoreSaved,
    );
  }

  @override
  Future<PageResult<ItinerarySummary>> getFavoriteItineraries({
    int page = 0,
    int size = 10,
    String? token,
  }) async {
    if (shouldThrow) {
      throw ApiException(message: 'Network failure', statusCode: 500);
    }
    return PageResult<ItinerarySummary>(
      content: favoriteResponse,
      pageNumber: page,
      pageSize: size,
      totalElements: favoriteResponse.length,
      totalPages: hasMoreFavorite ? page + 2 : page + 1,
      isLast: !hasMoreFavorite,
    );
  }

  @override
  Future<void> removeSavedItinerary(int itineraryId, {String? token}) async {
    if (shouldThrow) {
      throw ApiException(message: 'Failed to remove saved', statusCode: 400);
    }
    removeSavedCallCount++;
  }

  @override
  Future<void> removeFavorite(int itineraryId, {String? token}) async {
    if (shouldThrow) {
      throw ApiException(message: 'Failed to remove favorite', statusCode: 400);
    }
    removeFavoriteCallCount++;
  }
}

ItinerarySummary createSummary({
  required int id,
  required String title,
  int favoriteCount = 0,
  int ratingCount = 0,
  double averageRating = 0.0,
}) {
  return ItinerarySummary(
    itineraryId: id,
    title: title,
    location: 'Việt Nam',
    totalDays: 3,
    budget: 1000000,
    viewCount: 10,
    favoriteCount: favoriteCount,
    ratingCount: ratingCount,
    averageRating: averageRating,
  );
}

void main() {
  late FakeCollectionRepository repository;
  late CollectionNotifier notifier;

  setUp(() {
    repository = FakeCollectionRepository();
    notifier = CollectionNotifier(repository: repository);
  });

  group('CollectionNotifier - Saved Itineraries', () {
    test('loadInitialSaved loads data and deduplicates self', () async {
      repository.savedResponse = [
        createSummary(id: 1, title: 'Trip 1'),
        createSummary(id: 1, title: 'Trip 1 duplicate'),
        createSummary(id: 2, title: 'Trip 2'),
      ];
      repository.hasMoreSaved = true;

      await notifier.loadInitialSaved();

      expect(notifier.savedState.isLoading, isFalse);
      expect(notifier.savedState.error, isNull);
      expect(notifier.savedState.items.length, equals(2));
      expect(notifier.savedState.hasMore, isTrue);
    });

    test('loadMoreSaved deduplicates with existing items', () async {
      repository.savedResponse = [createSummary(id: 1, title: 'Trip 1')];
      repository.hasMoreSaved = true;
      await notifier.loadInitialSaved();

      repository.savedResponse = [
        createSummary(id: 1, title: 'Trip 1 dup'),
        createSummary(id: 2, title: 'Trip 2'),
      ];
      repository.hasMoreSaved = false;
      await notifier.loadMoreSaved();

      expect(notifier.savedState.items.length, equals(2));
      expect(notifier.savedState.items[1].itineraryId, equals(2));
      expect(notifier.savedState.hasMore, isFalse);
    });

    test('loadMoreSaved failure preserves existing items', () async {
      repository.savedResponse = [createSummary(id: 1, title: 'Trip 1')];
      repository.hasMoreSaved = true;
      await notifier.loadInitialSaved();

      repository.shouldThrow = true;
      await notifier.loadMoreSaved();

      expect(notifier.savedState.items.length, equals(1));
      expect(notifier.savedState.items.first.itineraryId, equals(1));
      expect(notifier.savedState.isLoadingMore, isFalse);
      expect(notifier.savedState.error, isNotNull);
    });

    test('removeSaved removes item from state on success', () async {
      repository.savedResponse = [
        createSummary(id: 1, title: 'Trip 1'),
        createSummary(id: 2, title: 'Trip 2'),
      ];
      await notifier.loadInitialSaved();

      await notifier.removeSaved(1);

      expect(repository.removeSavedCallCount, equals(1));
      expect(notifier.savedState.items.length, equals(1));
      expect(notifier.savedState.items.first.itineraryId, equals(2));
    });
  });

  group('CollectionNotifier - Favorite Itineraries', () {
    test('loadInitialFavorite loads data successfully', () async {
      repository.favoriteResponse = [createSummary(id: 10, title: 'Fav 10')];
      repository.hasMoreFavorite = false;

      await notifier.loadInitialFavorite();

      expect(notifier.favoriteState.isLoading, isFalse);
      expect(notifier.favoriteState.items.length, equals(1));
      expect(notifier.favoriteState.items.first.itineraryId, equals(10));
    });

    test('removeFavorite removes item from state on success', () async {
      repository.favoriteResponse = [
        createSummary(id: 10, title: 'Fav 10'),
        createSummary(id: 20, title: 'Fav 20'),
      ];
      await notifier.loadInitialFavorite();

      await notifier.removeFavorite(10);

      expect(repository.removeFavoriteCallCount, equals(1));
      expect(notifier.favoriteState.items.length, equals(1));
      expect(notifier.favoriteState.items.first.itineraryId, equals(20));
    });
  });

  group('CollectionNotifier - Social State Sync', () {
    test('applySocialUpdate unsaved and unfavorited updates both lists', () async {
      repository.savedResponse = [createSummary(id: 1, title: 'Trip 1')];
      repository.favoriteResponse = [createSummary(id: 1, title: 'Trip 1')];

      await notifier.loadInitialSaved();
      await notifier.loadInitialFavorite();

      expect(notifier.savedState.items.length, equals(1));
      expect(notifier.favoriteState.items.length, equals(1));

      notifier.applySocialUpdate(const SocialStateUpdate(
        itineraryId: 1,
        isSaved: false,
        isFavorited: false,
      ));

      expect(notifier.savedState.items.isEmpty, isTrue);
      expect(notifier.favoriteState.items.isEmpty, isTrue);
    });

    test('applySocialUpdate updates rating and favorite count in memory', () async {
      repository.savedResponse = [createSummary(id: 5, title: 'Trip 5', favoriteCount: 2)];
      await notifier.loadInitialSaved();

      notifier.applySocialUpdate(const SocialStateUpdate(
        itineraryId: 5,
        favoriteCount: 10,
        averageRating: 4.8,
        ratingCount: 15,
      ));

      final updated = notifier.savedState.items.first;
      expect(updated.favoriteCount, equals(10));
      expect(updated.averageRating, equals(4.8));
      expect(updated.ratingCount, equals(15));
    });
  });
}
