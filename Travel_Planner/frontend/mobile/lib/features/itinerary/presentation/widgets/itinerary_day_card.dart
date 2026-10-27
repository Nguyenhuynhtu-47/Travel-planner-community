import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/itinerary_day_detail.dart';
import 'activity_timeline_item.dart';

class ItineraryDayCard extends StatelessWidget {
  final ItineraryDayDetail day;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddActivity;
  final void Function(ActivityDetail activity)? onEditActivity;
  final void Function(ActivityDetail activity)? onDeleteActivity;
  final VoidCallback? onReorderActivities;

  const ItineraryDayCard({
    super.key,
    required this.day,
    this.onEdit,
    this.onDelete,
    this.onAddActivity,
    this.onEditActivity,
    this.onDeleteActivity,
    this.onReorderActivities,
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
                      (day.title != null &&
                              day.title!.trim().isNotEmpty &&
                              day.title!.trim().toLowerCase() !=
                                  'ngày ${day.dayNumber}'.toLowerCase())
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
                if (onEdit != null ||
                    onDelete != null ||
                    onAddActivity != null ||
                    (day.activities.length > 1 && onReorderActivities != null))
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
                        if (value == 'add_activity' && onAddActivity != null) {
                          onAddActivity!();
                        } else if (value == 'reorder' &&
                            onReorderActivities != null) {
                          onReorderActivities!();
                        } else if (value == 'edit' && onEdit != null) {
                          onEdit!();
                        } else if (value == 'delete' && onDelete != null) {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onAddActivity != null)
                          const PopupMenuItem<String>(
                            value: 'add_activity',
                            child: Row(
                              children: [
                                Icon(Icons.add_task_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Thêm hoạt động'),
                              ],
                            ),
                          ),
                        if (day.activities.length > 1 &&
                            onReorderActivities != null)
                          const PopupMenuItem<String>(
                            value: 'reorder',
                            child: Row(
                              children: [
                                Icon(Icons.swap_vert_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Sắp xếp hoạt động'),
                              ],
                            ),
                          ),
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
                    child: Column(
                      children: [
                        const Text(
                          'Chưa có hoạt động nào được lên kế hoạch cho ngày này.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (onAddActivity != null) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              side: const BorderSide(color: AppColors.hairline),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Thêm hoạt động đầu tiên',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: onAddActivity,
                          ),
                        ],
                      ],
                    ),
                  )
                else ...[
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: day.activities.length,
                    itemBuilder: (context, index) {
                      final act = day.activities[index];
                      return ActivityTimelineItem(
                        activity: act,
                        isLast: index == day.activities.length - 1,
                        onEdit: onEditActivity != null
                            ? () => onEditActivity!(act)
                            : null,
                        onDelete: onDeleteActivity != null
                            ? () => onDeleteActivity!(act)
                            : null,
                      );
                    },
                  ),
                  if (onAddActivity != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: const Text(
                            'Thêm hoạt động',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          onPressed: onAddActivity,
                        ),
                        if (day.activities.length > 1 &&
                            onReorderActivities != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(
                              Icons.swap_vert_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            label: const Text(
                              'Sắp xếp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onPressed: onReorderActivities,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
