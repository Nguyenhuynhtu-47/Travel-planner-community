import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/app_dialog.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../explore/presentation/widgets/itinerary_card.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../data/models/public_profile.dart';
import '../../data/models/public_user_summary.dart';
import '../../data/public_profile_repository.dart';
import '../../../messaging/data/messaging_repository.dart';
import '../../../messaging/data/messaging_realtime_client.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../messaging/presentation/widgets/share_bottom_sheet.dart';
import '../../../messaging/data/models/conversation_summary.dart';
import '../../../social/data/community_post_repository.dart';
import '../../../social/data/models/post_model.dart';
import '../../../social/presentation/widgets/post_card_widget.dart';
import '../../../social/presentation/widgets/post_comments_sheet.dart';
import 'profile_screen.dart';
import 'public_user_list_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final int userId;
  final AuthNotifier? authNotifier;
  final PublicProfileRepository? repository;
  final CommunityPostRepository? postRepository;
  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.authNotifier,
    this.repository,
    this.postRepository,
  });
  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final PublicProfileRepository _repo =
      widget.repository ?? PublicProfileRepository();
  late final CommunityPostRepository _postRepo =
      widget.postRepository ?? CommunityPostRepository();
  PublicProfile? _profile;
  List<ItinerarySummary> _itineraries = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _followBusy = false;
  bool _relationshipBusy = false;
  final MessagingRepository _messaging = MessagingRepository();
  String? _error, _moreError;
  String? get _token => widget.authNotifier?.token;

  bool get _following => _profile?.isFollowing ?? false;

  int _selectedTab = 0; // 0: Lịch trình, 1: Bài viết
  List<PostModel> _posts = [];
  bool _loadingPosts = false;
  bool _hasMorePosts = true;
  int _postsPage = 0;
  String? _postsError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _page = 0;
      _hasMore = true;
      _itineraries.clear();
    });
    try {
      final profile = await _repo.getProfile(widget.userId, token: _token);
      final page = await _repo.itineraries(widget.userId, token: _token);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _itineraries = page.content;
        _page = page.pageNumber;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể tải hồ sơ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.itineraries(
        widget.userId,
        page: _page + 1,
        token: _token,
      );
      if (mounted) {
        setState(() {
          _itineraries.addAll(page.content);
          _page = page.pageNumber;
          _hasMore = page.hasMore;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _moreError = 'Không thể tải thêm lịch trình.');
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      _postsPage = 0;
      _hasMorePosts = true;
    }
    if (!_hasMorePosts || (_loadingPosts && !refresh)) return;

    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });

    try {
      final posts = await _postRepo.getUserPosts(
        widget.userId,
        page: _postsPage,
        size: 10,
        token: _token,
      );
      if (mounted) {
        setState(() {
          if (refresh) {
            _posts = posts;
          } else {
            _posts.addAll(posts);
          }
          _postsPage++;
          _hasMorePosts = posts.length >= 10;
          _loadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _postsError = 'Không thể tải danh sách bài viết';
          _loadingPosts = false;
        });
      }
    }
  }

  Future<void> _likePost(PostModel post) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      AppToast.showWarning(context, 'Đăng nhập để thích bài viết.');
      return;
    }

    final newIsLiked = !post.isLikedByMe;
    final newCount = post.likeCount + (newIsLiked ? 1 : -1);
    final updated = post.copyWith(
      isLikedByMe: newIsLiked,
      likeCount: newCount < 0 ? 0 : newCount,
    );

    setState(() {
      final index = _posts.indexWhere((p) => p.postId == post.postId);
      if (index != -1) _posts[index] = updated;
    });

    try {
      if (newIsLiked) {
        await _postRepo.likePost(post.postId, token: token);
      } else {
        await _postRepo.unlikePost(post.postId, token: token);
      }
      AppSyncBus.emitPostLiked(post.postId, newIsLiked, newCount < 0 ? 0 : newCount);
    } catch (_) {
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.postId == post.postId);
          if (index != -1) _posts[index] = post;
        });
      }
    }
  }

  void _openPostComments(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostCommentsSheet(
        postId: post.postId,
        token: _token,
        repository: _postRepo,
        onCommentCountChanged: (delta) {
          setState(() {
            final idx = _posts.indexWhere((p) => p.postId == post.postId);
            if (idx != -1) {
              final newCount = (_posts[idx].commentCount + delta) < 0
                  ? 0
                  : _posts[idx].commentCount + delta;
              _posts[idx] = _posts[idx].copyWith(commentCount: newCount);
            }
          });
        },
      ),
    );
  }

  void _openSharePost(PostModel post) {
    final coverImage = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;
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
        _loadPosts(refresh: true);
      }
    });
  }

  void _openReport(PostModel post) {
    AppToast.showSuccess(
      context,
      'Đã ghi nhận báo cáo bài viết. Cảm ơn phản hồi của bạn!',
    );
  }

  Future<void> _toggleFollow() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      AppToast.showWarning(context, 'Đăng nhập để theo dõi người dùng.');
      return;
    }
    if (_followBusy) return;
    final old = _following;
    setState(() => _followBusy = true);
    try {
      if (old) {
        await _repo.unfollow(widget.userId, token);
      } else {
        await _repo.follow(widget.userId, token);
      }
      if (mounted) {
        final profile = _profile;
        if (profile != null) {
          setState(() {
            _profile = profile.copyWith(
              isFollowing: !old,
              followerCount: (profile.followerCount + (old ? -1 : 1))
                  .clamp(0, 1 << 31)
                  .toInt(),
            );
          });
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Không thể cập nhật theo dõi. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _relationshipAction(String action) async {
    final token = _token;
    if (token == null) {
      AppToast.showWarning(context, 'Đăng nhập để kết nối với người dùng.');
      return;
    }
    if (_relationshipBusy) return;
    setState(() => _relationshipBusy = true);
    try {
      final status = _profile?.friendshipStatus;
      final direction = _profile?.friendRequestDirection;
      if (action == 'send') {
        await _messaging.sendFriendRequest(widget.userId, token);
      }
      if (action == 'accept') {
        final requests = await _messaging.requests(token, 'received');
        final match = requests.content
            .where((item) => item.otherUser.userId == widget.userId)
            .firstOrNull;
        if (match != null) {
          await _messaging.acceptFriendRequest(match.friendshipId, token);
        }
      }
      if (action == 'cancel' || action == 'decline') {
        final requests = await _messaging.requests(
          token,
          direction == 'received' ? 'received' : 'sent',
        );
        final match = requests.content
            .where((item) => item.otherUser.userId == widget.userId)
            .firstOrNull;
        if (match != null) {
          if (action == 'cancel') {
            await _messaging.cancelFriendRequest(match.friendshipId, token);
          } else {
            await _messaging.declineFriendRequest(match.friendshipId, token);
          }
        }
      }
      if (action == 'unfriend' && status == 'ACCEPTED') {
        await _messaging.unfriend(widget.userId, token);
      }
      await _load();
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Không thể cập nhật quan hệ bạn bè.');
      }
    } finally {
      if (mounted) setState(() => _relationshipBusy = false);
    }
  }

  Future<void> _openConversation(PublicProfile profile) async {
    final token = _token;
    if (token == null || widget.authNotifier == null) {
      AppToast.showWarning(context, 'Đăng nhập để nhắn tin với người dùng.');
      return;
    }
    try {
      final conversation = await _messaging.openDirect(widget.userId, token);
      final realtime = MessagingRealtimeClient.shared
        ..connect(
          token,
          '${widget.authNotifier!.currentUser?['userId'] ?? ''}',
        );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            authNotifier: widget.authNotifier!,
            repository: _messaging,
            realtime: realtime,
            conversation: conversation,
          ),
        ),
      );

      _load();
    } on ApiException catch (error) {
      if (error.statusCode == 403 && mounted) {
        final preview = ConversationSummary(
          conversationId: -1,
          peer: PublicUserSummary(
            userId: profile.userId,
            handle: profile.handle,
            username: profile.handle,
            fullName: profile.fullName,
            avatar: profile.avatar,
          ),
          lastMessageSequence: 0,
          unreadCount: 0,
          canSendMessage: false,
          status: 'UNAVAILABLE',
        );
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(
              authNotifier: widget.authNotifier!,
              repository: _messaging,
              realtime: MessagingRealtimeClient.shared,
              conversation: preview,
              initialSystemNotice: 'Người này hiện không nhận tin nhắn mới từ người chưa kết bạn hoặc đang giới hạn liên hệ. Hãy gửi lời mời kết bạn hoặc kiểm tra lại cài đặt quyền riêng tư.',
            ),
          ),
        );
        return;
      }
      if (mounted) {
        AppToast.showError(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Bạn chưa thể nhắn tin cho người dùng này.',
        );
      }
    }
  }

  Widget _buildFollowButton(PublicProfile profile) {
    if (_following) {
      return BounceTap(
        enabled: !_followBusy,
        child: OutlinedButton(
        onPressed: _followBusy ? null : _toggleFollow,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(38),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: AppColors.surface,
        ),
        child: _followBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 15, color: AppColors.textPrimary),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Đang theo dõi',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
      );
    }

    return BounceTap(
      enabled: !_followBusy,
      child: FilledButton(
      onPressed: _followBusy ? null : _toggleFollow,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(38),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _followBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Theo dõi',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    ),
    );
  }

  Widget _buildMessageButton(PublicProfile profile) {
    return BounceTap(
      child: OutlinedButton(
      onPressed: () => _openConversation(profile),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(38),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: AppColors.surface,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 15,
            color: AppColors.textPrimary,
          ),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Nhắn tin',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildFriendButton(PublicProfile profile) {
    final status = profile.friendshipStatus;
    final direction = profile.friendRequestDirection;
    final isAccepted = status == 'ACCEPTED';
    final isPending = status == 'PENDING';

    final String label;
    final IconData icon;
    final VoidCallback? onTap;

    if (isAccepted) {
      label = 'Bạn bè';
      icon = Icons.people_outline;
      onTap = _relationshipBusy ? null : () => _confirmUnfriend(profile);
    } else if (isPending && direction == 'sent') {
      label = 'Hủy lời mời';
      icon = Icons.schedule_outlined;
      onTap = _relationshipBusy ? null : () => _relationshipAction('cancel');
    } else if (isPending && direction == 'received') {
      label = 'Phản hồi';
      icon = Icons.how_to_reg_outlined;
      onTap = _relationshipBusy ? null : () => _showFriendRequestRespondModal(profile);
    } else {
      label = 'Kết bạn';
      icon = Icons.person_add_outlined;
      onTap = (_relationshipBusy || (!profile.canSendFriendRequest && status != null))
          ? null
          : () => _relationshipAction('send');
    }

    return BounceTap(
      enabled: onTap != null,
      child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(38),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide(
          color: (isPending && direction == 'received')
              ? AppColors.primary
              : AppColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: (isPending && direction == 'received')
            ? AppColors.primaryLight.withValues(alpha: 0.15)
            : AppColors.surface,
      ),
      child: _relationshipBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textPrimary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: (isPending && direction == 'received')
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: (isPending && direction == 'received')
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    ),
    );
  }

  void _showFriendRequestRespondModal(PublicProfile profile) {
    final displayName = profile.fullName?.trim().isNotEmpty == true
        ? profile.fullName!.trim()
        : '@${profile.effectiveHandle}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Lời mời kết bạn từ $displayName',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1, color: AppColors.hairlineSoft),
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                title: const Text(
                  'Chấp nhận lời mời',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _relationshipAction('accept');
                },
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                title: const Text('Từ chối lời mời'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _relationshipAction('decline');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUnfriend(PublicProfile profile) async {
    final displayName = profile.fullName?.trim().isNotEmpty == true
        ? profile.fullName!.trim()
        : '@${profile.effectiveHandle}';
    final confirmed = await AppDialog.showConfirm(
      context,
      type: AppDialogType.danger,
      title: 'Hủy kết bạn',
      message: 'Bạn có chắc chắn muốn hủy kết bạn với $displayName không?',
      confirmText: 'Hủy kết bạn',
      cancelText: 'Đóng',
    );
    if (confirmed == true) {
      await _relationshipAction('unfriend');
    }
  }

  Future<void> _openUsers(bool followers) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserListScreen(
          userId: widget.userId,
          followers: followers,
          repository: _repo,
          authNotifier: widget.authNotifier,
          onUserSelected: _openSelectedProfile,
        ),
      ),
    );
    _load();
  }

  void _openSelectedProfile(PublicUserSummary user) {
    final currentUserId = int.tryParse(
      '${widget.authNotifier?.currentUser?['userId'] ?? ''}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            currentUserId == user.userId && widget.authNotifier != null
            ? ProfileScreen(authNotifier: widget.authNotifier!)
            : PublicProfileScreen(
                userId: user.userId,
                authNotifier: widget.authNotifier,
                repository: _repo,
              ),
      ),
    );
  }

  Widget _statItem(String label, int count, {VoidCallback? onTap}) {
    return BounceTap(
      enabled: onTap != null,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    if (_error != null || profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message: _error ?? 'Không tìm thấy hồ sơ.',
          onRetry: _load,
        ),
      );
    }
    final handleDisplay = profile.effectiveHandle.isNotEmpty
        ? profile.effectiveHandle
        : 'user';
    final name = profile.fullName?.trim().isNotEmpty == true
        ? profile.fullName!.trim()
        : '@$handleDisplay';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppColors.hairlineSoft),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: () async {
              await _load();
              if (_selectedTab == 1) {
                await _loadPosts(refresh: true);
              }
            },
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: _buildHeader(profile, name, handleDisplay),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: ProfileTabBarDelegate(
                      child: _buildTabBar(),
                    ),
                  ),
                ];
              },
              body: _selectedTab == 0
                  ? _buildItinerariesTab()
                  : _buildPostsTab(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    PublicProfile profile,
    String name,
    String handleDisplay,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instagram-inspired Header
          Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.surfaceStrong,
                backgroundImage: profile.avatar?.isNotEmpty == true
                    ? NetworkImage(profile.avatar!)
                    : null,
                child: profile.avatar?.isNotEmpty == true
                    ? null
                    : const Icon(
                        Icons.person_outline,
                        size: 38,
                        color: AppColors.textSecondary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _statItem('Lịch trình', _itineraries.length),
                    ),
                    Expanded(
                      child: _statItem(
                        'Người theo dõi',
                        profile.followerCount,
                        onTap: () => _openUsers(true),
                      ),
                    ),
                    Expanded(
                      child: _statItem(
                        'Đang theo dõi',
                        profile.followingCount,
                        onTap: () => _openUsers(false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name & Handle
          Text(
            name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@$handleDisplay',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (profile.bio?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              profile.bio!.trim(),
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Action Buttons: 3 buttons on one single row
          if (!profile.isOwnProfile) ...[
            Row(
              children: [
                Expanded(child: _buildFollowButton(profile)),
                const SizedBox(width: 8),
                Expanded(child: _buildMessageButton(profile)),
                const SizedBox(width: 8),
                Expanded(child: _buildFriendButton(profile)),
              ],
            ),
          ],
          if (profile.isOwnProfile && widget.authNotifier != null)
            BounceTap(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProfileScreen(authNotifier: widget.authNotifier!),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Chỉnh sửa hồ sơ'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(38),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.hairlineSoft, width: 0.5),
          bottom: BorderSide(color: AppColors.hairlineSoft, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: BounceTap(
              useSelectionHaptic: true,
              child: InkWell(
                onTap: () => setState(() => _selectedTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _selectedTab == 0
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: _selectedTab == 0
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Lịch trình',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _selectedTab == 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: BounceTap(
              useSelectionHaptic: true,
              child: InkWell(
                onTap: () {
                  setState(() => _selectedTab = 1);
                  if (_posts.isEmpty && !_loadingPosts) {
                    _loadPosts();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _selectedTab == 1
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 18,
                        color: _selectedTab == 1
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bài viết',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _selectedTab == 1
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItinerariesTab() {
    if (_itineraries.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(24),
          child: AppEmptyState(
            title: 'Chưa có lịch trình công khai',
            message: 'Các lịch trình công khai của người dùng sẽ hiện ở đây.',
            icon: Icons.luggage_outlined,
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200 &&
            !_loadingMore &&
            _hasMore) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        key: const PageStorageKey('public_profile_itineraries'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount:
            _itineraries.length + (_loadingMore || _moreError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _itineraries.length) {
            if (_moreError != null) {
              return Center(
                child: BounceTap(
                  child: TextButton(
                    onPressed: () {
                      setState(() => _moreError = null);
                      _loadMore();
                    },
                    child: const Text('Thử tải thêm'),
                  ),
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.base),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _itineraries[index];
          return ItineraryCard(
            itinerary: item,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ItineraryDetailScreen(
                  itineraryId: item.itineraryId,
                  initialSummary: item,
                  token: _token,
                  authNotifier: widget.authNotifier,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_loadingPosts && _posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_postsError != null && _posts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _postsError!,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              BounceTap(
                child: OutlinedButton(
                  onPressed: () => _loadPosts(refresh: true),
                  child: const Text('Thử lại'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(24),
          child: AppEmptyState(
            title: 'Chưa có bài viết nào',
            message: 'Người dùng này chưa chia sẻ bài viết nào.',
            icon: Icons.article_outlined,
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200 &&
            !_loadingPosts &&
            _hasMorePosts) {
          _loadPosts();
        }
        return false;
      },
      child: ListView.separated(
        key: const PageStorageKey('public_profile_posts'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _posts.length + (_hasMorePosts ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
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

          final post = _posts[index];
          return PostCardWidget(
            post: post,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            onLike: () => _likePost(post),
            onComment: () => _openPostComments(post),
            onShare: () => _openSharePost(post),
            onEdit: null,
            onDelete: null,
            onReport: () => _openReport(post),
            onItineraryTap: (itineraryId) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ItineraryDetailScreen(
                    itineraryId: itineraryId,
                    token: _token,
                    authNotifier: widget.authNotifier,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
