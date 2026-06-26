import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../app_colors.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import 'watch_history_screen.dart';
import 'downloads_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final GlobalKey<SavedScreenState> _savedKey = GlobalKey<SavedScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      SavedScreen(key: _savedKey),
      const WatchHistoryScreen(),
      const DownloadsScreen(),
      const ProfileScreen(),
    ];
  }

  final List<Map<String, dynamic>> _navItems = [
    {
      "icon": Icons.home_rounded,
      "label": "Home",
    },
    {
      "icon": Icons.bookmark_rounded,
      "label": "Saved",
    },
    {
      "icon": Icons.play_circle_fill_rounded,
      "label": "History",
    },
    {
      "icon": Icons.download_rounded,
      "label": "Downloads",
    },
    {
      "icon": Icons.person_rounded,
      "label": "Profile",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.darkBg.withAlpha(160),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withAlpha(18),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  _navItems.length,
                  (index) {
                    final isSelected = _currentIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _currentIndex = index);
                        if (index == 1) _savedKey.currentState?.refresh();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 14 : 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withAlpha(28)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                _navItems[index]["icon"],
                                key: ValueKey(isSelected),
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white38,
                                size: 24,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 7),
                              Text(
                                _navItems[index]["label"],
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}