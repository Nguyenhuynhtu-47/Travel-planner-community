import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/explore_repository.dart';
import '../data/models/itinerary_summary.dart';

enum ExploreStatus { initial, loading, success, error }

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

  int _requestId = 0;

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

  bool get isEmptyResults =>
      _status == ExploreStatus.success && _itineraries.isEmpty;

  Future<void> loadInitialItineraries({String? token}) async {
    await fetchItineraries(resetPage: true, token: token);
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
    fetchItineraries(resetPage: true, token: token);
  }

  void applyFilter(ExploreFilter newFilter, {String? token}) {
    _filter = newFilter;
    fetchItineraries(resetPage: true, token: token);
  }

  void setSort(String newSort, {String? token}) {
    if (_sort == newSort) return;
    _sort = newSort;
    fetchItineraries(resetPage: true, token: token);
  }

  void setQuickTheme(String? theme, {String? token}) {
    if (_filter.theme == theme) {
      _filter = _filter.copyWith(clearTheme: true);
    } else {
      _filter = _filter.copyWith(theme: theme);
    }
    fetchItineraries(resetPage: true, token: token);
  }

  void resetAllFilters({String? token}) {
    _searchKeyword = '';
    _filter = const ExploreFilter();
    _sort = 'createdAt,desc';
    fetchItineraries(resetPage: true, token: token);
  }

  void retry({String? token}) {
    fetchItineraries(resetPage: _itineraries.isEmpty, token: token);
  }
}
