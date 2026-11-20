import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../shared/navigation/main_navigation_shell.dart';

/// Animated Splash Screen displayed on every app cold start.
///
/// Features:
/// - Brand identity (Travel Planner logo, typography, tagline, description).
/// - Rich visual travel illustration.
/// - Coordinated multi-stage entrance animation (Logo -> Title -> Description -> Illustration).
/// - Synchronized transition: proceeds ONLY when both animation and [AuthNotifier]
///   initialization are complete.
/// - Transitions to [MainNavigationShell] if authenticated, or [LoginScreen] if unauthenticated.
/// - Zero interaction required; non-dismissible during splash via [PopScope].
class SplashScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final Duration animationDuration;
  final void Function(bool isAuthenticated)? onNavigate;

  const SplashScreen({
    super.key,
    required this.authNotifier,
    this.animationDuration = const Duration(milliseconds: 2400),
    this.onNavigate,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _descFade;
  late final Animation<Offset> _descSlide;
  late final Animation<double> _illustFade;
  late final Animation<double> _illustScale;

  bool _animationCompleted = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // 1. Logo: 0.0 - 0.35 (fade + slight scale)
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
      ),
    );

    // 2. Title: 0.20 - 0.50 (fade + slide up)
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.50, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Description: 0.35 - 0.65 (fade + slide up)
    _descFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );
    _descSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Illustration: 0.45 - 0.80 (fade + scale)
    _illustFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.80, curve: Curves.easeOut),
      ),
    );
    _illustScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Completion listener (0.80 - 1.0 is stabilization window)
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationCompleted();
      }
    });

    widget.authNotifier.addListener(_onAuthStatusChanged);

    // Start animation
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _controller.value = 1.0;
      _onAnimationCompleted();
    }
  }

  @override
  void dispose() {
    widget.authNotifier.removeListener(_onAuthStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationCompleted() {
    _animationCompleted = true;
    _checkAndNavigate();
  }

  void _onAuthStatusChanged() {
    if (widget.authNotifier.status != AuthStatus.initial && _animationCompleted) {
      _checkAndNavigate();
    }
  }

  void _checkAndNavigate() {
    if (_hasNavigated || !mounted) return;
    if (!_animationCompleted) return;
    if (widget.authNotifier.status == AuthStatus.initial) return;

    _hasNavigated = true;

    if (widget.onNavigate != null) {
      widget.onNavigate!(widget.authNotifier.isAuthenticated);
      return;
    }

    _proceedToNextScreen();
  }

  void _proceedToNextScreen() {
    if (!mounted) return;

    final Widget destination = widget.authNotifier.isAuthenticated
        ? MainNavigationShell(authNotifier: widget.authNotifier)
        : LoginScreen(authNotifier: widget.authNotifier);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFFF9F8),
                Color(0xFFFFEFF1),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 20.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),

                          // 1. Logo Travel Planner
                          FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: _buildLogoBadge(),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 2. Title & Slogan
                          FadeTransition(
                            opacity: _titleFade,
                            child: SlideTransition(
                              position: _titleSlide,
                              child: Column(
                                children: [
                                  const Text(
                                    'Travel Planner',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Text(
                                      'Hành trình vạn dặm · Khám phá đam mê',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 3. Description
                          FadeTransition(
                            opacity: _descFade,
                            child: SlideTransition(
                              position: _descSlide,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: const Text(
                                  'Lập kế hoạch thông minh, quản lý lịch trình chi tiết và chia sẻ trải nghiệm du lịch tuyệt vời cùng cộng đồng.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // 4. Travel Illustration Graphic
                          FadeTransition(
                            opacity: _illustFade,
                            child: ScaleTransition(
                              scale: _illustScale,
                              child: _buildTravelIllustration(),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF0F2),
            Color(0xFFFFDDE2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.travel_explore_rounded,
          size: 48,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildTravelIllustration() {
    return SizedBox(
      width: 290,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient halo
          Container(
            width: 260,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryLight.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
                radius: 0.85,
              ),
            ),
          ),

          // Central Itinerary Ticket Card
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.hairlineSoft,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đà Lạt Mộng Mơ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '3 ngày 2 đêm · 8 địa điểm',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.star_rounded,
                      size: 20,
                      color: Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.hairlineSoft),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniBadge(Icons.hotel_outlined, 'Nghỉ dưỡng'),
                      const SizedBox(width: 10),
                      _buildMiniBadge(Icons.restaurant_outlined, 'Ẩm thực'),
                      const SizedBox(width: 10),
                      _buildMiniBadge(Icons.photo_camera_outlined, 'Check-in'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Accent: Airplane (Top-Right)
          Positioned(
            top: 6,
            right: 12,
            child: Transform.rotate(
              angle: -0.22,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // Floating Accent: Pin (Top-Left)
          Positioned(
            top: 14,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: Color(0xFFF59E0B),
              ),
            ),
          ),

          // Floating Accent: Luggage (Bottom-Right)
          Positioned(
            bottom: 6,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
