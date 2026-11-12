import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/post_model.dart';

class PostCardWidget extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final void Function(int itineraryId)? onItineraryTap;

  const PostCardWidget({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.onItineraryTap,
  });

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${time.day}/${time.month}/${time.year}';
  }

  IconData _visibilityIcon(String visibility) {
    switch (visibility.toUpperCase()) {
      case 'FRIENDS':
        return Icons.group_outlined;
      case 'PRIVATE':
        return Icons.lock_outline;
      case 'PUBLIC':
      default:
        return Icons.public;
    }
  }

  String _visibilityTooltip(String visibility) {
    switch (visibility.toUpperCase()) {
      case 'FRIENDS':
        return 'Bạn bè';
      case 'PRIVATE':
        return 'Chỉ mình tôi';
      case 'PUBLIC':
      default:
        return 'Công khai';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairlineSoft, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceStrong,
                  backgroundImage: post.author.avatar != null &&
                          post.author.avatar!.isNotEmpty
                      ? NetworkImage(post.author.avatar!)
                      : null,
                  child: post.author.avatar == null || post.author.avatar!.isEmpty
                      ? const Icon(Icons.person, color: AppColors.muted)
                      : null,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (post.author.handle.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '@${post.author.handle.replaceFirst('@', '')}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AppColors.muted, fontSize: 10)),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: _visibilityTooltip(post.visibility),
                            child: Icon(
                              _visibilityIcon(post.visibility),
                              size: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                  tooltip: 'Tùy chọn',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                    if (value == 'report') onReport?.call();
                  },
                  itemBuilder: (context) => [
                    if (post.isOwner) ...[
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Chỉnh sửa bài viết'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Xóa bài viết', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ] else ...[
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Báo cáo bài viết'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Content Text
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                post.content,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

          // Media Photo Grid (0 to 5 photos)
          if (post.mediaUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildPhotoGrid(context, post.mediaUrls),
            ),

          // Attached Itinerary Card
          if (post.itinerary != null)
            _buildItineraryCard(context, post.itinerary!)
          else if (post.itineraryUnavailable)
            _buildItineraryUnavailableCard(),

          const SizedBox(height: 8),

          // Action Buttons: Like, Comment, Share
          const Divider(height: 1, color: AppColors.hairlineSoft),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Like Button
                Expanded(
                  child: InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                            color: post.isLikedByMe ? AppColors.primary : AppColors.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            post.likeCount > 0 ? '${post.likeCount}' : 'Thích',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: post.isLikedByMe ? FontWeight.w700 : FontWeight.w500,
                              color: post.isLikedByMe ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Comment Button
                Expanded(
                  child: InkWell(
                    onTap: onComment,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            post.commentCount > 0 ? '${post.commentCount}' : 'Bình luận',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
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

  Widget _buildPhotoGrid(BuildContext context, List<String> urls) {
    final count = urls.length;
    if (count == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            urls[0],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
          ),
        ),
      );
    } else if (count == 2) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Row(
          children: [
            Expanded(child: _singleImage(urls[0])),
            const SizedBox(width: 3),
            Expanded(child: _singleImage(urls[1])),
          ],
        ),
      );
    } else if (count == 3) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Row(
          children: [
            Expanded(flex: 2, child: _singleImage(urls[0])),
            const SizedBox(width: 3),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: _singleImage(urls[1])),
                  const SizedBox(height: 3),
                  Expanded(child: _singleImage(urls[2])),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (count == 4) {
      return AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _singleImage(urls[0])),
                  const SizedBox(width: 3),
                  Expanded(child: _singleImage(urls[1])),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _singleImage(urls[2])),
                  const SizedBox(width: 3),
                  Expanded(child: _singleImage(urls[3])),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 5 photos
      return AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(child: _singleImage(urls[0])),
                  const SizedBox(width: 3),
                  Expanded(child: _singleImage(urls[1])),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(child: _singleImage(urls[2])),
                  const SizedBox(width: 3),
                  Expanded(child: _singleImage(urls[3])),
                  const SizedBox(width: 3),
                  Expanded(child: _singleImage(urls[4])),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _singleImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
    );
  }

  Widget _imageErrorPlaceholder() {
    return Container(
      color: AppColors.surfaceStrong,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
      ),
    );
  }

  Widget _buildItineraryCard(BuildContext context, PostItineraryModel itinerary) {
    return InkWell(
      onTap: () => onItineraryTap?.call(itinerary.itineraryId),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairlineSoft, width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: itinerary.coverImage != null && itinerary.coverImage!.isNotEmpty
                  ? Image.network(
                      itinerary.coverImage!,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 68,
                        height: 68,
                        color: AppColors.surfaceStrong,
                        child: const Icon(Icons.map_outlined, color: AppColors.muted),
                      ),
                    )
                  : Container(
                      width: 68,
                      height: 68,
                      color: AppColors.surfaceStrong,
                      child: const Icon(Icons.map_outlined, color: AppColors.muted),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itinerary.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (itinerary.totalDays != null) ...[
                        const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Text(
                          '${itinerary.totalDays} ngày',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (itinerary.location != null && itinerary.location!.isNotEmpty) ...[
                        const Icon(Icons.place_outlined, size: 12, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            itinerary.location!,
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Clear attribution: Distinct Itinerary Creator
                  Text(
                    'Tác giả lịch trình: ${itinerary.owner?.displayName ?? "Ẩn danh"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildItineraryUnavailableCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairlineSoft, width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.muted, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lịch trình không khả dụng',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Lịch trình đính kèm đã bị xóa, đặt về riêng tư hoặc không còn khả dụng.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
