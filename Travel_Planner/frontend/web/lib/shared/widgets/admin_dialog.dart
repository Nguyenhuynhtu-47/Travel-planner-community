import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';

/// Standard Swiss Minimalist Modal Dialog for Admin Portal.
/// Aligned with docs/plan/admin-design-system.md (Section 5.7).
/// Provides a structured 3-part layout:
/// - Header: Title with optional badge and close button [X].
/// - Body: Scrollable content area with standard padding.
/// - Footer: Sticky bottom action row with secondary and primary CTAs.
class AdminDialog extends StatelessWidget {
  final String title;
  final Widget? titleBadge;
  final Widget content;
  final List<Widget>? actions;
  final double width;
  final VoidCallback? onClose;

  const AdminDialog({
    super.key,
    required this.title,
    this.titleBadge,
    required this.content,
    this.actions,
    this.width = 560.0,
    this.onClose,
  });

  /// Static helper to display an [AdminDialog] cleanly.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    Widget? titleBadge,
    required Widget content,
    List<Widget>? actions,
    double width = 560.0,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AdminDialog(
        title: title,
        titleBadge: titleBadge,
        content: content,
        actions: actions,
        width: width,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTypography.titleSection,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (titleBadge != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          titleBadge!,
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    tooltip: 'Đóng',
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: content,
              ),
            ),

            // Footer
            if (actions != null && actions!.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.border),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.surfaceSubtle,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (int i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      actions![i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
