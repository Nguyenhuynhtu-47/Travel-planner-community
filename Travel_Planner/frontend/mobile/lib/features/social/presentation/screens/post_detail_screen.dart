import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_header_button.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../messaging/presentation/widgets/share_bottom_sheet.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../data/community_post_repository.dart';
import '../../data/models/post_comment_model.dart';
import '../../data/models/post_model.dart';
import '../widgets/report_post_dialog.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final AuthNotifier? authNotifier;
  final CommunityPostRepository? repository;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.authNotifier,
    this.repository,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final CommunityPostRepository _repository =
      widget.repository ?? CommunityPostRepository();

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  PostModel? _post;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isNotFound = false;

  List<PostCommentModel> _comments = [];
  bool _loadingComments = false;
  bool _submittingComment = false;
  PostCommentModel? _replyTo;
  final Map<int, List<PostCommentModel>> _repliesByRoot = {};
  final Set<int> _loadingReplyRoots = {};
  final Set<int> _likedCommentIds = {};

  String? get _token => widget.authNotifier?.token;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPost() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isNotFound = false;
    });

    try {
      final post = await _repository.getPostById(widget.postId, token: _token);
      if (!mounted) return;
      setState(() {
        _post = post;
        _isLoading = false;
      });
      _loadComments();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.statusCode == 404 || e.statusCode == 403) {
          _isNotFound = true;
          _errorMessage = e.message.isNotEmpty
              ? e.message
              : 'Bài viết không tồn tại, đã bị ẩn hoặc bạn không có quyền xem.';
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải bài viết. Vui lòng thử lại sau.';
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final result = await _repository.getComments(
        widget.postId,
        page: 0,
        size: 30,
        token: _token,
      );
      if (!mounted) return;
      setState(() {
        _comments = result.comments;
        _loadingComments = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _loadReplies(int rootCommentId) async {
    if (_loadingReplyRoots.contains(rootCommentId)) return;
    setState(() => _loadingReplyRoots.add(rootCommentId));
    try {
      final result = await _repository.getCommentReplies(
        widget.postId,
        rootCommentId,
        page: 0,
        token: _token,
      );
      if (!mounted) return;
      setState(() {
        _repliesByRoot[rootCommentId] = result.comments;
      });
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Không thể tải phản hồi.');
      }
    } finally {
      if (mounted) setState(() => _loadingReplyRoots.remove(rootCommentId));
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submittingComment) return;
    final token = _token;
    if (token == null || token.isEmpty) {
      AppToast.showInfo(context, 'Vui lòng đăng nhập để bình luận.');
      return;
    }

    setState(() => _submittingComment = true);
    try {
      final created = await _repository.addComment(
        widget.postId,
        content: text,
        parentCommentId: _replyTo?.commentId,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        if (_replyTo != null) {
          final rootId = _replyTo!.rootCommentId ?? _replyTo!.commentId;
          final existing = _repliesByRoot[rootId] ?? [];
          _repliesByRoot[rootId] = [...existing, created];
        } else {
          _comments = [..._comments, created];
        }
        if (_post != null) {
          _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
          AppSyncBus.emitPostUpdated(_post!, widget.postId);
        }
        _replyTo = null;
        _commentController.clear();
        _submittingComment = false;
      });
      _commentFocusNode.unfocus();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingComment = false);
      AppToast.showError(context, 'Không thể gửi bình luận. Vui lòng thử lại.');
    }
  }

  void _handleLike() {
    if (_post == null) return;
    if (_token == null || _token!.isEmpty) {
      AppToast.showInfo(context, 'Vui lòng đăng nhập để thích bài viết.');
      return;
    }
    final currentLiked = _post!.isLikedByMe;
    final newCount = currentLiked ? _post!.likeCount - 1 : _post!.likeCount + 1;
    setState(() {
      _post = _post!.copyWith(
        isLikedByMe: !currentLiked,
        likeCount: newCount < 0 ? 0 : newCount,
      );
    });
    if (currentLiked) {
      _repository.unlikePost(widget.postId, token: _token!);
    } else {
      _repository.likePost(widget.postId, token: _token!);
    }
  }

  void _focusCommentInput([PostCommentModel? replyTo]) {
    setState(() => _replyTo = replyTo);
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  void _openShare() {
    if (_post == null) return;
    final coverImage =
        _post!.mediaUrls.isNotEmpty ? _post!.mediaUrls.first : null;
    ShareBottomSheet.show(
      context,
      targetType: 'POST',
      targetId: widget.postId,
      title: 'Bài viết của ${_post!.author.displayName}',
      subtitle: _post!.content.isNotEmpty ? _post!.content : null,
      coverImage: coverImage,
      authNotifier: widget.authNotifier,
    ).then((shared) {
      if (shared == true && mounted) {
        _fetchPost();
      }
    });
  }

  Future<void> _openPostOptions() async {
    final options = <AppBottomSheetOption<String>>[
      if (_token != null && _token!.isNotEmpty)
        const AppBottomSheetOption(
          value: 'report',
          icon: Icons.flag_outlined,
          label: 'Báo cáo bài viết',
          isDestructive: true,
        ),
      const AppBottomSheetOption(
        value: 'share',
        icon: Icons.share_outlined,
        label: 'Chia sẻ bài viết',
      ),
    ];

    final selected = await AppBottomSheet.showOptions<String>(
      context,
      title: 'Tùy chọn bài viết',
      options: options,
    );
    if (!mounted || selected == null) return;
    if (selected == 'report') {
      _openReport();
    } else if (selected == 'share') {
      _openShare();
    }
  }

  void _openReport() {
    if (_token == null) return;
    ReportPostDialog.show(
      context,
      postId: widget.postId,
      token: _token!,
      repository: _repository,
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

  void _openUserProfile(int userId) {
    final currentUserId = int.tryParse(
      '${widget.authNotifier?.currentUser?['userId'] ?? ''}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => currentUserId == userId && widget.authNotifier != null
            ? ProfileScreen(authNotifier: widget.authNotifier!)
            : PublicProfileScreen(
                userId: userId,
                authNotifier: widget.authNotifier,
              ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  IconData _visibilityIcon(String visibility) {
    return switch (visibility.toUpperCase()) {
      'FRIENDS' => Icons.group_outlined,
      'PRIVATE' => Icons.lock_outline,
      _ => Icons.public,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text(
            'Chi tiết bài viết',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 58,
          leading: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Center(child: AppHeaderBackButton()),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFEBEBEF)),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFA3E62)),
      );
    }

    if (_isNotFound || _post == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: AppColors.muted),
              const SizedBox(height: 16),
              const Text(
                'Bài viết không khả dụng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ??
                    'Bài viết này đã bị xóa, bị ẩn hoặc bạn không có quyền xem.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              BounceTap(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Quay lại'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            BounceTap(
              child: ElevatedButton(
                onPressed: _fetchPost,
                child: const Text('Thử lại'),
              ),
            ),
          ],
        ),
      );
    }

    final post = _post!;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFFA3E62),
            onRefresh: _fetchPost,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAuthorHeader(post),
                  if (post.content.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                      child: Text(
                        post.content.trim(),
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.45,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ),
                  if (post.mediaUrls.isNotEmpty) _buildEdgeToEdgeMedia(post),
                  if (post.itinerary != null)
                    _buildAttachedItinerary(post.itinerary!),
                  _buildReactionStats(post),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0xFFEFEFF4),
                  ),
                  _buildActionBar(post),
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      border: Border(
                        top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                        bottom: BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                  _buildInlineCommentsSection(),
                ],
              ),
            ),
          ),
        ),
        _buildBottomCommentBar(),
      ],
    );
  }

  Widget _buildAuthorHeader(PostModel post) {
    final avatar = post.author.avatar?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      child: Row(
        children: [
          BounceTap(
            child: GestureDetector(
              onTap: () => _openUserProfile(post.author.userId),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceStrong,
                  border: Border.all(color: const Color(0xFFEFEFF4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar.isNotEmpty
                    ? Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person,
                          color: AppColors.muted,
                        ),
                      )
                    : const Icon(Icons.person, color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BounceTap(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openUserProfile(post.author.userId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _formatTimeAgo(post.createdAt),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                        const Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                        Icon(
                          _visibilityIcon(post.visibility),
                          size: 13,
                          color: const Color(0xFF6E6E73),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          BounceTap.icon(
            child: IconButton(
              icon: const Icon(Icons.more_horiz, color: Color(0xFF6E6E73)),
              onPressed: _openPostOptions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeToEdgeMedia(PostModel post) {
    final urls = post.mediaUrls;
    final tags = List.generate(
      urls.length,
      (i) => 'post_detail_${post.postId}_$i',
    );

    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => FullscreenImageViewer.open(
          context,
          urls: urls,
          initialIndex: 0,
          heroTags: tags,
        ),
        child: Hero(
          tag: tags[0],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Image.network(
              urls[0],
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 220,
                color: AppColors.surfaceStrong,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final displayCount = urls.length > 4 ? 4 : urls.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        final isOverflowTile = index == 3 && urls.length > 4;
        return GestureDetector(
          onTap: () => FullscreenImageViewer.open(
            context,
            urls: urls,
            initialIndex: index,
            heroTags: tags,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: tags[index],
                child: Image.network(
                  urls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surfaceStrong,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              if (isOverflowTile)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: Text(
                    '+${urls.length - 4}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachedItinerary(PostItineraryModel itinerary) {
    final hasCover =
        itinerary.coverImage != null && itinerary.coverImage!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: BounceTap(
        child: Material(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _openItineraryDetail(itinerary.itineraryId),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEBEBEF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasCover
                        ? Image.network(
                            itinerary.coverImage!.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.map_outlined,
                              color: Color(0xFFFA3E62),
                            ),
                          )
                        : const Icon(
                            Icons.map_outlined,
                            color: Color(0xFFFA3E62),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itinerary.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${itinerary.totalDays} ngày • ${itinerary.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8E8E93),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionStats(PostModel post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFFFA3E62),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.favorite_rounded,
              size: 11,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${post.likeCount}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6E6E73),
            ),
          ),
          const Spacer(),
          Text(
            '${post.commentCount} bình luận • ${post.shareCount} lượt chia sẻ',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6E6E73),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _buildActionItem(
            icon: post.isLikedByMe
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: 'Thích',
            color: post.isLikedByMe
                ? const Color(0xFFFA3E62)
                : const Color(0xFF4B5563),
            onTap: _handleLike,
          ),
          _buildActionItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Bình luận',
            color: const Color(0xFF4B5563),
            onTap: () => _focusCommentInput(),
          ),
          _buildActionItem(
            icon: Icons.share_outlined,
            label: 'Chia sẻ',
            color: const Color(0xFF4B5563),
            onTap: _openShare,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: BounceTap(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineCommentsSection() {
    if (_loadingComments && _comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFA3E62)),
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: Text(
            'Chưa có bình luận nào. Hãy là người đầu tiên bình luận!',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF6E6E73)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final comment in _comments) ...[
            _buildCommentItem(comment),
            if (comment.replyCount > 0 &&
                !_repliesByRoot.containsKey(comment.commentId))
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 10),
                child: BounceTap(
                  child: GestureDetector(
                    onTap: () => _loadReplies(comment.commentId),
                    child: Text(
                      _loadingReplyRoots.contains(comment.commentId)
                          ? 'Đang tải phản hồi...'
                          : 'Xem ${comment.replyCount} phản hồi',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E6E73),
                      ),
                    ),
                  ),
                ),
              ),
            if (_repliesByRoot.containsKey(comment.commentId))
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Column(
                  children: _repliesByRoot[comment.commentId]!
                      .map((reply) => _buildCommentItem(reply, isReply: true))
                      .toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(PostCommentModel comment, {bool isReply = false}) {
    final avatar = comment.author.avatar?.trim() ?? '';
    final avatarSize = isReply ? 28.0 : 36.0;
    final isLiked = _likedCommentIds.contains(comment.commentId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BounceTap(
            child: GestureDetector(
              onTap: () => _openUserProfile(comment.author.userId),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceStrong,
                  border: Border.all(color: const Color(0xFFEFEFF4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar.isNotEmpty
                    ? Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person,
                          size: avatarSize * 0.55,
                          color: AppColors.muted,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: avatarSize * 0.55,
                        color: AppColors.muted,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.author.displayName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.content,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 5),
                  child: Row(
                    children: [
                      Text(
                        _formatTimeAgo(comment.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                      const SizedBox(width: 14),
                      BounceTap(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isLiked) {
                                _likedCommentIds.remove(comment.commentId);
                              } else {
                                _likedCommentIds.add(comment.commentId);
                              }
                            });
                          },
                          child: Text(
                            'Thích',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isLiked
                                  ? const Color(0xFFFA3E62)
                                  : const Color(0xFF6E6E73),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      BounceTap(
                        child: GestureDetector(
                          onTap: () => _focusCommentInput(comment),
                          child: const Text(
                            'Trả lời',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6E6E73),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCommentBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEBEBEF), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 10, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đang trả lời ${_replyTo!.author.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6E73),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    BounceTap.icon(
                      child: InkWell(
                        onTap: () => setState(() => _replyTo = null),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF1E1E1E),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
                        hintStyle: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF8E8E93),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BounceTap.icon(
                    enabled: !_submittingComment,
                    child: Material(
                      color: const Color(0xFFFA3E62),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _submittingComment ? null : _submitComment,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: _submittingComment
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
