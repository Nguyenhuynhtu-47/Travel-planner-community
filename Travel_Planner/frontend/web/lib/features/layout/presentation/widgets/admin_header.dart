import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';

class AdminHeader extends StatelessWidget implements PreferredSizeWidget {
  final AdminTab currentTab;
  final Map<String, dynamic>? currentUser;
  final VoidCallback onToggleSidebar;
  final VoidCallback onGoToProfile;
  final VoidCallback onLogout;
  final String? healthStatus;

  const AdminHeader({
    super.key,
    required this.currentTab,
    required this.currentUser,
    required this.onToggleSidebar,
    required this.onGoToProfile,
    required this.onLogout,
    this.healthStatus,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppHeights.header);

  @override
  Widget build(BuildContext context) {
    final fullName =
        currentUser?['fullName'] ?? currentUser?['username'] ?? 'Quản trị viên';
    final isOnline = healthStatus == 'UP';

    return Container(
      height: AppHeights.header,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // Sidebar toggle
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary, size: 20),
            tooltip: 'Đóng/Mở menu',
            splashRadius: 20,
            onPressed: onToggleSidebar,
          ),
          const SizedBox(width: AppSpacing.sm),

          // Breadcrumbs & Title with horizontal scrolling protection for compact viewports
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('/', style: TextStyle(fontSize: 12, color: AppColors.borderStrong)),
                  ),
                  Text(
                    currentTab.group.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('/', style: TextStyle(fontSize: 12, color: AppColors.borderStrong)),
                  ),
                  Text(
                    currentTab.shortTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryAccessible,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Profile chip button
          InkWell(
            onTap: onGoToProfile,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            hoverColor: AppColors.surfaceHover,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Quản trị viên',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Logout Icon button
          IconButton(
            icon: const Icon(Icons.logout, size: 18, color: AppColors.textMuted),
            tooltip: 'Đăng xuất',
            splashRadius: 18,
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
