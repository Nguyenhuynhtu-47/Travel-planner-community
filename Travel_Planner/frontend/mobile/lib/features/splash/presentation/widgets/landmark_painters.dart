import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Custom vector painter for the Eiffel Tower silhouette.
class EiffelTowerPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  const EiffelTowerPainter({
    this.primaryColor = const Color(0xFFFF5A5F),
    this.secondaryColor = const Color(0xFFF59E0B),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();

    // Spire needle
    path.moveTo(w * 0.48, h * 0.14);
    path.lineTo(w * 0.49, 0);
    path.lineTo(w * 0.51, 0);
    path.lineTo(w * 0.52, h * 0.14);

    // Top lantern / dome
    path.lineTo(w * 0.56, h * 0.16);
    path.lineTo(w * 0.44, h * 0.16);
    path.lineTo(w * 0.48, h * 0.14);

    // Top platform
    path.moveTo(w * 0.41, h * 0.20);
    path.lineTo(w * 0.59, h * 0.20);
    path.lineTo(w * 0.58, h * 0.23);
    path.lineTo(w * 0.42, h * 0.23);
    path.close();

    // Upper tower shaft
    path.moveTo(w * 0.44, h * 0.23);
    path.lineTo(w * 0.56, h * 0.23);
    path.lineTo(w * 0.62, h * 0.48);
    path.lineTo(w * 0.38, h * 0.48);
    path.close();

    // Middle platform
    path.moveTo(w * 0.34, h * 0.48);
    path.lineTo(w * 0.66, h * 0.48);
    path.lineTo(w * 0.64, h * 0.53);
    path.lineTo(w * 0.36, h * 0.53);
    path.close();

    // Lower flared legs & bottom arch
    path.moveTo(w * 0.38, h * 0.53);
    path.lineTo(w * 0.62, h * 0.53);
    // Right outer leg
    path.quadraticBezierTo(w * 0.66, h * 0.75, w * 0.88, h);
    path.lineTo(w * 0.70, h);
    // Middle inner arch
    path.quadraticBezierTo(w * 0.58, h * 0.72, w * 0.50, h * 0.72);
    path.quadraticBezierTo(w * 0.42, h * 0.72, w * 0.30, h);
    // Left outer leg
    path.lineTo(w * 0.12, h);
    path.quadraticBezierTo(w * 0.34, h * 0.75, w * 0.38, h * 0.53);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant EiffelTowerPainter oldDelegate) =>
      primaryColor != oldDelegate.primaryColor ||
      secondaryColor != oldDelegate.secondaryColor;
}

/// Custom vector painter for the Leaning Tower of Pisa.
class PisaTowerPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  const PisaTowerPainter({
    this.primaryColor = const Color(0xFFFF7A59),
    this.secondaryColor = const Color(0xFFFF385C),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Lean angle: ~-5 degrees around bottom center
    canvas.save();
    canvas.translate(w * 0.5, h);
    canvas.rotate(-0.08); // ~4.6 degrees lean
    canvas.translate(-w * 0.5, -h);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    // Main tower column silhouette
    final path = Path();
    // Belfry top
    path.moveTo(w * 0.38, h * 0.08);
    path.lineTo(w * 0.62, h * 0.08);
    path.lineTo(w * 0.60, h * 0.18);
    path.lineTo(w * 0.40, h * 0.18);
    path.close();

    // 6-tiered column body
    path.moveTo(w * 0.32, h * 0.18);
    path.lineTo(w * 0.68, h * 0.18);
    path.lineTo(w * 0.74, h * 0.90);
    path.lineTo(w * 0.26, h * 0.90);
    path.close();

    // Base pedestal
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.90, w * 0.56, h * 0.10),
      const Radius.circular(2),
    ));

    canvas.drawPath(path, paint);

    // Gallery floor divider stripes
    for (int i = 1; i <= 6; i++) {
      final y = h * (0.18 + i * 0.12);
      final inset = (i * 0.01) * w;
      canvas.drawLine(
        Offset(w * 0.30 - inset, y),
        Offset(w * 0.70 + inset, y),
        strokePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PisaTowerPainter oldDelegate) =>
      primaryColor != oldDelegate.primaryColor ||
      secondaryColor != oldDelegate.secondaryColor;
}

/// Custom vector painter for the Statue of Liberty silhouette.
class StatueOfLibertyPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  const StatueOfLibertyPainter({
    this.primaryColor = const Color(0xFFFF5A5F),
    this.secondaryColor = const Color(0xFFE00B41),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();

    // Torch flame (top-right)
    path.moveTo(w * 0.78, h * 0.02);
    path.quadraticBezierTo(w * 0.86, h * 0.05, w * 0.81, h * 0.12);
    path.quadraticBezierTo(w * 0.74, h * 0.08, w * 0.78, h * 0.02);
    path.close();

    // Torch handle & raised right arm
    path.moveTo(w * 0.76, h * 0.12);
    path.lineTo(w * 0.82, h * 0.12);
    path.lineTo(w * 0.76, h * 0.24);
    path.lineTo(w * 0.62, h * 0.32);
    path.lineTo(w * 0.58, h * 0.28);
    path.lineTo(w * 0.72, h * 0.18);
    path.close();

    // Radiate Crown Spikes
    final crownCenter = Offset(w * 0.46, h * 0.26);
    for (int i = -3; i <= 3; i++) {
      final angle = -math.pi / 2 + (i * 0.28);
      final spikeTip = Offset(
        crownCenter.dx + math.cos(angle) * (w * 0.24),
        crownCenter.dy + math.sin(angle) * (h * 0.14),
      );
      path.moveTo(crownCenter.dx + math.cos(angle - 0.08) * (w * 0.10),
          crownCenter.dy + math.sin(angle - 0.08) * (h * 0.07));
      path.lineTo(spikeTip.dx, spikeTip.dy);
      path.lineTo(crownCenter.dx + math.cos(angle + 0.08) * (w * 0.10),
          crownCenter.dy + math.sin(angle + 0.08) * (h * 0.07));
      path.close();
    }

    // Head
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.46, h * 0.28),
      width: w * 0.18,
      height: h * 0.12,
    ));

    // Robe body & tablet (left arm)
    path.moveTo(w * 0.38, h * 0.34);
    path.lineTo(w * 0.58, h * 0.34);
    // Right side drape
    path.quadraticBezierTo(w * 0.64, h * 0.55, w * 0.68, h * 0.90);
    // Base
    path.lineTo(w * 0.26, h * 0.90);
    // Left side drape & tablet outline
    path.quadraticBezierTo(w * 0.30, h * 0.55, w * 0.38, h * 0.34);
    path.close();

    // Pedestal base
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.20, h * 0.90, w * 0.56, h * 0.10),
      const Radius.circular(2),
    ));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StatueOfLibertyPainter oldDelegate) =>
      primaryColor != oldDelegate.primaryColor ||
      secondaryColor != oldDelegate.secondaryColor;
}

/// Custom vector painter for the Airplane with flight trail.
class AirplanePainter extends CustomPainter {
  final Color primaryColor;
  final Color trailColor;

  const AirplanePainter({
    this.primaryColor = AppColors.primary,
    this.trailColor = const Color(0xFFFFD1DA),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Vapor flight trail arc
    final trailPaint = Paint()
      ..color = trailColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final trailPath = Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(w * 0.22, h * 0.75, w * 0.45, h * 0.52);
    canvas.drawPath(trailPath, trailPaint);

    // Plane body rotated along flight vector (~-24 degrees)
    canvas.save();
    canvas.translate(w * 0.60, h * 0.42);
    canvas.rotate(-0.42);

    final planePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primary, Color(0xFFFF5A5F)],
      ).createShader(Rect.fromLTWH(-w * 0.35, -h * 0.35, w * 0.70, h * 0.70))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final planePath = Path();
    // Nose
    planePath.moveTo(w * 0.30, 0);
    // Right wing
    planePath.lineTo(w * 0.05, h * 0.08);
    planePath.lineTo(-w * 0.12, h * 0.32);
    planePath.lineTo(-w * 0.08, h * 0.08);
    // Fuselage to tail
    planePath.lineTo(-w * 0.25, h * 0.05);
    // Tail fin right
    planePath.lineTo(-w * 0.30, h * 0.16);
    planePath.lineTo(-w * 0.28, 0);
    // Tail fin left
    planePath.lineTo(-w * 0.30, -h * 0.16);
    planePath.lineTo(-w * 0.25, -h * 0.05);
    // Left wing
    planePath.lineTo(-w * 0.08, -h * 0.08);
    planePath.lineTo(-w * 0.12, -h * 0.32);
    planePath.lineTo(w * 0.05, -h * 0.08);
    planePath.close();

    canvas.drawPath(planePath, planePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AirplanePainter oldDelegate) =>
      primaryColor != oldDelegate.primaryColor ||
      trailColor != oldDelegate.trailColor;
}

/// Custom vector painter for the Location Pin with pulse ring.
class LocationPinPainter extends CustomPainter {
  final Color pinColor;
  final Color pulseColor;

  const LocationPinPainter({
    this.pinColor = const Color(0xFFF59E0B),
    this.pulseColor = const Color(0xFFFFE8D6),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ground pulse circle
    final groundPaint = Paint()
      ..color = pulseColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.94),
        width: w * 0.65,
        height: h * 0.12,
      ),
      groundPaint,
    );

    // Teardrop pin
    final pinPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [pinColor, const Color(0xFFFF5A5F)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.90))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final pinPath = Path();
    final center = Offset(w * 0.5, h * 0.38);
    final radius = w * 0.36;

    pinPath.moveTo(w * 0.5, h * 0.88);
    pinPath.quadraticBezierTo(w * 0.22, h * 0.58, center.dx - radius, center.dy);
    pinPath.arcToPoint(
      Offset(center.dx + radius, center.dy),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    pinPath.quadraticBezierTo(w * 0.78, h * 0.58, w * 0.5, h * 0.88);
    pinPath.close();

    canvas.drawPath(pinPath, pinPaint);

    // Inner cutout circle
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.44, holePaint);
  }

  @override
  bool shouldRepaint(covariant LocationPinPainter oldDelegate) =>
      pinColor != oldDelegate.pinColor || pulseColor != oldDelegate.pulseColor;
}

/// Custom vector painter for a Hot Air Balloon.
class HotAirBalloonPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  const HotAirBalloonPainter({
    this.primaryColor = const Color(0xFFFF5A5F),
    this.secondaryColor = const Color(0xFFF59E0B),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Balloon envelope
    final balloonPath = Path();
    final center = Offset(w * 0.5, h * 0.38);
    final radius = w * 0.40;

    balloonPath.moveTo(w * 0.5, h * 0.76);
    balloonPath.quadraticBezierTo(w * 0.24, h * 0.56, center.dx - radius, center.dy);
    balloonPath.arcToPoint(
      Offset(center.dx + radius, center.dy),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    balloonPath.quadraticBezierTo(w * 0.76, h * 0.56, w * 0.5, h * 0.76);
    balloonPath.close();

    canvas.drawPath(balloonPath, paint);

    // Rib lines
    final ribPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final leftRib = Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..quadraticBezierTo(w * 0.28, h * 0.38, w * 0.44, h * 0.76);
    final rightRib = Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..quadraticBezierTo(w * 0.72, h * 0.38, w * 0.56, h * 0.76);

    canvas.drawPath(leftRib, ribPaint);
    canvas.drawPath(rightRib, ribPaint);

    // Suspension cords
    final cordPaint = Paint()
      ..color = const Color(0xFF888888)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawLine(Offset(w * 0.42, h * 0.76), Offset(w * 0.44, h * 0.86), cordPaint);
    canvas.drawLine(Offset(w * 0.58, h * 0.76), Offset(w * 0.56, h * 0.86), cordPaint);

    // Basket
    final basketPaint = Paint()
      ..color = const Color(0xFFC0703C)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.40, h * 0.86, w * 0.20, h * 0.12),
        const Radius.circular(2),
      ),
      basketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant HotAirBalloonPainter oldDelegate) =>
      primaryColor != oldDelegate.primaryColor ||
      secondaryColor != oldDelegate.secondaryColor;
}
