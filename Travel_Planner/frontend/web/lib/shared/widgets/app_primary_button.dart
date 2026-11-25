import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'hover_movement.dart';

/// Standard Primary CTA button for Flutter Web Admin.
/// Follows Swiss Minimalist styling with a 4px corner radius and solid Teal background.
/// Features subtle upward movement (1.5px) on hover with zero layout shifts.
class AppPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;
  final double fontSize;

  const AppPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);

    final buttonChild = AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              key: ValueKey('text_$text'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: Colors.white),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );

    final btn = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (isLoading) return AppColors.primary;
          if (states.contains(WidgetState.disabled)) {
            return AppColors.primaryDisabled;
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primaryPressed;
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primaryDark;
          }
          return AppColors.primary;
        }),
        foregroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(64, height ?? AppHeights.buttonStandard),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        elevation: const WidgetStatePropertyAll<double>(0),
      ),
      child: buttonChild,
    );

    final animatedBtn = HoverMovement.button(
      enabled: onPressed != null && !isLoading,
      cursor: (onPressed == null || isLoading)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: btn,
    );

    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: animatedBtn);
    }
    return animatedBtn;
  }
}
