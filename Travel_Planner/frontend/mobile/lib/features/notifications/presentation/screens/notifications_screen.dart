import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: const AppEmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'Chưa có thông báo',
        message:
            'Khi có hoạt động hoặc cập nhật mới liên quan đến chuyến đi của bạn, thông báo sẽ xuất hiện tại đây.',
      ),
    );
  }
}
