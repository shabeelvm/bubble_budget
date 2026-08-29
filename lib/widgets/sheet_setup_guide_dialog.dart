import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/apps_script_template.dart';

class SheetSetupGuideDialog extends StatelessWidget {
  const SheetSetupGuideDialog({super.key});

  Future<void> _launchTemplateUrl() async {
    final Uri url = Uri.parse(kGoogleSheetTemplateUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  String _getPlaintextGuide() {
    return '''
Bubble Budget — Google Sheets Connection Guide

Step 1: Copy the Template
Open the official Google Sheet template in your browser and click "Make a copy":
$kGoogleSheetTemplateUrl

Step 2: Open Apps Script
In your new Google Sheet, go to:
Extensions > Apps Script

Step 3: Deploy the Web App
1. Paste the script code from the Bubble Budget app.
2. Click "Save".
3. Click "Deploy" > "New deployment".
4. Select "Web App".
5. Set "Execute as" to "Me".
6. Set "Who has access" to "Anyone".
7. Click "Deploy" and copy the Web App URL.

Step 4: Connect in the App
Go back to Bubble Budget, enter your customized Sheet Tag and paste the Web App Webhook URL, then tap "Verify & Connect".
''';
  }

  Future<void> _emailInstructions(BuildContext context) async {
    final guide = _getPlaintextGuide();
    final subject = 'Bubble Budget - Google Sheets Setup Guide';

    String encodeQueryParam(String text) {
      return Uri.encodeComponent(text).replaceAll('+', '%20');
    }

    final Uri emailLaunchUri = Uri.parse(
      'mailto:?subject=${encodeQueryParam(subject)}&body=${encodeQueryParam(guide)}',
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: guide));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instructions copied to clipboard (could not open mail app).')),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: guide));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructions copied to clipboard.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final stepBg = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF3F4F6);
    final stepBorder = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: stepBorder),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Sheets Setup Walkthrough',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Steps content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStepCard(
                      stepNumber: '1',
                      title: 'Copy the Template',
                      description: 'Copy our official Google Sheet budget spreadsheet template straight into your own Google Drive.',
                      stepBg: stepBg,
                      stepBorder: stepBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      action: ElevatedButton.icon(
                        onPressed: _launchTemplateUrl,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Template Spreadsheet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStepCard(
                      stepNumber: '2',
                      title: 'Open Apps Script',
                      description: 'In your newly copied Google Sheet, navigate to Extensions in the top menu, then click Apps Script.',
                      stepBg: stepBg,
                      stepBorder: stepBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 16),
                    _buildStepCard(
                      stepNumber: '3',
                      title: 'Deploy Web App',
                      description: 'Delete any template code, paste our Custom Apps Script, and click Deploy > New deployment. Select Web App.\n\n• Execute as: Me\n• Who has access: Anyone',
                      stepBg: stepBg,
                      stepBorder: stepBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 16),
                    _buildStepCard(
                      stepNumber: '4',
                      title: 'Connect & Verify',
                      description: 'Copy the generated Web App URL, paste it into the Webhook URL field in this screen, and tap Verify & Connect.',
                      stepBg: stepBg,
                      stepBorder: stepBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Bottom actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _emailInstructions(context),
                      icon: const Icon(Icons.email_outlined, size: 16),
                      label: const Text('Email Me Instructions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required Color stepBg,
    required Color stepBorder,
    required Color textPrimary,
    required Color textSecondary,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: stepBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stepBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number circle badge
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 12),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
