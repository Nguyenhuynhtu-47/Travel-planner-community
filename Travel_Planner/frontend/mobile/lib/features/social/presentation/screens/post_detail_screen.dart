import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../messaging/presentation/widgets/share_bottom_sheet.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../data/community_post_repository.dart';
import '../../data/models/post_model.dart';
import '../widgets/post_card_widget.dart';
import '../widgets/post_comments_sheet.dart';
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

  PostModel? _post;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isNotFound = false;

  String? get _token => widget.authNotifier?.token;

  @override
  void initState() {
    super.initState();
    _fetchPost();
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

  void _handleLike() {
    if (_post == null || _token == null) return;
    final currentLiked = _post!.isLikedByMe;
    final newCount = currentLiked ? _post!.likeCount - 1 : _post!.likeCount + 1;
    setState(() {
      _post = _post!.copyWith(
        isLikedByMe: !currentLiked,
        likeCount: newCount < 0 ? 0 : newCount,
      );
    });
    // In background, call toggleLike
    if (currentLiked) {
      _repository.unlikePost(widget.postId, token: _token!);
    } else {
      _repository.likePost(widget.postId, token: _token!);
    }
  }

  void _openComments() {
    if (_post == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostCommentsSheet(
        postId: widget.postId,
        token: _token,
        repository: _repository,
      ),
    ).then((_) {
      // Re-fetch post to update comment count
      _fetchPost();
    });
  }

  void _openShare() {
    if (_post == null) return;
    final coverImage = _post!.mediaUrls.isNotEmpty ? _post!.mediaUrls.first : null;
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

  void _openReport() {
    if (_token == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => ReportPostDialog(
        postId: widget.postId,
        token: _token!,
        repository: _repository,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chi tiết bài viết',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
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
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Quay lại'),
                onPressed: () => Navigator.of(context).pop(),
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
            ElevatedButton(
              onPressed: _fetchPost,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchPost,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PostCardWidget(
              post: _post!,
              onLike: _handleLike,
              onComment: _openComments,
              onShare: _openShare,
              onReport: _openReport,
              onItineraryTap: _openItineraryDetail,
              onUserTap: _openUserProfile,
            ),
            const SizedBox(height: 12),
            // Comments trigger section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.hairlineSoft),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(
                  _post!.commentCount > 0
                      ? 'Xem tất cả ${_post!.commentCount} bình luận'
                      : 'Viết bình luận đầu tiên...',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                onPressed: _openComments,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
