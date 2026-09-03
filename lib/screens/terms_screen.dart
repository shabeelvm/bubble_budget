import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'welcome_screen.dart';

class TermsScreen extends StatelessWidget {
  final bool isOnboarding;
  const TermsScreen({super.key, this.isOnboarding = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final textMuted = isDark ? Colors.white.withAlpha(120) : const Color(0xFF9CA3AF);

    if (isOnboarding) {
      // Screen 1: Clean Data & Privacy Screen
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
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.security_rounded,
                            size: 40,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Privacy & Data Control',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bubble Budget is designed with a strict privacy-first philosophy:',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 32),

                        // 2. Commitments (Original Privacy & Data Control settings/text style)
                        _buildFeatureTile(
                          context,
                          Icons.storage_rounded,
                          'Local Storage',
                          'All your budget configurations and transaction history are stored 100% locally on your phone. Nothing is uploaded to external third-party servers.',
                          textPrimary,
                          textSecondary,
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureTile(
                          context,
                          Icons.cloud_done_rounded,
                          'Google Sheets Sync',
                          'Optionally connect your own private Google Sheet for backups—only for your eyes. Perfect for financial planning on your laptop or PC.',
                          textPrimary,
                          textSecondary,
                        ),
                        const SizedBox(height: 16),
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
                        // Open the detailed T&C wall-of-text ONLY if explicitly clicked
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
                                color: Color(0xFF0D9488),
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
                          settings.hasAgreedTerms = true;
                          // Navigate to Screen 2 (WelcomeScreen)
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
                          backgroundColor: const Color(0xFF0D9488),
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

    // Default detailed terms screen (wall-of-text) when isOnboarding is false
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service & Privacy Policy',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: August 2026',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Local-First Storage',
              'All your budget configurations, category details, and transaction history are stored 100% locally on your device in a secure private SQLite database. No central servers, proxies, or cloud endpoints owned by us ever hold, process, or transmit your financial logs.',
              textSecondary,
            ),
            _buildSection(
              '2. Data Loss & Uninstallation',
              'Because your data is stored strictly on your device, deleting or uninstalling the Bubble Budget application from your device will permanently erase all your transaction logs, custom categories, and historical data. We highly recommend setting up Google Sheets Sync (see Section 3) to preserve a secure, cloud-saved ledger.',
              textSecondary,
            ),
            _buildSection(
              '3. User-Owned Google Sheets Sync',
              'If you choose to enable cloud backup sync, transaction payloads are sent directly from your device to your personal Google Sheet via a Google Apps Script Webhook. This connection is direct and private. We have no access to your spreadsheet, your Google account, or your API credentials.',
              textSecondary,
            ),
            _buildSection(
              '4. Data Storage, Retention, and Sync Limits',
              'The Application operates primarily as an on-device utility. Local transaction records are capped at five hundred (500) entries. Upon reaching this capacity, the Application automatically prunes older records on a First-In, First-Out (FIFO) basis to accommodate new entries. The Application provides advisory notifications approaching this limit, but users are solely responsible for backing up records via CSV export or external Google Sheets synchronization. The Developer is not responsible for pruned or unrecoverable local data. Single transaction amounts are capped at 10,000,000 for data integrity. Connected external URLs (such as Google Apps Script endpoints) are masked for security and must be retrieved from the host provider if lost.',
              textSecondary,
            ),
            _buildSection(
              '5. Disclaimer & Agreement',
              'Bubble Budget is provided "as is" without warranty of any kind. You are solely responsible for managing your local database, maintaining your secure Google Sheets Sync integrations, and securing access to your physical device.',
              textSecondary,
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(BuildContext context, IconData icon, String title, String description, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0D9488), size: 22),
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
      ),
    );
  }

  Widget _buildSection(String title, String body, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
          ),
        ],
      ),
    );
  }
}
