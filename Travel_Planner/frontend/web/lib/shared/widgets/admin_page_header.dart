import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';

/// Standard, flat page header for Admin screens.
/// Displays the screen title, optional descriptive subtitle, and primary/secondary actions.
/// Follows Swiss Minimalist styling with sharp 1px hairline border separation.
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 960;

          final titleColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.titlePage,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          );

          if (isCompact && actions != null && actions!.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(child: titleColumn),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions!,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(child: titleColumn),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.lg),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
