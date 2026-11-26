import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_dialog.dart';

Future<bool?> showDeleteActivityConfirmationDialog(
  BuildContext context, {
  required String activityName,
}) {
  return AppDialog.showConfirm(
    context,
    type: AppDialogType.danger,
    title: 'Xóa hoạt động',
    message:
        'Bạn có chắc chắn muốn xóa hoạt động "$activityName"? Hành động này không thể hoàn tác.',
    confirmText: 'Xóa hoạt động',
    cancelText: 'Hủy',
    useElevatedConfirmButton: true,
  );
}
