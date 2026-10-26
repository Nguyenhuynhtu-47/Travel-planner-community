import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

Future<bool?> showDeleteDayConfirmationDialog(
  BuildContext context, {
  required int dayNumber,
  String? dayTitle,
  bool hasActivities = false,
}) {
  final titleSuffix = (dayTitle != null && dayTitle.trim().isNotEmpty)
      ? ' ("${dayTitle.trim()}")'
      : '';

  final warningNotice = hasActivities
      ? '\n\nLưu ý: Tất cả các hoạt động thuộc ngày này cũng sẽ bị xóa. Các ngày tiếp theo sẽ được tự động đánh số lại.'
      : '\n\nCác ngày tiếp theo sẽ được tự động đánh số lại.';

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Xác nhận xóa Ngày $dayNumber'),
      content: Text(
        'Bạn có chắc chắn muốn xóa Ngày $dayNumber$titleSuffix không?$warningNotice',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Xóa ngày'),
        ),
      ],
    ),
  );
}
