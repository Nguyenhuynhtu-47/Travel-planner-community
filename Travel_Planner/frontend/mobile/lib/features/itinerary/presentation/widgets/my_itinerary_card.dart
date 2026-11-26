import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_bottom_sheet.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../explore/data/models/itinerary_summary.dart';

class MyItineraryCard extends StatelessWidget {
  final ItinerarySummary itinerary;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const MyItineraryCard({
    super.key,
    required this.itinerary,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onShare,
  });

  String _formatBudget(double budget) {
    if (budget <= 0) return 'Miễn phí';
    final formatted = budget.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$formatted đ';
  }

  void _openActionsSheet(BuildContext context) {
    AppBottomSheet.showOptions<void>(
      context,
      title: itinerary.title,
      options: [
        if (onEdit != null)
          AppBottomSheetOption(
            icon: Icons.edit_outlined,
            label: 'Chỉnh sửa lịch trình',
            onTap: onEdit,
          ),
        if (onShare != null)
          AppBottomSheetOption(
            icon: Icons.share_outlined,
            label: 'Chia sẻ lịch trình',
            onTap: onShare,
          ),
        if (onDelete != null)
          AppBottomSheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Xóa lịch trình',
            isDestructive: true,
            onTap: onDelete,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = itinerary.visibility == 'PUBLIC';
    final isDraft = itinerary.status == 'DRAFT';
    final hasImage =
        itinerary.coverImage != null && itinerary.coverImage!.trim().isNotEmpty;

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
                // 1. Left: 80x80 rounded square thumbnail
                Stack(
                  children: [
                    Container(
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
                      child: hasImage
                          ? Image.network(
                              itinerary.coverImage!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                            )
                          : _buildImagePlaceholder(),
                    ),
                    if (isDraft)
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade800,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Bản nháp',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isPublic ? Icons.public : Icons.lock_outline,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // 2. Center: Hierarchical Info
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              itinerary.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6E6E73),
                            ),
                          ),
                          Text(
                            '${itinerary.totalDays} ngày',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6E6E73),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _formatBudget(itinerary.budget),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFA3E62),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPublic
                                  ? const Color(0xFFFFF0F3)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPublic ? 'Công khai' : 'Riêng tư',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isPublic
                                    ? const Color(0xFFFA3E62)
                                    : const Color(0xFF6E6E73),
                              ),
                            ),
                          ),
                          if (itinerary.theme != null &&
                              itinerary.theme!.trim().isNotEmpty)
                            Text(
                              '• ${itinerary.theme!.trim()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Right: Quick Action Buttons
                if (onShare != null || onEdit != null || onDelete != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onShare != null)
                        BounceTap.icon(
                          child: InkWell(
                            onTap: onShare,
                            borderRadius: BorderRadius.circular(18),
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.share_outlined,
                                size: 19,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                          ),
                        ),
                      if (onEdit != null || onDelete != null)
                        BounceTap.icon(
                          child: InkWell(
                            onTap: () => _openActionsSheet(context),
                            borderRadius: BorderRadius.circular(18),
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 20,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: AppColors.muted),
      ),
    );
  }
}
