import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';

class AdminSidebar extends StatelessWidget {
  final AdminTab currentTab;
  final ValueChanged<AdminTab> onSelectTab;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final Map<String, dynamic>? currentUser;
  final VoidCallback onLogout;
  final int pendingReportsCount;

  const AdminSidebar({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.currentUser,
    required this.onLogout,
    this.pendingReportsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final width = isCollapsed ? 72.0 : 260.0;
    final fullName =
        currentUser?['fullName'] ?? currentUser?['username'] ?? 'Quản trị viên';
    final role = currentUser?['role']?.toString().toUpperCase() ?? 'ADMIN';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo & Header
          _buildLogo(),
          const Divider(height: 1, color: AppColors.border),

          // Menu navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildGroupHeader('TỔNG QUAN'),
                _buildMenuItem(AdminTab.dashboard),

                _buildGroupHeader('QUẢN LÝ CỘNG ĐỒNG'),
                _buildMenuItem(AdminTab.posts),
                _buildMenuItem(
                  AdminTab.reports,
                  badgeCount: pendingReportsCount,
                ),
                _buildMenuItem(AdminTab.users),

                _buildGroupHeader('QUẢN LÝ DU LỊCH'),
                _buildMenuItem(AdminTab.places),
                _buildMenuItem(AdminTab.itineraries),

                _buildGroupHeader('QUẢN LÝ NỘI DUNG'),
                _buildMenuItem(AdminTab.media),
                _buildMenuItem(AdminTab.administrativeAreas),

                _buildGroupHeader('HỆ THỐNG'),
                _buildMenuItem(AdminTab.auditLogs),
                _buildMenuItem(AdminTab.settings),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Footer - User info & actions
          _buildFooter(fullName, role),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.travel_explore,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Travel Planner',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Admin Portal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    if (isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.hairlineSoft),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 16, top: 18, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildMenuItem(AdminTab tab, {int badgeCount = 0}) {
    final isSelected = currentTab == tab;

    final itemWidget = Container(
      margin: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => onSelectTab(tab),
        borderRadius: BorderRadius.circular(8),
        hoverColor: isSelected ? AppColors.primaryLight : AppColors.surfaceSoft,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 12 : 14,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? tab.activeIcon : tab.icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tab.shortTitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!tab.isImplemented)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Sắp có',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                else if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(
        message: tab.title,
        preferBelow: false,
        child: itemWidget,
      );
    }

    return itemWidget;
  }

  Widget _buildFooter(String fullName, String role) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Tooltip(
              message: 'Hồ sơ ($fullName)',
              child: IconButton(
                icon: const Icon(Icons.person_outline, size: 22, color: AppColors.textSecondary),
                onPressed: () => onSelectTab(AdminTab.profile),
              ),
            ),
            const SizedBox(height: 4),
            Tooltip(
              message: 'Mở rộng menu',
              child: IconButton(
                icon: const Icon(Icons.chevron_right, size: 22, color: AppColors.textSecondary),
                onPressed: onToggleCollapse,
              ),
            ),
            const SizedBox(height: 4),
            Tooltip(
              message: 'Đăng xuất',
              child: IconButton(
                icon: const Icon(Icons.logout, size: 20, color: AppColors.error),
                onPressed: onLogout,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          InkWell(
            onTap: () => onSelectTab(AdminTab.profile),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Thu gọn', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: onToggleCollapse,
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
                tooltip: 'Đăng xuất',
                onPressed: onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
