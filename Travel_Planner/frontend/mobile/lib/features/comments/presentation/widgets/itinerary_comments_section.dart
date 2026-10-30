import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/itinerary_comment.dart';
import '../comments_notifier.dart';

class ItineraryCommentsSection extends StatefulWidget {
  final int itineraryId;
  final String? token;
  final AuthNotifier? authNotifier;

  const ItineraryCommentsSection({
    super.key,
    required this.itineraryId,
    this.token,
    this.authNotifier,
  });

  @override
  State<ItineraryCommentsSection> createState() => _ItineraryCommentsSectionState();
}

class _ItineraryCommentsSectionState extends State<ItineraryCommentsSection> {
  late final CommentsNotifier _notifier;
  final TextEditingController _controller = TextEditingController();
  String? get _token => widget.token ?? widget.authNotifier?.token;
  bool get _isAuthenticated => _token?.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _notifier = CommentsNotifier(itineraryId: widget.itineraryId)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _notifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await _notifier.submit(_controller.text, _token);
    if (success && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _notifier,
        if (widget.authNotifier != null) widget.authNotifier!,
      ]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bình luận (${_notifier.totalElements})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            if (_isAuthenticated) _buildComposer() else _buildLoginPrompt(),
            if (_notifier.isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_notifier.errorMessage != null && _notifier.comments.isEmpty)
              _buildError()
            else if (_notifier.comments.isEmpty)
              const AppEmptyState(
                title: 'Chưa có bình luận',
                message: 'Hãy chia sẻ suy nghĩ đầu tiên về lịch trình này.',
                icon: Icons.mode_comment_outlined,
              )
            else ...[
              const SizedBox(height: 8),
              for (final comment in _notifier.comments) _CommentTile(comment: comment),
              if (_notifier.hasMore)
                Center(
                  child: TextButton.icon(
                    onPressed: _notifier.isLoadingMore ? null : _notifier.loadMore,
                    icon: _notifier.isLoadingMore
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Chia sẻ cảm nhận của bạn…',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                          color: Colors.white,
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
          padding: const EdgeInsets.only(top: 6),
          child: Text(_notifier.submitError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ),
    ],
  );

  Widget _buildLoginPrompt() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(8)),
    child: const Text('Đăng nhập để tham gia bình luận.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
  );

  Widget _buildError() => Column(
    children: [
      Text(_notifier.errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
      TextButton(onPressed: () => _notifier.load(refresh: true), child: const Text('Thử lại')),
    ],
  );
}

class _CommentTile extends StatelessWidget {
  final ItineraryComment comment;

  const _CommentTile({required this.comment});

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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceStrong,
            backgroundImage: comment.avatar?.isNotEmpty == true ? NetworkImage(comment.avatar!) : null,
            child: comment.avatar?.isNotEmpty == true
                ? null
                : const Icon(Icons.person_outline, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    Text(timeLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textBody)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
