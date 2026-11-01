import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/itinerary_summary.dart';

enum CompactCardHighlight { rating, popular, theme }

class CompactItineraryCard extends StatelessWidget {
  final ItinerarySummary itinerary;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorited;
  final CompactCardHighlight highlight;

  const CompactItineraryCard({
    super.key,
    required this.itinerary,
    required this.onTap,
    this.onFavoriteTap,
    this.isFavorited = false,
    this.highlight = CompactCardHighlight.rating,
  });

  @override
  Widget build(BuildContext context) {
    const cardWidth = 195.0;
    const cardHeight = 230.0;

    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.hairlineSoft, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Image Container with Favorite button
                SizedBox(
                  height: 118,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(),
                      // Subtle top gradient for contrast
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Duration badge bottom-left
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${itinerary.totalDays}N',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Favorite button top-right
                      if (onFavoriteTap != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onFavoriteTap,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Icon(
                                  isFavorited
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: isFavorited
                                      ? AppColors.primary
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Bottom Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          itinerary.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const Spacer(),

                        // Location
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                itinerary.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Highlight metric based on section type
                        _buildHighlightRow(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightRow() {
    switch (highlight) {
      case CompactCardHighlight.rating:
        if (itinerary.averageRating > 0) {
          return Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 13,
                color: Color(0xFFFFB800),
              ),
              const SizedBox(width: 2),
              Text(
                itinerary.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (itinerary.ratingCount > 0)
                Text(
                  ' (${itinerary.ratingCount})',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
            ],
          );
        }
        return const Text(
          'Mới chia sẻ',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        );

      case CompactCardHighlight.popular:
        final favCount = itinerary.favoriteCount;
        return Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              size: 12,
              color: AppColors.primary,
            ),
            const SizedBox(width: 3),
            Text(
              '$favCount yêu thích',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        );

      case CompactCardHighlight.theme:
        final theme = itinerary.theme;
        if (theme != null && theme.trim().isNotEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.hairlineSoft, width: 0.8),
            ),
            child: Text(
              theme,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  Widget _buildImage() {
    final cover = itinerary.coverImage;
    if (cover != null && cover.trim().isNotEmpty) {
      return Image.network(
        cover,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(isLoading: true);
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder({bool isLoading = false}) {
    return Container(
      color: AppColors.surfaceSoft,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.landscape_rounded,
                size: 32,
                color: AppColors.borderStrong,
              ),
      ),
    );
  }
}
