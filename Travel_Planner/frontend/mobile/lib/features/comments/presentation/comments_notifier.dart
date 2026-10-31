import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../explore/data/models/page_result.dart';
import '../data/comments_repository.dart';
import '../data/models/itinerary_comment.dart';

class CommentsNotifier extends ChangeNotifier {
  final int itineraryId;
  final CommentsRepository _repository;
  static const int _pageSize = 10;

  final List<ItineraryComment> comments = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool isSubmitting = false;
  String? errorMessage;
  int? errorStatusCode;
  String? submitError;
  PageResult<ItineraryComment>? _pageResult;
  bool _isDisposed = false;

  CommentsNotifier({required this.itineraryId, CommentsRepository? repository})
    : _repository = repository ?? CommentsRepository();

  bool get hasMore => _pageResult?.hasMore ?? false;
  int get totalElements => _pageResult?.totalElements ?? comments.length;

  Future<void> load({bool refresh = false}) async {
    if (isLoadingMore) return;
    isLoading = true;
    errorMessage = null;
    errorStatusCode = null;
    if (refresh) comments.clear();
    _notifySafely();
    try {
      final result = await _repository.getComments(itineraryId, page: 0, size: _pageSize);
      comments
        ..clear()
        ..addAll(result.content);
      _pageResult = result;
    } on ApiException catch (error) {
      errorMessage = error.message;
      errorStatusCode = error.statusCode;
    } catch (_) {
      errorMessage = 'Không thể tải bình luận. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadMore() async {
    final currentPage = _pageResult;
    if (currentPage == null || !currentPage.hasMore || isLoadingMore) return;
    isLoadingMore = true;
    errorMessage = null;
    _notifySafely();
    try {
      final result = await _repository.getComments(
        itineraryId,
        page: currentPage.pageNumber + 1,
        size: _pageSize,
      );
      comments.addAll(result.content);
      _pageResult = result;
    } on ApiException catch (error) {
      errorMessage = error.message;
      errorStatusCode = error.statusCode;
    } catch (_) {
      errorMessage = 'Không thể tải thêm bình luận. Vui lòng thử lại.';
    } finally {
      isLoadingMore = false;
      _notifySafely();
    }
  }

  Future<bool> submit(String content, String? token) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || token == null || token.isEmpty || isSubmitting) return false;
    isSubmitting = true;
    submitError = null;
    _notifySafely();
    try {
      final comment = await _repository.createComment(
        itineraryId,
        content: trimmed,
        token: token,
      );
      errorMessage = null;
      errorStatusCode = null;
      comments.insert(0, comment);
      if (_pageResult != null) {
        final updatedTotal = _pageResult!.totalElements + 1;
        final updatedTotalPages = (updatedTotal / _pageResult!.pageSize).ceil();
        _pageResult = PageResult<ItineraryComment>(
          content: comments,
          pageNumber: _pageResult!.pageNumber,
          pageSize: _pageResult!.pageSize,
          totalElements: updatedTotal,
          totalPages: updatedTotalPages,
          isLast: _pageResult!.pageNumber + 1 >= updatedTotalPages,
        );
      }
      return true;
    } on ApiException catch (error) {
      submitError = error.message;
      return false;
    } catch (_) {
      submitError = 'Không thể gửi bình luận. Vui lòng thử lại.';
      return false;
    } finally {
      isSubmitting = false;
      _notifySafely();
    }
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
