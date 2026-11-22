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
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final fullName =
        currentUser?['fullName'] ?? currentUser?['username'] ?? 'Quản trị viên';
    final isOnline = healthStatus == 'UP';

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Sidebar toggle
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary, size: 22),
            tooltip: 'Đóng/Mở menu',
            onPressed: onToggleSidebar,
          ),
          const SizedBox(width: 8),

          // Breadcrumbs & Title
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
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
                        color: AppColors.muted,
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
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  currentTab.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Backend Health indicator
          if (healthStatus != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFFECFDF5) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOnline ? const Color(0xFFA7F3D0) : Colors.amber.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? AppColors.success : Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'Hệ thống: Trực tuyến' : 'Hệ thống: $healthStatus',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOnline ? const Color(0xFF047857) : Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Profile chip button
          InkWell(
            onTap: onGoToProfile,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Logout button
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: AppColors.textSecondary),
            tooltip: 'Đăng xuất',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
