import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/sync/auto_refresh_lifecycle_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/current_user_avatar_button.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../messaging/presentation/screens/messaging_inbox_screen.dart';
import '../../../messaging/presentation/screens/friends_screen.dart';
import '../../../messaging/data/messaging_realtime_client.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../community_feed_notifier.dart';
import '../../data/community_post_repository.dart';
import '../../data/models/post_model.dart';
import '../widgets/post_card_widget.dart';
import '../widgets/post_comments_sheet.dart';
import '../widgets/report_post_dialog.dart';
import '../../../messaging/presentation/widgets/share_bottom_sheet.dart';
import 'create_post_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final CommunityFeedNotifier? notifier;
  final CommunityPostRepository? repository;

  const CommunityFeedScreen({
    super.key,
    this.authNotifier,
    this.notifier,
    this.repository,
  });

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen>
    with
        SingleTickerProviderStateMixin,
        AutoRefreshLifecycleMixin<CommunityFeedScreen> {
  late final TabController _tabController;
  late final CommunityFeedNotifier _notifier;
  late final CommunityPostRepository _repo;
  late final ScrollController _scrollController;
  late final MessagingRealtimeClient _realtime;
  StreamSubscription? _messagingEvents;
  String? _activeAccountKey;
  bool _initialFeedLoaded = false;

  String? get _token => widget.authNotifier?.token;
  bool get _isAuthenticated => widget.authNotifier?.isAuthenticated == true;

  @override
  Set<SyncDomain> get syncDomains => {SyncDomain.posts, SyncDomain.comments};

  @override
  Duration get syncTtl => const Duration(minutes: 3);

  @override
  Future<void> onRefreshData({bool isBackground = false}) async {
    final token = _token;
    if (token != null) {
      _notifier.fetchBadges(token);
    }
    await _notifier.refresh(token);
  }

  @override
  void onSyncEvent(SyncEvent event) {
    if (!mounted) return;
    if (event.domain == SyncDomain.posts) {
      if (event.type == SyncEventType.liked ||
          event.type == SyncEventType.unliked) {
        final payload = event.payload;
        if (payload is Map && event.id is int) {
          final isLiked = payload['isLiked'] == true;
          final likeCount = (payload['likeCount'] as num?)?.toInt() ?? 0;
          _notifier.applyLikeUpdate(event.id as int, isLiked, likeCount);
        }
        return;
      }
      if (event.type == SyncEventType.deleted && event.id is int) {
        _notifier.removePost(event.id as int);
        return;
      }
      if (event.type == SyncEventType.updated && event.payload is PostModel) {
        _notifier.updatePostInList(event.payload as PostModel);
        return;
      }
      if (event.type == SyncEventType.created && event.payload is PostModel) {
        final post = event.payload as PostModel;
        final pubIdx = _notifier.publicPosts.indexWhere(
          (p) => p.postId == post.postId,
        );
        if (pubIdx == -1) {
          _notifier.addPost(post);
        }
        return;
      }
    }
    refreshIfStale(isBackground: true);
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? CommunityPostRepository();
    _notifier = widget.notifier ?? CommunityFeedNotifier(repository: _repo);
    _realtime = MessagingRealtimeClient.shared;
    _messagingEvents = _realtime.events.listen((_) {
      final token = _token;
      if (token != null) _notifier.fetchBadges(token);
    });
    widget.authNotifier?.addListener(_authChanged);
    _tabController = TabController(length: 2, vsync: this);
    _scrollController = ScrollController();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _notifier.setTab(_tabController.index, _token);
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        _notifier.loadMore(_token);
      }
    });

    _authChanged();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _messagingEvents?.cancel();
    widget.authNotifier?.removeListener(_authChanged);
    super.dispose();
  }

  void _authChanged() {
    final auth = widget.authNotifier;
    if (auth?.isAuthenticated != true || auth?.token == null) {
      final hadAccount = _activeAccountKey != null;
      _activeAccountKey = null;
      if (hadAccount) _notifier.resetForAccount();
      if (!_initialFeedLoaded || hadAccount) {
        _initialFeedLoaded = true;
        _notifier.loadInitial(null);
      }
      return;
    }
    final accountKey = '${auth!.currentUser?['userId'] ?? ''}';
    if (_activeAccountKey != accountKey) {
      _activeAccountKey = accountKey;
      _notifier.resetForAccount();
      _initialFeedLoaded = true;
      _notifier.loadInitial(auth.token);
    } else {
      _notifier.fetchBadges(auth.token!);
    }
  }

  @override
  void onAppResumed() {
    super.onAppResumed();
    final token = _token;
    if (token != null) {
      _notifier.fetchBadges(token);
    }
  }

  Future<void> _openChatInbox({int initialTab = 0}) async {
    if (!_isAuthenticated) {
      _showLoginRequiredPrompt('trò chuyện cùng bạn bè');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => switch (initialTab) {
          1 => FriendsScreen(authNotifier: widget.authNotifier!),
          2 => FriendsScreen(authNotifier: widget.authNotifier!, initialTab: 1),
          _ => MessagingInboxScreen(authNotifier: widget.authNotifier!),
        },
      ),
    );
    if (mounted && _token != null) _notifier.fetchBadges(_token!);
  }

  void _showLoginRequiredPrompt(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vui lòng đăng nhập để $action'),
        action: SnackBarAction(
          label: 'Đăng nhập',
          onPressed: () {
            // Optional trigger
          },
        ),
      ),
    );
  }

  void _openCreatePost() {
    if (!_isAuthenticated) {
      _showLoginRequiredPrompt('đăng bài viết mới');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatePostScreen(
          authNotifier: widget.authNotifier!,
          repository: _repo,
          notifier: _notifier,
        ),
      ),
    );
  }

  void _openEditPost(PostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatePostScreen(
          authNotifier: widget.authNotifier!,
          repository: _repo,
          notifier: _notifier,
          editingPost: post,
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa bài viết'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa bài viết này không? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _token != null) {
      try {
        await _repo.deletePost(post.postId, token: _token!);
        _notifier.removePost(post.postId);
        AppSyncBus.emitPostDeleted(post.postId);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã xóa bài viết')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể xóa bài viết')),
          );
        }
      }
    }
  }

  void _openComments(PostModel post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostCommentsSheet(
        postId: post.postId,
        token: _token,
        repository: _repo,
        notifier: _notifier,
      ),
    );
  }

  void _openSharePost(PostModel post) {
    if (!_isAuthenticated || _token == null) {
      _showLoginRequiredPrompt('chia sẻ bài viết');
      return;
    }
    final coverImage =
        post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;
    ShareBottomSheet.show(
      context,
      targetType: 'POST',
      targetId: post.postId,
      title: 'Bài viết của ${post.author.displayName}',
      subtitle: post.content.isNotEmpty ? post.content : null,
      coverImage: coverImage,
      authNotifier: widget.authNotifier,
    ).then((shared) {
      if (shared == true && mounted) {
        _notifier.refresh(_token);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chia sẻ bài viết thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _openReport(PostModel post) {
    if (!_isAuthenticated || _token == null) {
      _showLoginRequiredPrompt('báo cáo bài viết');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => ReportPostDialog(
        postId: post.postId,
        token: _token!,
        repository: _repo,
      ),
    );
  }

  void _openItineraryDetail(int itineraryId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItineraryDetailScreen(
          itineraryId: itineraryId,
          authNotifier: widget.authNotifier,
        ),
      ),
    );
  }

  Future<void> _openUserProfile(int userId) async {
    if (userId <= 0) return;
    final currentUserId = int.tryParse(
      '${widget.authNotifier?.currentUser?['userId'] ?? ''}',
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => currentUserId == userId && widget.authNotifier != null
            ? ProfileScreen(authNotifier: widget.authNotifier!)
            : PublicProfileScreen(
                userId: userId,
                authNotifier: widget.authNotifier,
              ),
      ),
    );
    if (mounted && _token != null) _notifier.fetchBadges(_token!);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const AppPageTitle(title: 'Cộng đồng'),
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              // Chat Inbox Shortcut
              IconButton(
                tooltip: 'Bạn bè và lời mời',
                icon: Badge(
                  isLabelVisible: _notifier.friendRequestsCount > 0,
                  label: Text('${_notifier.friendRequestsCount}'),
                  child: const Icon(Icons.person_add_alt_1_outlined, size: 22),
                ),
                onPressed: () => _openChatInbox(initialTab: 2),
              ),
              IconButton(
                tooltip: 'Tin nhắn',
                icon: Badge(
                  isLabelVisible: _notifier.unreadMessagesTotal > 0,
                  label: _notifier.unreadMessagesTotal > 0
                      ? Text(
                          _notifier.unreadMessagesTotal > 99
                              ? '99+'
                              : '${_notifier.unreadMessagesTotal}',
                        )
                      : null,
                  child: const Icon(Icons.chat_bubble_outline, size: 22),
                ),
                onPressed: _openChatInbox,
              ),

              // Notifications Shortcut
              IconButton(
                tooltip: 'Thông báo',
                icon: const Icon(Icons.notifications_outlined, size: 24),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              if (_isAuthenticated && widget.authNotifier != null)
                CurrentUserAvatarButton(
                  avatarUrl: widget.authNotifier?.currentUser?['avatar']
                      ?.toString(),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProfileScreen(authNotifier: widget.authNotifier!),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.hairlineSoft, width: 1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Dành cho bạn'),
                    Tab(text: 'Đang theo dõi'),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 3,
            onPressed: _openCreatePost,
            icon: const Icon(Icons.edit_note, size: 24),
            label: const Text(
              'Đăng bài',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Public Feed ("Dành cho bạn")
              _buildFeedStream(_notifier.publicPosts, isFollowingTab: false),

              // Tab 2: Following Feed ("Đang theo dõi")
              _buildFeedStream(_notifier.followingPosts, isFollowingTab: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedStream(
    List<PostModel> posts, {
    required bool isFollowingTab,
  }) {
    if (_notifier.isLoading && posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_notifier.error != null && posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _notifier.error!,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _notifier.refresh(_token),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (isFollowingTab && !_isAuthenticated) {
      return const AppEmptyState(
        icon: Icons.people_outline,
        title: 'Theo dõi bạn bè và người sáng tạo',
        message:
            'Đăng nhập để xem bài viết từ những người bạn theo dõi và bạn bè.',
      );
    }

    if (posts.isEmpty) {
      return AppEmptyState(
        icon: Icons.dynamic_feed_outlined,
        title: isFollowingTab ? 'Chưa có bài viết mới' : 'Bảng tin còn trống',
        message: isFollowingTab
            ? 'Hãy kết nối với bạn bè và theo dõi những người khác để cập nhật tin tức.'
            : 'Hãy là người đầu tiên chia sẻ khoảnh khắc du lịch của bạn!',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await _notifier.refresh(_token);
        recordRefreshedNow();
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: posts.length + (_notifier.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final post = posts[index];
          return PostCardWidget(
            post: post,
            onLike: () {
              if (!_isAuthenticated || _token == null) {
                _showLoginRequiredPrompt('thích bài viết');
                return;
              }
              _notifier.toggleLike(post.postId, _token!);
            },
            onComment: () => _openComments(post),
            onShare: () => _openSharePost(post),
            onEdit: () => _openEditPost(post),
            onDelete: () => _confirmDeletePost(post),
            onReport: () => _openReport(post),
            onItineraryTap: _openItineraryDetail,
            onUserTap: _openUserProfile,
          );
        },
      ),
    );
  }
}
