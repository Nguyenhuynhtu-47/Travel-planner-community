import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/itinerary_summary.dart';

class ItineraryCard extends StatelessWidget {
  final ItinerarySummary itinerary;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const ItineraryCard({
    super.key,
    required this.itinerary,
    this.onTap,
    this.onFavoriteTap,
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

    return Container(
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
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child:
                      itinerary.coverImage != null &&
                          itinerary.coverImage!.trim().isNotEmpty
                      ? Image.network(
                          itinerary.coverImage!.trim(),
                          fit: BoxFit.cover,
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

                // Favorite Heart Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onFavoriteTap,
                      customBorder: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
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
                    Row(
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
                    ),
                  ],
                ],
              ),
            ),
          ],
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
