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
/// - Staggered entrance animation:
///   - Phase 1: Brand Logo entrance (fade + subtle scale).
///   - Phase 2: World travel landmark silhouettes appear staggered around center
///     (Eiffel Tower, Airplane, Leaning Tower of Pisa, Statue of Liberty, Hot Air Balloon, Location Pin).
///   - Phase 3: Greeting and brand typography slide in sequentially
///     ("Xin chào!" -> "Cùng khám phá thế giới" -> "Travel Planner").
///   - Phase 4: Gentle exit fade & coordinated navigation.
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
    this.animationDuration = const Duration(milliseconds: 2800),
    this.onNavigate,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Phase 1: Logo animations
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Phase 2: Landmark animations (fade + translation/scale)
  late final Animation<double> _eiffelFade;
  late final Animation<Offset> _eiffelSlide;

  late final Animation<double> _airplaneFade;
  late final Animation<Offset> _airplaneSlide;

  late final Animation<double> _pisaFade;
  late final Animation<Offset> _pisaSlide;

  late final Animation<double> _libertyFade;
  late final Animation<Offset> _libertySlide;

  late final Animation<double> _balloonFade;
  late final Animation<Offset> _balloonSlide;

  late final Animation<double> _pinFade;
  late final Animation<double> _pinScale;

  // Phase 3: Staggered typography
  late final Animation<double> _greetingFade;
  late final Animation<Offset> _greetingSlide;

  late final Animation<double> _sloganFade;
  late final Animation<Offset> _sloganSlide;

  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;

  // Phase 4: Exit fade out
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
    // ----------------------------------------------------
    // Phase 1: Logo (0.00 - 0.32)
    // ----------------------------------------------------
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.28, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.32, curve: Curves.easeOutBack),
      ),
    );

    // ----------------------------------------------------
    // Phase 2: Staggered Landmark Silhouettes
    // ----------------------------------------------------
    // 1. Eiffel Tower (Top-Left): 0.20 - 0.48
    _eiffelFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.48, curve: Curves.easeOut),
      ),
    );
    _eiffelSlide = Tween<Offset>(
      begin: const Offset(-0.25, -0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.48, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Airplane (Top-Right): 0.26 - 0.54
    _airplaneFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.26, 0.54, curve: Curves.easeOut),
      ),
    );
    _airplaneSlide = Tween<Offset>(
      begin: const Offset(-0.35, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.26, 0.54, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Pisa Tower (Mid-Left): 0.32 - 0.60
    _pisaFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.60, curve: Curves.easeOut),
      ),
    );
    _pisaSlide = Tween<Offset>(
      begin: const Offset(-0.20, 0.20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Statue of Liberty (Mid-Right): 0.38 - 0.66
    _libertyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.66, curve: Curves.easeOut),
      ),
    );
    _libertySlide = Tween<Offset>(
      begin: const Offset(0.25, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.66, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Hot Air Balloon (Bottom-Left): 0.44 - 0.72
    _balloonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.44, 0.72, curve: Curves.easeOut),
      ),
    );
    _balloonSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.44, 0.72, curve: Curves.easeOutCubic),
      ),
    );

    // 6. Location Pin (Bottom-Right): 0.50 - 0.78
    _pinFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.78, curve: Curves.easeOut),
      ),
    );
    _pinScale = Tween<double>(begin: 0.40, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.78, curve: Curves.easeOutBack),
      ),
    );

    // ----------------------------------------------------
    // Phase 3: Staggered Typography
    // ----------------------------------------------------
    // Line 1: "Xin chào!" (0.32 - 0.56)
    _greetingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.56, curve: Curves.easeOut),
      ),
    );
    _greetingSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.56, curve: Curves.easeOutCubic),
      ),
    );

    // Line 2: "Cùng khám phá thế giới" (0.44 - 0.68)
    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.44, 0.68, curve: Curves.easeOut),
      ),
    );
    _sloganSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.40),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.44, 0.68, curve: Curves.easeOutCubic),
      ),
    );

    // Line 3: "Travel Planner" (0.56 - 0.80)
    _brandFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.80, curve: Curves.easeOut),
      ),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    // ----------------------------------------------------
    // Phase 4: Exit Fade (0.88 - 1.00)
    // ----------------------------------------------------
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.88, 1.00, curve: Curves.easeInCubic),
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

                      // Anchor center for orbital landmarks and typography
                      final cx = w * 0.5;
                      final cy = h * 0.46;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ----------------------------------------------
                          // 1. Orbital Landmark Silhouettes
                          // ----------------------------------------------

                          // Top-Left: Eiffel Tower
                          Positioned(
                            left: cx - (w * 0.38).clamp(90.0, 150.0),
                            top: cy - (h * 0.28).clamp(95.0, 180.0),
                            child: FadeTransition(
                              opacity: _eiffelFade,
                              child: SlideTransition(
                                position: _eiffelSlide,
                                child: const SizedBox(
                                  width: 36,
                                  height: 50,
                                  child: CustomPaint(
                                    painter: EiffelTowerPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Top-Right: Airplane with vapor trail
                          Positioned(
                            left: cx + (w * 0.22).clamp(65.0, 120.0),
                            top: cy - (h * 0.30).clamp(100.0, 190.0),
                            child: FadeTransition(
                              opacity: _airplaneFade,
                              child: SlideTransition(
                                position: _airplaneSlide,
                                child: const SizedBox(
                                  width: 44,
                                  height: 40,
                                  child: CustomPaint(
                                    painter: AirplanePainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Mid-Left: Leaning Tower of Pisa
                          Positioned(
                            left: cx - (w * 0.42).clamp(105.0, 160.0),
                            top: cy + (h * 0.04).clamp(15.0, 45.0),
                            child: FadeTransition(
                              opacity: _pisaFade,
                              child: SlideTransition(
                                position: _pisaSlide,
                                child: const SizedBox(
                                  width: 32,
                                  height: 48,
                                  child: CustomPaint(
                                    painter: PisaTowerPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Mid-Right: Statue of Liberty
                          Positioned(
                            left: cx + (w * 0.26).clamp(75.0, 130.0),
                            top: cy + (h * 0.02).clamp(10.0, 40.0),
                            child: FadeTransition(
                              opacity: _libertyFade,
                              child: SlideTransition(
                                position: _libertySlide,
                                child: const SizedBox(
                                  width: 34,
                                  height: 50,
                                  child: CustomPaint(
                                    painter: StatueOfLibertyPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom-Left: Hot Air Balloon
                          Positioned(
                            left: cx - (w * 0.32).clamp(80.0, 130.0),
                            top: cy + (h * 0.25).clamp(85.0, 170.0),
                            child: FadeTransition(
                              opacity: _balloonFade,
                              child: SlideTransition(
                                position: _balloonSlide,
                                child: const SizedBox(
                                  width: 34,
                                  height: 46,
                                  child: CustomPaint(
                                    painter: HotAirBalloonPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom-Right: Location Pin
                          Positioned(
                            left: cx + (w * 0.24).clamp(65.0, 115.0),
                            top: cy + (h * 0.26).clamp(90.0, 175.0),
                            child: FadeTransition(
                              opacity: _pinFade,
                              child: ScaleTransition(
                                scale: _pinScale,
                                child: const SizedBox(
                                  width: 32,
                                  height: 40,
                                  child: CustomPaint(
                                    painter: LocationPinPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ----------------------------------------------
                          // 2. Central Logo & Typography
                          // ----------------------------------------------
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Minimalist Logo Badge
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
                                        'Cùng khám phá thế giới',
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
