import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/community_post_repository.dart';
import '../../data/models/post_comment_model.dart';
import '../community_feed_notifier.dart';

class PostCommentsSheet extends StatefulWidget {
  final int postId;
  final String? token;
  final CommunityPostRepository repository;
  final CommunityFeedNotifier notifier;

  const PostCommentsSheet({
    super.key,
    required this.postId,
    required this.token,
    required this.repository,
    required this.notifier,
  });

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<PostCommentModel> _comments = [];
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
    super.dispose();
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
        token: widget.token!,
      );
      if (mounted) {
        setState(() {
          _comments.add(comment);
          _commentController.clear();
          _submitting = false;
        });
        widget.notifier.updateCommentCount(widget.postId, 1);
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
          _comments.removeWhere((c) => c.commentId == comment.commentId);
        });
        widget.notifier.updateCommentCount(widget.postId, -1);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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

          // Flat Comments List
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
                    : _comments.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có bình luận nào. Hãy là người đầu tiên!',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.surfaceStrong,
                                    backgroundImage: comment.author.avatar != null &&
                                            comment.author.avatar!.isNotEmpty
                                        ? NetworkImage(comment.author.avatar!)
                                        : null,
                                    child: comment.author.avatar == null ||
                                            comment.author.avatar!.isEmpty
                                        ? const Icon(Icons.person, size: 18, color: AppColors.muted)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
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
                                  ),
                                ],
                              );
                            },
                          ),
          ),

          // Bottom Input Field
          if (widget.token != null)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.hairlineSoft, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Viết bình luận...',
                          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                            onPressed: _submitComment,
                          ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
