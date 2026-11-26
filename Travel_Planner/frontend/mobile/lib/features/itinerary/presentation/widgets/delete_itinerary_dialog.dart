import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_dialog.dart';

Future<bool?> showDeleteItineraryConfirmationDialog(
  BuildContext context, {
  required String itineraryTitle,
}) {
  return AppDialog.showConfirm(
    context,
    type: AppDialogType.danger,
    title: 'Xác nhận xóa lịch trình',
    message:
        'Bạn có chắc chắn muốn xóa lịch trình "$itineraryTitle" không?\n\n'
        'Lịch trình này sẽ bị gỡ bỏ khỏi danh sách lịch trình hoạt động của bạn.',
    confirmText: 'Xóa lịch trình',
    cancelText: 'Hủy',
  );
}
