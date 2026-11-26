import 'package:flutter/material.dart';

import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/app_dialog.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';
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
  final Map<int, List<PostCommentModel>> _repliesByRoot = {};
  final Map<int, PostCommentModel> _collapsedReplyPreviews = {};
  final Map<int, int> _replyPageByRoot = {};
  final Map<int, bool> _replyHasMoreByRoot = {};
  final Map<int, String> _replyErrorsByRoot = {};
  final Set<int> _expandedRoots = {};
  final Set<int> _loadingReplyRoots = {};
  PostCommentModel? _replyTo;
  bool _loading = true;
  bool _loadingMoreRoots = false;
  bool _hasMoreRoots = false;
  int _rootPage = 0;
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

  Future<void> _loadComments({bool append = false}) async {
    if (_loadingMoreRoots || (append && !_hasMoreRoots)) return;
    final requestedPage = append ? _rootPage + 1 : 0;
    setState(() {
      if (append) {
        _loadingMoreRoots = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    try {
      final result = await widget.repository.getComments(
        widget.postId,
        page: requestedPage,
        token: widget.token,
      );
      if (mounted) {
        setState(() {
          if (append) {
            final existingIds = _comments
                .map((comment) => comment.commentId)
                .toSet();
            _comments.addAll(
              result.comments.where(
                (comment) => !existingIds.contains(comment.commentId),
              ),
            );
          } else {
            _comments = result.comments;
          }
          _rootPage = result.pageNumber;
          _hasMoreRoots = !result.last;
          _loading = false;
          _loadingMoreRoots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!append) _error = 'Không thể tải bình luận';
          _loading = false;
          _loadingMoreRoots = false;
        });
      }
    }
  }

  Future<void> _toggleReplies(PostCommentModel root) async {
    final rootId = root.commentId;
    if (_expandedRoots.contains(rootId)) {
      setState(() => _expandedRoots.remove(rootId));
      return;
    }
    setState(() => _expandedRoots.add(rootId));
    if (root.replyCount > 0 && !_replyPageByRoot.containsKey(rootId)) {
      await _loadReplies(rootId, page: 0);
    }
  }

  Future<void> _loadReplies(int rootId, {required int page}) async {
    if (_loadingReplyRoots.contains(rootId)) return;
    setState(() {
      _loadingReplyRoots.add(rootId);
      _replyErrorsByRoot.remove(rootId);
    });
    try {
      final result = await widget.repository.getCommentReplies(
        widget.postId,
        rootId,
        page: page,
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        final preview = _collapsedReplyPreviews[rootId];
        final current = page == 0
            ? <PostCommentModel>[?preview]
            : (_repliesByRoot[rootId] ?? []);
        final existingIds = current.map((comment) => comment.commentId).toSet();
        current.addAll(
          result.comments.where(
            (comment) => !existingIds.contains(comment.commentId),
          ),
        );
        _repliesByRoot[rootId] = current;
        _replyPageByRoot[rootId] = result.pageNumber;
        _replyHasMoreByRoot[rootId] = !result.last;
        _loadingReplyRoots.remove(rootId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _replyErrorsByRoot[rootId] = 'Không thể tải câu trả lời';
        _loadingReplyRoots.remove(rootId);
      });
    }
  }

  int _rootIdFor(PostCommentModel comment) => comment.parentCommentId == null
      ? comment.commentId
      : comment.rootCommentId ?? comment.parentCommentId!;

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
          if (_replyTo == null) {
            _comments.add(comment);
          } else {
            final rootId = _rootIdFor(_replyTo!);
            final replies = _repliesByRoot.putIfAbsent(rootId, () => []);
            final isDirectReply = _replyTo!.commentId == rootId;
            if (replies.every(
              (reply) => reply.commentId != comment.commentId,
            )) {
              if (isDirectReply) {
                replies.insert(0, comment);
                _collapsedReplyPreviews[rootId] = comment;
              } else {
                replies.add(comment);
              }
            }
            if (!isDirectReply) _expandedRoots.add(rootId);
            final rootIndex = _comments.indexWhere(
              (root) => root.commentId == rootId,
            );
            if (rootIndex >= 0) {
              _comments[rootIndex] = _comments[rootIndex].copyWith(
                replyCount: _comments[rootIndex].replyCount + 1,
              );
            }
            _replyHasMoreByRoot.putIfAbsent(rootId, () => false);
          }
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
        AppToast.showError(
          context,
          'Không thể gửi bình luận. Vui lòng thử lại.',
        );
      }
    }
  }

  Future<void> _deleteComment(PostCommentModel comment) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      type: AppDialogType.danger,
      title: 'Xác nhận xóa',
      message: 'Bạn có chắc chắn muốn xóa bình luận này không?',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
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
          final rootId = _rootIdFor(comment);
          if (comment.parentCommentId == null) {
            if (comment.replyCount > 0) {
              final rootIndex = _comments.indexWhere(
                (item) => item.commentId == rootId,
              );
              if (rootIndex >= 0) {
                _comments[rootIndex] = _comments[rootIndex].copyWith(
                  content: 'Bình luận đã bị xóa',
                  deleted: true,
                );
              }
              _expandedRoots.add(rootId);
            } else {
              _repliesByRoot.remove(rootId);
              _expandedRoots.remove(rootId);
              _comments.removeWhere((item) => item.commentId == rootId);
            }
          } else {
            _repliesByRoot[rootId]?.removeWhere(
              (item) => item.commentId == comment.commentId,
            );
            final rootIndex = _comments.indexWhere(
              (item) => item.commentId == rootId,
            );
            if (rootIndex >= 0) {
              _comments[rootIndex] = _comments[rootIndex].copyWith(
                replyCount: (_comments[rootIndex].replyCount - 1)
                    .clamp(0, 1 << 30)
                    .toInt(),
              );
            }
          }
          if (_replyTo?.commentId == comment.commentId) {
            _replyTo = null;
          }
        });
        widget.notifier?.updateCommentCount(widget.postId, -1);
        widget.onCommentCountChanged?.call(-1);
        AppSyncBus.emitPostCommentChanged(widget.postId, -1);
        if (comment.parentCommentId == null &&
            comment.replyCount > 0 &&
            !_repliesByRoot.containsKey(comment.commentId)) {
          await _loadReplies(comment.commentId, page: 0);
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Không thể xóa bình luận');
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
            backgroundImage:
                comment.author.avatar != null &&
                    comment.author.avatar!.isNotEmpty
                ? NetworkImage(comment.author.avatar!)
                : null,
            child:
                comment.author.avatar == null || comment.author.avatar!.isEmpty
                ? Icon(
                    Icons.person,
                    size: isReply ? 16 : 18,
                    color: AppColors.muted,
                  )
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
                          if (comment.isOwner && !comment.deleted)
                            BounceTap.icon(
                              child: InkWell(
                                key: ValueKey(
                                  'delete_comment_${comment.commentId}',
                                ),
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
                            ),
                        ],
                      ),
                      if (comment.parentCommentId != null &&
                          comment.replyToUser != null) ...[
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
                if (widget.token != null && !comment.deleted)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: BounceTap(
                      child: InkWell(
                        key: ValueKey('reply_comment_${comment.commentId}'),
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
    final availableHeight = (screenHeight - keyboardHeight).clamp(
      0.0,
      screenHeight,
    );
    final sheetHeight = keyboardHeight > 0
        ? (availableHeight * 0.92).clamp(240.0, availableHeight)
        : (screenHeight * 0.75).clamp(240.0, screenHeight * 0.85);

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
                  BounceTap.icon(
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
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
                      child: BounceTap(
                        child: TextButton(
                          onPressed: _loadComments,
                          child: Text(_error!),
                        ),
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
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _comments.length +
                          (_hasMoreRoots || _loadingMoreRoots ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        if (index >= _comments.length) {
                          return Center(
                            child: BounceTap(
                              enabled: !_loadingMoreRoots,
                              child: TextButton.icon(
                                onPressed: _loadingMoreRoots
                                    ? null
                                    : () => _loadComments(append: true),
                                icon: _loadingMoreRoots
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more),
                                label: const Text('Xem thêm bình luận'),
                              ),
                            ),
                          );
                        }
                        final root = _comments[index];
                        final expanded = _expandedRoots.contains(
                          root.commentId,
                        );
                        final replies =
                            _repliesByRoot[root.commentId] ??
                            const <PostCommentModel>[];
                        final preview = _collapsedReplyPreviews[root.commentId];
                        final collapsedReplyCount =
                            (root.replyCount - (preview == null ? 0 : 1)).clamp(
                              0,
                              root.replyCount,
                            );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCommentItem(root, isReply: false),
                            if (!expanded && preview != null) ...[
                              const SizedBox(height: 8),
                              _buildCommentItem(preview, isReply: true),
                            ],
                            if (expanded
                                ? root.replyCount > 0 || replies.isNotEmpty
                                : collapsedReplyCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 58,
                                  top: 4,
                                ),
                                child: BounceTap(
                                  child: InkWell(
                                    onTap: () => _toggleReplies(root),
                                    child: Text(
                                      expanded
                                          ? 'Thu gọn câu trả lời'
                                          : preview == null
                                          ? 'Xem ${root.replyCount} câu trả lời'
                                          : 'Xem $collapsedReplyCount câu trả lời khác',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (expanded &&
                                _loadingReplyRoots.contains(root.commentId))
                              const Padding(
                                padding: EdgeInsets.only(left: 58, top: 8),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            if (expanded &&
                                _replyErrorsByRoot.containsKey(root.commentId))
                              BounceTap(
                                child: TextButton(
                                  onPressed: () => _loadReplies(
                                    root.commentId,
                                    page:
                                        _repliesByRoot.containsKey(root.commentId)
                                        ? (_replyPageByRoot[root.commentId] ??
                                                  -1) +
                                              1
                                        : 0,
                                  ),
                                  child: Text(
                                    _replyErrorsByRoot[root.commentId]!,
                                  ),
                                ),
                              ),
                            if (expanded)
                              for (final reply in replies) ...[
                                const SizedBox(height: 8),
                                _buildCommentItem(reply, isReply: true),
                              ],
                            if (expanded &&
                                (_replyHasMoreByRoot[root.commentId] ?? false))
                              Padding(
                                padding: const EdgeInsets.only(left: 58),
                                child: BounceTap(
                                  enabled: !_loadingReplyRoots.contains(
                                    root.commentId,
                                  ),
                                  child: TextButton(
                                    onPressed:
                                        _loadingReplyRoots.contains(
                                          root.commentId,
                                        )
                                        ? null
                                        : () => _loadReplies(
                                            root.commentId,
                                            page:
                                                (_replyPageByRoot[root
                                                        .commentId] ??
                                                    0) +
                                                1,
                                          ),
                                    child: const Text('Xem thêm câu trả lời'),
                                  ),
                                ),
                              ),
                            if (expanded &&
                                replies.isEmpty &&
                                !_loadingReplyRoots.contains(root.commentId) &&
                                !_replyErrorsByRoot.containsKey(root.commentId))
                              const Padding(
                                padding: EdgeInsets.only(left: 58, top: 6),
                                child: Text(
                                  'Chưa có câu trả lời nào.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
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
                      top: BorderSide(color: AppColors.hairlineSoft, width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyTo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
                              BounceTap.icon(
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppColors.muted,
                                  ),
                                  tooltip: 'Hủy trả lời',
                                  onPressed: () =>
                                      setState(() => _replyTo = null),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                                    color: AppColors.muted,
                                    fontSize: 14,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : BounceTap.icon(
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.send_rounded,
                                        color: AppColors.primary,
                                      ),
                                      onPressed: _submitComment,
                                    ),
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
