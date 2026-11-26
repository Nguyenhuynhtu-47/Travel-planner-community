import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? disabledBackgroundColor;
  final double? borderRadius;
  final double? height;

  const AppPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.borderRadius,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);

    final activeColor = backgroundColor ?? AppColors.primary;
    final disabledColor = disabledBackgroundColor ?? AppColors.primaryDisabled;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: activeColor,
        disabledBackgroundColor: isLoading ? activeColor : disabledColor,
        disabledForegroundColor: Colors.white,
        minimumSize: height != null ? Size.fromHeight(height!) : null,
        shape: borderRadius != null
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius!),
              )
            : null,
      ),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: isLoading
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(text, key: ValueKey('text_$text')),
      ),
    );
  }
}
