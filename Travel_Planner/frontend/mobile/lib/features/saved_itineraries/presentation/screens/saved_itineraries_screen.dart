import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_header_button.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';

class SavedItinerariesScreen extends StatelessWidget {
  const SavedItinerariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lịch trình đã lưu',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        actions: [
          AppHeaderIconButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Thông báo',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const AppEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'Lịch trình đã lưu',
        message:
            'Tính năng lưu và đánh dấu lịch trình yêu thích đang được phát triển và sẽ sớm ra mắt.',
      ),
    );
  }
}
