import 'dart:ui';

import 'package:flutter/material.dart';

import 'bounce_tap.dart';

/// Standardized 38x38px circular header button for Travel Planner AppBars.
///
/// Supports two visual modes:
/// - Standard / Collapsed (`isOverlay: false`): `#F4F5F7` light grey circle
///   with `#1E1E1E` 20px icon (or `#FFF0F3` bg + `#FAD2DA` border + `#FA3E62`
///   icon when `isActive: true`).
/// - Overlay (`isOverlay: true`): `Colors.black.withValues(alpha: 0.35)` with
///   subtle [BackdropFilter] blur and white 20px icon, designed for full-bleed
///   collapsing cover headers.
class AppHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isOverlay;
  final bool isActive;
  final bool isHighlighted;
  final Color? iconColor;
  final Widget? badge;

  const AppHeaderIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.isOverlay = false,
    this.isActive = false,
    this.isHighlighted = false,
    this.iconColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final bool usePinkTint = !isOverlay && (isActive || isHighlighted);
    final Color bgColor = isOverlay
        ? Colors.black.withValues(alpha: 0.35)
        : (usePinkTint ? const Color(0xFFFFF0F3) : const Color(0xFFF4F5F7));
    final Color resolvedIconColor = iconColor ??
        (isOverlay
            ? Colors.white
            : (usePinkTint
                ? const Color(0xFFFA3E62)
                : const Color(0xFF1E1E1E)));

    Widget iconWidget = badge ??
        Icon(
          icon,
          size: 20,
          color: resolvedIconColor,
        );

    Widget circle = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: usePinkTint && isActive
            ? Border.all(color: const Color(0xFFFAD2DA), width: 1)
            : (isOverlay
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1,
                  )
                : null),
      ),
      alignment: Alignment.center,
      child: iconWidget,
    );

    if (isOverlay) {
      circle = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: circle,
        ),
      );
    }

    Widget button = BounceTap.icon(
      enabled: onPressed != null,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(child: circle),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

/// Standardized circular back button for AppBars and collapsing headers.
class AppHeaderBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isOverlay;

  const AppHeaderBackButton({
    super.key,
    this.onPressed,
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppHeaderIconButton(
      icon: Icons.arrow_back,
      tooltip: 'Quay lại',
      isOverlay: isOverlay,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
    );
  }
}

/// Pinned [SliverPersistentHeaderDelegate] for [TabBar] beneath a [SliverAppBar].
class PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  const PinnedTabBarDelegate(
    this.tabBar, {
    this.backgroundColor = const Color(0xFFFFFFFF),
  });

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F5)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant PinnedTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
