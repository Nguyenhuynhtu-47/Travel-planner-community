import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/explore_repository.dart';
import '../data/models/itinerary_summary.dart';
import '../../social/data/social_repository.dart';
import '../../collection/data/collection_repository.dart';
import '../../social/data/models/social_state_update.dart';

enum ExploreStatus { initial, loading, success, error }

enum SectionStatus { initial, loading, success, error }

enum HomeSectionType { featured, recommended, topRated, popular, recent }

class SectionState<T> {
  final SectionStatus status;
  final List<T> items;
  final String? errorMessage;

  const SectionState({
    this.status = SectionStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  bool get isLoading => status == SectionStatus.loading;
  bool get isSuccess => status == SectionStatus.success;
  bool get isError => status == SectionStatus.error;
  bool get isEmpty => isSuccess && items.isEmpty;

  SectionState<T> copyWith({
    SectionStatus? status,
    List<T>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SectionState<T>(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ExploreFilter {
  final String? location;
  final String? theme;
  final double? minBudget;
  final double? maxBudget;
  final int? minDays;
  final int? maxDays;
  final double? minRating;

  const ExploreFilter({
    this.location,
    this.theme,
    this.minBudget,
    this.maxBudget,
    this.minDays,
    this.maxDays,
    this.minRating,
  });

  bool get isEmpty =>
      (location == null || location!.trim().isEmpty) &&
      (theme == null || theme!.trim().isEmpty) &&
      minBudget == null &&
      maxBudget == null &&
      minDays == null &&
      maxDays == null &&
      minRating == null;

  int get activeFilterCount {
    int count = 0;
    if (location != null && location!.trim().isNotEmpty) count++;
    if (theme != null && theme!.trim().isNotEmpty) count++;
    if (minBudget != null || maxBudget != null) count++;
    if (minDays != null || maxDays != null) count++;
    if (minRating != null) count++;
    return count;
  }

  ExploreFilter copyWith({
    String? location,
    String? theme,
    double? minBudget,
    double? maxBudget,
    int? minDays,
    int? maxDays,
    double? minRating,
    bool clearLocation = false,
    bool clearTheme = false,
    bool clearBudget = false,
    bool clearDays = false,
    bool clearRating = false,
  }) {
    return ExploreFilter(
      location: clearLocation ? null : (location ?? this.location),
      theme: clearTheme ? null : (theme ?? this.theme),
      minBudget: clearBudget ? null : (minBudget ?? this.minBudget),
      maxBudget: clearBudget ? null : (maxBudget ?? this.maxBudget),
      minDays: clearDays ? null : (minDays ?? this.minDays),
      maxDays: clearDays ? null : (maxDays ?? this.maxDays),
      minRating: clearRating ? null : (minRating ?? this.minRating),
    );
  }
}

class ExploreNotifier extends ChangeNotifier {
  final ExploreRepository _repository;

  ExploreStatus _status = ExploreStatus.initial;
  List<ItinerarySummary> _itineraries = [];
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  bool _isLastPage = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  String _searchKeyword = '';
  String _sort = 'createdAt,desc';
  ExploreFilter _filter = const ExploreFilter();
  bool _isViewingAll = false;
  HomeSectionType? _viewingAllSection;

  int _requestId = 0;

  // Section States for Homepage
  SectionState<ItinerarySummary> _featuredSection = const SectionState();
  SectionState<ItinerarySummary> _recommendedSection = const SectionState();
  SectionState<ItinerarySummary> _topRatedSection = const SectionState();
  SectionState<ItinerarySummary> _popularSection = const SectionState();
  SectionState<ItinerarySummary> _recentSection = const SectionState();

  // Favorited itinerary IDs for active user
  final Set<int> _favoritedItineraryIds = {};
  final Set<int> _inFlightFavoriteIds = {};

  ExploreNotifier({ExploreRepository? repository})
    : _repository = repository ?? ExploreRepository();

  ExploreStatus get status => _status;
  bool get isLoading => _status == ExploreStatus.loading;
  bool get isSuccess => _status == ExploreStatus.success;
  bool get isError => _status == ExploreStatus.error;
  bool get isLoadingMore => _isLoadingMore;
  List<ItinerarySummary> get itineraries => List.unmodifiable(_itineraries);
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalElements => _totalElements;
  bool get isLastPage => _isLastPage;
  String? get errorMessage => _errorMessage;
  String get searchKeyword => _searchKeyword;
  String get sort => _sort;
  ExploreFilter get filter => _filter;
  bool get isViewingAll => _isViewingAll;
  HomeSectionType? get viewingAllSection => _viewingAllSection;

  SectionState<ItinerarySummary> get featuredSection => _featuredSection;
  SectionState<ItinerarySummary> get recommendedSection => _recommendedSection;
  SectionState<ItinerarySummary> get topRatedSection => _topRatedSection;
  SectionState<ItinerarySummary> get popularSection => _popularSection;
  SectionState<ItinerarySummary> get recentSection => _recentSection;

  Set<int> get favoritedItineraryIds => Set.unmodifiable(_favoritedItineraryIds);
  bool isFavorited(int itineraryId) => _favoritedItineraryIds.contains(itineraryId);
  bool isFavoriteLoading(int itineraryId) => _inFlightFavoriteIds.contains(itineraryId);

  bool get isSearchOrFilterActive =>
      _searchKeyword.isNotEmpty || !_filter.isEmpty || _isViewingAll;

  bool get isEmptyResults =>
      _status == ExploreStatus.success && _itineraries.isEmpty;

  Future<void> loadInitialItineraries({String? token}) async {
    await Future.wait([
      fetchItineraries(resetPage: true, token: token),
      loadHomeSections(token: token),
    ]);
  }

  Future<void> refreshAll({String? token}) async {
    await Future.wait([
      fetchItineraries(resetPage: true, token: token),
      loadHomeSections(token: token),
    ]);
  }

  Future<void> loadHomeSections({String? token}) async {
    _featuredSection = _featuredSection.copyWith(
      status: SectionStatus.loading,
      clearError: true,
    );
    _recommendedSection = _recommendedSection.copyWith(
      status: SectionStatus.loading,
      clearError: true,
    );
    _topRatedSection = _topRatedSection.copyWith(
      status: SectionStatus.loading,
      clearError: true,
    );
    _popularSection = _popularSection.copyWith(
      status: SectionStatus.loading,
      clearError: true,
    );
    _recentSection = _recentSection.copyWith(
      status: SectionStatus.loading,
      clearError: true,
    );
    notifyListeners();

    await Future.wait([
      _loadFeaturedSection(token: token),
      _loadRecommendedSection(token: token),
      _loadTopRatedSection(token: token),
      _loadPopularSection(token: token),
      _loadRecentSection(token: token),
      loadUserFavorites(token: token),
    ]);
  }

  Future<void> retrySection(HomeSectionType type, {String? token}) async {
    switch (type) {
      case HomeSectionType.featured:
        _featuredSection = _featuredSection.copyWith(
          status: SectionStatus.loading,
          clearError: true,
        );
        notifyListeners();
        await _loadFeaturedSection(token: token);
      case HomeSectionType.recommended:
        _recommendedSection = _recommendedSection.copyWith(
          status: SectionStatus.loading,
          clearError: true,
        );
        notifyListeners();
        await _loadRecommendedSection(token: token);
      case HomeSectionType.topRated:
        _topRatedSection = _topRatedSection.copyWith(
          status: SectionStatus.loading,
          clearError: true,
        );
        notifyListeners();
        await _loadTopRatedSection(token: token);
      case HomeSectionType.popular:
        _popularSection = _popularSection.copyWith(
          status: SectionStatus.loading,
          clearError: true,
        );
        notifyListeners();
        await _loadPopularSection(token: token);
      case HomeSectionType.recent:
        _recentSection = _recentSection.copyWith(
          status: SectionStatus.loading,
          clearError: true,
        );
        notifyListeners();
        await _loadRecentSection(token: token);
    }
  }

  Future<void> _loadFeaturedSection({String? token}) async {
    try {
      final res = await _repository.getPublicItineraries(
        sort: 'viewCount,desc',
        size: 6,
        token: token,
      );
      _featuredSection = SectionState(
        status: SectionStatus.success,
        items: res.content,
      );
    } catch (_) {
      _featuredSection = const SectionState(
        status: SectionStatus.error,
        errorMessage: 'Không thể tải lịch trình nổi bật.',
      );
    }
    notifyListeners();
  }

  Future<void> _loadRecommendedSection({String? token}) async {
    try {
      final res = await _repository.getRecommendations(
        page: 0,
        size: 6,
        token: token,
      );
      _recommendedSection = SectionState(
        status: SectionStatus.success,
        items: res.content,
      );
    } catch (_) {
      _recommendedSection = const SectionState(
        status: SectionStatus.error,
        errorMessage: 'Không thể tải lịch trình gợi ý.',
      );
    }
    notifyListeners();
  }

  Future<void> _loadTopRatedSection({String? token}) async {
    try {
      var res = await _repository.getPublicItineraries(
        minRating: 4.0,
        sort: 'rating,desc',
        size: 6,
        token: token,
      );
      if (res.content.isEmpty) {
        res = await _repository.getPublicItineraries(
          sort: 'rating,desc',
          size: 6,
          token: token,
        );
      }
      final sorted = List<ItinerarySummary>.from(res.content);
      sorted.sort((a, b) {
        final rateCmp = b.averageRating.compareTo(a.averageRating);
        if (rateCmp != 0) return rateCmp;
        return b.ratingCount.compareTo(a.ratingCount);
      });
      _topRatedSection = SectionState(
        status: SectionStatus.success,
        items: sorted,
      );
    } catch (_) {
      _topRatedSection = const SectionState(
        status: SectionStatus.error,
        errorMessage: 'Không thể tải lịch trình đánh giá cao.',
      );
    }
    notifyListeners();
  }

  Future<void> _loadPopularSection({String? token}) async {
    try {
      final res = await _repository.getPublicItineraries(
        sort: 'favoriteCount,desc',
        size: 6,
        token: token,
      );
      _popularSection = SectionState(
        status: SectionStatus.success,
        items: res.content,
      );
    } catch (_) {
      _popularSection = const SectionState(
        status: SectionStatus.error,
        errorMessage: 'Không thể tải lịch trình phổ biến.',
      );
    }
    notifyListeners();
  }

  Future<void> _loadRecentSection({String? token}) async {
    try {
      final res = await _repository.getPublicItineraries(
        sort: 'createdAt,desc',
        size: 6,
        token: token,
      );
      _recentSection = SectionState(
        status: SectionStatus.success,
        items: res.content,
      );
    } catch (_) {
      _recentSection = const SectionState(
        status: SectionStatus.error,
        errorMessage: 'Không thể tải lịch trình mới nhất.',
      );
    }
    notifyListeners();
  }

  void showAllForSection(HomeSectionType type, {String? token}) {
    _isViewingAll = true;
    _viewingAllSection = type;
    _currentPage = 0;
    _searchKeyword = '';
    switch (type) {
      case HomeSectionType.featured:
        _filter = const ExploreFilter();
        _sort = 'viewCount,desc';
      case HomeSectionType.recommended:
        _filter = const ExploreFilter();
        _sort = 'favoriteCount,desc';
      case HomeSectionType.topRated:
        _filter = const ExploreFilter(minRating: 4.0);
        _sort = 'rating,desc';
      case HomeSectionType.popular:
        _filter = const ExploreFilter();
        _sort = 'favoriteCount,desc';
      case HomeSectionType.recent:
        _filter = const ExploreFilter();
        _sort = 'createdAt,desc';
    }
    fetchItineraries(resetPage: true, token: token);
  }

  void closeViewingAll({String? token}) {
    _isViewingAll = false;
    _viewingAllSection = null;
    _searchKeyword = '';
    _filter = const ExploreFilter();
    _sort = 'createdAt,desc';
    loadHomeSections(token: token);
    fetchItineraries(resetPage: true, token: token);
  }

  Future<void> fetchItineraries({bool resetPage = true, String? token}) async {
    final currentRequestId = ++_requestId;

    if (resetPage) {
      _currentPage = 0;
      _isLastPage = false;
      _status = ExploreStatus.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final pageResult = await _repository.getPublicItineraries(
        keyword: _searchKeyword.isEmpty ? null : _searchKeyword,
        location: _filter.location,
        theme: _filter.theme,
        minBudget: _filter.minBudget,
        maxBudget: _filter.maxBudget,
        minDays: _filter.minDays,
        maxDays: _filter.maxDays,
        minRating: _filter.minRating,
        page: _currentPage,
        size: 10,
        sort: _sort,
        token: token,
      );

      if (currentRequestId != _requestId) return;

      _itineraries = pageResult.content;
      _currentPage = pageResult.pageNumber;
      _totalPages = pageResult.totalPages;
      _totalElements = pageResult.totalElements;
      _isLastPage = pageResult.isLast || (_currentPage + 1 >= _totalPages);
      _status = ExploreStatus.success;
      _errorMessage = null;
    } on ApiException catch (e) {
      if (currentRequestId != _requestId) return;
      _status = ExploreStatus.error;
      _errorMessage = e.message;
    } catch (_) {
      if (currentRequestId != _requestId) return;
      _status = ExploreStatus.error;
      _errorMessage =
          'Không thể tải danh sách lịch trình. Vui lòng kiểm tra kết nối mạng.';
    } finally {
      if (currentRequestId == _requestId) {
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({String? token}) async {
    if (_isLoadingMore || _isLastPage || _status == ExploreStatus.loading) {
      return;
    }

    final currentRequestId = _requestId;
    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _currentPage + 1;

    try {
      final pageResult = await _repository.getPublicItineraries(
        keyword: _searchKeyword.isEmpty ? null : _searchKeyword,
        location: _filter.location,
        theme: _filter.theme,
        minBudget: _filter.minBudget,
        maxBudget: _filter.maxBudget,
        minDays: _filter.minDays,
        maxDays: _filter.maxDays,
        minRating: _filter.minRating,
        page: nextPage,
        size: 10,
        sort: _sort,
        token: token,
      );

      if (currentRequestId != _requestId) return;

      _itineraries = [..._itineraries, ...pageResult.content];
      _currentPage = pageResult.pageNumber;
      _totalPages = pageResult.totalPages;
      _totalElements = pageResult.totalElements;
      _isLastPage = pageResult.isLast || (_currentPage + 1 >= _totalPages);
    } catch (_) {
      // Retain existing items if load-more encounters error
    } finally {
      if (currentRequestId == _requestId) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void search(String keyword, {String? token}) {
    final trimmed = keyword.trim();
    if (_searchKeyword == trimmed && _status == ExploreStatus.success) return;

    _searchKeyword = trimmed;
    _isViewingAll = trimmed.isNotEmpty;
    fetchItineraries(resetPage: true, token: token);
  }

  void applyFilter(ExploreFilter newFilter, {String? token}) {
    _filter = newFilter;
    _isViewingAll = !newFilter.isEmpty;
    fetchItineraries(resetPage: true, token: token);
  }

  void setSort(String newSort, {String? token}) {
    if (_sort == newSort) return;
    _sort = newSort;
    fetchItineraries(resetPage: true, token: token);
  }

  void setQuickTheme(String? theme, {String? token}) {
    if (theme == null) {
      if (_filter.theme == null) return;
      _filter = _filter.copyWith(clearTheme: true);
    } else if (_filter.theme == theme) {
      _filter = _filter.copyWith(clearTheme: true);
    } else {
      _filter = _filter.copyWith(theme: theme);
      _isViewingAll = true;
    }
    fetchItineraries(resetPage: true, token: token);
  }

  void resetAllFilters({String? token}) {
    _searchKeyword = '';
    _filter = const ExploreFilter();
    _sort = 'createdAt,desc';
    _isViewingAll = false;
    loadHomeSections(token: token);
    fetchItineraries(resetPage: true, token: token);
  }

  void retry({String? token}) {
    fetchItineraries(resetPage: _itineraries.isEmpty, token: token);
    loadHomeSections(token: token);
  }

  Future<void> loadUserFavorites({
    String? token,
    CollectionRepository? collectionRepository,
  }) async {
    if (token == null || token.isEmpty) {
      if (_favoritedItineraryIds.isNotEmpty) {
        _favoritedItineraryIds.clear();
        notifyListeners();
      }
      return;
    }

    final repo = collectionRepository ?? CollectionRepository();
    try {
      final page = await repo.getFavoriteItineraries(
        page: 0,
        size: 100,
        token: token,
      );
      _favoritedItineraryIds.clear();
      for (final item in page.content) {
        _favoritedItineraryIds.add(item.itineraryId);
      }
      notifyListeners();
    } catch (_) {
      // Non-blocking: retain existing favorites
    }
  }

  Future<bool> toggleFavorite({
    required int itineraryId,
    required String? token,
    SocialRepository? socialRepository,
  }) async {
    if (_inFlightFavoriteIds.contains(itineraryId)) {
      return isFavorited(itineraryId);
    }
    _inFlightFavoriteIds.add(itineraryId);

    final wasFavorited = _favoritedItineraryIds.contains(itineraryId);
    final nextFavorited = !wasFavorited;

    // Optimistic update
    if (nextFavorited) {
      _favoritedItineraryIds.add(itineraryId);
      _updateItemFavoriteCount(itineraryId, 1);
    } else {
      _favoritedItineraryIds.remove(itineraryId);
      _updateItemFavoriteCount(itineraryId, -1);
    }
    notifyListeners();

    final repo = socialRepository ?? SocialRepository();
    try {
      if (nextFavorited) {
        await repo.addFavorite(itineraryId, token: token);
      } else {
        await repo.removeFavorite(itineraryId, token: token);
      }
      return nextFavorited;
    } catch (e) {
      // Rollback optimistic update on error
      if (nextFavorited) {
        _favoritedItineraryIds.remove(itineraryId);
        _updateItemFavoriteCount(itineraryId, -1);
      } else {
        _favoritedItineraryIds.add(itineraryId);
        _updateItemFavoriteCount(itineraryId, 1);
      }
      notifyListeners();
      rethrow;
    } finally {
      _inFlightFavoriteIds.remove(itineraryId);
      notifyListeners();
    }
  }

  void _updateItemFavoriteCount(int itineraryId, int delta) {
    ItinerarySummary updateSummary(ItinerarySummary item) {
      if (item.itineraryId != itineraryId) return item;
      final newCount = (item.favoriteCount + delta).clamp(0, 999999);
      return item.copyWith(favoriteCount: newCount);
    }

    _itineraries = _itineraries.map(updateSummary).toList();
    if (_featuredSection.items.isNotEmpty) {
      _featuredSection = _featuredSection.copyWith(
        items: _featuredSection.items.map(updateSummary).toList(),
      );
    }
    if (_recommendedSection.items.isNotEmpty) {
      _recommendedSection = _recommendedSection.copyWith(
        items: _recommendedSection.items.map(updateSummary).toList(),
      );
    }
    if (_topRatedSection.items.isNotEmpty) {
      _topRatedSection = _topRatedSection.copyWith(
        items: _topRatedSection.items.map(updateSummary).toList(),
      );
    }
    if (_popularSection.items.isNotEmpty) {
      _popularSection = _popularSection.copyWith(
        items: _popularSection.items.map(updateSummary).toList(),
      );
    }
    if (_recentSection.items.isNotEmpty) {
      _recentSection = _recentSection.copyWith(
        items: _recentSection.items.map(updateSummary).toList(),
      );
    }
  }

  void applySocialUpdate(SocialStateUpdate update) {
    bool changed = false;

    if (update.isFavorited != null) {
      if (update.isFavorited == true && !_favoritedItineraryIds.contains(update.itineraryId)) {
        _favoritedItineraryIds.add(update.itineraryId);
        _updateItemFavoriteCount(update.itineraryId, 1);
        changed = true;
      } else if (update.isFavorited == false && _favoritedItineraryIds.contains(update.itineraryId)) {
        _favoritedItineraryIds.remove(update.itineraryId);
        _updateItemFavoriteCount(update.itineraryId, -1);
        changed = true;
      }
    }

    if (update.favoriteCount != null || update.averageRating != null || update.ratingCount != null) {
      ItinerarySummary syncItem(ItinerarySummary item) {
        if (item.itineraryId != update.itineraryId) return item;
        changed = true;
        return item.copyWith(
          favoriteCount: update.favoriteCount ?? item.favoriteCount,
          averageRating: update.averageRating ?? item.averageRating,
          ratingCount: update.ratingCount ?? item.ratingCount,
        );
      }

      _itineraries = _itineraries.map(syncItem).toList();
      if (_featuredSection.items.isNotEmpty) {
        _featuredSection = _featuredSection.copyWith(
          items: _featuredSection.items.map(syncItem).toList(),
        );
      }
      if (_recommendedSection.items.isNotEmpty) {
        _recommendedSection = _recommendedSection.copyWith(
          items: _recommendedSection.items.map(syncItem).toList(),
        );
      }
      if (_topRatedSection.items.isNotEmpty) {
        _topRatedSection = _topRatedSection.copyWith(
          items: _topRatedSection.items.map(syncItem).toList(),
        );
      }
      if (_popularSection.items.isNotEmpty) {
        _popularSection = _popularSection.copyWith(
          items: _popularSection.items.map(syncItem).toList(),
        );
      }
      if (_recentSection.items.isNotEmpty) {
        _recentSection = _recentSection.copyWith(
          items: _recentSection.items.map(syncItem).toList(),
        );
      }
    }

    if (changed) {
      notifyListeners();
    }
  }
}
