import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../auth/signin_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/settings_screen.dart';
import '../profile/customer_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDark = themeNotifier.value == ThemeMode.dark;
  UserProfile? _profile;
  bool _isLoadingProfile = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _loadError = null;
    });
    try {
      final profile = await UserService.getProfile();
      if (mounted) setState(() => _profile = profile);
    } on UserException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _toggleTheme(bool value) {
    setState(() => _isDark = value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _openSettings() async {
    final nav = Navigator.of(context);
    final updated = await nav.push<UserProfile>(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    // If Settings → Personal Information returned an updated profile, apply it instantly
    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.of(context).card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_isLoadingProfile)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
              onPressed: _fetchProfile,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          children: [
            // ── Error Banner ──
            if (_loadError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: AppColors.errorRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _loadError!,
                        style: const TextStyle(
                          color: AppColors.errorRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _fetchProfile,
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Profile Header Card ──
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final avatarRadius = w < 340 ? 30.0 : 40.0;
                final nameFontSize = w < 340 ? 16.0 : 20.0;
                final compact = w < 360;

                return Container(
                  padding: EdgeInsets.all(compact ? 14 : 20),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: theme.iconBg,
                        backgroundImage:
                            (_profile?.profilePictureUrl != null &&
                                _profile!.profilePictureUrl!.isNotEmpty)
                            ? NetworkImage(_profile!.profilePictureUrl!)
                            : null,
                        child:
                            (_profile?.profilePictureUrl == null ||
                                _profile!.profilePictureUrl!.isEmpty)
                            ? Icon(
                                Icons.person,
                                size: avatarRadius * 1.1,
                                color: AppColors.textGrey,
                              )
                            : null,
                      ),
                      SizedBox(width: compact ? 12 : 18),
                      // Name / email / badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + Edit button on the same line
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _isLoadingProfile
                                      ? _Shimmer(
                                          width: 130,
                                          height: 22,
                                          theme: theme,
                                        )
                                      : Text(
                                          _profile?.fullName.isEmpty == false
                                              ? _profile!.fullName
                                              : 'Loading...',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: nameFontSize,
                                            fontWeight: FontWeight.bold,
                                            color: theme.textPrimary,
                                          ),
                                        ),
                                ),
                                SizedBox(width: compact ? 8 : 12),
                                GestureDetector(
                                  onTap: () async {
                                    final nav = Navigator.of(context);
                                    final updated = await nav.push<UserProfile>(
                                      MaterialPageRoute(
                                        builder: (_) => EditProfileScreen(
                                          profile: _profile,
                                        ),
                                      ),
                                    );
                                    if (updated != null && mounted) {
                                      setState(() => _profile = updated);
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 12 : 16,
                                      vertical: compact ? 8 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: compact ? 14 : 16,
                                        ),
                                        SizedBox(width: compact ? 4 : 6),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: compact ? 12 : 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Email — full width, wraps if long
                            _isLoadingProfile
                                ? _Shimmer(width: 170, height: 14, theme: theme)
                                : Text(
                                    _profile?.email ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textGrey,
                                    ),
                                    maxLines: 2,
                                    softWrap: true,
                                  ),
                            const SizedBox(height: 10),
                            // Verified badge
                            if (_profile != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _profile!.isEmailVerified
                                      ? AppColors.primary
                                      : AppColors.textGrey.withValues(
                                          alpha: 0.3,
                                        ),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _profile!.isEmailVerified
                                          ? Icons.verified
                                          : Icons.warning_amber_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _profile!.isEmailVerified
                                          ? 'Verified'
                                          : 'Unverified',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Stats Card ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isLoadingProfile
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Shimmer(width: 48, height: 40, theme: theme),
                        _Shimmer(width: 48, height: 40, theme: theme),
                        _Shimmer(width: 48, height: 40, theme: theme),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          value: '${_profile?.watchedCount ?? 0}',
                          label: 'Watched',
                          theme: theme,
                        ),
                        _StatItem(
                          value: '${_profile?.savedCount ?? 0}',
                          label: 'Saved',
                          theme: theme,
                        ),
                        _StatItem(
                          value: '${_profile?.reviewsCount ?? 0}',
                          label: 'Reviews',
                          theme: theme,
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 20),

            // ── Bio ──
            if (_isLoadingProfile)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Shimmer(width: 40, height: 16, theme: theme),
                    const SizedBox(height: 12),
                    _Shimmer(width: double.infinity, height: 14, theme: theme),
                    const SizedBox(height: 8),
                    _Shimmer(width: 220, height: 14, theme: theme),
                  ],
                ),
              )
            else if (_profile?.bio != null && _profile!.bio!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _profile!.bio!,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // ── Theme Toggle ──
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.themeToggleBg,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThemeOption(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Light',
                    isSelected: !_isDark,
                    theme: theme,
                    onTap: () => _toggleTheme(false),
                  ),
                  _ThemeOption(
                    icon: Icons.nightlight_round,
                    label: 'Dark',
                    isSelected: _isDark,
                    theme: theme,
                    onTap: () => _toggleTheme(true),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Action Cards ──
            _ActionCard(
              icon: Icons.settings_outlined,
              title: 'Settings',
              theme: theme,
              onTap: _openSettings,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.phone_outlined,
              title: 'Customer Support',
              theme: theme,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerSupportScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.logout,
              title: 'Log Out',
              theme: theme,
              isDestructive: true,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer placeholder ──────────────────────────────────────────────

class _Shimmer extends StatelessWidget {
  final double width;
  final double height;
  final AppTheme theme;

  const _Shimmer({
    required this.width,
    required this.height,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.iconBg,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ── Helper Widgets ───────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final AppTheme theme;

  const _StatItem({
    required this.value,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: theme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final AppTheme theme;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.themeToggleSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? theme.textPrimary : theme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? theme.textPrimary : theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final AppTheme theme;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.theme,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDestructive ? AppColors.errorRed : theme.textPrimary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? AppColors.errorRed : theme.textPrimary,
                ),
              ),
            ),
            if (!isDestructive)
              Icon(Icons.chevron_right, color: theme.textSecondary),
          ],
        ),
      ),
    );
  }
}
