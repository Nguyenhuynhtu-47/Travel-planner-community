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
    final width = isCollapsed ? 68.0 : 252.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Branding header
          _buildLogo(),
          const Divider(height: 1, color: AppColors.border),

          // Flat Menu Navigation with consistent SaaS icons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
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

          // Bottom collapse toggle control
          _buildCollapseToggle(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.travel_explore,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Travel Planner',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Admin Portal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
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
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Divider(
            height: 1, indent: 14, endIndent: 14, color: AppColors.hairlineSoft),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 12, top: 14, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Flat menu item with uniform icon, spacing, and styling
  Widget _buildMenuItem(
    AdminTab tab, {
    int badgeCount = 0,
  }) {
    final isSelected = currentTab == tab;
    final iconData = isSelected ? tab.activeIcon : tab.icon;

    if (isCollapsed) {
      return Tooltip(
        message: tab.title,
        preferBelow: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: InkWell(
            onTap: () => onSelectTab(tab),
            borderRadius: BorderRadius.circular(6),
            hoverColor: isSelected ? AppColors.primaryLight : AppColors.surfaceSoft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    iconData,
                    size: 20,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () => onSelectTab(tab),
        borderRadius: BorderRadius.circular(6),
        hoverColor: isSelected ? AppColors.primaryLight : AppColors.surfaceSoft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                iconData,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tab.shortTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!tab.isImplemented)
                _buildComingSoonBadge()
              else if (badgeCount > 0)
                _buildCountBadge(badgeCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildComingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Sắp có',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildCollapseToggle() {
    if (isCollapsed) {
      return Container(
        height: 48,
        alignment: Alignment.center,
        child: Tooltip(
          message: 'Mở rộng menu',
          child: IconButton(
            icon: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            onPressed: onToggleCollapse,
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onToggleCollapse,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.chevron_left, size: 18, color: AppColors.muted),
                    SizedBox(width: 8),
                    Text(
                      'Thu gọn menu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
