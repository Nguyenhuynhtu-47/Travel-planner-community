import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../social/presentation/screens/post_detail_screen.dart';
import '../../data/messaging_date_time.dart';
import '../../data/models/chat_message.dart';

class ShareMessageCard extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final AuthNotifier? authNotifier;
  final int peerReadSequence;
  final VoidCallback? onRetry;

  const ShareMessageCard({
    super.key,
    required this.message,
    required this.isOwn,
    this.authNotifier,
    this.peerReadSequence = 0,
    this.onRetry,
  });

  void _handleTap(BuildContext context) {
    if (message.shareTargetId == null) {
      AppToast.showWarning(context, 'Nội dung được chia sẻ không còn khả dụng');
      return;
    }

    if (message.isItineraryShare) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ItineraryDetailScreen(
            itineraryId: message.shareTargetId!,
            authNotifier: authNotifier,
          ),
        ),
      );
    } else if (message.isPostShare) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(
            postId: message.shareTargetId!,
            authNotifier: authNotifier,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = message.shareMetadata;
    final isItinerary = message.isItineraryShare;
    final title = metadata?.title ??
        (isItinerary ? 'Lịch trình được chia sẻ' : 'Bài viết được chia sẻ');
    final subtitle = metadata?.subtitle;
    final coverImage = metadata?.coverImage;
    final authorName = metadata?.authorName;
    final authorAvatar = metadata?.authorAvatar;
    final hasNote = message.content.trim().isNotEmpty;

    return Container(
      constraints: const BoxConstraints(maxWidth: 275),
      child: Column(
        crossAxisAlignment:
            isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Optional user note above or below card
          if (hasNote)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOwn ? AppColors.primaryLight : AppColors.surfaceStrong,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),

          // Main Card
          BounceTap(
            child: Material(
            color: Colors.white,
            elevation: 1.5,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _handleTap(context),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.hairlineSoft,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cover Image with Type Badge
                    Stack(
                      children: [
                        if (coverImage != null && coverImage.isNotEmpty)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              coverImage,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _placeholderCover(isItinerary),
                            ),
                          )
                        else
                          _placeholderCover(isItinerary),

                        // Type Badge overlay
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isItinerary
                                      ? Icons.map_outlined
                                      : Icons.article_outlined,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isItinerary ? 'Lịch trình' : 'Bài viết',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Card Body
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (authorName != null && authorName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor: AppColors.surfaceStrong,
                                  backgroundImage: (authorAvatar != null &&
                                          authorAvatar.isNotEmpty)
                                      ? NetworkImage(authorAvatar)
                                      : null,
                                  child: (authorAvatar == null ||
                                          authorAvatar.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          size: 10,
                                          color: AppColors.muted,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    authorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Divider and Action call-to-action
                    const Divider(height: 1, color: AppColors.hairlineSoft),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Nhấn để xem chi tiết',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 11,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),

          // Message Status & Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 2, left: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MessagingDateTime.format(message.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                if (message.failed) ...[
                  const SizedBox(width: 6),
                  BounceTap(
                    enabled: onRetry != null,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: onRetry,
                      child: const Text('Thử gửi lại', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ] else if (message.sending) ...[
                  const SizedBox(width: 6),
                  const Text('Đang gửi…', style: TextStyle(fontSize: 10)),
                ] else if (isOwn &&
                    message.recipientVisible &&
                    message.sequenceNumber <= peerReadSequence) ...[
                  const SizedBox(width: 6),
                  const Text('Đã đọc', style: TextStyle(fontSize: 10)),
                ] else if (isOwn &&
                    message.recipientVisible &&
                    message.messageId != null) ...[
                  const SizedBox(width: 6),
                  const Text('Đã gửi', style: TextStyle(fontSize: 10)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCover(bool isItinerary) {
    return Container(
      width: double.infinity,
      height: 90,
      color: AppColors.surfaceStrong,
      child: Center(
        child: Icon(
          isItinerary ? Icons.map_outlined : Icons.article_outlined,
          size: 36,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
