import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'auth/signup_screen.dart';
import 'auth/signin_screen.dart';

const String _kPosterBase = 'https://image.tmdb.org/t/p/w342';

/// Nollywood posters (TMDB image CDN), three per onboarding page.
const List<String> _kOnboardingPosters = [
  '$_kPosterBase/3nO3VboeVLVOwIHMkTRIwTrrKQP.jpg', // King of Boys
  '$_kPosterBase/9aMG2ftIFqFAN69FdjovKJY0hsd.jpg', // A Tribe Called Judah
  '$_kPosterBase/xb30hkUpBm23stnVgDJGYGsC0R0.jpg', // Aníkúlápó
  '$_kPosterBase/qJpP0QJZE1Lcxswchana8opO9uW.jpg', // The Wedding Party
  '$_kPosterBase/kn28W24slBLyGr8ZIZnxNE5YZrY.jpg', // The Black Book
  '$_kPosterBase/nGwFsB6EXUCr21wzPgtP5juZPSv.jpg', // Gangs of Lagos
  '$_kPosterBase/1pfvgpvHl5W9pV5P4dcnqhzMeUk.jpg', // Battle on Buka Street
  '$_kPosterBase/yAFYuGRA9D1phwDvEfzVZKAJYkF.jpg', // Omo Ghetto: The Saga
  '$_kPosterBase/uPZtE5DSo9VIX2N3NPtmTayhgP8.jpg', // Jagun Jagun
  '$_kPosterBase/k8medyObgY0XTt2dL7BqjxXkqmw.jpg', // Citation
  '$_kPosterBase/rzPxqPcmhjvRU8WtIqwbW95EPQ4.jpg', // Chief Daddy
  '$_kPosterBase/zNoyzNcMa2d8i0cynPKI7KM9Zh0.jpg', // Ìjọ̀gbọ̀n
];

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final url in _kOnboardingPosters) {
      precacheImage(NetworkImage(url), context);
    }
  }

  List<String> _postersForPage(int index) => List.generate(
      3, (i) => _kOnboardingPosters[(index * 3 + i) % _kOnboardingPosters.length]);

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
                          child: _PosterFan(posters: _postersForPage(index)),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three posters fanned out: the centre one in front, the outer two
/// tilted and tucked behind it.
class _PosterFan extends StatelessWidget {
  final List<String> posters;

  const _PosterFan({required this.posters});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Size the front poster (2:3) so the whole fan fits. Each tilted
        // side poster reaches ~1.0 front-widths out from centre, so the fan
        // spans ~2.05 front-widths in total.
        final frontWidth = math.min(
          constraints.maxHeight * 0.85 / 1.5,
          constraints.maxWidth / 2.1,
        );
        final sideOffset = frontWidth * 0.55;

        // Fill the available space so the fan is centred on the page rather
        // than sized to the front poster and pinned to the left edge.
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none, // don't crop the soft shadows
            children: [
              _side(posters[0], frontWidth, -sideOffset, -0.10),
              _side(posters[2], frontWidth, sideOffset, 0.10),
              _PosterCard(url: posters[1], width: frontWidth, elevated: true),
            ],
          ),
        );
      },
    );
  }

  Widget _side(String url, double frontWidth, double dx, double angle) {
    return Transform.translate(
      offset: Offset(dx, frontWidth * 0.06),
      child: Transform.rotate(
        angle: angle,
        child: _PosterCard(url: url, width: frontWidth * 0.82),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final String url;
  final double width;
  final bool elevated;

  const _PosterCard({
    required this.url,
    required this.width,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.28 : 0.16),
            blurRadius: elevated ? 28 : 16,
            offset: Offset(0, elevated ? 14 : 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}

class _OnboardingData {
  final String title;
  final String subtitle;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
  });
}
