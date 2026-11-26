import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tactile spring-bounce wrapper for buttons and interactive elements.
///
/// Uses [Listener] to observe pointer events without competing in Flutter's
/// gesture arena, so it never conflicts with [ElevatedButton], [IconButton],
/// [InkWell], [TabBar], [BottomNavigationBar], or scrollable lists.
///
/// - On press (`onPointerDown`): scales down to [pressedScale] in 90ms.
/// - On release/cancel (`onPointerUp` / `onPointerCancel`): springs to ~1.035
///   and settles back to 1.0 in 170ms.
class BounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double pressedScale;
  final double overshootScale;
  final bool useSelectionHaptic;
  final HitTestBehavior behavior;

  const BounceTap({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.pressedScale = 0.95,
    this.overshootScale = 1.035,
    this.useSelectionHaptic = false,
    this.behavior = HitTestBehavior.opaque,
  });

  /// Preset for small icon buttons (Like, Favorite, Share, Bookmark, AppBar icons).
  const BounceTap.icon({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.pressedScale = 0.87,
    this.overshootScale = 1.05,
    this.useSelectionHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Offset? _downPosition;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isInteractive => widget.enabled;

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isInteractive) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;

    _downPosition = event.position;
    _isPressed = true;

    if (widget.useSelectionHaptic) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }

    final current = _scaleAnimation.value;
    _controller.duration = const Duration(milliseconds: 90);
    _scaleAnimation = Tween<double>(
      begin: current,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    ));
    _controller.forward(from: 0.0);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isPressed || _downPosition == null) return;
    // Cancel press bounce if user starts dragging/scrolling
    if ((event.position - _downPosition!).distance > 18.0) {
      _springBack();
    }
  }

  void _springBack() {
    if (!_isPressed) return;
    _isPressed = false;
    _downPosition = null;

    if (!mounted) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);
      return;
    }

    final current = _scaleAnimation.value;
    _controller.duration = const Duration(milliseconds: 170);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: current, end: widget.overshootScale)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.overshootScale, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_controller);
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = GestureDetector(
        behavior: widget.behavior,
        onTap: widget.enabled ? widget.onTap : null,
        child: content,
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: (_) => _springBack(),
      onPointerCancel: (_) => _springBack(),
      child: content,
    );
  }
}
