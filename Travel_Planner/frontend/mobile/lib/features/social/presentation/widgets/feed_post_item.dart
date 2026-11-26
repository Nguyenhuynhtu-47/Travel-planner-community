import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_bottom_sheet.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/post_model.dart';
import 'fullscreen_image_viewer.dart';

/// Shared 8px full-bleed section divider between feed posts.
class FeedSectionDivider extends StatelessWidget {
  const FeedSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
    );
  }
}

/// Shared Facebook-style full-bleed post item used across Community and Profile feeds.
class FeedPostItem extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final void Function(int itineraryId)? onItineraryTap;
  final void Function(int userId)? onUserTap;
  final VoidCallback? onTap;
  final String? heroScope;

  const FeedPostItem({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.onItineraryTap,
    this.onUserTap,
    this.onTap,
    this.heroScope,
  });

  @override
  State<FeedPostItem> createState() => _FeedPostItemState();
}

class _FeedPostItemState extends State<FeedPostItem> {
  bool _isExpanded = false;

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
  }

  IconData _visibilityIcon(String visibility) {
    return switch (visibility.toUpperCase()) {
      'FRIENDS' => Icons.group_outlined,
      'PRIVATE' => Icons.lock_outline,
      _ => Icons.public,
    };
  }

  Future<void> _openOptionsSheet() async {
    final post = widget.post;
    final options = <AppBottomSheetOption<String>>[
      if (post.isOwner && widget.onEdit != null)
        const AppBottomSheetOption(
          value: 'edit',
          icon: Icons.edit_outlined,
          label: 'Chỉnh sửa bài viết',
        ),
      if (post.isOwner && widget.onDelete != null)
        const AppBottomSheetOption(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Xóa bài viết',
          isDestructive: true,
        ),
      if (widget.onShare != null)
        const AppBottomSheetOption(
          value: 'share',
          icon: Icons.share_outlined,
          label: 'Chia sẻ bài viết',
        ),
      if (!post.isOwner && widget.onReport != null)
        const AppBottomSheetOption(
          value: 'report',
          icon: Icons.flag_outlined,
          label: 'Báo cáo bài viết',
          isDestructive: true,
        ),
    ];

    if (options.isEmpty) return;

    final selected = await AppBottomSheet.showOptions<String>(
      context,
      title: 'Tùy chọn bài viết',
      options: options,
    );

    if (!mounted || selected == null) return;
    switch (selected) {
      case 'edit':
        widget.onEdit?.call();
      case 'delete':
        widget.onDelete?.call();
      case 'share':
        widget.onShare?.call();
      case 'report':
        widget.onReport?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hasOptions =
        (post.isOwner && (widget.onEdit != null || widget.onDelete != null)) ||
        (!post.isOwner && widget.onReport != null) ||
        widget.onShare != null;

    final content = post.content.trim();
    final isLongContent =
        content.length > 180 || '\n'.allMatches(content).length >= 4;

    final hasStats =
        post.likeCount > 0 || post.commentCount > 0 || post.shareCount > 0;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Post Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: BounceTap(
                    enabled:
                        widget.onUserTap != null && post.author.userId > 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          widget.onUserTap != null && post.author.userId > 0
                          ? () => widget.onUserTap!(post.author.userId)
                          : null,
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceStrong,
                              border: Border.all(
                                color: const Color(0xFFEFEFF4),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child:
                                post.author.avatar != null &&
                                    post.author.avatar!.trim().isNotEmpty
                                ? Image.network(
                                    post.author.avatar!.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person,
                                      color: AppColors.muted,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: AppColors.muted,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        post.author.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E1E1E),
                                        ),
                                      ),
                                    ),
                                    if (post.author.handle.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '@${post.author.handle.replaceFirst('@', '')}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6E6E73),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      _formatTime(post.createdAt),
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
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasOptions)
                  BounceTap.icon(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_horiz,
                          color: Color(0xFF6E6E73),
                        ),
                        onPressed: _openOptionsSheet,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Post Caption (with smart truncation)
          if (content.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap ?? widget.onComment,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content,
                      maxLines: isLongContent && !_isExpanded ? 4 : null,
                      overflow: isLongContent && !_isExpanded
                          ? TextOverflow.ellipsis
                          : null,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    if (isLongContent) ...[
                      const SizedBox(height: 4),
                      BounceTap(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          child: Text(
                            _isExpanded ? 'Thu gọn' : 'Xem thêm',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6E6E73),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 3. Full-Bleed Media Grid
          if (post.mediaUrls.isNotEmpty) _buildFullBleedMedia(context, post),

          // 4. Attached Itinerary Card or Unavailable Banner
          if (post.itinerary != null)
            _buildAttachedItinerary(post.itinerary!)
          else if (post.itineraryUnavailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEBEBEF)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.link_off_rounded, size: 18, color: Color(0xFF6E6E73)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lịch trình không còn khả dụng',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6E6E73),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Reaction & Comment Count Bar
          if (hasStats)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  if (post.likeCount > 0) ...[
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
                        fontSize: 12.5,
                        color: Color(0xFF6E6E73),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (post.commentCount > 0 || post.shareCount > 0)
                    Text(
                      [
                        if (post.commentCount > 0)
                          '${post.commentCount} bình luận',
                        if (post.shareCount > 0)
                          '${post.shareCount} lượt chia sẻ',
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6E6E73),
                      ),
                    ),
                ],
              ),
            ),

          // 6. Hairline Divider & 3 Equal Action Buttons
          const Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFEFEFF4),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildActionButton(
                  icon: post.isLikedByMe
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: 'Thích',
                  color: post.isLikedByMe
                      ? const Color(0xFFFA3E62)
                      : const Color(0xFF6E6E73),
                  isBold: post.isLikedByMe,
                  onTap: widget.onLike,
                ),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Bình luận',
                  color: const Color(0xFF6E6E73),
                  onTap: widget.onComment ?? widget.onTap,
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Chia sẻ',
                  color: const Color(0xFF6E6E73),
                  onTap: widget.onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBleedMedia(BuildContext context, PostModel post) {
    final urls = post.mediaUrls;
    final scopePrefix =
        widget.heroScope != null ? '${widget.heroScope}_' : '';
    final tags = List.generate(
      urls.length,
      (i) => 'feed_post_$scopePrefix${post.postId}_$i',
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
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              urls[0],
              width: double.infinity,
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
        ),
      );
    }

    if (urls.length == 2) {
      return AspectRatio(
        aspectRatio: 3 / 2,
        child: Row(
          children: [
            Expanded(child: _buildMediaTile(context, urls, tags, 0)),
            const SizedBox(width: 2),
            Expanded(child: _buildMediaTile(context, urls, tags, 1)),
          ],
        ),
      );
    }

    if (urls.length == 3) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildMediaTile(context, urls, tags, 0),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(child: _buildMediaTile(context, urls, tags, 1)),
                  const SizedBox(height: 2),
                  Expanded(child: _buildMediaTile(context, urls, tags, 2)),
                ],
              ),
            ),
          ],
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
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildMediaTile(context, urls, tags, index),
            if (isOverflowTile)
              IgnorePointer(
                child: Container(
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
              ),
          ],
        );
      },
    );
  }

  Widget _buildMediaTile(
    BuildContext context,
    List<String> urls,
    List<String> tags,
    int index,
  ) {
    return GestureDetector(
      onTap: () => FullscreenImageViewer.open(
        context,
        urls: urls,
        initialIndex: index,
        heroTags: tags,
      ),
      child: Hero(
        tag: tags[index],
        child: Image.network(
          urls[index],
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.surfaceStrong,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachedItinerary(PostItineraryModel itinerary) {
    final hasCover =
        itinerary.coverImage != null && itinerary.coverImage!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: BounceTap(
        enabled: widget.onItineraryTap != null,
        child: Material(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onItineraryTap != null
                ? () => widget.onItineraryTap!(itinerary.itineraryId)
                : null,
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
                    width: 54,
                    height: 54,
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
                        Row(
                          children: [
                            Text(
                              '${itinerary.totalDays} ngày',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                            if (itinerary.location != null &&
                                itinerary.location!.trim().isNotEmpty) ...[
                              const Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF6E6E73),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  itinerary.location!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF6E6E73),
                                  ),
                                ),
                              ),
                            ],
                          ],
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    bool isBold = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: BounceTap(
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
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
}
