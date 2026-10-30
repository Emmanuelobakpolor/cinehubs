import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../services/storage_service.dart';
import '../profile/privacy_policy_screen.dart';
import '../profile/terms_of_service_screen.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';

/// Guests can browse freely; actions such as playing, downloading or saving
/// need an account. Returns true when the user is already signed in.
/// Otherwise shows a sign-up sheet and returns false — a successful sign in
/// or sign up resets the app to the main screen.
Future<bool> requireAccount(
  BuildContext context, {
  String title = 'Create a free account',
  String message =
      'Sign up or sign in to watch, download and save movies on Cinehubs.',
}) async {
  if (StorageService.loggedIn.value) return true;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.of(context).background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _AccountPromptSheet(
      title: title,
      message: message,
      onSignUp: () {
        Navigator.pop(sheetContext);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        );
      },
      onSignIn: () {
        Navigator.pop(sheetContext);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignInScreen()),
        );
      },
    ),
  );
  return false;
}

class _AccountPromptSheet extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onSignUp;
  final VoidCallback onSignIn;

  const _AccountPromptSheet({
    required this.title,
    required this.message,
    required this.onSignUp,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.iconBg,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _AccountButtons(onSignUp: onSignUp, onSignIn: onSignIn),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Not now',
                style: TextStyle(color: theme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stand-in for account-only tabs (Saved, History, Downloads, Profile)
/// while browsing as a guest.
class GuestPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Shows Terms / Privacy links — used on the Profile tab so guests can
  /// still reach them.
  final bool showLegalLinks;

  const GuestPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.showLegalLinks = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Leave room for the floating bottom navigation bar.
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 110),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 42),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                _AccountButtons(
                  onSignUp: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
                  onSignIn: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  ),
                ),
                if (showLegalLinks) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TermsOfServiceScreen()),
                        ),
                        child: const Text('Terms of Service'),
                      ),
                      Text('·', style: TextStyle(color: theme.textSecondary)),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen()),
                        ),
                        child: const Text('Privacy Policy'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountButtons extends StatelessWidget {
  final VoidCallback onSignUp;
  final VoidCallback onSignIn;

  const _AccountButtons({required this.onSignUp, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Sign up',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: onSignIn,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'I already have an account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
