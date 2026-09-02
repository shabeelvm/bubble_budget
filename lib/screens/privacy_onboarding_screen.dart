import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'welcome_screen.dart';
import 'terms_screen.dart';

class PrivacyOnboardingScreen extends StatelessWidget {
  const PrivacyOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF4B5563);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      // 1. Icon & Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.security_rounded, color: Colors.blueAccent, size: 36),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Privacy & Data Control',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Bubble Budget is designed with a strict privacy-first philosophy:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 36),

                      // 2. Features
                      _buildFeatureTile(
                        context,
                        Icons.storage_rounded,
                        'Local Storage',
                        'All your budget configurations and transaction history are stored 100% locally on your phone. Nothing is uploaded to external third-party servers.',
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureTile(
                        context,
                        Icons.cloud_done_rounded,
                        'Google Sheets Sync',
                        'Optionally connect your own private Google Sheet for backups—only for your eyes. Perfect for financial planning on your laptop or PC.',
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureTile(
                        context,
                        Icons.wifi_off_rounded,
                        'Offline-First & Account-Free',
                        'No sign-up, no email registration, and no password required. Full app functionality is fully available offline.',
                        textPrimary,
                        textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Subtle T&C Link & Action CTA
              Column(
                children: [
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsScreen(isOnboarding: false)),
                      );
                    },
                    child: const Text.rich(
                      TextSpan(
                        text: 'By continuing, you agree to our ',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final settings = SettingsService();
                        settings.hasAcceptedPrivacy = true;
                        // Move to WelcomeScreen (Screen 2) using premium scaled-fade transition
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 800),
                            pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                              );
                              final scaleTween = Tween<double>(begin: 0.9, end: 1.0).animate(
                                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                              );
                              return FadeTransition(
                                opacity: fadeTween,
                                child: ScaleTransition(
                                  scale: scaleTween,
                                  child: child,
                                ),
                              );
                            },
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Agree and Continue',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile(BuildContext context, IconData icon, String title, String description, Color textPrimary, Color textSecondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blueAccent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}