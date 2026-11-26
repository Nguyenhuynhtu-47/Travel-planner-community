import 'package:flutter/material.dart';

import 'bounce_tap.dart';

enum AppDialogType { danger, logout, warning, info, success }

/// Modern centered confirmation & alert dialog for Travel Planner.
///
/// Uses [showGeneralDialog] with a 220ms `ScaleTransition` (0.9 -> 1.0,
/// `Curves.easeOutBack`) + `FadeTransition`, centered icon badge, and
/// equal-width dual action buttons wrapped with [BounceTap].
class AppConfirmDialog extends StatelessWidget {
  final AppDialogType type;
  final IconData? icon;
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool showCancel;
  final bool useElevatedConfirmButton;

  const AppConfirmDialog({
    super.key,
    this.type = AppDialogType.danger,
    this.icon,
    required this.title,
    required this.message,
    this.confirmText = 'Xác nhận',
    this.cancelText = 'Hủy',
    this.showCancel = true,
    this.useElevatedConfirmButton = false,
  });

  _AppDialogVisuals get _visuals {
    switch (type) {
      case AppDialogType.danger:
        return _AppDialogVisuals(
          icon: icon ?? Icons.delete_outline_rounded,
          iconColor: const Color(0xFFFA3E62),
          badgeBgColor: const Color(0xFFFFF0F3),
        );
      case AppDialogType.logout:
        return _AppDialogVisuals(
          icon: icon ?? Icons.logout_rounded,
          iconColor: const Color(0xFFFA3E62),
          badgeBgColor: const Color(0xFFFFF0F3),
        );
      case AppDialogType.warning:
        return _AppDialogVisuals(
          icon: icon ?? Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF59E0B),
          badgeBgColor: const Color(0xFFFFFBEB),
        );
      case AppDialogType.info:
        return _AppDialogVisuals(
          icon: icon ?? Icons.info_outline_rounded,
          iconColor: const Color(0xFFFA3E62),
          badgeBgColor: const Color(0xFFFFF0F3),
        );
      case AppDialogType.success:
        return _AppDialogVisuals(
          icon: icon ?? Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF10B981),
          badgeBgColor: const Color(0xFFECFDF5),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = _visuals;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = (screenWidth * 0.86).clamp(280.0, 400.0);

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Top icon badge (56x56, radius 16)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: visuals.badgeBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  visuals.icon,
                  color: visuals.iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              // 2. Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E1E),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // 3. Description message
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6E6E73),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // 4. Equal-width dual action buttons
              Row(
                children: [
                  if (showCancel) ...[
                    Expanded(
                      child: BounceTap(
                        child: SizedBox(
                          height: 46,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF4B5563),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              cancelText,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: BounceTap(
                      child: SizedBox(
                        height: 46,
                        child: useElevatedConfirmButton
                            ? ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFA3E62),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  confirmText,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : FilledButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFA3E62),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  confirmText,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDialogVisuals {
  final IconData icon;
  final Color iconColor;
  final Color badgeBgColor;

  const _AppDialogVisuals({
    required this.icon,
    required this.iconColor,
    required this.badgeBgColor,
  });
}

/// Helper entry point to show [AppConfirmDialog] with smooth scale + fade animation.
class AppDialog {
  static Future<bool?> showConfirm(
    BuildContext context, {
    AppDialogType type = AppDialogType.danger,
    IconData? icon,
    required String title,
    required String message,
    String confirmText = 'Xác nhận',
    String cancelText = 'Hủy',
    bool showCancel = true,
    bool barrierDismissible = true,
    bool useElevatedConfirmButton = false,
  }) {
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration:
          disableMotion ? Duration.zero : const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondaryAnimation) => AppConfirmDialog(
        type: type,
        icon: icon,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        showCancel: showCancel,
        useElevatedConfirmButton: useElevatedConfirmButton,
      ),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        if (disableMotion) return child;
        final scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
    );
  }

  static Future<bool?> showInfo(
    BuildContext context, {
    IconData? icon,
    required String title,
    required String message,
    String buttonText = 'Đã hiểu',
    bool barrierDismissible = true,
  }) {
    return showConfirm(
      context,
      type: AppDialogType.info,
      icon: icon,
      title: title,
      message: message,
      confirmText: buttonText,
      showCancel: false,
      barrierDismissible: barrierDismissible,
    );
  }
}
