import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/itinerary_day_detail.dart';
import '../../data/models/reorder_activity_item.dart';
import 'activity_timeline_item.dart';

class ItineraryDayCard extends StatefulWidget {
  final ItineraryDayDetail day;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddActivity;
  final void Function(ActivityDetail activity)? onEditActivity;
  final void Function(ActivityDetail activity)? onDeleteActivity;
  final VoidCallback? onReorderActivities;
  final Future<bool> Function(List<ReorderActivityItem> reorderedItems)?
  onSaveActivityOrder;

  const ItineraryDayCard({
    super.key,
    required this.day,
    this.onEdit,
    this.onDelete,
    this.onAddActivity,
    this.onEditActivity,
    this.onDeleteActivity,
    this.onReorderActivities,
    this.onSaveActivityOrder,
  });

  @override
  State<ItineraryDayCard> createState() => _ItineraryDayCardState();
}

class _ItineraryDayCardState extends State<ItineraryDayCard> {
  bool _isReordering = false;
  bool _isSaving = false;
  late List<ActivityDetail> _items;

  @override
  void initState() {
    super.initState();
    _items = List<ActivityDetail>.from(widget.day.activities);
  }

  @override
  void didUpdateWidget(ItineraryDayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSaving && !_isReordering) {
      _items = List<ActivityDetail>.from(widget.day.activities);
    }
  }

  void _startReordering() {
    setState(() {
      _items = List<ActivityDetail>.from(widget.day.activities);
      _isReordering = true;
    });
  }

  void _cancelReorder() {
    setState(() {
      _isReordering = false;
      _items = List<ActivityDetail>.from(widget.day.activities);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  Future<void> _saveReorder() async {
    if (widget.onSaveActivityOrder == null) {
      setState(() => _isReordering = false);
      return;
    }

    setState(() => _isSaving = true);

    final reorderItems = <ReorderActivityItem>[];
    for (int i = 0; i < _items.length; i++) {
      reorderItems.add(
        ReorderActivityItem(
          activityId: _items[i].activityId,
          displayOrder: i + 1,
        ),
      );
    }

    try {
      final success = await widget.onSaveActivityOrder!(reorderItems);
      if (!mounted) return;
      if (success) {
        setState(() {
          _isSaving = false;
          _isReordering = false;
        });
      } else {
        // Save failed: restore original server state order
        setState(() {
          _isSaving = false;
          _items = List<ActivityDetail>.from(widget.day.activities);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _items = List<ActivityDetail>.from(widget.day.activities);
      });
    }
  }

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
    final day = widget.day;
    final hasReorderCapability =
        day.activities.length > 1 &&
        (widget.onSaveActivityOrder != null ||
            widget.onReorderActivities != null);

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
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${day.date!.day.toString().padLeft(2, '0')}/${day.date!.month.toString().padLeft(2, '0')}/${day.date!.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (widget.onEdit != null ||
                    widget.onDelete != null ||
                    widget.onAddActivity != null ||
                    hasReorderCapability)
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
                        if (value == 'add_activity' &&
                            widget.onAddActivity != null) {
                          widget.onAddActivity!();
                        } else if (value == 'reorder') {
                          if (widget.onSaveActivityOrder != null) {
                            _startReordering();
                          } else if (widget.onReorderActivities != null) {
                            widget.onReorderActivities!();
                          }
                        } else if (value == 'edit' && widget.onEdit != null) {
                          widget.onEdit!();
                        } else if (value == 'delete' &&
                            widget.onDelete != null) {
                          widget.onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (widget.onAddActivity != null && !_isReordering)
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
                        if (hasReorderCapability && !_isReordering)
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
                        if (widget.onEdit != null && !_isReordering)
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
                        if (widget.onDelete != null && !_isReordering)
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

          // Day Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description if present
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
                        if (widget.onAddActivity != null) ...[
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
                            onPressed: widget.onAddActivity,
                          ),
                        ],
                      ],
                    ),
                  )
                else if (_isReordering) ...[
                  // Inline Reorder Header Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD1DA)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.swap_vert_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kéo biểu tượng ≡ để đổi thứ tự hoạt động',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reorderable list
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _items.length,
                    // ignore: deprecated_member_use
                    onReorder: _isSaving ? (oldIndex, newIndex) {} : _onReorder,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 4,
                        color: Colors.transparent,
                        shadowColor: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final act = _items[index];
                      return _buildReorderItem(act, index);
                    },
                  ),

                  // Reorder Action Buttons
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSaving ? null : _cancelReorder,
                          child: const Text(
                            'Hủy',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSaving ? null : _saveReorder,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Lưu thứ tự',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Normal Timeline List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: day.activities.length,
                    itemBuilder: (context, index) {
                      final act = day.activities[index];
                      return ActivityTimelineItem(
                        activity: act,
                        isLast: index == day.activities.length - 1,
                        onEdit: widget.onEditActivity != null
                            ? () => widget.onEditActivity!(act)
                            : null,
                        onDelete: widget.onDeleteActivity != null
                            ? () => widget.onDeleteActivity!(act)
                            : null,
                      );
                    },
                  ),
                  if (widget.onAddActivity != null || hasReorderCapability) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (widget.onAddActivity != null)
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
                            onPressed: widget.onAddActivity,
                          ),
                        if (hasReorderCapability)
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
                            onPressed: () {
                              if (widget.onSaveActivityOrder != null) {
                                _startReordering();
                              } else if (widget.onReorderActivities != null) {
                                widget.onReorderActivities!();
                              }
                            },
                          ),
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

  Widget _buildReorderItem(ActivityDetail act, int index) {
    return Container(
      key: ValueKey(act.activityId),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.drag_handle_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Index badge
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.primary,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Activity info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  act.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (act.timeRangeFormatted != null ||
                    (act.estimatedCost != null && act.estimatedCost! > 0) ||
                    act.destination != null) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (act.timeRangeFormatted != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 11,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              act.timeRangeFormatted!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      if (act.estimatedCost != null && act.estimatedCost! > 0)
                        Text(
                          _formatCost(act.estimatedCost!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      if (act.destination != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 2),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                act.destination!.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Popup Menu for edit / delete
          if (widget.onEditActivity != null || widget.onDeleteActivity != null)
            SizedBox(
              width: 24,
              height: 24,
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit' && widget.onEditActivity != null) {
                    widget.onEditActivity!(act);
                  } else if (value == 'delete' &&
                      widget.onDeleteActivity != null) {
                    widget.onDeleteActivity!(act);
                  }
                },
                itemBuilder: (context) => [
                  if (widget.onEditActivity != null)
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
                  if (widget.onDeleteActivity != null)
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
    );
  }
}
