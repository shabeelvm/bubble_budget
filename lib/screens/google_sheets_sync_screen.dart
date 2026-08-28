import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../services/db_service.dart';

class GoogleSheetsSyncScreen extends StatefulWidget {
  const GoogleSheetsSyncScreen({super.key});

  @override
  State<GoogleSheetsSyncScreen> createState() => _GoogleSheetsSyncScreenState();
}

class _GoogleSheetsSyncScreenState extends State<GoogleSheetsSyncScreen> {
  final SettingsService _settings = SettingsService();
  final SyncService _syncService = SyncService();
  final DBService _dbService = DBService();
  final TextEditingController _webhookController = TextEditingController();
  
  bool _isTesting = false;
  bool _isSyncing = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _webhookController.text = _settings.sheetsWebhookUrl;
    _updatePendingCount();
  }

  Future<void> _updatePendingCount() async {
    final unsynced = await _dbService.getUnsyncedExpenses();
    if (mounted) {
      setState(() => _pendingCount = unsynced.length);
    }
  }

  Future<String> _loadScriptCode() async {
    return await rootBundle.loadString('assets/scripts/google_apps_script.js');
  }

  String _getSetupGuide(String scriptCode) {
    return '''
Bubble Budget — Google Sheets Setup Kit

1. Create a new Google Sheet.
2. Go to Extensions > Apps Script.
3. Delete any existing code and paste the script provided below.
4. Click 'Save' and 'Deploy' > 'New Deployment'.
5. Select 'Web App', set 'Who has access' to 'Anyone'.
6. Copy the Web App URL and paste it into the Bubble Budget app.

--- APPS SCRIPT CODE ---
$scriptCode
''';
  }

  Future<void> _emailSetupKit() async {
    final scriptCode = await _loadScriptCode();
    final guide = _getSetupGuide(scriptCode);
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      query: _encodeQueryParameters({
        'subject': 'Bubble Budget — Google Sheets Setup Kit',
        'body': guide,
      }),
    );
    
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      _showSnackbar('Could not launch email app', isError: true);
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '\${Uri.encodeComponent(e.key)}=\${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _copyScriptCode() async {
    final scriptCode = await _loadScriptCode();
    await Clipboard.setData(ClipboardData(text: scriptCode));
    _showSnackbar('Script code copied to clipboard!');
  }

  Future<void> _shareSetupKit() async {
    final scriptCode = await _loadScriptCode();
    final guide = _getSetupGuide(scriptCode);
    await Share.share(guide, subject: 'Bubble Budget Setup Kit');
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    final success = await _syncService.testWebhook(_webhookController.text);
    if (!mounted) return;
    setState(() => _isTesting = false);
    _showSnackbar(
      success ? 'Connection Successful!' : 'Connection Failed. Check URL.',
      isError: !success,
    );
  }

  Future<void> _syncPending() async {
    setState(() => _isSyncing = true);
    await _syncService.syncAllPending();
    await _updatePendingCount();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    _showSnackbar('Sync complete!');
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Google Sheets Sync'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('1. Setup Kit', [
            _buildCard([
              const Text(
                'Get everything you need to connect your Google Sheets in seconds.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                icon: Icons.email_outlined,
                label: 'Email Setup Kit to Myself',
                onTap: _emailSetupKit,
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy Script Code',
                onTap: _copyScriptCode,
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Share via Apps',
                onTap: _shareSetupKit,
              ),
            ]),
          ]),
          const SizedBox(height: 24),
          _buildSection('2. Configuration', [
            TextField(
              controller: _webhookController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Google Sheets Webhook URL',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                hintText: 'https://script.google.com/...',
              ),
              onChanged: (value) => _settings.sheetsWebhookUrl = value,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_alt),
                label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('3. Maintenance', [
            _buildCard([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pending Records', style: TextStyle(color: Colors.white)),
                  Text('\$_pendingCount', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isSyncing || _pendingCount == 0) ? null : _syncPending,
                  icon: _isSyncing 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync Pending Records'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ]),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
