import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../screens/terms_screen.dart';

class PrivacyConsentDialog extends StatefulWidget {
  final VoidCallback onAccepted;

  const PrivacyConsentDialog({super.key, required this.onAccepted});

  static void show(BuildContext context, {required VoidCallback onAccepted}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PrivacyConsentDialog(onAccepted: onAccepted),
    );
  }

  @override
  State<PrivacyConsentDialog> createState() => _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends State<PrivacyConsentDialog> {
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.security_rounded, color: Colors.blueAccent, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Privacy & Data Control',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Bubble Budget is designed with a strict privacy-first philosophy:',
                style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildFeatureTile(
                Icons.storage_rounded,
                'Local Storage',
                'All your budget data lives securely on your phone. Nothing is stored on external servers.',
              ),
              _buildFeatureTile(
                Icons.cloud_done_rounded,
                'Google Sheets Sync',
                'Optionally connect your own private Google Sheet for backups—only for your eyes. Perfect for financial planning on your laptop or PC.',
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermsScreen()),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to our ',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
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
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _settings.hasAcceptedPrivacy = true;
                    Navigator.pop(context);
                    widget.onAccepted();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Agree & Continue',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
