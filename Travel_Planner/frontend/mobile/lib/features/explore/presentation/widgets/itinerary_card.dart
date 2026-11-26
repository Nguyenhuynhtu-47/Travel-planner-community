import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../data/models/itinerary_summary.dart';

class ItineraryCard extends StatelessWidget {
  final ItinerarySummary itinerary;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorited;
  final bool showFavorite;
  final Widget? topTrailingWidget;
  final IconData? actionIcon;
  final Color? actionIconColor;
  final VoidCallback? onActionTap;
  final VoidCallback? onCreatorTap;
  final String? heroTag;
  final bool isCompactHorizontal;

  const ItineraryCard({
    super.key,
    required this.itinerary,
    this.onTap,
    this.onFavoriteTap,
    this.isFavorited = false,
    this.showFavorite = true,
    this.topTrailingWidget,
    this.actionIcon,
    this.actionIconColor,
    this.onActionTap,
    this.onCreatorTap,
    this.heroTag,
    this.isCompactHorizontal = false,
  });

  String _formatBudget(double budget) {
    if (budget <= 0) return 'Miễn phí';
    final formatted = budget.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$formatted ₫';
  }

  @override
  Widget build(BuildContext context) {
    final hasRating = itinerary.ratingCount > 0 && itinerary.averageRating > 0;
    final isTopRated =
        itinerary.averageRating >= 4.5 && itinerary.ratingCount >= 2;

    if (isCompactHorizontal) {
      return _buildCompactHorizontal(context, hasRating);
    }

    return BounceTap(
      enabled: onTap != null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.hairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Photo Container
            Stack(
              children: [
                Hero(
                  tag: heroTag ?? 'itinerary_card_${itinerary.itineraryId}',
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child:
                        itinerary.coverImage != null &&
                            itinerary.coverImage!.trim().isNotEmpty
                        ? Image.network(
                            itinerary.coverImage!.trim(),
                            fit: BoxFit.cover,
                            frameBuilder:
                                (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) return child;
                                  final disableMotion =
                                      MediaQuery.maybeOf(context)
                                          ?.disableAnimations ??
                                      false;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: disableMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    child: child,
                                  );
                                },
                            errorBuilder: (context, error, stackTrace) =>
                                _buildImagePlaceholder(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: AppColors.surfaceSoft,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : _buildImagePlaceholder(),
                  ),
                ),

                // Top Badge (Guest Favorite)
                if (isTopRated)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Yêu thích',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Action / Favorite Button
                if (topTrailingWidget != null ||
                    actionIcon != null ||
                    (showFavorite && onFavoriteTap != null))
                  Positioned(
                    top: 8,
                    right: 8,
                    child: topTrailingWidget ??
                        (actionIcon != null
                            ? _CustomCardActionButton(
                                icon: actionIcon!,
                                iconColor: actionIconColor,
                                onTap: onActionTap,
                              )
                            : _FavoriteHeartButton(
                                onTap: onFavoriteTap,
                                isFavorited: isFavorited,
                              )),
                  ),
              ],
            ),

            // Itinerary Details
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location and Total Days
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${itinerary.location} • ${itinerary.totalDays} ngày',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (itinerary.theme != null &&
                          itinerary.theme!.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            itinerary.theme!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    itinerary.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Ratings and Creator Info Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Rating
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.textPrimary, // Ink rating
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasRating
                                ? itinerary.averageRating.toStringAsFixed(1)
                                : 'Mới',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (hasRating) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${itinerary.ratingCount})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Budget
                      Text(
                        _formatBudget(itinerary.budget),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  // Creator info
                  if (itinerary.creator != null) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.hairlineSoft),
                    const SizedBox(height: 8),
                    BounceTap(
                      enabled: onCreatorTap != null,
                      child: InkWell(
                        onTap: onCreatorTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.surfaceSoft,
                            backgroundImage:
                                itinerary.creator!.avatar != null &&
                                    itinerary.creator!.avatar!.trim().isNotEmpty
                                ? NetworkImage(itinerary.creator!.avatar!.trim())
                                : null,
                            child:
                                itinerary.creator!.avatar == null ||
                                    itinerary.creator!.avatar!.trim().isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 12,
                                    color: AppColors.muted,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Bởi ${itinerary.creator!.displayName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCompactHorizontal(BuildContext context, bool hasRating) {
    final creator = itinerary.creator;
    final hasCreatorAvatar =
        creator?.avatar != null && creator!.avatar!.trim().isNotEmpty;

    return BounceTap(
      enabled: onTap != null,
      child: Material(
        color: const Color(0xFFFFFFFF),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: heroTag ?? 'itinerary_card_${itinerary.itineraryId}',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFEFEFF4),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        itinerary.coverImage != null &&
                            itinerary.coverImage!.trim().isNotEmpty
                        ? Image.network(
                            itinerary.coverImage!.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itinerary.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E1E),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${itinerary.location} • ${itinerary.totalDays} ngày',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (creator != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 9,
                                  backgroundColor: AppColors.surfaceStrong,
                                  backgroundImage: hasCreatorAvatar
                                      ? NetworkImage(creator.avatar!.trim())
                                      : null,
                                  child: !hasCreatorAvatar
                                      ? const Icon(
                                          Icons.person,
                                          size: 11,
                                          color: AppColors.muted,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 110,
                                  ),
                                  child: Text(
                                    creator.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF6E6E73),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (hasRating)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  itinerary.averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                              ],
                            ),
                          Text(
                            _formatBudget(itinerary.budget),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFA3E62),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (actionIcon != null && onActionTap != null) ...[
                  const SizedBox(width: 8),
                  BounceTap.icon(
                    child: Material(
                      color: const Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: onActionTap,
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            actionIcon,
                            size: 19,
                            color: actionIconColor ?? const Color(0xFFFA3E62),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.surfaceSoft,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.landscape_outlined,
              size: 40,
              color: AppColors.borderStrong,
            ),
            const SizedBox(height: 4),
            Text(
              itinerary.location.isNotEmpty
                  ? itinerary.location
                  : 'Lịch trình du lịch',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteHeartButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isFavorited;

  const _FavoriteHeartButton({
    this.onTap,
    this.isFavorited = false,
  });

  @override
  State<_FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<_FavoriteHeartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return BounceTap.icon(
      enabled: widget.onTap != null,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) {
            if (!disableMotion) setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (!disableMotion) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (!disableMotion) setState(() => _pressed = false);
          },
          customBorder: const CircleBorder(),
          child: AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: disableMotion
                ? Duration.zero
                : const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isFavorited
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: widget.isFavorited ? Colors.redAccent : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _CustomCardActionButton extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _CustomCardActionButton({
    required this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  State<_CustomCardActionButton> createState() => _CustomCardActionButtonState();
}

class _CustomCardActionButtonState extends State<_CustomCardActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return BounceTap.icon(
      enabled: widget.onTap != null,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) {
            if (!disableMotion) setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (!disableMotion) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (!disableMotion) setState(() => _pressed = false);
          },
          customBorder: const CircleBorder(),
          child: AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: disableMotion
                ? Duration.zero
                : const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.iconColor ?? Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
