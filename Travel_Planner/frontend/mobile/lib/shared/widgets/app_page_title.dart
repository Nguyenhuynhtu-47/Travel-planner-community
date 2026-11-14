import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Standardized Page Title widget for Mobile AppBars.
/// Provides a clear visual hierarchy with approximately 20sp, w700 typography
/// and a subtle short accent line beneath the title without requiring any subtitles.
class AppPageTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool showAccentLine;
  final double fontSize;

  const AppPageTitle({
    super.key,
    required this.title,
    this.icon,
    this.showAccentLine = true,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    Widget titleText = Text(
      title,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (icon != null) {
      titleText = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: fontSize,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 8),
          Flexible(child: titleText),
        ],
      );
    }

    if (!showAccentLine) {
      return titleText;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleText,
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 2.5,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }
}

