import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Branded Launch Screen showcasing `logo_smalll.jpg` fitted cleanly to the
/// screen alongside "Built by Plexus Labs & Systems LTD" ownership recognition.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();

    _navTimer = Timer(const Duration(milliseconds: 2100), _goToHome);
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E131F),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Fit logo_smalll.jpg responsively to the device screen width & height
              final shortestSide = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              final logoDimension =
                  (shortestSide * 0.62).clamp(160.0, 320.0);

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 8),
                    // Center fitted logo_smalll.jpg + App Title
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: logoDimension,
                            height: logoDimension,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D2FF)
                                      .withValues(alpha: 0.18),
                                  blurRadius: 32,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/logo_smalll.jpg',
                              width: logoDimension,
                              height: logoDimension,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'SlicePDF Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Precision PDF Range Splitter & Page Verifier',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Ownership & Recognition Badge
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 340),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ENGINEERED & BUILT BY',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: AppTheme.secondary.withValues(
                                  alpha: 0.95,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'Plexus Labs & Systems LTD',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
