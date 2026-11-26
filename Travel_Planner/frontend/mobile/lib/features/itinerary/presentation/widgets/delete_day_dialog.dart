import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_dialog.dart';

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

  return AppDialog.showConfirm(
    context,
    type: AppDialogType.danger,
    title: 'Xác nhận xóa Ngày $dayNumber',
    message:
        'Bạn có chắc chắn muốn xóa Ngày $dayNumber$titleSuffix không?$warningNotice',
    confirmText: 'Xóa ngày',
    cancelText: 'Hủy',
  );
}
