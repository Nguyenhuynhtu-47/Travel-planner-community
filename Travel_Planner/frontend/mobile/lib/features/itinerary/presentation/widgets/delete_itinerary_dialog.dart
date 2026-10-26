import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

Future<bool?> showDeleteItineraryConfirmationDialog(
  BuildContext context, {
  required String itineraryTitle,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xác nhận xóa lịch trình'),
      content: Text(
        'Bạn có chắc chắn muốn xóa lịch trình "$itineraryTitle" không?\n\n'
        'Lịch trình này sẽ bị gỡ bỏ khỏi danh sách lịch trình hoạt động của bạn.',
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
          child: const Text('Xóa lịch trình'),
        ),
      ],
    ),
  );
}
