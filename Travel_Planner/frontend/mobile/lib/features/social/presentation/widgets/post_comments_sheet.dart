import 'package:flutter/material.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/community_post_repository.dart';
import '../../data/models/post_comment_model.dart';
import '../community_feed_notifier.dart';

class PostCommentsSheet extends StatefulWidget {
  final int postId;
  final String? token;
  final CommunityPostRepository repository;
  final CommunityFeedNotifier? notifier;
  final void Function(int delta)? onCommentCountChanged;

  const PostCommentsSheet({
    super.key,
    required this.postId,
    required this.token,
    required this.repository,
    this.notifier,
    this.onCommentCountChanged,
  });

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<PostCommentModel> _comments = [];
  PostCommentModel? _replyTo;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _startReply(PostCommentModel comment) {
    setState(() => _replyTo = comment);
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.repository.getComments(
        widget.postId,
        token: widget.token,
      );
      if (mounted) {
        setState(() {
          _comments = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải bình luận';
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || widget.token == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      final comment = await widget.repository.addComment(
        widget.postId,
        content: text,
        parentCommentId: _replyTo?.commentId,
        token: widget.token!,
      );
      if (mounted) {
        setState(() {
          _comments.add(comment);
          _commentController.clear();
          _replyTo = null;
          _submitting = false;
        });
        widget.notifier?.updateCommentCount(widget.postId, 1);
        widget.onCommentCountChanged?.call(1);
        AppSyncBus.emitPostCommentChanged(widget.postId, 1);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi bình luận. Vui lòng thử lại.')),
        );
      }
    }
  }

  Future<void> _deleteComment(PostCommentModel comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa bình luận này không?'),
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

    if (confirmed != true || widget.token == null) return;

    try {
      await widget.repository.deleteComment(
        widget.postId,
        comment.commentId,
        token: widget.token!,
      );
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) =>
              c.commentId == comment.commentId ||
              c.rootCommentId == comment.commentId ||
              c.parentCommentId == comment.commentId);
          if (_replyTo?.commentId == comment.commentId) {
            _replyTo = null;
          }
        });
        widget.notifier?.updateCommentCount(widget.postId, -1);
        widget.onCommentCountChanged?.call(-1);
        AppSyncBus.emitPostCommentChanged(widget.postId, -1);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa bình luận')),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${time.day}/${time.month}';
  }

  Widget _buildCommentItem(PostCommentModel comment, {bool isReply = false}) {
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 36.0 : 0.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 16,
            backgroundColor: AppColors.surfaceStrong,
            backgroundImage: comment.author.avatar != null && comment.author.avatar!.isNotEmpty
                ? NetworkImage(comment.author.avatar!)
                : null,
            child: comment.author.avatar == null || comment.author.avatar!.isEmpty
                ? Icon(Icons.person, size: isReply ? 16 : 18, color: AppColors.muted)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.author.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(comment.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          const Spacer(),
                          if (comment.isOwner)
                            InkWell(
                              onTap: () => _deleteComment(comment),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (comment.parentCommentId != null && comment.replyToUser != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Trả lời @${comment.replyToUser!.displayName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.token != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: InkWell(
                      onTap: () => _startReply(comment),
                      child: const Text(
                        'Trả lời',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final availableHeight = (screenHeight - keyboardHeight).clamp(0.0, screenHeight);
    final sheetHeight = keyboardHeight > 0
        ? (availableHeight * 0.92).clamp(240.0, availableHeight)
        : (screenHeight * 0.75).clamp(240.0, screenHeight * 0.85);

    final rootComments = _comments.where((c) => c.parentCommentId == null).toList();
    final orphanReplies = _comments
        .where((c) =>
            c.parentCommentId != null &&
            !rootComments.any((r) => r.commentId == (c.rootCommentId ?? c.parentCommentId)))
        .toList();
    final displayRoots = [...rootComments, ...orphanReplies];

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Bình luận',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.hairlineSoft),

            // Threaded Comments List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: TextButton(
                            onPressed: _loadComments,
                            child: Text(_error!),
                          ),
                        )
                      : displayRoots.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa có bình luận nào. Hãy là người đầu tiên!',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(16),
                              itemCount: displayRoots.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final root = displayRoots[index];
                                final replies = _comments
                                    .where((c) =>
                                        c != root &&
                                        (c.rootCommentId == root.commentId ||
                                            c.parentCommentId == root.commentId))
                                    .toList();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCommentItem(root, isReply: false),
                                    for (final reply in replies) ...[
                                      const SizedBox(height: 8),
                                      _buildCommentItem(reply, isReply: true),
                                    ],
                                  ],
                                );
                              },
                            ),
            ),

            // Bottom Input Field with Reply Preview
            if (widget.token != null)
              SafeArea(
                top: false,
                bottom: keyboardHeight == 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                        top: BorderSide(color: AppColors.hairlineSoft, width: 1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyTo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: AppColors.surfaceSoft,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Đang trả lời @${_replyTo!.author.displayName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
                                tooltip: 'Hủy trả lời',
                                onPressed: () => setState(() => _replyTo = null),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _inputFocusNode,
                                maxLines: 3,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: _replyTo != null
                                      ? 'Trả lời @${_replyTo!.author.displayName}...'
                                      : 'Viết bình luận...',
                                  hintStyle: const TextStyle(
                                      color: AppColors.muted, fontSize: 14),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  filled: true,
                                  fillColor: AppColors.surfaceSoft,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _submitting
                                ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.send_rounded,
                                        color: AppColors.primary),
                                    onPressed: _submitComment,
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
