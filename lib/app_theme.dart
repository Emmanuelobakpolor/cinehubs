import 'package:flutter/material.dart';

class AppTheme {
  final bool isDark;

  const AppTheme._(this.isDark);

  static AppTheme of(BuildContext context) =>
      AppTheme._(Theme.of(context).brightness == Brightness.dark);

  Color get background    => isDark ? const Color(0xFF121212) : Colors.white;
  Color get card          => isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50;
  Color get textPrimary   => isDark ? Colors.white            : const Color(0xFF1A1A1A);
  Color get textSecondary => isDark ? Colors.white54          : const Color(0xFF9E9E9E);
  Color get iconBg        => isDark ? Colors.white12          : Colors.grey.shade200;
  Color get progressTrack => isDark ? Colors.white12          : Colors.grey.shade200;
  Color get inputBg       => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

  Color get themeToggleBg       => isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100;
  Color get themeToggleSelected => isDark ? const Color(0xFF3A3A3A) : Colors.white;

  // Hero section — overlaid on movie poster
  Color get heroTopGradient => isDark ? Colors.black : Colors.white;
  Color get heroIcon        => isDark ? Colors.white : Colors.black87;
  Color get heroPillFill    => isDark ? Colors.white : Colors.black;
  Color get heroPillText    => isDark ? Colors.black : Colors.white;
  Color get heroPillBorder  => isDark
      ? Colors.white.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.35);
}
