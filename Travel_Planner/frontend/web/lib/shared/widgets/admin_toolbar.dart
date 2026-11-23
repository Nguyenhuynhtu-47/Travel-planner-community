import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';

/// Standard, unified toolbar for Admin list and table views.
/// Hosts the search field, dropdown filters, and action buttons in a cohesive layout.
/// Rendered with a subtle background tint (`#F8FAFC`) and 1px bottom border.
class AdminToolbar extends StatelessWidget {
  final Widget? searchField;
  final List<Widget>? filters;
  final List<Widget>? actions;

  const AdminToolbar({
    super.key,
    this.searchField,
    this.filters,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 768;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?searchField,
                if (filters != null && filters!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: filters!,
                  ),
                ],
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              if (searchField != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320, minWidth: 200),
                  child: searchField!,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              if (filters != null && filters!.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: filters!,
                  ),
                )
              else
                const Spacer(),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
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
