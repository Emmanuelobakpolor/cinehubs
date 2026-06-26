import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../services/user_service.dart';
import 'edit_profile_screen.dart';
import 'customer_support_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    // State lives inside the dialog via StatefulBuilder
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChangePasswordDialog(
        onSubmit: (oldPw, newPw, confirmPw) async {
          if (newPw != confirmPw) {
            return 'New passwords do not match.';
          }
          if (newPw.length < 6) {
            return 'New password must be at least 6 characters.';
          }
          try {
            await UserService.changePassword(
              oldPassword: oldPw,
              newPassword: newPw,
            );
            return null; // success
          } on UserException catch (e) {
            return e.message;
          }
        },
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Password updated successfully'),
              backgroundColor: AppColors.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );

    // Dispose controllers after dialog closes
    Future.delayed(const Duration(seconds: 1), () {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {

    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,

      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        centerTitle: false,

        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        title: Text(
          'Settings',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // ================= ACCOUNT =================

            _SectionHeader(
              title: 'ACCOUNT',
              theme: theme,
            ),

            const SizedBox(height: 14),

            _SettingsItem(
              icon: Icons.person_rounded,
              title: 'Personal Information',
              subtitle: 'Name, email, profile photo',

              onTap: () async {
                // Capture navigator before the async gap
                final nav = Navigator.of(context);
                final updated = await nav.push<UserProfile>(
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
                // Bubble the updated profile up to ProfileScreen
                if (updated != null && mounted) {
                  nav.pop(updated);
                }
              },

              theme: theme,
            ),

            _SettingsItem(
              icon: Icons.lock_rounded,
              title: 'Password & Security',
              subtitle: 'Change password, 2FA',

              onTap: _showChangePasswordDialog,

              theme: theme,
            ),

            const SizedBox(height: 39),

            // ================= SUPPORT =================

            _SectionHeader(
              title: 'SUPPORT & LEGAL',
              theme: theme,
            ),

          

            _SettingsItem(
              icon: Icons.headset_mic_rounded,
              title: 'Customer Support',
              subtitle: 'Get help, report an issue',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerSupportScreen(),
                ),
              ),
              theme: theme,
            ),

_SettingsItem(
               icon: Icons.description_rounded,
               title: 'Terms of Service',
               onTap: () => Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (_) => const TermsOfServiceScreen(),
                 ),
               ),
               theme: theme,
             ),

             _SettingsItem(
               icon: Icons.privacy_tip_rounded,
               title: 'Privacy Policy',
               onTap: () => Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (_) => const PrivacyPolicyScreen(),
                 ),
               ),
               theme: theme,
             ),

            const SizedBox(height: 40),

            Center(
              child: Text(
                'Cinehubs v2.4.1 • 2026',
                style: TextStyle(
                  color: theme.textSecondary.withAlpha(180),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ================= SECTION HEADER =================

class _SectionHeader extends StatelessWidget {

  final String title;
  final AppTheme theme;

  const _SectionHeader({
    required this.title,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(left: 4),

      child: Text(
        title,

        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ================= SETTINGS ITEM =================

class _SettingsItem extends StatelessWidget {

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final AppTheme theme;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,

          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),

            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(22),

              border: Border.all(
                color: Colors.white.withAlpha(10),
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),

            child: Row(
              children: [

                // ICON CONTAINER

                Container(
                  height: 48,
                  width: 48,

                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(14),
                  ),

                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // TEXTS

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(
                        title,

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),

                      if (subtitle != null) ...[

                        const SizedBox(height: 4),

                        Text(
                          subtitle!,

                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                trailing ??
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: theme.textSecondary,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Change Password Dialog ────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  /// Returns an error message string on failure, or null on success.
  final Future<String?> Function(String old, String newPw, String confirm)
      onSubmit;
  final VoidCallback onSuccess;

  const _ChangePasswordDialog({
    required this.onSubmit,
    required this.onSuccess,
  });

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final error = await widget.onSubmit(
      _currentCtrl.text,
      _newCtrl.text,
      _confirmCtrl.text,
    );

    if (!mounted) return;

    if (error == null) {
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return AlertDialog(
      backgroundColor: theme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Change Password',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PasswordField(
            controller: _currentCtrl,
            label: 'Current Password',
            obscure: _obscureCurrent,
            onToggle: () =>
                setState(() => _obscureCurrent = !_obscureCurrent),
            theme: theme,
          ),
          const SizedBox(height: 14),
          _PasswordField(
            controller: _newCtrl,
            label: 'New Password',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
            theme: theme,
          ),
          const SizedBox(height: 14),
          _PasswordField(
            controller: _confirmCtrl,
            label: 'Confirm New Password',
            obscure: _obscureConfirm,
            onToggle: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            theme: theme,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.errorRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.errorRed, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor:
                AppColors.primary.withValues(alpha: 0.5),
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final AppTheme theme;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: theme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary, fontSize: 14),
        filled: true,
        fillColor: theme.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textGrey,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}