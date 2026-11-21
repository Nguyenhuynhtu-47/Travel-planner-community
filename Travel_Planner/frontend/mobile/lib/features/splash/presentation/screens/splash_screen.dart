import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../shared/navigation/main_navigation_shell.dart';
import '../widgets/landmark_painters.dart';

/// Minimalist Wanderlog-inspired Animated Splash Screen for Travel Planner.
///
/// Features:
/// - Minimalist aesthetic: generous white space, subtle warm gradient canvas,
///   no cluttering cards, borders, or ticket graphics.
/// - Clearly partitioned 4-zone responsive layout:
///   - Top Zone: Eiffel Tower (Left) & Airplane (Right) well above central logo.
///   - Center Zone: Travel Planner circular logo and 3 greeting typography lines
///     ("Xin chào!" -> "Cùng khám phá thế giới" -> "Travel Planner").
///   - Flanking Zone: Leaning Tower of Pisa (Far Left) & Statue of Liberty (Far Right)
///     hugging the screen edges, completely separated from text lines.
///   - Bottom Zone: Hot Air Balloon (Left) & Location Pin (Right) well below text.
/// - Coordinated 4800ms animation sequence:
///   - Phase 1 (0.0s - 2.4s): Staggered entrance for Logo, landmark silhouettes,
///     and typography lines.
///   - Phase 2 (2.4s - 4.3s): Continuous natural secondary movement (logo breathing pulse,
///     airplane soaring climb, balloon swaying float, gentle landmark drift),
///     preventing any frozen or static delay.
///   - Phase 3 (4.3s - 4.8s): Soft exit fade out and synchronized screen navigation.
/// - Synchronized transition: proceeds ONLY when BOTH animation and [AuthNotifier]
///   initialization are complete.
/// - Seamless navigation to [MainNavigationShell] if authenticated, or [LoginScreen] if unauthenticated.
/// - Non-dismissible during splash via [PopScope(canPop: false)].
class SplashScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final Duration animationDuration;
  final void Function(bool isAuthenticated)? onNavigate;

  const SplashScreen({
    super.key,
    required this.authNotifier,
    this.animationDuration = const Duration(milliseconds: 4800),
    this.onNavigate,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Phase 1 & 2: Logo entrance & continuous breathing pulse
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Phase 1 & 2: Landmark silhouettes with entrance + continuous dynamic motion
  late final Animation<double> _eiffelFade;
  late final Animation<Offset> _eiffelSlide;
  late final Animation<double> _eiffelRotate;

  late final Animation<double> _airplaneFade;
  late final Animation<Offset> _airplaneSlide;
  late final Animation<double> _airplaneRotate;

  late final Animation<double> _pisaFade;
  late final Animation<Offset> _pisaSlide;
  late final Animation<double> _pisaRotate;

  late final Animation<double> _libertyFade;
  late final Animation<Offset> _libertySlide;

  late final Animation<double> _balloonFade;
  late final Animation<Offset> _balloonSlide;
  late final Animation<double> _balloonRotate;

  late final Animation<double> _pinFade;
  late final Animation<Offset> _pinSlide;
  late final Animation<double> _pinScale;

  // Phase 1: Staggered typography
  late final Animation<double> _greetingFade;
  late final Animation<Offset> _greetingSlide;

  late final Animation<double> _sloganFade;
  late final Animation<Offset> _sloganSlide;

  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;

  // Phase 3: Exit fade out
  late final Animation<double> _exitFade;

  bool _animationCompleted = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _initAnimations();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationCompleted();
      }
    });

    widget.authNotifier.addListener(_onAuthStatusChanged);

    _controller.forward();
  }

  void _initAnimations() {
    // -----------------------------------------------------------------
    // 1. Logo: Entrance (0.00 - 0.25) & Continuous Breathing Pulse (0.25 - 0.88)
    // -----------------------------------------------------------------
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.18, curve: Curves.easeOut),
      ),
    );

    _logoScale = TweenSequence<double>([
      // Entrance: scale up with gentle bounce
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.68, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.00)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 7,
      ),
      // Continuous breathing pulse cycle 1
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.00, end: 1.045)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.045, end: 1.00)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 15,
      ),
      // Continuous breathing pulse cycle 2
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.00, end: 1.035)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 17,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.035, end: 1.00)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 16,
      ),
      // Stabilize before exit
      TweenSequenceItem(
        tween: ConstantTween<double>(1.00),
        weight: 12,
      ),
    ]).animate(_controller);

    // -----------------------------------------------------------------
    // 2. Orbital Landmark Silhouettes: Staggered Entrance & Dynamic Cruise
    // -----------------------------------------------------------------

    // 2.1 Eiffel Tower (Top-Left): entrance (0.08 - 0.28) + subtle floating sway (0.28 - 0.88)
    _eiffelFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.24, curve: Curves.easeOut),
      ),
    );
    _eiffelSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(-0.40, -0.40)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(-0.40, -0.40),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.03, -0.05),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(-0.03, -0.05),
          end: const Offset(0.02, 0.02),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.02, 0.02)),
        weight: 12,
      ),
    ]).animate(_controller);

    _eiffelRotate = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(-0.06), weight: 8),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.06, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.025)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.025, end: 0.02)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 12),
    ]).animate(_controller);

    // 2.2 Airplane (Top-Right): entrance (0.12 - 0.32) + soaring flight climb outward (0.32 - 0.88)
    _airplaneFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.28, curve: Curves.easeOut),
      ),
    );
    _airplaneSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(-0.35, 0.35)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(-0.35, 0.35),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.16, -0.18),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 56,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.16, -0.18)),
        weight: 12,
      ),
    ]).animate(_controller);

    _airplaneRotate = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 12),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.04)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.04, end: -0.09)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 56,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(-0.09), weight: 12),
    ]).animate(_controller);

    // 2.3 Pisa Tower (Mid-Left, Far Left): entrance from left (0.16 - 0.35) + leaning oscillation (0.35 - 0.88)
    _pisaFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.32, curve: Curves.easeOut),
      ),
    );
    _pisaSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(-0.60, 0.0)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(-0.60, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 19,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.03, -0.04),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 26,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.03, -0.04),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 27,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 12,
      ),
    ]).animate(_controller);

    _pisaRotate = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(-0.05), weight: 16),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.05, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 19,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.03)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 26,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.03, end: 0.02)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 27,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 12),
    ]).animate(_controller);

    // 2.4 Statue of Liberty (Mid-Right, Far Right): entrance from right (0.20 - 0.38) + gentle drift (0.38 - 0.88)
    _libertyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.36, curve: Curves.easeOut),
      ),
    );
    _libertySlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.60, 0.0)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.60, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.03, -0.04),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(-0.03, -0.04),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 12,
      ),
    ]).animate(_controller);

    // 2.5 Hot Air Balloon (Bottom-Left): entrance from bottom (0.24 - 0.42) + floating sway (0.42 - 0.88)
    _balloonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.24, 0.40, curve: Curves.easeOut),
      ),
    );
    _balloonSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.0, 0.55)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.0, 0.55),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.04, -0.12),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(-0.04, -0.12),
          end: const Offset(0.03, 0.05),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.03, 0.05),
          end: const Offset(-0.02, -0.06),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(-0.02, -0.06)),
        weight: 12,
      ),
    ]).animate(_controller);

    _balloonRotate = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 36),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.05)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.05, end: 0.05)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.05, end: -0.02)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 12),
    ]).animate(_controller);

    // 2.6 Location Pin (Bottom-Right): entrance drop (0.28 - 0.46) + pulse bounce (0.46 - 0.88)
    _pinFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.44, curve: Curves.easeOut),
      ),
    );
    _pinSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.0, -0.45)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.0, -0.45),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.0, -0.06),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 21,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.0, -0.06),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 21,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 12,
      ),
    ]).animate(_controller);

    _pinScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.30), weight: 28),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.30, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.00)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.00, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 21,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.00)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 21,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.00), weight: 12),
    ]).animate(_controller);

    // -----------------------------------------------------------------
    // 3. Staggered Typography: Clear, Crisp & High Legibility
    // -----------------------------------------------------------------
    // Line 1: "Xin chào!" (0.18 - 0.34)
    _greetingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.34, curve: Curves.easeOut),
      ),
    );
    _greetingSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.65),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.34, curve: Curves.easeOutCubic),
      ),
    );

    // Line 2: "Cùng khám phá thế giới" (0.26 - 0.42)
    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.26, 0.42, curve: Curves.easeOut),
      ),
    );
    _sloganSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.55),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.26, 0.42, curve: Curves.easeOutCubic),
      ),
    );

    // Line 3: "Travel Planner" (0.34 - 0.50)
    _brandFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.34, 0.50, curve: Curves.easeOut),
      ),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.50),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.34, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    // -----------------------------------------------------------------
    // 4. Phase 3: Exit Fade Out (0.90 - 1.00)
    // -----------------------------------------------------------------
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.90, 1.00, curve: Curves.easeInCubic),
      ),
    );
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
                Color(0xFFFFFDFC),
                Color(0xFFFFF7F5),
              ],
              stops: [0.0, 0.65, 1.0],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _exitFade.value.clamp(0.0, 1.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;

                      // Vertical anchor: 0.45 of screen height
                      final cy = h * 0.45;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ==============================================
                          // 1. TOP ZONE: Above Logo & Central Content
                          // ==============================================

                          // Top-Left: Eiffel Tower (54x74 dp)
                          Positioned(
                            left: (w * 0.08).clamp(16.0, 42.0),
                            top: (cy - 170.0).clamp(20.0, 180.0),
                            child: FadeTransition(
                              opacity: _eiffelFade,
                              child: SlideTransition(
                                position: _eiffelSlide,
                                child: Transform.rotate(
                                  angle: _eiffelRotate.value,
                                  child: const SizedBox(
                                    width: 54,
                                    height: 74,
                                    child: CustomPaint(
                                      painter: EiffelTowerPainter(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Top-Right: Airplane with vapor trail (66x58 dp)
                          Positioned(
                            right: (w * 0.06).clamp(16.0, 38.0),
                            top: (cy - 175.0).clamp(18.0, 175.0),
                            child: FadeTransition(
                              opacity: _airplaneFade,
                              child: SlideTransition(
                                position: _airplaneSlide,
                                child: Transform.rotate(
                                  angle: _airplaneRotate.value,
                                  child: const SizedBox(
                                    width: 66,
                                    height: 58,
                                    child: CustomPaint(
                                      painter: AirplanePainter(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ==============================================
                          // 2. FLANKING ZONE: Hugging the screen edges,
                          //    completely avoiding the central text lines!
                          // ==============================================

                          // Mid-Left: Leaning Tower of Pisa (48x72 dp)
                          Positioned(
                            left: (w * 0.03).clamp(8.0, 20.0),
                            top: (cy - 30.0).clamp(170.0, 360.0),
                            child: FadeTransition(
                              opacity: _pisaFade,
                              child: SlideTransition(
                                position: _pisaSlide,
                                child: Transform.rotate(
                                  angle: _pisaRotate.value,
                                  child: const SizedBox(
                                    width: 48,
                                    height: 72,
                                    child: CustomPaint(
                                      painter: PisaTowerPainter(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Mid-Right: Statue of Liberty (52x74 dp)
                          Positioned(
                            right: (w * 0.03).clamp(8.0, 20.0),
                            top: (cy - 35.0).clamp(165.0, 355.0),
                            child: FadeTransition(
                              opacity: _libertyFade,
                              child: SlideTransition(
                                position: _libertySlide,
                                child: const SizedBox(
                                  width: 52,
                                  height: 74,
                                  child: CustomPaint(
                                    painter: StatueOfLibertyPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ==============================================
                          // 3. BOTTOM ZONE: Below the bottom of text lines
                          // ==============================================

                          // Bottom-Left: Hot Air Balloon (52x70 dp)
                          Positioned(
                            left: (w * 0.09).clamp(16.0, 42.0),
                            top: (cy + 120.0).clamp(320.0, 570.0),
                            child: FadeTransition(
                              opacity: _balloonFade,
                              child: SlideTransition(
                                position: _balloonSlide,
                                child: Transform.rotate(
                                  angle: _balloonRotate.value,
                                  child: const SizedBox(
                                    width: 52,
                                    height: 70,
                                    child: CustomPaint(
                                      painter: HotAirBalloonPainter(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom-Right: Location Pin (48x62 dp)
                          Positioned(
                            right: (w * 0.09).clamp(16.0, 42.0),
                            top: (cy + 125.0).clamp(325.0, 575.0),
                            child: FadeTransition(
                              opacity: _pinFade,
                              child: SlideTransition(
                                position: _pinSlide,
                                child: ScaleTransition(
                                  scale: _pinScale,
                                  child: const SizedBox(
                                    width: 48,
                                    height: 62,
                                    child: CustomPaint(
                                      painter: LocationPinPainter(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ==============================================
                          // 4. CENTER ZONE: Logo & Greeting Typography
                          //    100% exclusive uninterrupted space
                          // ==============================================
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Minimalist Logo Badge with continuous subtle breathing pulse
                                  FadeTransition(
                                    opacity: _logoFade,
                                    child: ScaleTransition(
                                      scale: _logoScale,
                                      child: _buildMinimalLogoBadge(),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Line 1: Friendly Greeting "Xin chào!"
                                  FadeTransition(
                                    opacity: _greetingFade,
                                    child: SlideTransition(
                                      position: _greetingSlide,
                                      child: const Text(
                                        'Xin chào!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // Line 2: Inspiring Motto "Cùng khám phá thế giới"
                                  FadeTransition(
                                    opacity: _sloganFade,
                                    child: SlideTransition(
                                      position: _sloganSlide,
                                      child: const Text(
                                        'Cùng khám phá thế giới với',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.3,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // Line 3: Brand Name "Travel Planner"
                                  FadeTransition(
                                    opacity: _brandFade,
                                    child: SlideTransition(
                                      position: _brandSlide,
                                      child: const Text(
                                        'Travel Planner',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Clean, modern circular logo emblem without heavy shadows or borders.
  Widget _buildMinimalLogoBadge() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: const Color(0xFFFFD1DA),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.travel_explore_rounded,
          size: 42,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
