import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/bounce_tap.dart';

/// Design tokens for the Travel Planner Authentication Flow UI.
class AuthUiTokens {
  static const Color primary = Color(0xFFFA3E62);
  static const Color primaryGradientEnd = Color(0xFFFF7A8F);
  static const Color primaryDisabled = Color(0xFFFAD2DA);
  static const Color background = Color(0xFFFFFFFF);
  static const Color title = Color(0xFF1E1E1E);
  static const Color subtitle = Color(0xFF6E6E73);
  static const Color border = Color(0xFFE5E7EB);
}

/// Frosted-glass circular back button placed on the curved wave header.
class AuthBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AuthBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return BounceTap.icon(
      child: Material(
        color: Colors.white.withValues(alpha: 0.20),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Curved organic wave header with pink-red gradient and topographic contour lines.
///
/// Supports two proportions:
/// - Standard (`isCompact: false`): ~31% of screen height with a floating white
///   circular icon badge centered at the wave boundary.
/// - Compact (`isCompact: true`): ~19% of screen height with an inline title
///   for dense forms like Registration or Change Password.
class AuthWaveHeader extends StatelessWidget {
  final IconData? icon;
  final String? compactTitle;
  final String? compactSubtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool isCompact;
  final double? waveHeightRatio;
  final double? badgeSize;

  const AuthWaveHeader({
    super.key,
    this.icon,
    this.compactTitle,
    this.compactSubtitle,
    this.showBackButton = true,
    this.onBack,
    this.isCompact = false,
    this.waveHeightRatio,
    this.badgeSize,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;

    // 30%-35% for standard screens, 18%-22% for compact or custom ratio screens
    final double effectiveRatio = waveHeightRatio ?? (isCompact ? 0.18 : 0.30);
    final double minH = (isCompact || waveHeightRatio != null) ? 96.0 : 185.0;
    final double maxH = (isCompact || waveHeightRatio != null) ? 172.0 : 275.0;
    final double baseWaveHeight = (screenHeight * effectiveRatio).clamp(minH, maxH);

    final double minSafeH = topPadding + ((isCompact || waveHeightRatio != null) ? 72.0 : 130.0);
    final double waveHeight = baseWaveHeight < minSafeH ? minSafeH : baseWaveHeight;

    final bool hasBadge = !isCompact && icon != null;
    final double effectiveBadgeSize = badgeSize ?? 72.0;
    final double totalHeight = hasBadge ? waveHeight + (effectiveBadgeSize * 0.34) : waveHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        width: double.infinity,
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Gradient + Topographic pattern clipped by organic wave
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: waveHeight,
              child: ClipPath(
                clipper: _AuthWaveClipper(isCompact: isCompact),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AuthUiTokens.primary,
                        AuthUiTokens.primaryGradientEnd,
                      ],
                    ),
                  ),
                  child: CustomPaint(
                    painter: _TopographicContourPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),

            // Back button in safe area
            if (showBackButton)
              Positioned(
                top: topPadding + 10,
                left: 16,
                child: AuthBackButton(
                  onPressed: onBack ?? () => Navigator.of(context).pop(),
                ),
              ),

            // Compact mode title inside the wave
            if (isCompact && compactTitle != null)
              Positioned(
                top: topPadding + 12,
                left: showBackButton ? 68 : 24,
                right: 24,
                bottom: 24,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compactTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (compactSubtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          compactSubtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.90),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Standard mode floating white circular icon badge on the wave
            if (hasBadge)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: effectiveBadgeSize,
                    height: effectiveBadgeSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AuthUiTokens.primary.withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AuthUiTokens.primary.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: effectiveBadgeSize * 0.47,
                      color: AuthUiTokens.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Organic asymmetric wave clipper matching the reference aesthetic.
class _AuthWaveClipper extends CustomClipper<Path> {
  final bool isCompact;

  const _AuthWaveClipper({required this.isCompact});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()..lineTo(0, h * (isCompact ? 0.78 : 0.76));

    // Smooth S-curve wave: gentle crest on left-center, dip on right-center
    path.cubicTo(
      w * 0.22,
      h * (isCompact ? 0.64 : 0.62),
      w * 0.42,
      h * (isCompact ? 0.88 : 0.86),
      w * 0.62,
      h * (isCompact ? 0.94 : 0.93),
    );
    path.cubicTo(
      w * 0.78,
      h * (isCompact ? 1.00 : 1.00),
      w * 0.90,
      h * (isCompact ? 0.96 : 0.95),
      w,
      h * (isCompact ? 0.84 : 0.82),
    );

    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _AuthWaveClipper oldClipper) {
    return oldClipper.isCompact != isCompact;
  }
}

/// Draws subtle topographic contour lines inside the header for depth and travel theme.
class _TopographicContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..isAntiAlias = true;

    // 1. Nested organic contour loops centered upper-left
    _drawContourFamily(
      canvas: canvas,
      center: Offset(w * 0.22, h * 0.36),
      radiiX: [w * 0.10, w * 0.18, w * 0.27, w * 0.37, w * 0.48],
      radiiY: [h * 0.13, h * 0.22, h * 0.33, h * 0.45, h * 0.58],
      wobbleSeed: 1.2,
      paint: basePaint..color = Colors.white.withValues(alpha: 0.16),
    );

    // 2. Secondary contour loops centered lower-right
    _drawContourFamily(
      canvas: canvas,
      center: Offset(w * 0.80, h * 0.62),
      radiiX: [w * 0.08, w * 0.16, w * 0.25, w * 0.35, w * 0.46],
      radiiY: [h * 0.11, h * 0.20, h * 0.31, h * 0.43, h * 0.56],
      wobbleSeed: 2.7,
      paint: basePaint..color = Colors.white.withValues(alpha: 0.13),
    );

    // 3. Flowing topographic ridge lines across the canvas
    final ridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.10)
      ..isAntiAlias = true;

    for (int i = 0; i < 4; i++) {
      final yOffset = h * (0.14 + i * 0.18);
      final path = Path()..moveTo(-w * 0.05, yOffset);
      path.cubicTo(
        w * 0.28,
        yOffset - h * 0.14,
        w * 0.62,
        yOffset + h * 0.16,
        w * 1.05,
        yOffset - h * 0.05,
      );
      canvas.drawPath(path, ridgePaint);
    }
  }

  void _drawContourFamily({
    required Canvas canvas,
    required Offset center,
    required List<double> radiiX,
    required List<double> radiiY,
    required double wobbleSeed,
    required Paint paint,
  }) {
    const int segments = 24;
    for (int ring = 0; ring < radiiX.length; ring++) {
      final rx = radiiX[ring];
      final ry = radiiY[ring];
      final points = <Offset>[];

      for (int i = 0; i < segments; i++) {
        final angle = (i / segments) * 2 * math.pi;
        final wobble = 1.0 +
            0.14 * math.sin(angle * 2 + wobbleSeed + ring * 0.4) +
            0.08 * math.cos(angle * 3 - wobbleSeed);
        points.add(
          Offset(
            center.dx + rx * wobble * math.cos(angle),
            center.dy + ry * wobble * math.sin(angle),
          ),
        );
      }

      final path = _smoothClosedPath(points);
      canvas.drawPath(path, paint);
    }
  }

  Path _smoothClosedPath(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;

    final int n = pts.length;
    final firstMid = Offset(
      (pts[n - 1].dx + pts[0].dx) / 2,
      (pts[n - 1].dy + pts[0].dy) / 2,
    );
    path.moveTo(firstMid.dx, firstMid.dy);

    for (int i = 0; i < n; i++) {
      final p0 = pts[i];
      final p1 = pts[(i + 1) % n];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _TopographicContourPainter oldDelegate) => false;
}
