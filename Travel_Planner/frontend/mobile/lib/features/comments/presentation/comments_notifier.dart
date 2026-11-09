import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../explore/data/models/page_result.dart';
import '../data/comments_repository.dart';
import '../data/models/itinerary_comment.dart';

class CommentsNotifier extends ChangeNotifier {
  final int? itineraryId;
  final int? activityId;
  final CommentsRepository _repository;
  static const int _pageSize = 10;

  final List<ItineraryComment> comments = [];
  final Map<int, List<ItineraryComment>> replies = {};
  final Map<int, PageResult<ItineraryComment>> _replyPages = {};
  final Set<int> loadingReplies = {};
  bool isLoading = true;
  bool isLoadingMore = false;
  bool isSubmitting = false;
  String? errorMessage;
  int? errorStatusCode;
  String? submitError;
  PageResult<ItineraryComment>? _pageResult;
  bool _isDisposed = false;

  CommentsNotifier({required this.itineraryId, CommentsRepository? repository})
    : activityId = null, _repository = repository ?? CommentsRepository();

  CommentsNotifier.forActivity({required this.activityId, CommentsRepository? repository})
    : itineraryId = null, _repository = repository ?? CommentsRepository();

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
      final result = await _getPage(0);
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
      final result = await _getPage(currentPage.pageNumber + 1);
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

  Future<PageResult<ItineraryComment>> _getPage(int page) => activityId != null
      ? _repository.getActivityComments(activityId!, page: page, size: _pageSize)
      : _repository.getComments(itineraryId!, page: page, size: _pageSize);

  Future<bool> submit(String content, String? token, {int? parentCommentId}) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || token == null || token.isEmpty || isSubmitting) return false;
    isSubmitting = true;
    submitError = null;
    _notifySafely();
    try {
      final comment = parentCommentId != null
          ? await _repository.createReply(parentCommentId, content: trimmed, token: token)
          : activityId != null
              ? await _repository.createActivityComment(activityId!, content: trimmed, token: token)
              : await _repository.createComment(itineraryId!, content: trimmed, token: token);
      errorMessage = null;
      errorStatusCode = null;
      if (parentCommentId != null) {
        final rootId = comment.rootCommentId ?? parentCommentId;
        replies.putIfAbsent(rootId, () => <ItineraryComment>[]).add(comment);
        final rootIndex = comments.indexWhere((item) => item.commentId == rootId);
        if (rootIndex >= 0) {
          final root = comments[rootIndex];
          comments[rootIndex] = ItineraryComment(
            commentId: root.commentId, content: root.content, userId: root.userId,
            username: root.username, fullName: root.fullName, avatar: root.avatar,
            createdAt: root.createdAt, updatedAt: root.updatedAt,
            parentCommentId: root.parentCommentId, rootCommentId: root.rootCommentId,
            replyCount: root.replyCount + 1, deleted: root.deleted,
          );
        }
      } else {
        comments.insert(0, comment);
      }
      if (parentCommentId == null && _pageResult != null) {
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

  Future<void> loadReplies(int rootId, {bool refresh = false}) async {
    if (loadingReplies.contains(rootId)) return;
    if (refresh) { replies.remove(rootId); _replyPages.remove(rootId); }
    loadingReplies.add(rootId); _notifySafely();
    try {
      final result = await _repository.getReplies(rootId, page: refresh ? 0 : (_replyPages[rootId]?.pageNumber ?? -1) + 1, size: _pageSize);
      final list = replies.putIfAbsent(rootId, () => <ItineraryComment>[]);
      final seen = list.map((comment) => comment.commentId).toSet();
      list.addAll(result.content.where((comment) => seen.add(comment.commentId)));
      _replyPages[rootId] = result;
      errorMessage = null;
    } on ApiException catch (error) { errorMessage = error.message; }
      catch (_) { errorMessage = 'Không thể tải câu trả lời. Vui lòng thử lại.'; }
    finally { loadingReplies.remove(rootId); _notifySafely(); }
  }

  bool repliesHaveMore(int rootId) => _replyPages[rootId]?.hasMore ?? false;

  Future<bool> updateComment(int commentId, String content, String? token) async {
    if (token == null || token.isEmpty || content.trim().isEmpty || isSubmitting) return false;
    isSubmitting = true; submitError = null; _notifySafely();
    try {
      final updated = await _repository.updateComment(commentId, content: content.trim(), token: token);
      _replaceComment(updated); return true;
    } catch (_) { submitError = 'Không thể sửa bình luận. Vui lòng thử lại.'; return false; }
    finally { isSubmitting = false; _notifySafely(); }
  }

  Future<bool> deleteComment(int commentId, String? token) async {
    if (token == null || token.isEmpty || isSubmitting) return false;
    isSubmitting = true; _notifySafely();
    try {
      await _repository.deleteComment(commentId, token: token);
      final old = _findComment(commentId);
      if (old != null) {
        _replaceComment(ItineraryComment(commentId: old.commentId, content: 'Bình luận đã bị xóa',
          userId: old.userId, username: old.username, fullName: old.fullName, avatar: old.avatar,
          createdAt: old.createdAt, updatedAt: old.updatedAt, parentCommentId: old.parentCommentId,
          rootCommentId: old.rootCommentId, replyCount: old.replyCount, deleted: true));
        if (old.parentCommentId != null) _decrementRootReplyCount(old.rootCommentId);
      }
      return true;
    } catch (_) { submitError = 'Không thể xóa bình luận. Vui lòng thử lại.'; return false; }
    finally { isSubmitting = false; _notifySafely(); }
  }

  void _replaceComment(ItineraryComment value) {
    final index = comments.indexWhere((item) => item.commentId == value.commentId);
    if (index >= 0) comments[index] = value;
    for (final list in replies.values) {
      final replyIndex = list.indexWhere((item) => item.commentId == value.commentId);
      if (replyIndex >= 0) list[replyIndex] = value;
    }
  }

  ItineraryComment? _findComment(int id) {
    for (final item in comments) { if (item.commentId == id) return item; }
    for (final list in replies.values) { for (final item in list) { if (item.commentId == id) return item; } }
    return null;
  }

  void _decrementRootReplyCount(int? rootId) {
    if (rootId == null) return;
    final index = comments.indexWhere((item) => item.commentId == rootId);
    if (index < 0) return;
    final root = comments[index];
    comments[index] = ItineraryComment(commentId: root.commentId, content: root.content,
      userId: root.userId, username: root.username, fullName: root.fullName, avatar: root.avatar,
      createdAt: root.createdAt, updatedAt: root.updatedAt, rootCommentId: root.rootCommentId,
      replyCount: root.replyCount > 0 ? root.replyCount - 1 : 0, deleted: root.deleted);
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
