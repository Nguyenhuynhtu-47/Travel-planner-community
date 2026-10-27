import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../explore/data/models/itinerary_summary.dart';
import '../data/itinerary_crud_repository.dart';

enum MyItinerariesStatus { initial, loading, success, error }

class MyItinerariesNotifier extends ChangeNotifier {
  final ItineraryCrudRepository _repository;

  MyItinerariesStatus _status = MyItinerariesStatus.initial;
  List<ItinerarySummary> _itineraries = [];
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  bool _isLastPage = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  String? _statusFilter;
  String? _visibilityFilter;
  String _sort = 'createdAt,desc';

  int _requestId = 0;

  MyItinerariesNotifier({ItineraryCrudRepository? repository})
    : _repository = repository ?? ItineraryCrudRepository();

  MyItinerariesStatus get status => _status;
  bool get isLoading => _status == MyItinerariesStatus.loading;
  bool get isSuccess => _status == MyItinerariesStatus.success;
  bool get isError => _status == MyItinerariesStatus.error;
  bool get isLoadingMore => _isLoadingMore;
  List<ItinerarySummary> get itineraries => List.unmodifiable(_itineraries);
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalElements => _totalElements;
  bool get isLastPage => _isLastPage;
  String? get errorMessage => _errorMessage;

  String? get statusFilter => _statusFilter;
  String? get visibilityFilter => _visibilityFilter;
  String get sort => _sort;

  bool get isEmptyResults =>
      _status == MyItinerariesStatus.success && _itineraries.isEmpty;

  Future<void> loadInitialItineraries({String? token}) async {
    await fetchItineraries(resetPage: true, token: token);
  }

  Future<void> refresh({String? token}) async {
    await fetchItineraries(resetPage: true, token: token);
  }

  Future<void> fetchItineraries({bool resetPage = true, String? token}) async {
    final currentRequestId = ++_requestId;

    if (resetPage) {
      _currentPage = 0;
      _isLastPage = false;
      _status = MyItinerariesStatus.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final pageResult = await _repository.getMyItineraries(
        token: token,
        page: _currentPage,
        size: 10,
        sort: _sort,
        status: _statusFilter,
        visibility: _visibilityFilter,
      );

      if (currentRequestId != _requestId) return;

      _itineraries = pageResult.content;
      _currentPage = pageResult.pageNumber;
      _totalPages = pageResult.totalPages;
      _totalElements = pageResult.totalElements;
      _isLastPage = pageResult.isLast || (_currentPage + 1 >= _totalPages);
      _status = MyItinerariesStatus.success;
      _errorMessage = null;
    } on ApiException catch (e) {
      if (currentRequestId != _requestId) return;
      _status = MyItinerariesStatus.error;
      _errorMessage = e.message;
    } catch (_) {
      if (currentRequestId != _requestId) return;
      _status = MyItinerariesStatus.error;
      _errorMessage =
          'Không thể tải danh sách lịch trình. Vui lòng kiểm tra kết nối mạng.';
    } finally {
      if (currentRequestId == _requestId) {
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({String? token}) async {
    if (_isLoadingMore ||
        _isLastPage ||
        _status == MyItinerariesStatus.loading) {
      return;
    }

    final currentRequestId = _requestId;
    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _currentPage + 1;

    try {
      final pageResult = await _repository.getMyItineraries(
        token: token,
        page: nextPage,
        size: 10,
        sort: _sort,
        status: _statusFilter,
        visibility: _visibilityFilter,
      );

      if (currentRequestId != _requestId) return;

      _itineraries = [..._itineraries, ...pageResult.content];
      _currentPage = pageResult.pageNumber;
      _totalPages = pageResult.totalPages;
      _totalElements = pageResult.totalElements;
      _isLastPage = pageResult.isLast || (_currentPage + 1 >= _totalPages);
    } catch (_) {
      // Retain existing list on page-fetch error
    } finally {
      if (currentRequestId == _requestId) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void setStatusFilter(String? status, {String? token}) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    fetchItineraries(resetPage: true, token: token);
  }

  void setVisibilityFilter(String? visibility, {String? token}) {
    if (_visibilityFilter == visibility) return;
    _visibilityFilter = visibility;
    fetchItineraries(resetPage: true, token: token);
  }

  void setSort(String sort, {String? token}) {
    if (_sort == sort) return;
    _sort = sort;
    fetchItineraries(resetPage: true, token: token);
  }
}
