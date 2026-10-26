import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/reorder_activity_item.dart';

Future<bool?> showReorderActivitiesDialog(
  BuildContext context, {
  required int itineraryId,
  required int dayId,
  required int dayNumber,
  required List<ActivityDetail> activities,
  required AuthNotifier authNotifier,
  required ItineraryCrudRepository repository,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ReorderActivitiesDialog(
      itineraryId: itineraryId,
      dayId: dayId,
      dayNumber: dayNumber,
      activities: activities,
      authNotifier: authNotifier,
      repository: repository,
    ),
  );
}

class _ReorderActivitiesDialog extends StatefulWidget {
  final int itineraryId;
  final int dayId;
  final int dayNumber;
  final List<ActivityDetail> activities;
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository repository;

  const _ReorderActivitiesDialog({
    required this.itineraryId,
    required this.dayId,
    required this.dayNumber,
    required this.activities,
    required this.authNotifier,
    required this.repository,
  });

  @override
  State<_ReorderActivitiesDialog> createState() => _ReorderActivitiesDialogState();
}

class _ReorderActivitiesDialogState extends State<_ReorderActivitiesDialog> {
  late List<ActivityDetail> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List<ActivityDetail>.from(widget.activities);
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

  Future<void> _saveOrder() async {
    final token = widget.authNotifier.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để lưu thứ tự hoạt động.'),
          backgroundColor: AppColors.error,
        ),
      );
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
      await widget.repository.reorderActivities(
        widget.itineraryId,
        widget.dayId,
        reorderItems,
        token: token,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu thứ tự hoạt động. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sắp xếp hoạt động',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Ngày ${widget.dayNumber} • Giữ và kéo để đổi thứ tự',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reorderable list
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  // ignore: deprecated_member_use
                  onReorder: _isSaving ? (oldIndex, newIndex) {} : _onReorder,
                  itemBuilder: (context, index) {
                    final activity = _items[index];
                    return Container(
                      key: ValueKey(activity.activityId),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
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
                        title: Text(
                          activity.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: activity.timeRangeFormatted != null
                            ? Text(
                                activity.timeRangeFormatted!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.drag_handle_rounded,
                          color: AppColors.muted,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSaving ? null : _saveOrder,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Lưu thứ tự',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
