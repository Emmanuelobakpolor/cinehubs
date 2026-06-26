import 'package:flutter/material.dart';
import '../../app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
              'Terms of Service',
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

            // Agreement notice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'By using Cinehubs, you agree to these terms. Please read them carefully.',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Content Sections
            _TermsSection(
              title: '1. Service Overview',
              content:
                  'Cinehubs provides streaming entertainment services including movies and TV shows. Content availability varies by region and subscription plan.',
              theme: theme,
            ),

            _TermsSection(
              title: '2. Account Registration',
              content:
                  'You must create an account to access most features. You are responsible for maintaining the security of your account and password. Notify us immediately of any unauthorized access.',
              theme: theme,
            ),

            _TermsSection(
              title: '3. Subscription & Billing',
              content:
                  '• Subscriptions are billed on a recurring basis\n'
                  '• You may cancel anytime through account settings\n'
                  '• Refunds are not provided for partial months\n'
                  '• We may change pricing with 30 days notice',
              theme: theme,
            ),

            _TermsSection(
              title: '4. Acceptable Use',
              content:
                  'You agree not to:\n'
                  '• Share account credentials outside your household\n'
                  '• Download or redistribute content illegally\n'
                  '• Circumvent any security measures\n'
                  '• Use the service for commercial purposes',
              theme: theme,
            ),

            _TermsSection(
              title: '5. Content License',
              content:
                  'Content is provided for personal, non-commercial use. All rights remain with their respective owners. We reserve the right to remove content at any time.',
              theme: theme,
            ),

            _TermsSection(
              title: '6. Disclaimer',
              content:
                  'Cinehubs is provided "as is" without warranties of any kind. We do not guarantee uninterrupted service or error-free content.',
              theme: theme,
            ),

            _TermsSection(
              title: '7. Limitation of Liability',
              content:
                  'We shall not be liable for any indirect damages arising from your use of the service. Our total liability shall not exceed the amount paid in the last billing period.',
              theme: theme,
            ),

            _TermsSection(
              title: '8. Termination',
              content:
                  'We may suspend or terminate your account for violations of these terms. You may terminate your account at any time through the app settings.',
              theme: theme,
            ),

            _TermsSection(
              title: '9. Changes to Terms',
              content:
                  'We may modify these terms. Continued use of the service constitutes acceptance of updated terms.',
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
                    'Contact Support',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'For questions about these terms, contact us at Cinehubscustomercare@gmail.com',
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

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;
  final AppTheme theme;

  const _TermsSection({
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
              fontSize: 17,
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