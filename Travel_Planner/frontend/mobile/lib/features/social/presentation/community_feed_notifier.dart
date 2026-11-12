import 'package:flutter/foundation.dart';
import '../data/community_post_repository.dart';
import '../data/models/post_model.dart';

class CommunityFeedNotifier extends ChangeNotifier {
  final CommunityPostRepository _repository;

  CommunityFeedNotifier({CommunityPostRepository? repository})
      : _repository = repository ?? CommunityPostRepository();

  List<PostModel> _publicPosts = [];
  List<PostModel> _followingPosts = [];

  bool _loadingPublic = false;
  bool _loadingFollowing = false;
  bool _loadingMore = false;

  int _publicPage = 0;
  int _followingPage = 0;

  bool _hasMorePublic = true;
  bool _hasMoreFollowing = true;

  int _currentTab = 0; // 0 = Public ("Dành cho bạn"), 1 = Following ("Đang theo dõi")
  String? _error;

  int _unreadMessagesCount = 0;
  int _friendRequestsCount = 0;

  List<PostModel> get publicPosts => List.unmodifiable(_publicPosts);
  List<PostModel> get followingPosts => List.unmodifiable(_followingPosts);
  List<PostModel> get currentPosts => _currentTab == 0 ? _publicPosts : _followingPosts;

  bool get isLoading => _currentTab == 0 ? _loadingPublic : _loadingFollowing;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _currentTab == 0 ? _hasMorePublic : _hasMoreFollowing;
  int get currentTab => _currentTab;
  String? get error => _error;
  int get unreadMessagesCount => _unreadMessagesCount;
  int get friendRequestsCount => _friendRequestsCount;

  void setTab(int tab, String? token) {
    if (_currentTab == tab) return;
    _currentTab = tab;
    notifyListeners();
    if (_currentTab == 1 && _followingPosts.isEmpty && token != null) {
      loadFollowing(token, refresh: true);
    }
  }

  Future<void> loadInitial(String? token) async {
    _error = null;
    await Future.wait([
      loadPublic(token, refresh: true),
      if (token != null) loadFollowing(token, refresh: true),
      if (token != null) fetchBadges(token),
    ]);
  }

  Future<void> refresh(String? token) async {
    _error = null;
    if (_currentTab == 0) {
      await loadPublic(token, refresh: true);
    } else if (token != null) {
      await loadFollowing(token, refresh: true);
    }
    if (token != null) {
      fetchBadges(token);
    }
  }

  Future<void> loadPublic(String? token, {bool refresh = false}) async {
    if (_loadingPublic) return;
    if (refresh) {
      _publicPage = 0;
      _hasMorePublic = true;
    }
    _loadingPublic = true;
    notifyListeners();

    try {
      final posts = await _repository.getPublicFeed(
        page: _publicPage,
        size: 10,
        token: token,
      );
      final uniquePosts = <PostModel>[];
      final seen = <int>{};
      for (final p in posts) {
        if (seen.add(p.postId)) uniquePosts.add(p);
      }
      if (refresh) {
        _publicPosts = uniquePosts;
      } else {
        // Section 1.2 Offset pagination client deduplication
        final existingIds = _publicPosts.map((p) => p.postId).toSet();
        _publicPosts.addAll(uniquePosts.where((p) => !existingIds.contains(p.postId)));
      }
      _hasMorePublic = posts.length >= 10;
      _publicPage++;
      _error = null;
    } catch (e) {
      _error = 'Không thể tải bảng tin công đồng';
    } finally {
      _loadingPublic = false;
      notifyListeners();
    }
  }

  Future<void> loadFollowing(String token, {bool refresh = false}) async {
    if (_loadingFollowing) return;
    if (refresh) {
      _followingPage = 0;
      _hasMoreFollowing = true;
    }
    _loadingFollowing = true;
    notifyListeners();

    try {
      final posts = await _repository.getFollowingFeed(
        page: _followingPage,
        size: 10,
        token: token,
      );
      final uniquePosts = <PostModel>[];
      final seen = <int>{};
      for (final p in posts) {
        if (seen.add(p.postId)) uniquePosts.add(p);
      }
      if (refresh) {
        _followingPosts = uniquePosts;
      } else {
        final existingIds = _followingPosts.map((p) => p.postId).toSet();
        _followingPosts.addAll(uniquePosts.where((p) => !existingIds.contains(p.postId)));
      }
      _hasMoreFollowing = posts.length >= 10;
      _followingPage++;
      _error = null;
    } catch (e) {
      _error = 'Không thể tải bảng tin đang theo dõi';
    } finally {
      _loadingFollowing = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(String? token) async {
    if (_loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();

    try {
      if (_currentTab == 0) {
        final posts = await _repository.getPublicFeed(
          page: _publicPage,
          size: 10,
          token: token,
        );
        final existingIds = _publicPosts.map((p) => p.postId).toSet();
        final newItems = posts.where((p) => !existingIds.contains(p.postId)).toList();
        _publicPosts.addAll(newItems);
        _hasMorePublic = posts.length >= 10;
        _publicPage++;
      } else if (token != null) {
        final posts = await _repository.getFollowingFeed(
          page: _followingPage,
          size: 10,
          token: token,
        );
        final existingIds = _followingPosts.map((p) => p.postId).toSet();
        final newItems = posts.where((p) => !existingIds.contains(p.postId)).toList();
        _followingPosts.addAll(newItems);
        _hasMoreFollowing = posts.length >= 10;
        _followingPage++;
      }
    } catch (_) {
      // Keep existing items on pagination error
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(int postId, String token) async {
    int publicIndex = _publicPosts.indexWhere((p) => p.postId == postId);
    int followingIndex = _followingPosts.indexWhere((p) => p.postId == postId);

    PostModel? target = publicIndex != -1
        ? _publicPosts[publicIndex]
        : (followingIndex != -1 ? _followingPosts[followingIndex] : null);

    if (target == null) return;

    final wasLiked = target.isLikedByMe;
    final newLiked = !wasLiked;
    final newCount = wasLiked ? (target.likeCount > 0 ? target.likeCount - 1 : 0) : target.likeCount + 1;

    // Optimistic UI update
    final updated = target.copyWith(isLikedByMe: newLiked, likeCount: newCount);
    if (publicIndex != -1) _publicPosts[publicIndex] = updated;
    if (followingIndex != -1) _followingPosts[followingIndex] = updated;
    notifyListeners();

    try {
      if (newLiked) {
        await _repository.likePost(postId, token: token);
      } else {
        await _repository.unlikePost(postId, token: token);
      }
    } catch (e) {
      // Rollback on failure
      if (publicIndex != -1) _publicPosts[publicIndex] = target;
      if (followingIndex != -1) _followingPosts[followingIndex] = target;
      notifyListeners();
    }
  }

  void addPost(PostModel post) {
    _publicPosts.insert(0, post);
    if (post.isOwner) {
      _followingPosts.insert(0, post);
    }
    notifyListeners();
  }

  void updatePostInList(PostModel post) {
    final pubIdx = _publicPosts.indexWhere((p) => p.postId == post.postId);
    if (pubIdx != -1) _publicPosts[pubIdx] = post;

    final folIdx = _followingPosts.indexWhere((p) => p.postId == post.postId);
    if (folIdx != -1) _followingPosts[folIdx] = post;

    notifyListeners();
  }

  void removePost(int postId) {
    _publicPosts.removeWhere((p) => p.postId == postId);
    _followingPosts.removeWhere((p) => p.postId == postId);
    notifyListeners();
  }

  void updateCommentCount(int postId, int delta) {
    final pubIdx = _publicPosts.indexWhere((p) => p.postId == postId);
    if (pubIdx != -1) {
      final p = _publicPosts[pubIdx];
      final newCount = (p.commentCount + delta) < 0 ? 0 : p.commentCount + delta;
      _publicPosts[pubIdx] = p.copyWith(commentCount: newCount);
    }

    final folIdx = _followingPosts.indexWhere((p) => p.postId == postId);
    if (folIdx != -1) {
      final p = _followingPosts[folIdx];
      final newCount = (p.commentCount + delta) < 0 ? 0 : p.commentCount + delta;
      _followingPosts[folIdx] = p.copyWith(commentCount: newCount);
    }

    notifyListeners();
  }

  Future<void> fetchBadges(String token) async {
    try {
      final unread = await _repository.getTotalUnread(token: token);
      _unreadMessagesCount = unread;
      notifyListeners();
    } catch (_) {}
  }

  void setFriendRequestsCount(int count) {
    _friendRequestsCount = count;
    notifyListeners();
  }
}
