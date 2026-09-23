import 'dart:async';

import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/fcm_service.dart';
import '../services/storage_service.dart';
import 'onboarding_screen.dart';
import 'main/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _glowController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _glowPulse;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _glowPulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _glowController.repeat(reverse: true);

    _logoController.forward().then((_) {
      _textController.forward();
    });

    _timer = Timer(const Duration(milliseconds: 3200), () async {
      if (!mounted) return;
      final isLoggedIn = await StorageService.hasTokens();
      if (isLoggedIn) FCMService.registerAfterLogin();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isLoggedIn ? const MainScreen() : const OnboardingScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _glowController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Cinematic background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D0D0D),
                  Color(0xFF1A1A1A),
                  Color(0xFF111111),
                ],
              ),
            ),
          ),

          // Radial golden glow behind logo
          Center(
            child: AnimatedBuilder(
              animation: _glowPulse,
              builder: (context, _) {
                return Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary
                            .withValues(alpha: 0.18 * _glowPulse.value),
                        AppColors.primary
                            .withValues(alpha: 0.06 * _glowPulse.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: AnimatedBuilder(
                      animation: _glowPulse,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.5 * _glowPulse.value),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.25 * _glowPulse.value),
                                blurRadius: 100,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'lib/assets/3cc6fce607ac4d25744e2645eb35bcafb9dc5e19.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // App name + tagline
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        // CINEHUB wordmark
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFD4AF37),
                              Color(0xFFBFA726),
                              Color(0xFFE8C84A),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'CINEHUBS',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 10,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Divider with gold accent
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 1,
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 40,
                              height: 1,
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Tagline
                        Text(
                          'Nollywood & Beyond, On Demand',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom loader
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom brand text
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: const Center(
                child: Text(
                  'Stream · Discover · Experience',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF555555),
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
