import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/itinerary_day_detail.dart';
import 'activity_timeline_item.dart';

class ItineraryDayCard extends StatelessWidget {
  final ItineraryDayDetail day;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ItineraryDayCard({
    super.key,
    required this.day,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: AppColors.hairlineSoft)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFD1DA)),
                  ),
                  child: Text(
                    'Ngày ${day.dayNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      (day.title != null && day.title!.trim().isNotEmpty)
                          ? day.title!.trim()
                          : '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (day.date != null) ...[
                  Text(
                    '${day.date!.day.toString().padLeft(2, '0')}/${day.date!.month.toString().padLeft(2, '0')}/${day.date!.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (onEdit != null || onDelete != null)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) {
                          onEdit!();
                        } else if (value == 'delete' && onDelete != null) {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Sửa ngày'),
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
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Xóa ngày',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day.description != null &&
                    day.description!.trim().isNotEmpty) ...[
                  Text(
                    day.description!.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textBody,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Activities list
                if (day.activities.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: const Center(
                      child: Text(
                        'Chưa có hoạt động nào được lên kế hoạch cho ngày này.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: day.activities.length,
                    itemBuilder: (context, index) {
                      return ActivityTimelineItem(
                        activity: day.activities[index],
                        isLast: index == day.activities.length - 1,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
