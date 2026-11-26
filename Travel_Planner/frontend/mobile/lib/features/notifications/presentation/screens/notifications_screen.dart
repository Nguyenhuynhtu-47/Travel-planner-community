import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_header_button.dart';
import '../../../../shared/widgets/app_page_title.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leadingWidth: 58,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Center(child: AppHeaderBackButton()),
        ),
        title: const AppPageTitle(title: 'Thông báo', fontSize: 18),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: AppColors.hairlineSoft,
          ),
        ),
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
