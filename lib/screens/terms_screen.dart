import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final textMuted = isDark ? Colors.white.withAlpha(120) : const Color(0xFF9CA3AF);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                onPressed: () => Navigator.pop(context),
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
          ],
        ),
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
