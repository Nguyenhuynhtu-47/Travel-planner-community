import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/bounce_tap.dart';
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
  final GlobalKey _composerKey = GlobalKey();
  ItineraryComment? _replyTo;
  bool _isCommentsExpanded = false;
  String? get _token => widget.token ?? widget.authNotifier?.token;
  bool get _isAuthenticated => _token?.isNotEmpty ?? false;
  String get _replyDisplayName => _replyTo?.displayName ?? 'người dùng';

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
      setState(() {
        _replyTo = null;
        _isCommentsExpanded = true;
      });
    }
  }

  void _startReply(ItineraryComment comment) {
    setState(() => _replyTo = comment);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_composerFocus);
      final composerContext = _composerKey.currentContext;
      if (composerContext != null) {
        Scrollable.ensureVisible(
          composerContext,
          alignment: 0.85,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
      builder: (context, _) => widget.activityId == null
          ? _buildItinerarySection()
          : _buildActivitySection(),
    );
  }

  Widget _buildItinerarySection() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(),
        const SizedBox(height: 14),
        if (_isAuthenticated) _buildComposer() else _buildLoginPrompt(),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildCommentItems(),
          ),
        ),
      ],
    ),
  );

  Widget _buildActivitySection() => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.base,
      AppSpacing.md,
      AppSpacing.base,
      0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            children: _buildCommentItems(),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairlineSoft)),
          ),
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: _isAuthenticated ? _buildComposer() : _buildLoginPrompt(),
        ),
      ],
    ),
  );

  Widget _buildSectionTitle() => Text(
    'Bình luận${widget.activityId == null ? '' : ' hoạt động'} (${_notifier.totalElements})',
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1E1E1E),
    ),
  );

  List<Widget> _buildCommentItems() {
    if (_notifier.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.base),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }
    if (_notifier.errorMessage != null && _notifier.comments.isEmpty) {
      return [_buildError()];
    }
    if (_notifier.comments.isEmpty) {
      return const [
        AppEmptyState(
          title: 'Chưa có bình luận',
          message: 'Hãy chia sẻ suy nghĩ đầu tiên về lịch trình này.',
          icon: Icons.mode_comment_outlined,
        ),
      ];
    }

    final isItineraryCollapsible = widget.activityId == null;
    final totalLoaded = _notifier.comments.length;
    final isCollapsed =
        isItineraryCollapsible && !_isCommentsExpanded && totalLoaded > 2;
    final displayedComments = isCollapsed
        ? _notifier.comments.take(2).toList()
        : _notifier.comments;
    final totalForCount = _notifier.totalElements > totalLoaded
        ? _notifier.totalElements
        : totalLoaded;
    final remainingCount = totalForCount - 2;

    return [
      const SizedBox(height: AppSpacing.sm),
      for (final comment in displayedComments)
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
      if (isCollapsed && remainingCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(
            child: BounceTap(
              child: Material(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => setState(() => _isCommentsExpanded = true),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xem thêm $remainingCount bình luận',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF1E1E1E),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      if (!isCollapsed && _notifier.hasMore)
        Center(
          child: BounceTap(
            enabled: !_notifier.isLoadingMore,
            child: TextButton.icon(
              onPressed: _notifier.isLoadingMore ? null : _notifier.loadMore,
              icon: _notifier.isLoadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                _notifier.errorMessage != null ? 'Thử lại' : 'Xem thêm bình luận',
              ),
            ),
          ),
        ),
      if (isItineraryCollapsible && _isCommentsExpanded && totalLoaded > 2)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(
            child: BounceTap(
              child: Material(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => setState(() => _isCommentsExpanded = false),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Thu gọn bình luận',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 18,
                          color: Color(0xFF6E6E73),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
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
                  'Đang trả lời @$_replyDisplayName',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              BounceTap.icon(
                child: IconButton(
                  onPressed: () => setState(() => _replyTo = null),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Hủy trả lời',
                ),
              ),
            ],
          ),
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: _composerKey,
              controller: _controller,
              focusNode: _composerFocus,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _replyTo == null
                    ? 'Viết bình luận…'
                    : 'Trả lời @$_replyDisplayName…',
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: Color(0xFFFA3E62),
                    width: 1.2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final isDisabled =
                  _notifier.isSubmitting || value.text.trim().isEmpty;
              return SizedBox(
                width: 44,
                height: 44,
                child: BounceTap.icon(
                  enabled: !isDisabled,
                  child: IconButton.filled(
                    tooltip: 'Gửi bình luận',
                    style: IconButton.styleFrom(
                      backgroundColor: isDisabled
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFFFA3E62),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                    ),
                    onPressed: isDisabled ? null : _submit,
                    icon: _notifier.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 19),
                  ),
                ),
              );
            },
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
    final name = comment.displayName;
    final date = comment.createdAt?.toLocal();
    final timeLabel = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BounceTap(
            enabled: onCreatorTap != null,
            child: GestureDetector(
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
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BounceTap(
                        enabled: onCreatorTap != null,
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
                      BounceTap(
                        enabled: onReply != null,
                        child: TextButton(
                          onPressed: onReply,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                          ),
                          child: const Text('Trả lời'),
                        ),
                      ),
                      if (canManage)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirm = await AppDialog.showConfirm(
                                context,
                                type: AppDialogType.danger,
                                title: 'Xóa bình luận?',
                                message:
                                    'Các câu trả lời vẫn được giữ trong cuộc trò chuyện.',
                                confirmText: 'Xóa',
                                cancelText: 'Hủy',
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
                                    BounceTap(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Hủy'),
                                      ),
                                    ),
                                    BounceTap(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(
                                          context,
                                          controller.text,
                                        ),
                                        child: const Text('Lưu'),
                                      ),
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

  void _startReply(ItineraryComment comment) {
    widget.onReply(comment);
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final canManage =
        widget.currentUserId != null && widget.currentUserId == comment.userId;
    final replies =
        widget.notifier.replies[comment.commentId] ??
        const <ItineraryComment>[];
    final preview = widget.notifier.collapsedReplyPreviews[comment.commentId];
    final collapsedReplyCount = (comment.replyCount - (preview == null ? 0 : 1))
        .clamp(0, comment.replyCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentTile(
          comment: comment,
          canManage: canManage,
          onReply: comment.deleted ? null : () => _startReply(comment),
          onCreatorTap: () => widget.onCreatorTap(comment.userId),
          onEdit: (text) => widget.notifier.updateComment(
            comment.commentId,
            text,
            widget.token,
          ),
          onDelete: () =>
              widget.notifier.deleteComment(comment.commentId, widget.token),
        ),
        if (!_expanded && preview != null)
          Container(
            margin: const EdgeInsets.only(left: 18),
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFFAD2DA), width: 2),
              ),
            ),
            child: _CommentTile(
              comment: preview,
              canManage:
                  widget.currentUserId != null &&
                  widget.currentUserId == preview.userId,
              onReply: () => _startReply(preview),
              onCreatorTap: () => widget.onCreatorTap(preview.userId),
              onEdit: (text) => widget.notifier.updateComment(
                preview.commentId,
                text,
                widget.token,
              ),
              onDelete: () => widget.notifier.deleteComment(
                preview.commentId,
                widget.token,
              ),
            ),
          ),
        if (_expanded
            ? comment.replyCount > 0 || replies.isNotEmpty
            : collapsedReplyCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xxl),
            child: BounceTap(
              child: TextButton.icon(
                onPressed: () async {
                  if (_expanded) {
                    setState(() => _expanded = false);
                  } else {
                    setState(() => _expanded = true);
                    if (!widget.notifier.hasLoadedReplies(comment.commentId)) {
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
                      : preview == null
                      ? 'Xem ${comment.replyCount} câu trả lời'
                      : 'Xem $collapsedReplyCount câu trả lời khác',
                ),
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
                onReply: () => _startReply(reply),
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
            BounceTap(
              child: TextButton(
                onPressed: () =>
                    widget.notifier.loadReplies(comment.commentId, refresh: true),
                child: const Text('Không tải được câu trả lời · Thử lại'),
              ),
            )
          else if (widget.notifier.repliesHaveMore(comment.commentId))
            BounceTap(
              child: TextButton(
                onPressed: () => widget.notifier.loadReplies(comment.commentId),
                child: const Text('Tải thêm câu trả lời'),
              ),
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
