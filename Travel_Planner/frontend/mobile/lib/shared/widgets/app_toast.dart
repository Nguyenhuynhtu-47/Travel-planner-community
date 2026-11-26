import 'dart:async';

import 'package:flutter/material.dart';

enum AppToastType { error, success, warning, info }

/// Global top-floating toast notification system using Flutter's [Overlay].
///
/// Displays a single non-overlapping card below the top [SafeArea] so it is
/// never obscured by the virtual keyboard. Supports swipe-up to dismiss,
/// close button, optional action button, and 3-second auto-dismissal.
class AppToast {
  static OverlayEntry? _currentEntry;

  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      type: AppToastType.error,
      title: title ?? 'Thông báo lỗi',
      message: message,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      type: AppToastType.success,
      title: title ?? 'Thành công',
      message: message,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      type: AppToastType.warning,
      title: title ?? 'Cảnh báo',
      message: message,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      type: AppToastType.info,
      title: title ?? 'Thông báo',
      message: message,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void dismiss() {
    final entry = _currentEntry;
    _currentEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }

  static void _show(
    BuildContext context, {
    required AppToastType type,
    required String title,
    required String message,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Close any active toast before showing the new one
    dismiss();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _AppToastOverlay(
        type: type,
        title: title,
        message: message,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        onDisposed: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
        },
        onDismiss: () {
          if (_currentEntry == entry) {
            dismiss();
          } else if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _AppToastStyle {
  final Color accentColor;
  final Color badgeBgColor;
  final IconData icon;

  const _AppToastStyle({
    required this.accentColor,
    required this.badgeBgColor,
    required this.icon,
  });

  static _AppToastStyle fromType(AppToastType type) {
    switch (type) {
      case AppToastType.error:
        return const _AppToastStyle(
          accentColor: Color(0xFFFA3E62),
          badgeBgColor: Color(0xFFFFF0F3),
          icon: Icons.error_outline_rounded,
        );
      case AppToastType.success:
        return const _AppToastStyle(
          accentColor: Color(0xFF10B981),
          badgeBgColor: Color(0xFFECFDF5),
          icon: Icons.check_circle_outline_rounded,
        );
      case AppToastType.warning:
        return const _AppToastStyle(
          accentColor: Color(0xFFF59E0B),
          badgeBgColor: Color(0xFFFFFBEB),
          icon: Icons.warning_amber_rounded,
        );
      case AppToastType.info:
        return const _AppToastStyle(
          accentColor: Color(0xFF3B82F6),
          badgeBgColor: Color(0xFFEFF6FF),
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _AppToastOverlay extends StatefulWidget {
  final AppToastType type;
  final String title;
  final String message;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
  final VoidCallback onDisposed;

  const _AppToastOverlay({
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
    required this.onDisposed,
  });

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.20, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();

    _autoDismissTimer = Timer(widget.duration, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    widget.onDisposed();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final style = _AppToastStyle.fromType(widget.type);

    return Positioned(
      top: topInset + 12,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < -150) {
                    widget.onDismiss();
                  }
                },
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFF0F0F5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left status icon badge
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: style.badgeBgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            style.icon,
                            color: style.accentColor,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Middle title + message
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E1E1E),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF6E6E73),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Optional action button
                        if (widget.actionLabel != null &&
                            widget.onAction != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              widget.onDismiss();
                              widget.onAction!();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: style.accentColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              widget.actionLabel!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: style.accentColor,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(width: 4),
                        // Right close button
                        InkWell(
                          onTap: widget.onDismiss,
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
