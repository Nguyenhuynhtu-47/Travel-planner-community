import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/shared/widgets/hover_movement.dart';

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
    final width = isCollapsed ? 68.0 : AppHeights.sidebarExpanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: ClipRect(
        child: OverflowBox(
          minWidth: isCollapsed ? 68.0 : AppHeights.sidebarExpanded,
          maxWidth: isCollapsed ? 68.0 : AppHeights.sidebarExpanded,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo & Branding header
              _buildLogo(),
              const Divider(height: 1, color: AppColors.border),

              // Flat Menu Navigation with consistent SaaS icons
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                    _buildMenuItem(AdminTab.announcements),
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
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: AppHeights.header,
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 12 : AppSpacing.lg,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sidebarItem),
            ),
            child: const Icon(
              Icons.travel_explore,
              color: Colors.white,
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
                    'Cổng quản trị',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
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
          height: 1,
          indent: 14,
          endIndent: 14,
          color: AppColors.hairlineSoft,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 12, top: 14, bottom: 4),
      child: Text(
        title,
        style: AppTypography.captionTable.copyWith(
          fontSize: 10.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  // Flat menu item with uniform icon, spacing, and styling
  Widget _buildMenuItem(AdminTab tab, {int badgeCount = 0}) {
    return _SidebarMenuItem(
      tab: tab,
      isSelected: currentTab == tab,
      isCollapsed: isCollapsed,
      badgeCount: badgeCount,
      onSelectTab: onSelectTab,
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
            icon: const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: onToggleCollapse,
          ),
        ),
      );
    }

    return HoverMovement.slide(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggleCollapse,
            hoverColor: AppColors.primaryTint,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Thu gọn',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarMenuItem extends StatefulWidget {
  final AdminTab tab;
  final bool isSelected;
  final bool isCollapsed;
  final int badgeCount;
  final ValueChanged<AdminTab> onSelectTab;

  const _SidebarMenuItem({
    required this.tab,
    required this.isSelected,
    required this.isCollapsed,
    required this.badgeCount,
    required this.onSelectTab,
  });

  @override
  State<_SidebarMenuItem> createState() => _SidebarMenuItemState();
}

class _SidebarMenuItemState extends State<_SidebarMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final isSelected = widget.isSelected;
    final isHovered = _isHovered && !isSelected;
    final iconData = isSelected ? tab.activeIcon : tab.icon;

    if (widget.isCollapsed) {
      return Tooltip(
        message: tab.title,
        preferBelow: false,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onSelectTab(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(
                isHovered ? 2.0 : 0.0,
                0.0,
                0.0,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLight
                    : (isHovered ? AppColors.primaryTint : Colors.transparent),
                borderRadius: BorderRadius.circular(AppRadius.sidebarItem),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryBorder
                      : (isHovered
                            ? AppColors.primaryBorder
                            : Colors.transparent),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    iconData,
                    size: 20,
                    color: isSelected
                        ? AppColors.primaryAccessible
                        : (isHovered
                              ? AppColors.primaryAccessible
                              : AppColors.textSecondary),
                  ),
                  if (widget.badgeCount > 0)
                    Positioned(
                      top: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          widget.badgeCount > 99
                              ? '99+'
                              : widget.badgeCount.toString(),
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onSelectTab(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(isHovered ? 2.0 : 0.0, 0.0, 0.0),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryLight
                : (isHovered ? AppColors.primaryTint : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.sidebarItem),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryBorder
                  : (isHovered ? AppColors.primaryBorder : Colors.transparent),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 6,
                  bottom: 6,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 7,
                  bottom: 7,
                ),
                child: Row(
                  children: [
                    Icon(
                      iconData,
                      size: 18,
                      color: isSelected
                          ? AppColors.primaryAccessible
                          : (isHovered
                                ? AppColors.primaryAccessible
                                : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tab.shortTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : (isHovered ? FontWeight.w500 : FontWeight.w400),
                          color: isSelected
                              ? AppColors.primaryAccessible
                              : (isHovered
                                    ? AppColors.primaryAccessible
                                    : AppColors.textPrimary),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!tab.isImplemented)
                      _buildComingSoonBadge()
                    else if (widget.badgeCount > 0)
                      _buildCountBadge(widget.badgeCount),
                  ],
                ),
              ),
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
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Text(
        'Sắp có',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
