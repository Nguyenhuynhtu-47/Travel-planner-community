import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/itinerary_comment.dart';
import '../../data/comments_repository.dart';
import '../comments_notifier.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class ItineraryCommentsSection extends StatefulWidget {
  final int? itineraryId;
  final int? activityId;
  final String? token;
  final AuthNotifier? authNotifier;
  final CommentsRepository? repository;

  const ItineraryCommentsSection({
    super.key,
    required this.itineraryId,
    this.token,
    this.authNotifier,
    this.repository,
  }) : activityId = null;

  const ItineraryCommentsSection.forActivity({
    super.key,
    required this.activityId,
    this.token,
    this.authNotifier,
    this.repository,
  }) : itineraryId = null;

  @override
  State<ItineraryCommentsSection> createState() =>
      _ItineraryCommentsSectionState();
}

class _ItineraryCommentsSectionState extends State<ItineraryCommentsSection> {
  late final CommentsNotifier _notifier;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  ItineraryComment? _replyTo;
  String? get _token => widget.token ?? widget.authNotifier?.token;
  bool get _isAuthenticated => _token?.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _notifier = widget.activityId != null
        ? CommentsNotifier.forActivity(
            activityId: widget.activityId!,
            repository: widget.repository,
          )
        : CommentsNotifier(
            itineraryId: widget.itineraryId!,
            repository: widget.repository,
          );
    _notifier.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _composerFocus.dispose();
    _notifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await _notifier.submit(
      _controller.text,
      _token,
      parentCommentId: _replyTo?.commentId,
    );
    if (success && mounted) {
      _controller.clear();
      setState(() => _replyTo = null);
    }
  }

  void _startReply(ItineraryComment comment) {
    setState(() => _replyTo = comment);
    FocusScope.of(context).requestFocus(_composerFocus);
  }

  void _openCreator(int? userId) {
    if (userId == null || userId <= 0) return;
    final currentId = int.tryParse(
      '${widget.authNotifier?.currentUser?['userId'] ?? ''}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => currentId == userId && widget.authNotifier != null
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        _notifier,
        if (widget.authNotifier != null) widget.authNotifier!,
      ]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.lg,
          AppSpacing.base,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bình luận${widget.activityId == null ? '' : ' hoạt động'} (${_notifier.totalElements})',
              style: AppTextStyles.titleMd.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isAuthenticated) _buildComposer() else _buildLoginPrompt(),
            if (_notifier.isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.base),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_notifier.errorMessage != null &&
                _notifier.comments.isEmpty)
              _buildError()
            else if (_notifier.comments.isEmpty)
              const AppEmptyState(
                title: 'Chưa có bình luận',
                message: 'Hãy chia sẻ suy nghĩ đầu tiên về lịch trình này.',
                icon: Icons.mode_comment_outlined,
              )
            else ...[
              const SizedBox(height: AppSpacing.sm),
              for (final comment in _notifier.comments)
                _CommentThread(
                  key: ValueKey('comment_thread_${comment.commentId}'),
                  comment: comment,
                  notifier: _notifier,
                  token: _token,
                  currentUserId: int.tryParse(
                    '${widget.authNotifier?.currentUser?['userId'] ?? ''}',
                  ),
                  onReply: _startReply,
                  onCreatorTap: _openCreator,
                ),
              if (_notifier.hasMore)
                Center(
                  child: TextButton.icon(
                    onPressed: _notifier.isLoadingMore
                        ? null
                        : _notifier.loadMore,
                    icon: _notifier.isLoadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(
                      _notifier.errorMessage != null
                          ? 'Thử lại'
                          : 'Xem thêm bình luận',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_replyTo != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Đang trả lời ${_replyTo!.fullName ?? _replyTo!.username ?? 'người dùng'}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _replyTo = null),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Hủy trả lời',
              ),
            ],
          ),
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _composerFocus,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Chia sẻ cảm nhận của bạn…',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                tooltip: 'Gửi bình luận',
                onPressed: _notifier.isSubmitting || value.text.trim().isEmpty
                    ? null
                    : _submit,
                icon: _notifier.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ],
      ),
      if (_notifier.submitError != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs + AppSpacing.xxs),
          child: Text(
            _notifier.submitError!,
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
        ),
    ],
  );

  Widget _buildLoginPrompt() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
    child: Text(
      'Đăng nhập để tham gia bình luận.',
      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
    ),
  );

  Widget _buildError() => AppErrorState(
    message: _notifier.errorMessage!,
    onRetry: () => _notifier.load(refresh: true),
  );
}

class _CommentTile extends StatelessWidget {
  final ItineraryComment comment;
  final VoidCallback? onReply;
  final bool canManage;
  final Future<bool> Function(String)? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCreatorTap;

  const _CommentTile({
    required this.comment,
    this.onReply,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
    this.onCreatorTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = comment.fullName?.trim().isNotEmpty == true
        ? comment.fullName!.trim()
        : comment.username ?? 'Người dùng';
    final date = comment.createdAt?.toLocal();
    final timeLabel = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onCreatorTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surfaceStrong,
              backgroundImage: comment.avatar?.isNotEmpty == true
                  ? NetworkImage(comment.avatar!)
                  : null,
              child: comment.avatar?.isNotEmpty == true
                  ? null
                  : const Icon(Icons.person_outline, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onCreatorTap,
                        child: Text(
                          name,
                          style: AppTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  comment.content,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textBody,
                  ),
                ),
                if (comment.parentCommentId != null &&
                    comment.replyToName != null)
                  Text(
                    'Trả lời @${comment.replyToName}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                if (!comment.deleted)
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      TextButton(
                        onPressed: onReply,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                        ),
                        child: const Text('Trả lời'),
                      ),
                      if (canManage)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Xóa bình luận?'),
                                  content: const Text(
                                    'Các câu trả lời vẫn được giữ trong cuộc trò chuyện.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                              if (!context.mounted) return;
                              if (confirm == true) onDelete?.call();
                            }
                            if (value == 'edit' && onEdit != null) {
                              final controller = TextEditingController(
                                text: comment.content,
                              );
                              final value = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Sửa bình luận'),
                                  content: TextField(
                                    controller: controller,
                                    maxLines: 4,
                                    maxLength: 2000,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Hủy'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(
                                        context,
                                        controller.text,
                                      ),
                                      child: const Text('Lưu'),
                                    ),
                                  ],
                                ),
                              );
                              if (!context.mounted) {
                                controller.dispose();
                                return;
                              }
                              controller.dispose();
                              if (value != null) await onEdit!(value);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Sửa')),
                            PopupMenuItem(value: 'delete', child: Text('Xóa')),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpacing.sm),
                            child: Icon(Icons.more_horiz, size: 18),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentThread extends StatefulWidget {
  final ItineraryComment comment;
  final CommentsNotifier notifier;
  final String? token;
  final int? currentUserId;
  final ValueChanged<ItineraryComment> onReply;
  final ValueChanged<int?> onCreatorTap;
  const _CommentThread({
    super.key,
    required this.comment,
    required this.notifier,
    required this.token,
    required this.currentUserId,
    required this.onReply,
    required this.onCreatorTap,
  });
  @override
  State<_CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<_CommentThread> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final canManage =
        widget.currentUserId != null && widget.currentUserId == comment.userId;
    final replies =
        widget.notifier.replies[comment.commentId] ??
        const <ItineraryComment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentTile(
          comment: comment,
          canManage: canManage,
          onReply: comment.deleted ? null : () => widget.onReply(comment),
          onCreatorTap: () => widget.onCreatorTap(comment.userId),
          onEdit: (text) => widget.notifier.updateComment(
            comment.commentId,
            text,
            widget.token,
          ),
          onDelete: () =>
              widget.notifier.deleteComment(comment.commentId, widget.token),
        ),
        if (comment.replyCount > 0 || replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xxl),
            child: TextButton.icon(
              onPressed: () async {
                if (_expanded) {
                  setState(() => _expanded = false);
                } else {
                  setState(() => _expanded = true);
                  if (replies.isEmpty) {
                    await widget.notifier.loadReplies(comment.commentId);
                  }
                }
              },
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.subdirectory_arrow_right,
                size: 17,
              ),
              label: Text(
                _expanded
                    ? 'Thu gọn câu trả lời'
                    : 'Xem ${comment.replyCount} câu trả lời',
              ),
            ),
          ),
        if (_expanded) ...[
          for (final reply in replies)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xl),
              child: _CommentTile(
                comment: reply,
                canManage:
                    widget.currentUserId != null &&
                    widget.currentUserId == reply.userId,
                onReply: () => widget.onReply(reply),
                onCreatorTap: () => widget.onCreatorTap(reply.userId),
                onEdit: (text) => widget.notifier.updateComment(
                  reply.commentId,
                  text,
                  widget.token,
                ),
                onDelete: () => widget.notifier.deleteComment(
                  reply.commentId,
                  widget.token,
                ),
              ),
            ),
          if (widget.notifier.loadingReplies.contains(comment.commentId))
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (widget.notifier.errorMessage != null && replies.isEmpty)
            TextButton(
              onPressed: () =>
                  widget.notifier.loadReplies(comment.commentId, refresh: true),
              child: const Text('Không tải được câu trả lời · Thử lại'),
            )
          else if (widget.notifier.repliesHaveMore(comment.commentId))
            TextButton(
              onPressed: () => widget.notifier.loadReplies(comment.commentId),
              child: const Text('Tải thêm câu trả lời'),
            ),
        ],
      ],
    );
  }
}

class ActivityCommentsSection extends StatelessWidget {
  final int activityId;
  final String? token;
  final AuthNotifier? authNotifier;
  final CommentsRepository? repository;
  const ActivityCommentsSection({
    super.key,
    required this.activityId,
    this.token,
    this.authNotifier,
    this.repository,
  });
  @override
  Widget build(BuildContext context) => ItineraryCommentsSection.forActivity(
    activityId: activityId,
    token: token,
    authNotifier: authNotifier,
    repository: repository,
  );
}
