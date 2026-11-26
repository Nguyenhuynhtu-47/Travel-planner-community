import 'package:flutter/material.dart';

import '../../data/models/post_model.dart';
import 'feed_post_item.dart';

/// Backwards-compatible alias delegating to [FeedPostItem].
class PostCardWidget extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final void Function(int itineraryId)? onItineraryTap;
  final void Function(int userId)? onUserTap;
  final EdgeInsetsGeometry? margin;
  final String? heroScope;

  const PostCardWidget({
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
    this.margin,
    this.heroScope,
  });

  @override
  Widget build(BuildContext context) {
    return FeedPostItem(
      post: post,
      onLike: onLike,
      onComment: onComment,
      onShare: onShare,
      onEdit: onEdit,
      onDelete: onDelete,
      onReport: onReport,
      onItineraryTap: onItineraryTap,
      onUserTap: onUserTap,
      heroScope: heroScope,
    );
  }
}
