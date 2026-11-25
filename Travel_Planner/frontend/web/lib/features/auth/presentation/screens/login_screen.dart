import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../auth_notifier.dart';

class LoginScreen extends StatefulWidget {
  final AuthNotifier authNotifier;

  const LoginScreen({super.key, required this.authNotifier});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    widget.authNotifier.clearErrors();
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.authNotifier.login(
      _usernameOrEmailController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      final error = widget.authNotifier.errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authNotifier,
      builder: (context, _) {
        final valErrors = widget.authNotifier.validationErrors;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;

              if (isDesktop) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _WaveSplitBackgroundPainter(),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(flex: 45, child: _DesktopBrandPane()),
                        Expanded(
                          flex: 55,
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                56,
                                36,
                                48,
                                36,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                ),
                                child: _buildLoginForm(valErrors: valErrors),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MobileWaveBrandHeader(),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildLoginForm(valErrors: valErrors),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoginForm({required Map<String, String>? valErrors}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 14,
                      color: AppColors.primaryAccessible,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'ADMIN PORTAL',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppColors.primaryAccessible,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Đăng nhập hệ thống',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sử dụng tài khoản quản trị viên để truy cập trung tâm điều hành.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
              height: 1.48,
            ),
          ),
          const SizedBox(height: 28),
          AppTextField(
            label: 'Tên đăng nhập hoặc Email',
            hint: 'Nhập tên đăng nhập hoặc email',
            controller: _usernameOrEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            errorText: valErrors?['usernameOrEmail'],
            labelStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            inputStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted.withValues(alpha: 0.85),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên đăng nhập hoặc email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Mật khẩu',
            hint: 'Nhập mật khẩu',
            controller: _passwordController,
            isPassword: true,
            textInputAction: TextInputAction.done,
            errorText: valErrors?['password'],
            onFieldSubmitted: (_) => _submit(),
            labelStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            inputStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted.withValues(alpha: 0.85),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mật khẩu';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          AppPrimaryButton(
            text: 'Đăng nhập',
            width: double.infinity,
            height: 50,
            fontSize: 15.5,
            isLoading: widget.authNotifier.isLoading,
            onPressed: _submit,
          )
        ],
      ),
    );
  }
}

class _DesktopBrandPane extends StatelessWidget {
  const _DesktopBrandPane();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 36, 56, 36),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 72).clamp(0.0, 2000.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'WELCOME BACK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 28),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.travel_explore,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Travel Planner',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: const Text(
                          'Travel Planner Portal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Hệ thống quản trị tập trung cho điểm đến bản đồ, điều phối tài khoản người dùng và kiểm duyệt nội dung cộng đồng du lịch.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'TRAVEL PLANNER  |  ADMINISTRATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileWaveBrandHeader extends StatelessWidget {
  const _MobileWaveBrandHeader();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _TopBannerWaveClipper(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 46),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryActive],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Travel Planner',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Travel Planner Portal',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the 45:55 split desktop background with a layered organic wave divider
/// and restrained travel route vector accents inside the left brand zone.
class _WaveSplitBackgroundPainter extends CustomPainter {
  const _WaveSplitBackgroundPainter();

  Path _buildOrganicWavePath({
    required double height,
    required List<double> xOffsets,
  }) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(xOffsets[0], 0);

    final segHeight = height / 4;
    for (int i = 0; i < 4; i++) {
      final yStart = segHeight * i;
      final yEnd = segHeight * (i + 1);
      final xStart = xOffsets[i];
      final xEnd = xOffsets[i + 1];
      final bulge = (i % 2 == 0) ? 24.0 : -20.0;

      path.cubicTo(
        xStart + bulge,
        yStart + segHeight * 0.32,
        xEnd + bulge,
        yStart + segHeight * 0.68,
        xEnd,
        yEnd,
      );
    }

    path
      ..lineTo(0, height)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final baseX = size.width * 0.445;

    // 1. Soft outermost wave halo layer
    final backWavePath = _buildOrganicWavePath(
      height: size.height,
      xOffsets: [baseX + 26, baseX + 42, baseX + 24, baseX + 44, baseX + 26],
    );
    canvas.drawPath(
      backWavePath,
      Paint()..color = AppColors.primaryBorder.withValues(alpha: 0.45),
    );

    // 2. Mid translucent coral wave layer
    final midWavePath = _buildOrganicWavePath(
      height: size.height,
      xOffsets: [baseX + 12, baseX + 22, baseX + 10, baseX + 24, baseX + 14],
    );
    canvas.drawPath(
      midWavePath,
      Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.55),
    );

    // 3. Primary brand wave region (#FF385C -> #E00B41)
    final mainWavePath = _buildOrganicWavePath(
      height: size.height,
      xOffsets: [baseX - 4, baseX + 8, baseX - 6, baseX + 10, baseX - 2],
    );

    final rect = Rect.fromLTWH(0, 0, baseX + 32, size.height);
    final mainPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryActive],
      ).createShader(rect);

    canvas.drawPath(mainWavePath, mainPaint);

    // 4. Restrained vector travel route & waypoint accents inside primary region
    canvas.save();
    canvas.clipPath(mainWavePath);

    final routePath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.22)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.10,
        size.width * 0.24,
        size.height * 0.30,
        size.width * 0.38,
        size.height * 0.17,
      );

    final routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final metric in routePath.computeMetrics()) {
      double distance = 0;
      const dash = 6.0;
      const gap = 5.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), routePaint);
        distance += dash + gap;
      }
    }

    final pinRingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final pinDotPaint = Paint()..color = Colors.white.withValues(alpha: 0.28);

    final pins = [
      Offset(size.width * 0.05, size.height * 0.22),
      Offset(size.width * 0.22, size.height * 0.20),
      Offset(size.width * 0.38, size.height * 0.17),
    ];
    for (final pt in pins) {
      canvas.drawCircle(pt, 7, pinRingPaint);
      canvas.drawCircle(pt, 2.8, pinDotPaint);
    }

    // Minimal compass arcs in bottom-left corner
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final bottomCenter = Offset(size.width * 0.06, size.height * 0.94);
    canvas.drawCircle(bottomCenter, 68, arcPaint);
    canvas.drawCircle(bottomCenter, 108, arcPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopBannerWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 20)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height,
        size.width * 0.52,
        size.height - 14,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height - 26,
        size.width,
        size.height - 10,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
