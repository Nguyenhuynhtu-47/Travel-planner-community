import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double r = w / 2;
    final center = Offset(r, r);

    final blue = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;

    // Draw Google 4-color arcs
    final rect = Rect.fromCircle(center: center, radius: r);
    final strokeWidth = w * 0.22;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Blue arc (right top)
    arcPaint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect.deflate(strokeWidth / 2), -0.785, 1.57, false, arcPaint);

    // Green arc (bottom right)
    arcPaint.color = const Color(0xFF34A853);
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0.785, 1.57, false, arcPaint);

    // Yellow arc (bottom left)
    arcPaint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect.deflate(strokeWidth / 2), 2.356, 1.57, false, arcPaint);

    // Red arc (top left)
    arcPaint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect.deflate(strokeWidth / 2), 3.926, 1.57, false, arcPaint);

    // Center blue crossbar
    final barRect = Rect.fromLTWH(
      center.dx - strokeWidth * 0.1,
      center.dy - strokeWidth / 2,
      r * 0.95,
      strokeWidth,
    );
    canvas.drawRect(barRect, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoogleSignInButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    this.text = 'Tiếp tục với Google',
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.8),
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: isLoading
            ? const SizedBox(
                key: ValueKey('google_loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              )
            : Row(
                key: const ValueKey('google_content'),
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GoogleLogo(size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AuthDividerWithText extends StatelessWidget {
  final String text;
  final double verticalPadding;

  const AuthDividerWithText({
    super.key,
    this.text = 'Hoặc',
    this.verticalPadding = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        ],
      ),
    );
  }
}
