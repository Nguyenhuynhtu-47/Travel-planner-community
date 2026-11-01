import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ThemeCategoryItem {
  final String title;
  final IconData icon;

  const ThemeCategoryItem({
    required this.title,
    required this.icon,
  });
}

class ThemeCategoryCard extends StatelessWidget {
  final ThemeCategoryItem item;
  final VoidCallback onTap;
  final bool isSelected;

  const ThemeCategoryCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isSelected = false,
  });

  static const List<ThemeCategoryItem> defaultThemes = [
    ThemeCategoryItem(
      title: 'Nghỉ dưỡng',
      icon: Icons.beach_access_rounded,
    ),
    ThemeCategoryItem(
      title: 'Khám phá',
      icon: Icons.explore_rounded,
    ),
    ThemeCategoryItem(
      title: 'Ẩm thực',
      icon: Icons.restaurant_rounded,
    ),
    ThemeCategoryItem(
      title: 'Văn hóa',
      icon: Icons.temple_buddhist_rounded,
    ),
    ThemeCategoryItem(
      title: 'Phiêu lưu',
      icon: Icons.terrain_rounded,
    ),
    ThemeCategoryItem(
      title: 'Sinh thái',
      icon: Icons.forest_rounded,
    ),
    ThemeCategoryItem(
      title: 'Biển đảo',
      icon: Icons.sailing_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 90,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.textPrimary : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.textPrimary : AppColors.hairlineSoft,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.surfaceSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
