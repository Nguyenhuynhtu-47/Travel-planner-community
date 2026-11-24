import 'dart:async';
import 'package:flutter/material.dart';

/// Reusable subtle motion wrapper for interactive components on Flutter Web.
/// Provides smooth micro-translations (1–2px) on hover with zero layout shifts.
/// Aligned with the subtle movement refinement specification:
/// - Duration: 150ms
/// - Curve: Curves.easeOut
/// - Smooth return to (0,0) when pointer leaves
class HoverMovement extends StatefulWidget {
  final Widget child;
  final double dx;
  final double dy;
  final Duration duration;
  final Curve curve;
  final bool enabled;
  final MouseCursor? cursor;
  final ValueChanged<bool>? onHoverChanged;

  const HoverMovement({
    super.key,
    required this.child,
    this.dx = 0.0,
    this.dy = -1.5,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.easeOut,
    this.enabled = true,
    this.cursor,
    this.onHoverChanged,
  });

  /// Factory for button lift (upward translation by 1.5px)
  factory HoverMovement.button({
    Key? key,
    required Widget child,
    bool enabled = true,
    MouseCursor cursor = SystemMouseCursors.click,
  }) {
    return HoverMovement(
      key: key,
      dx: 0.0,
      dy: -1.5,
      enabled: enabled,
      cursor: cursor,
      child: child,
    );
  }

  /// Factory for card lift (upward translation by 2.0px)
  factory HoverMovement.card({
    Key? key,
    required Widget child,
    bool enabled = true,
    MouseCursor cursor = SystemMouseCursors.click,
  }) {
    return HoverMovement(
      key: key,
      dx: 0.0,
      dy: -2.0,
      enabled: enabled,
      cursor: cursor,
      child: child,
    );
  }

  /// Factory for navigation / sidebar slide (horizontal translation by 2.0px)
  factory HoverMovement.slide({
    Key? key,
    required Widget child,
    bool enabled = true,
    MouseCursor cursor = SystemMouseCursors.click,
  }) {
    return HoverMovement(
      key: key,
      dx: 2.0,
      dy: 0.0,
      enabled: enabled,
      cursor: cursor,
      child: child,
    );
  }

  /// Factory for row item subtle shift (horizontal translation by 1.5px)
  factory HoverMovement.row({
    Key? key,
    required Widget child,
    bool enabled = true,
  }) {
    return HoverMovement(
      key: key,
      dx: 1.5,
      dy: 0.0,
      enabled: enabled,
      cursor: SystemMouseCursors.basic,
      child: child,
    );
  }

  @override
  State<HoverMovement> createState() => _HoverMovementState();
}

class _HoverMovementState extends State<HoverMovement> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = disableMotion ? Duration.zero : widget.duration;

    return MouseRegion(
      cursor: widget.cursor ?? MouseCursor.defer,
      onEnter: (_) {
        if (!_isHovered) {
          setState(() => _isHovered = true);
          widget.onHoverChanged?.call(true);
        }
      },
      onExit: (_) {
        if (_isHovered) {
          setState(() => _isHovered = false);
          widget.onHoverChanged?.call(false);
        }
      },
      child: AnimatedContainer(
        duration: duration,
        curve: widget.curve,
        transform: Matrix4.translationValues(
          _isHovered ? widget.dx : 0.0,
          _isHovered ? widget.dy : 0.0,
          0.0,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Tracker class to coordinate hover state across all cells in an [AdminDataRow].
class RowHoverTracker {
  final ValueNotifier<bool> isHovered = ValueNotifier<bool>(false);
  int _activeCount = 0;
  Timer? _exitTimer;

  void enter() {
    _activeCount++;
    _exitTimer?.cancel();
    if (!isHovered.value) {
      isHovered.value = true;
    }
  }

  void exit() {
    _activeCount--;
    if (_activeCount <= 0) {
      _activeCount = 0;
      _exitTimer?.cancel();
      _exitTimer = Timer(const Duration(milliseconds: 35), () {
        if (_activeCount <= 0 && isHovered.value) {
          isHovered.value = false;
        }
      });
    }
  }

  void dispose() {
    _exitTimer?.cancel();
    isHovered.dispose();
  }
}
