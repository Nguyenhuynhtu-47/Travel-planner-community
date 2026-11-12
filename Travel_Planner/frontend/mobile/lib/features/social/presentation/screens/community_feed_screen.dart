import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../messaging/presentation/screens/community_screen.dart' as messaging;
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../community_feed_notifier.dart';
import '../../data/community_post_repository.dart';
import '../../data/models/post_model.dart';
import '../widgets/post_card_widget.dart';
import '../widgets/post_comments_sheet.dart';
import '../widgets/report_post_dialog.dart';
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
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final CommunityFeedNotifier _notifier;
  late final CommunityPostRepository _repo;
  late final ScrollController _scrollController;

  String? get _token => widget.authNotifier?.token;
  bool get _isAuthenticated => widget.authNotifier?.isAuthenticated == true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? CommunityPostRepository();
    _notifier = widget.notifier ?? CommunityFeedNotifier(repository: _repo);
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

    _notifier.loadInitial(_token);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openChatInbox() {
    if (!_isAuthenticated) {
      _showLoginRequiredPrompt('trò chuyện cùng bạn bè');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => messaging.CommunityScreen(
          authNotifier: widget.authNotifier,
        ),
      ),
    );
  }

  void _openFriends() {
    if (!_isAuthenticated) {
      _showLoginRequiredPrompt('xem danh sách bạn bè');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => messaging.CommunityScreen(
          authNotifier: widget.authNotifier,
        ),
      ),
    );
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
        content: const Text('Bạn có chắc chắn muốn xóa bài viết này không? Hành động này không thể hoàn tác.'),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa bài viết')),
          );
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostCommentsSheet(
        postId: post.postId,
        token: _token,
        repository: _repo,
        notifier: _notifier,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text(
              'Cộng đồng du lịch',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            surfaceTintColor: Colors.transparent,
            actions: [
              // Chat Inbox Shortcut
              IconButton(
                tooltip: 'Tin nhắn',
                icon: Badge(
                  isLabelVisible: _notifier.unreadMessagesCount > 0,
                  label: Text('${_notifier.unreadMessagesCount}'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                onPressed: _openChatInbox,
              ),

              // Friends Shortcut
              IconButton(
                tooltip: 'Bạn bè & Lời mời',
                icon: Badge(
                  isLabelVisible: _notifier.friendRequestsCount > 0,
                  label: Text('${_notifier.friendRequestsCount}'),
                  child: const Icon(Icons.people_outline),
                ),
                onPressed: _openFriends,
              ),

              // Notifications Shortcut
              IconButton(
                tooltip: 'Thông báo',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.hairlineSoft, width: 1)),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
            label: const Text('Đăng bài', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildFeedStream(List<PostModel> posts, {required bool isFollowingTab}) {
    if (_notifier.isLoading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_notifier.error != null && posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_notifier.error!, style: const TextStyle(color: AppColors.muted)),
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
        message: 'Đăng nhập để xem bài viết từ những người bạn theo dõi và bạn bè.',
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
      onRefresh: () => _notifier.refresh(_token),
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
            onEdit: () => _openEditPost(post),
            onDelete: () => _confirmDeletePost(post),
            onReport: () => _openReport(post),
            onItineraryTap: _openItineraryDetail,
          );
        },
      ),
    );
  }
}
