import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../explore/data/models/itinerary_summary.dart';
import '../data/collection_repository.dart';
import '../../social/data/models/social_state_update.dart';

class SubListState {
  final List<ItinerarySummary> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  const SubListState({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  SubListState copyWith({
    List<ItinerarySummary>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return SubListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CollectionNotifier extends ChangeNotifier {
  final CollectionRepository _repository;

  SubListState _savedState = const SubListState();
  SubListState _favoriteState = const SubListState();

  int _savedGeneration = 0;
  int _favoriteGeneration = 0;

  SubListState get savedState => _savedState;
  SubListState get favoriteState => _favoriteState;

  CollectionNotifier({CollectionRepository? repository})
      : _repository = repository ?? CollectionRepository();

  // Deduplication helper
  List<ItinerarySummary> _deduplicate(
    List<ItinerarySummary> current,
    List<ItinerarySummary> incoming,
  ) {
    final seenIds = <int>{};
    for (final item in current) {
      seenIds.add(item.itineraryId);
    }
    final result = List<ItinerarySummary>.from(current);
    for (final item in incoming) {
      if (!seenIds.contains(item.itineraryId)) {
        seenIds.add(item.itineraryId);
        result.add(item);
      }
    }
    return result;
  }

  // Deduplicate incoming list in itself
  List<ItinerarySummary> _deduplicateSelf(List<ItinerarySummary> items) {
    final seenIds = <int>{};
    final result = <ItinerarySummary>[];
    for (final item in items) {
      if (!seenIds.contains(item.itineraryId)) {
        seenIds.add(item.itineraryId);
        result.add(item);
      }
    }
    return result;
  }

  // ================= SAVED ITINERARIES =================

  Future<void> loadInitialSaved({String? token}) async {
    final gen = ++_savedGeneration;
    _savedState = _savedState.copyWith(
      isLoading: true,
      clearError: true,
    );
    notifyListeners();

    try {
      final pageResult = await _repository.getSavedItineraries(
        page: 0,
        size: 10,
        token: token,
      );

      if (gen != _savedGeneration) return;

      final uniqueItems = _deduplicateSelf(pageResult.content);
      _savedState = SubListState(
        items: uniqueItems,
        page: pageResult.pageNumber,
        hasMore: pageResult.hasMore,
        isLoading: false,
        isLoadingMore: false,
        error: null,
      );
    } on ApiException catch (e) {
      if (gen != _savedGeneration) return;
      _savedState = _savedState.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (_) {
      if (gen != _savedGeneration) return;
      _savedState = _savedState.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách lịch trình đã lưu. Vui lòng thử lại.',
      );
    } finally {
      if (gen == _savedGeneration) {
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSaved({String? token}) async {
    if (_savedState.isLoading || _savedState.isLoadingMore || !_savedState.hasMore) {
      return;
    }

    final gen = _savedGeneration;
    final nextPage = _savedState.page + 1;

    _savedState = _savedState.copyWith(
      isLoadingMore: true,
      clearError: true,
    );
    notifyListeners();

    try {
      final pageResult = await _repository.getSavedItineraries(
        page: nextPage,
        size: 10,
        token: token,
      );

      if (gen != _savedGeneration) return;

      final mergedItems = _deduplicate(_savedState.items, pageResult.content);
      _savedState = _savedState.copyWith(
        items: mergedItems,
        page: pageResult.pageNumber,
        hasMore: pageResult.hasMore,
        isLoadingMore: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      if (gen != _savedGeneration) return;
      // Preserve existing items
      _savedState = _savedState.copyWith(
        isLoadingMore: false,
        error: e.message,
      );
    } catch (_) {
      if (gen != _savedGeneration) return;
      _savedState = _savedState.copyWith(
        isLoadingMore: false,
        error: 'Lỗi khi tải thêm lịch trình đã lưu.',
      );
    } finally {
      if (gen == _savedGeneration) {
        notifyListeners();
      }
    }
  }

  Future<void> refreshSaved({String? token}) async {
    await loadInitialSaved(token: token);
  }

  Future<void> removeSaved(int itineraryId, {String? token}) async {
    await _repository.removeSavedItinerary(itineraryId, token: token);
    _savedState = _savedState.copyWith(
      items: _savedState.items.where((i) => i.itineraryId != itineraryId).toList(),
    );
    notifyListeners();
  }

  // ================= FAVORITE ITINERARIES =================

  Future<void> loadInitialFavorite({String? token}) async {
    final gen = ++_favoriteGeneration;
    _favoriteState = _favoriteState.copyWith(
      isLoading: true,
      clearError: true,
    );
    notifyListeners();

    try {
      final pageResult = await _repository.getFavoriteItineraries(
        page: 0,
        size: 10,
        token: token,
      );

      if (gen != _favoriteGeneration) return;

      final uniqueItems = _deduplicateSelf(pageResult.content);
      _favoriteState = SubListState(
        items: uniqueItems,
        page: pageResult.pageNumber,
        hasMore: pageResult.hasMore,
        isLoading: false,
        isLoadingMore: false,
        error: null,
      );
    } on ApiException catch (e) {
      if (gen != _favoriteGeneration) return;
      _favoriteState = _favoriteState.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (_) {
      if (gen != _favoriteGeneration) return;
      _favoriteState = _favoriteState.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách lịch trình yêu thích. Vui lòng thử lại.',
      );
    } finally {
      if (gen == _favoriteGeneration) {
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreFavorite({String? token}) async {
    if (_favoriteState.isLoading || _favoriteState.isLoadingMore || !_favoriteState.hasMore) {
      return;
    }

    final gen = _favoriteGeneration;
    final nextPage = _favoriteState.page + 1;

    _favoriteState = _favoriteState.copyWith(
      isLoadingMore: true,
      clearError: true,
    );
    notifyListeners();

    try {
      final pageResult = await _repository.getFavoriteItineraries(
        page: nextPage,
        size: 10,
        token: token,
      );

      if (gen != _favoriteGeneration) return;

      final mergedItems = _deduplicate(_favoriteState.items, pageResult.content);
      _favoriteState = _favoriteState.copyWith(
        items: mergedItems,
        page: pageResult.pageNumber,
        hasMore: pageResult.hasMore,
        isLoadingMore: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      if (gen != _favoriteGeneration) return;
      _favoriteState = _favoriteState.copyWith(
        isLoadingMore: false,
        error: e.message,
      );
    } catch (_) {
      if (gen != _favoriteGeneration) return;
      _favoriteState = _favoriteState.copyWith(
        isLoadingMore: false,
        error: 'Lỗi khi tải thêm lịch trình yêu thích.',
      );
    } finally {
      if (gen == _favoriteGeneration) {
        notifyListeners();
      }
    }
  }

  Future<void> refreshFavorite({String? token}) async {
    await loadInitialFavorite(token: token);
  }

  Future<void> removeFavorite(int itineraryId, {String? token}) async {
    await _repository.removeFavorite(itineraryId, token: token);
    _favoriteState = _favoriteState.copyWith(
      items: _favoriteState.items.where((i) => i.itineraryId != itineraryId).toList(),
    );
    notifyListeners();
  }

  // ================= STATE SYNCHRONIZATION =================

  void applySocialUpdate(SocialStateUpdate update) {
    bool changed = false;

    if (update.isSaved == false) {
      final initialCount = _savedState.items.length;
      final newSaved = _savedState.items.where((i) => i.itineraryId != update.itineraryId).toList();
      if (newSaved.length != initialCount) {
        _savedState = _savedState.copyWith(items: newSaved);
        changed = true;
      }
    }

    if (update.isFavorited == false) {
      final initialCount = _favoriteState.items.length;
      final newFav = _favoriteState.items.where((i) => i.itineraryId != update.itineraryId).toList();
      if (newFav.length != initialCount) {
        _favoriteState = _favoriteState.copyWith(items: newFav);
        changed = true;
      }
    }

    // Update metadata (favoriteCount, averageRating, ratingCount) if items exist
    if (update.favoriteCount != null || update.averageRating != null || update.ratingCount != null) {
      final updatedSaved = _savedState.items.map((item) {
        if (item.itineraryId == update.itineraryId) {
          return item.copyWith(
            favoriteCount: update.favoriteCount ?? item.favoriteCount,
            averageRating: update.averageRating ?? item.averageRating,
            ratingCount: update.ratingCount ?? item.ratingCount,
          );
        }
        return item;
      }).toList();

      final updatedFav = _favoriteState.items.map((item) {
        if (item.itineraryId == update.itineraryId) {
          return item.copyWith(
            favoriteCount: update.favoriteCount ?? item.favoriteCount,
            averageRating: update.averageRating ?? item.averageRating,
            ratingCount: update.ratingCount ?? item.ratingCount,
          );
        }
        return item;
      }).toList();

      _savedState = _savedState.copyWith(items: updatedSaved);
      _favoriteState = _favoriteState.copyWith(items: updatedFav);
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }
}

