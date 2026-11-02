import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../core/theme/app_colors.dart';

/// Reusable marker builder for map views.
///
/// Builds lightweight, custom map markers with sequence numbers,
/// day badges, and customizable colors without coupling to itinerary or activity models.
class MapMarkerBuilder {
  MapMarkerBuilder._();

  /// Builds a stop/activity marker pin with an optional sequence number and day badge.
  ///
  /// Anchored at the bottom tip ([Alignment.topCenter]) so that the pin points
  /// directly to [point].
  static Marker buildStopMarker({
    required LatLng point,
    int? sequence,
    String? dayBadge,
    Color pinColor = AppColors.primary,
    Color badgeColor = AppColors.textPrimary,
    Color textColor = Colors.white,
    IconData? icon,
    VoidCallback? onTap,
    double width = 42.0,
    double height = 54.0,
    String? semanticLabel,
    Key? key,
  }) {
    final markerWidget = _StopMarkerWidget(
      sequence: sequence,
      dayBadge: dayBadge,
      pinColor: pinColor,
      badgeColor: badgeColor,
      textColor: textColor,
      icon: icon,
      width: width,
      height: height,
      semanticLabel: semanticLabel,
    );

    return Marker(
      key: key,
      point: point,
      width: width,
      height: height,
      alignment: Alignment.topCenter,
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: markerWidget,
            )
          : markerWidget,
    );
  }

  /// Builds a classic destination or drop-pin marker.
  ///
  /// Anchored at the bottom tip ([Alignment.topCenter]).
  static Marker buildPinMarker({
    required LatLng point,
    Color color = AppColors.primary,
    Color iconColor = Colors.white,
    IconData icon = Icons.place,
    double size = 44.0,
    VoidCallback? onTap,
    String? semanticLabel,
    Key? key,
  }) {
    final pinWidget = SizedBox(
      width: size,
      height: size,
      child: Semantics(
        label: semanticLabel ?? 'Ghim vị trí',
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Drop shadow at bottom
            Positioned(
              bottom: 2,
              child: Container(
                width: size * 0.35,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.all(Radius.elliptical(12, 4)),
                ),
              ),
            ),
            // Pin Icon
            Positioned(
              top: 0,
              child: Icon(
                icon,
                size: size * 0.9,
                color: color,
                shadows: const [
                  Shadow(
                    color: Colors.black38,
                    offset: Offset(0, 1.5),
                    blurRadius: 3.0,
                  ),
                ],
              ),
            ),
            // Inner dot or accent
            Positioned(
              top: size * 0.22,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Marker(
      key: key,
      point: point,
      width: size,
      height: size,
      alignment: Alignment.topCenter,
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: pinWidget,
            )
          : pinWidget,
    );
  }

  /// Builds a user current location / GPS indicator dot.
  ///
  /// Anchored at the exact center ([Alignment.center]).
  static Marker buildGpsMarker({
    required LatLng point,
    double size = 22.0,
    Color color = AppColors.info,
    String? semanticLabel,
    Key? key,
  }) {
    return Marker(
      key: key,
      point: point,
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Semantics(
        label: semanticLabel ?? 'Vị trí hiện tại của bạn',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4.0,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a numbered circular badge marker.
  ///
  /// Anchored at the exact center ([Alignment.center]).
  static Marker buildNumberedMarker({
    required LatLng point,
    required int number,
    Color backgroundColor = AppColors.primary,
    Color textColor = Colors.white,
    double size = 32.0,
    VoidCallback? onTap,
    String? semanticLabel,
    Key? key,
  }) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 3.5,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );

    return Marker(
      key: key,
      point: point,
      width: size,
      height: size,
      alignment: Alignment.center,
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                label: semanticLabel ?? 'Điểm dừng số $number',
                child: badge,
              ),
            )
          : Semantics(
              label: semanticLabel ?? 'Điểm dừng số $number',
              child: badge,
            ),
    );
  }

  /// Flexible custom marker wrapper.
  static Marker buildCustomMarker({
    required LatLng point,
    required Widget child,
    double width = 40.0,
    double height = 40.0,
    Alignment alignment = Alignment.topCenter,
    VoidCallback? onTap,
    Key? key,
  }) {
    return Marker(
      key: key,
      point: point,
      width: width,
      height: height,
      alignment: alignment,
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: child,
            )
          : child,
    );
  }
}

/// Internal rendering widget for [MapMarkerBuilder.buildStopMarker].
class _StopMarkerWidget extends StatelessWidget {
  final int? sequence;
  final String? dayBadge;
  final Color pinColor;
  final Color badgeColor;
  final Color textColor;
  final IconData? icon;
  final double width;
  final double height;
  final String? semanticLabel;

  const _StopMarkerWidget({
    this.sequence,
    this.dayBadge,
    required this.pinColor,
    required this.badgeColor,
    required this.textColor,
    this.icon,
    required this.width,
    required this.height,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ??
        (sequence != null
            ? 'Điểm dừng $sequence${dayBadge != null ? ' ($dayBadge)' : ''}'
            : 'Điểm dừng');

    return Semantics(
      label: label,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Day Badge (optional)
            if (dayBadge != null && dayBadge!.trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 2.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2.0,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  dayBadge!.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),

            // 2. Main Pin Body with Sequence or Icon
            Flexible(
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Base Teardrop Pin Shape
                  CustomPaint(
                    size: Size(width, height * 0.7),
                    painter: _PinTeardropPainter(color: pinColor),
                  ),

                  // Center Sequence Number or Icon
                  Positioned(
                    top: (height * 0.7) * 0.18,
                    child: _buildPinContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinContent() {
    if (sequence != null) {
      return Text(
        '$sequence',
        style: TextStyle(
          color: textColor,
          fontSize: 13.0,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      );
    }

    if (icon != null) {
      return Icon(
        icon,
        size: 14.0,
        color: textColor,
      );
    }

    return Container(
      width: 8.0,
      height: 8.0,
      decoration: BoxDecoration(
        color: textColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Custom painter for the teardrop pin shape with drop shadow.
class _PinTeardropPainter extends CustomPainter {
  final Color color;

  _PinTeardropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final width = size.width;
    final height = size.height;
    final radius = width * 0.42;
    final center = Offset(width / 2, radius + 1.0);

    final path = Path();
    // Start at bottom tip
    path.moveTo(width / 2, height);
    // Left curve up to circular head
    path.quadraticBezierTo(
      width * 0.1,
      height * 0.58,
      center.dx - radius,
      center.dy + (radius * 0.2),
    );
    // Arc across the top of circle
    path.arcToPoint(
      Offset(center.dx + radius, center.dy + (radius * 0.2)),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    // Right curve down to bottom tip
    path.quadraticBezierTo(
      width * 0.9,
      height * 0.58,
      width / 2,
      height,
    );
    path.close();

    // Draw shadow first
    canvas.save();
    canvas.translate(0, 1.5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw main pin
    canvas.drawPath(path, paint);

    // Subtle white highlight stroke along the head
    final borderPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 0.5, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PinTeardropPainter oldDelegate) =>
      oldDelegate.color != color;
}
