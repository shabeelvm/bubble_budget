import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
            const Text(
              'Terms of Service & Privacy Policy',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: August 2026',
              style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(120)),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Local-First Storage',
              'All your budget configurations, category details, and transaction history are stored 100% locally on your device in a secure private SQLite database. No central servers, proxies, or cloud endpoints owned by us ever hold, process, or transmit your financial logs.',
            ),
            _buildSection(
              '2. Data Loss & Uninstallation',
              'Because your data is stored strictly on your device, deleting or uninstalling the Bubble Budget application from your device will permanently erase all your transaction logs, custom categories, and historical data. We highly recommend setting up Google Sheets Sync (see Section 3) to preserve a secure, cloud-saved ledger.',
            ),
            _buildSection(
              '3. User-Owned Google Sheets Sync',
              'If you choose to enable cloud backup sync, transaction payloads are sent directly from your device to your personal Google Sheet via a Google Apps Script Webhook. This connection is direct and private. We have no access to your spreadsheet, your Google account, or your API credentials.',
            ),
            _buildSection(
              '4. Anonymous Usage Analytics',
              'If you opt-in to share usage statistics, the application transmits lightweight, pseudo-anonymous event tracking (e.g. app opened, sync toggled). This transmission uses a random, non-identifiable session UUID and general device metadata (platform, app version). To strictly enforce privacy, any sensitive values—such as financial transaction amounts, categories, or notes—are stripped before transmission. You can disable or enable analytics at any time in the Settings menu.',
            ),
            _buildSection(
              '5. Disclaimer & Agreement',
              'Bubble Budget is provided "as is" without warranty of any kind. You are solely responsible for managing your local database, maintaining your secure Google Sheets Sync integrations, and securing access to your physical device.',
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

  Widget _buildSection(String title, String body) {
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
            style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}
