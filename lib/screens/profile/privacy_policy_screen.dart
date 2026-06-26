import 'package:flutter/material.dart';
import '../../app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Your Privacy Matters',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: June 2026',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 24),

            // Content Sections
            _PolicySection(
              title: 'Introduction',
              content:
                  'Cinehubs respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, and safeguard your data when you use our movie streaming service.',
              theme: theme,
            ),

            _PolicySection(
              title: 'Information We Collect',
              content:
                  '• Personal Information: Name, email, and profile details you provide\n'
                  '• Usage Data: Movies watched, search history, and preferences\n'
                  '• Device Information: Device type, operating system, and app version\n'
                  '• Payment Information: Transaction details (processed securely)',
              theme: theme,
            ),

            _PolicySection(
              title: 'How We Use Your Information',
              content:
                  'We use your information to provide and improve our service, personalize your experience, process payments, and communicate with you about updates or promotional offers.',
              theme: theme,
            ),

            _PolicySection(
              title: 'Data Security',
              content:
                  'Your data is protected using industry-standard encryption and security measures. We never sell your personal information to third parties.',
              theme: theme,
            ),

            _PolicySection(
              title: 'Your Rights',
              content:
                  'You have the right to access, update, or delete your personal information. You may also opt out of promotional communications at any time through your account settings.',
              theme: theme,
            ),

            _PolicySection(
              title: 'Changes to This Policy',
              content:
                  'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy on this page.',
              theme: theme,
            ),

            const SizedBox(height: 30),

            // Contact
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questions?',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'If you have any questions about this Privacy Policy, please contact us at Cinehubscustomercare@gmail.com',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
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

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;
  final AppTheme theme;

  const _PolicySection({
    required this.title,
    required this.content,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}