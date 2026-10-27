import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/activity_detail.dart';

class ActivityTimelineItem extends StatelessWidget {
  final ActivityDetail activity;
  final bool isLast;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ActivityTimelineItem({
    super.key,
    required this.activity,
    this.isLast = false,
    this.onEdit,
    this.onDelete,
  });

  String _formatCost(double cost) {
    if (cost <= 0) return 'Miễn phí';
    final formatted = cost.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$formatted ₫';
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatted = activity.timeRangeFormatted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22FF385C),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.hairline,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Activity details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 8.0 : 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time & cost badge row & actions
                  if (timeFormatted != null ||
                      (activity.estimatedCost != null &&
                          activity.estimatedCost! > 0) ||
                      onEdit != null ||
                      onDelete != null)
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (timeFormatted != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.hairline,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeFormatted,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (activity.estimatedCost != null &&
                                  activity.estimatedCost! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFBBF7D0),
                                    ),
                                  ),
                                  child: Text(
                                    _formatCost(activity.estimatedCost!),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (onEdit != null || onDelete != null)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              padding: EdgeInsets.zero,
                              onSelected: (value) {
                                if (value == 'edit' && onEdit != null) {
                                  onEdit!();
                                } else if (value == 'delete' &&
                                    onDelete != null) {
                                  onDelete!();
                                }
                              },
                              itemBuilder: (context) => [
                                if (onEdit != null)
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 16),
                                        SizedBox(width: 8),
                                        Text('Sửa hoạt động'),
                                      ],
                                    ),
                                  ),
                                if (onDelete != null)
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                          color: AppColors.error,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Xóa hoạt động',
                                          style: TextStyle(
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 6),

                  // Name
                  Text(
                    activity.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  // Description
                  if (activity.description != null &&
                      activity.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      activity.description!.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textBody,
                        height: 1.4,
                      ),
                    ),
                  ],

                  // Destination card
                  if (activity.destination != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.hairlineSoft),
                      ),
                      child: Row(
                        children: [
                          if (activity.destination!.imageUrl != null &&
                              activity.destination!.imageUrl!
                                  .trim()
                                  .isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                activity.destination!.imageUrl!.trim(),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _destinationPlaceholder(),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ] else ...[
                            _destinationPlaceholder(),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.destination!.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (activity.destination!.address != null &&
                                    activity.destination!.address!
                                        .trim()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    activity.destination!.address!.trim(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (activity.destination!.description != null &&
                                    activity.destination!.description!
                                        .trim()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    activity.destination!.description!.trim(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textBody,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationPlaceholder() => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(6),
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.place, size: 18, color: AppColors.primary),
  );
}
