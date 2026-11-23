import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';

/// Flat, compact tab bar for Admin screens with nested sub-views.
/// Replaces oversized pill tabs with a high-density, professional SaaS tab strip.
class AdminTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<String> tabs;
  final ValueChanged<int>? onTap;

  const AdminTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.onTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        onTap: onTap,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        indicatorColor: AppColors.primary,
        indicatorWeight: 2,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        tabs: tabs.map((title) => Tab(text: title)).toList(),
      ),
    );
  }
}
