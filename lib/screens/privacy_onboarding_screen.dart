import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'terms_screen.dart';

class PrivacyOnboardingScreen extends StatelessWidget {
  const PrivacyOnboardingScreen({super.key});

  // This screen is only ever reached on the very first run, before the user can
  // reach the theme toggle in Settings, so it is dark by construction rather
  // than by relying on the app's default ThemeMode resolving to dark.
  // Built once, not per frame.
  static final ThemeData _theme = AppTheme.darkTheme;

  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Colors.white70;
  static const Color _textMuted = Colors.white60;

  // Two steps on one blue ramp: the lighter tone carries icons and links
  // (8.3:1 on black), the saturated tone fills the primary action and keeps a
  // white label readable (5.1:1).
  static const Color _accent = Color(0xFF60A5FA);
  static const Color _accentTint = Color(0x2660A5FA);
  static const Color _accentFill = Color(0xFF2563EB);

  static const SystemUiOverlayStyle _overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlay,
        child: Scaffold(
          backgroundColor: _theme.scaffoldBackgroundColor,
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
                          const SizedBox(height: 40),
                          // 1. Icon & Header
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: _accentTint,
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              color: _accent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Privacy & Data Control',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: const Text(
                              'Bubble Budget is designed with a strict privacy-first philosophy:',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: _textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 2. Features
                          _buildFeatureTile(
                            Icons.storage_rounded,
                            'Local Storage',
                            'All your budget configurations and transaction history are stored 100% locally on your phone. Nothing is uploaded to external third-party servers.',
                          ),
                          const SizedBox(height: 22),
                          _buildFeatureTile(
                            Icons.cloud_done_rounded,
                            'Google Sheets Sync',
                            'Optionally connect your own private Google Sheet for backups—only for your eyes. Perfect for financial planning on your laptop or PC.',
                          ),
                          const SizedBox(height: 22),
                          _buildFeatureTile(
                            Icons.wifi_off_rounded,
                            'Offline-First & Account-Free',
                            'No sign-up, no email registration, and no password required. Full app functionality is fully available offline.',
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
                            style: TextStyle(fontSize: 13, color: _textMuted, height: 1.4),
                            children: [
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: _accent,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _accent,
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
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(28)),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x4D2563EB),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
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
                              backgroundColor: _accentFill,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(28)),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Agree and Continue',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                            ),
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
        ),
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _accentTint,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Icon(icon, color: _accent, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
