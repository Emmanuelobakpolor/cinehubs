import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'auth/signup_screen.dart';
import 'auth/signin_screen.dart';
import 'main/main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      title: 'Naija Stories, Front and Centre',
      subtitle:
          'Nollywood blockbusters, indie gems and diaspora favourites — curated for the culture, not buried under everything else.',
    ),
    _OnboardingData(
      title: 'Watch Now, Pay Your Way',
      subtitle:
          'Subscribe monthly or unlock a single title at a time — pay in Naira, no foreign card required.',
    ),
    _OnboardingData(
      title: 'Download. Data-Friendly. Yours Offline.',
      subtitle:
          'Save a movie once, watch it anywhere — built for real-world networks, not just fibre.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % _pages.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget _illustrationFor(int index) {
    switch (index) {
      case 0:
        return const _DiscoverIllustration();
      case 1:
        return const _PayIllustration();
      default:
        return const _OfflineIllustration();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          page.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          page.subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _illustrationFor(index),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: List.generate(_pages.length, (i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _currentPage ? 28 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _currentPage
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignUpScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sign up and Get Started',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignInScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'I already have an account',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                    ),
                    child: const Text(
                      'Browse movies first',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
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

/// Hosts a looping animation on a square stage with soft gold ripples
/// behind it. [builder] receives the loop progress (0→1) and stage size.
class _LoopingStage extends StatefulWidget {
  final Duration duration;
  final Widget Function(double t, double size) builder;

  const _LoopingStage({required this.duration, required this.builder});

  @override
  State<_LoopingStage> createState() => _LoopingStageState();
}

class _LoopingStageState extends State<_LoopingStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "Reduce Motion" setting.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0.85;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _RipplePainter(t)),
                    ),
                    widget.builder(t, size),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double t;

  _RipplePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      maxR * 0.62,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.primary.withValues(alpha: 0.18),
          AppColors.primary.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: center, radius: maxR * 0.62)),
    );

    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      canvas.drawCircle(
        center,
        maxR * (0.35 + 0.6 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.primary.withValues(alpha: (1 - p) * 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}

/// Page 1: a pulsing play button with genre icons orbiting it.
class _DiscoverIllustration extends StatelessWidget {
  const _DiscoverIllustration();

  static const _icons = [
    Icons.movie_creation_outlined,
    Icons.theater_comedy_outlined,
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.music_note_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return _LoopingStage(
      duration: const Duration(seconds: 8),
      builder: (t, size) {
        final pulse = 1 + 0.06 * math.sin(t * 2 * math.pi * 4);
        final orbitR = size * 0.36;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < _icons.length; i++)
              _orbitingChip(
                icon: _icons[i],
                angle: t * 2 * math.pi + i * 2 * math.pi / _icons.length,
                radius: orbitR,
                size: size * 0.15,
              ),
            Transform.scale(
              scale: pulse,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: size * 0.18),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _orbitingChip({
    required IconData icon,
    required double angle,
    required double radius,
    required double size,
  }) {
    // Slightly elliptical orbit; chips at the "front" look a bit larger.
    final depth = (math.sin(angle) + 1) / 2;
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.8),
      child: Transform.scale(
        scale: 0.85 + 0.25 * depth,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: size * 0.5),
        ),
      ),
    );
  }
}

/// Page 2: a floating Naira card, rising coins and a Monthly / Per-title
/// toggle that flips back and forth.
class _PayIllustration extends StatelessWidget {
  const _PayIllustration();

  @override
  Widget build(BuildContext context) {
    return _LoopingStage(
      duration: const Duration(seconds: 5),
      builder: (t, size) {
        final bob = math.sin(t * 2 * math.pi) * size * 0.02;

        // Toggle position: hold left, slide right, hold, slide back.
        double s;
        if (t < 0.4) {
          s = 0;
        } else if (t < 0.5) {
          s = (t - 0.4) / 0.1;
        } else if (t < 0.9) {
          s = 1;
        } else {
          s = 1 - (t - 0.9) / 0.1;
        }
        s = Curves.easeInOut.transform(s);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < 4; i++) _coin(t, i, size),
            Transform.translate(
              offset: Offset(0, -size * 0.06 + bob),
              child: Container(
                width: size * 0.6,
                height: size * 0.37,
                padding: EdgeInsets.all(size * 0.04),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.contactless_rounded,
                        color: Colors.white70, size: size * 0.07),
                    const Spacer(),
                    Text(
                      '₦',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.11,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: size * 0.01),
                    Text(
                      'Pay in Naira',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: size * 0.04,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, size * 0.25),
              child: _toggle(s, size),
            ),
          ],
        );
      },
    );
  }

  Widget _coin(double t, int i, double size) {
    final p = (t + i / 4) % 1.0;
    final x = (i.isEven ? -1 : 1) * size * (0.36 + 0.04 * (i ~/ 2));
    final y = size * (0.18 - 0.42 * p);
    final coinSize = size * 0.1;
    return Transform.translate(
      offset: Offset(x, y),
      child: Opacity(
        opacity: math.sin(p * math.pi).clamp(0.0, 1.0),
        child: Container(
          width: coinSize,
          height: coinSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Text(
            '₦',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: coinSize * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(double s, double size) {
    final width = size * 0.62;
    final height = size * 0.11;
    Color labelColor(bool active) => Color.lerp(
        AppColors.textDark, Colors.white, active ? 1 - s : s)!;
    final labelStyle = TextStyle(
        fontSize: size * 0.038, fontWeight: FontWeight.w600);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment(-1 + 2 * s, 0),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text('Monthly',
                      style: labelStyle.copyWith(color: labelColor(true))),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('Per title',
                      style: labelStyle.copyWith(color: labelColor(false))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Page 3: a download ring that fills up, then flips to a check mark with
/// an "Offline ready" badge.
class _OfflineIllustration extends StatelessWidget {
  const _OfflineIllustration();

  static const double _fillEnd = 0.65;

  @override
  Widget build(BuildContext context) {
    return _LoopingStage(
      duration: const Duration(milliseconds: 4000),
      builder: (t, size) {
        final progress =
            Curves.easeInOut.transform((t / _fillEnd).clamp(0.0, 1.0));
        final done = t >= _fillEnd;
        final doneT = done ? ((t - _fillEnd) / (1 - _fillEnd)) : 0.0;
        final pop = done
            ? Curves.elasticOut.transform((doneT * 2.5).clamp(0.0, 1.0))
            : 0.0;
        final arrowBounce =
            done ? 0.0 : math.sin(t * 2 * math.pi * 5).abs() * size * 0.025;
        final ringSize = size * 0.5;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _ProgressRingPainter(progress),
                child: Center(
                  child: done
                      ? Transform.scale(
                          scale: pop,
                          child: Icon(Icons.check_rounded,
                              color: AppColors.successGreen,
                              size: ringSize * 0.45),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.translate(
                              offset: Offset(0, arrowBounce),
                              child: Icon(Icons.download_rounded,
                                  color: AppColors.primary,
                                  size: ringSize * 0.32),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: ringSize * 0.1,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, size * 0.36),
              child: Opacity(
                opacity: done ? (doneT * 4).clamp(0.0, 1.0) : 0.0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: size * 0.045, vertical: size * 0.022),
                  decoration: BoxDecoration(
                    color: AppColors.textDark,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: AppColors.primary, size: size * 0.05),
                      SizedBox(width: size * 0.02),
                      Text(
                        'Offline ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.04,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;

  _ProgressRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.07;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke,
    );
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.divider,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

class _OnboardingData {
  final String title;
  final String subtitle;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
  });
}
