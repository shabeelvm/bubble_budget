import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../services/db_service.dart';
import '../services/audio_service.dart';
import '../constants/apps_script_template.dart';
import '../widgets/sheet_setup_guide_dialog.dart';

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
  final TextEditingController _tagController = TextEditingController();

  // Pre-filled so the name field can never be the thing standing between the
  // user and a working connection. It is only ever a label.
  static const String _defaultSheetTag = 'My Budget Sheet';
  
  bool _isVerifying = false;
  bool _isSyncing = false;
  bool _isEditing = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tagController.text = _settings.sheetTag.isEmpty ? _defaultSheetTag : _settings.sheetTag;
    _updatePendingCount();

    // Attach listeners for reactive sync state updates
    _syncService.isSyncingNotifier.addListener(_onSyncStateChanged);
    _syncService.syncCompletedNotifier.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    _syncService.isSyncingNotifier.removeListener(_onSyncStateChanged);
    _syncService.syncCompletedNotifier.removeListener(_onSyncStateChanged);
    _tagController.dispose();
    _webhookController.dispose();
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (mounted) {
      _updatePendingCount();
    }
  }

  Future<void> _updatePendingCount() async {
    final count = await _dbService.getUnsyncedExpenseCount();
    if (mounted) {
      setState(() => _pendingCount = count);
    }
  }

  String _getSetupGuide() {
    return '''
Bubble Budget — Google Sheets Setup Kit

1. Create a new Google Sheet.
2. Go to Extensions > Apps Script.
3. Delete any existing code and paste the script provided below.
4. Click 'Save' and 'Deploy' > 'New Deployment'.
5. Select 'Web App', set 'Who has access' to 'Anyone'.
6. Copy the Web App URL and paste it into the Bubble Budget app.

--- APPS SCRIPT CODE ---
$kAppsScriptCode
''';
  }

  Future<void> _emailSetupKit() async {
    final guide = _getSetupGuide();
    final subject = 'Bubble Budget — Google Sheets Setup Kit';
    
    String encodeQueryParam(String text) {
      return Uri.encodeComponent(text).replaceAll('+', '%20');
    }
    
    final Uri emailLaunchUri = Uri.parse(
      'mailto:?subject=${encodeQueryParam(subject)}&body=${encodeQueryParam(guide)}',
    );
    
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        final launched = await launchUrl(
          emailLaunchUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    } catch (_) {}

    // Fallback: copy setup instructions to clipboard
    await Clipboard.setData(ClipboardData(text: guide));
    _showSnackbar('Could not launch email app. Instructions copied to clipboard!');
  }

  Future<void> _copyScriptCode() async {
    await Clipboard.setData(const ClipboardData(text: kAppsScriptCode));
    _showSnackbar('Apps Script code copied to clipboard!');
  }

  Future<void> _shareSetupKit() async {
    final guide = _getSetupGuide();
    await Share.share(guide, subject: 'Bubble Budget Setup Kit');
  }



  Future<void> _verifyAndConnect() async {
    final rawUrl = _webhookController.text.trim();
    final tag = _tagController.text.trim();

    if (rawUrl.isEmpty) {
      _showSnackbar('Paste the connection link from Google to continue.', isError: true);
      return;
    }
    if (tag.isEmpty) {
      _showSnackbar('Give this connection a name so you can recognise it later.', isError: true);
      return;
    }

    var url = rawUrl;
    if (url.endsWith('/dev')) {
      url = '${url.substring(0, url.length - 4)}/exec';
    } else if (url.endsWith('/edit')) {
      url = '${url.substring(0, url.length - 5)}/exec';
    }

    setState(() => _isVerifying = true);
    final success = await _syncService.verifyAndConnect(url, tag);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (success) {
      final nowStr = DateTime.now().toLocal().toIso8601String();
      await _settings.saveConnection(
        url: url,
        tag: tag,
        lastVerifiedAt: nowStr,
      );
      await AudioService().playSuccess();
      _showSnackbar('Connection Verified & Connected!');
      setState(() {
        _isEditing = false;
        _webhookController.clear();
      });
      await _updatePendingCount();
    } else {
      // Almost every failure here is one of two things. Naming them beats
      // asking a non-technical user to go and diagnose "permissions".
      _showSnackbar(
        "Couldn't reach your sheet. Two things to check in Google:\n"
        "1. Deploy > Manage deployments > 'Who has access' must be set to 'Anyone'.\n"
        "2. Paste the deployment link ending in /exec - not your sheet's own web address.",
        isError: true,
        duration: const Duration(seconds: 12),
      );
    }
  }

  Future<void> _confirmDisconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Sheets?'),
        content: const Text(
          'Are you sure you want to disconnect? This will permanently erase your secure credentials from device storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _settings.disconnect();
      _webhookController.clear();
      _tagController.clear();
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        _showSnackbar('Disconnected successfully.', isError: false);
      }
    }
  }

  Future<void> _syncPending() async {
    setState(() => _isSyncing = true);
    await _syncService.syncAllPending();
    await _updatePendingCount();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    _showSnackbar('Sync complete!');
  }

  void _showSnackbar(String message, {bool isError = false, Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
        // Anything given a longer life is something the user has to read and
        // act on, so give them a way to dismiss it.
        showCloseIcon: duration != null,
      ),
    );
  }

  String _formatTimestamp(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (_) {
      return isoString;
    }
  }

  String _getMaskedUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('https://script.google.com/')) {
      return 'https://script.google.com/...${'•' * 8}';
    }
    if (url.length <= 25) {
      return '${url.substring(0, url.length ~/ 2)}...${'•' * 8}';
    }
    return '${url.substring(0, 25)}...${'•' * 8}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF4B5563);
    
    final bool isConnected = _settings.webhookUrl.isNotEmpty;
    final bool showSetup = !isConnected || _isEditing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sheets Sync'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isConnected) ...[
            _buildSection('1. Setup Kit', [
              _buildCard([
                Text(
                  'The Google side of this is much easier on a computer. Send yourself the kit, then finish it in your browser.',
                  style: TextStyle(color: textSecondary),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  icon: Icons.email_outlined,
                  label: 'Email the kit to myself',
                  onTap: _emailSetupKit,
                  primary: true,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'Send it another way',
                  onTap: _shareSetupKit,
                ),
                const SizedBox(height: 20),
                Text(
                  'OR SET IT UP FROM HERE',
                  style: TextStyle(
                    color: textSecondary.withAlpha(179),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.map_outlined,
                  label: 'View setup walkthrough',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const SheetSetupGuideDialog(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy script code',
                  onTap: _copyScriptCode,
                ),
              ]),
            ]),
            const SizedBox(height: 24),
          ],
          _buildSection('2. Configuration', [
            if (showSetup) ...[
              _buildCard([
                TextField(
                  controller: _tagController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Name this connection',
                    labelStyle: TextStyle(color: textSecondary),
                    helperText: 'Just a label, so you know which sheet this is. Your Google Sheet file name works well.',
                    helperStyle: TextStyle(color: textSecondary.withOpacity(0.7)),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _webhookController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Connection link from Google',
                    labelStyle: TextStyle(color: textSecondary),
                    hintText: 'https://script.google.com/macros/s/...',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Note: For security, your Web App URL will be masked after saving. If you need to reconnect or view the URL later, retrieve it from your Google Sheet (Deploy > Manage deployments).',
                  style: TextStyle(color: textSecondary.withOpacity(0.7), fontSize: 11),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isVerifying ? null : _verifyAndConnect,
                    icon: _isVerifying 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.flash_on),
                    label: Text(_isVerifying ? 'Verifying...' : 'Verify & Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _webhookController.clear();
                          _tagController.text = _settings.sheetTag.isEmpty ? _defaultSheetTag : _settings.sheetTag;
                        });
                      },
                      child: Text('Cancel', style: TextStyle(color: textSecondary)),
                    ),
                  ),
                ],
              ]),
            ] else ...[
              _buildCard([
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _settings.sheetTag.isNotEmpty ? _settings.sheetTag : 'Connected Sheet',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Webhook: ${_getMaskedUrl(_settings.webhookUrl)}',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                      ),
                      child: const Text(
                        'Connected',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_settings.webhookLastVerifiedAt.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last verified: ${_formatTimestamp(_settings.webhookLastVerifiedAt)}',
                    style: TextStyle(
                      color: textSecondary.withOpacity(0.6),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                            _tagController.text = _settings.sheetTag.isEmpty ? _defaultSheetTag : _settings.sheetTag;
                            _webhookController.clear();
                          });
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Update Webhook'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          side: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _confirmDisconnect,
                        icon: const Icon(Icons.power_settings_new_rounded, size: 16),
                        label: const Text('Disconnect'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ]),
            ],
          ]),
          const SizedBox(height: 24),
          _buildSection('3. Maintenance', [
            _buildCard([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('Pending Records', style: TextStyle(color: textPrimary)),
                        if (_syncService.isSyncingNotifier.value) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Syncing with Google Sheets...',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_pendingCount',
                    style: TextStyle(
                      color: _pendingCount > 0 ? Colors.orangeAccent : Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!isConnected || _isSyncing || _pendingCount == 0) ? null : _syncPending,
                  icon: _isSyncing 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync Pending Records'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE5E7EB),
                    disabledForegroundColor: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ),
              if (!isConnected) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Connect Google Sheets to enable syncing.',
                    style: TextStyle(color: textSecondary.withOpacity(0.5), fontSize: 12),
                  ),
                ),
              ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFE5E7EB)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF6B7280);

    // A tint rather than a filled button: this is the recommended route, but it
    // must not out-shout "Verify & Connect" further down the screen.
    final Color background = primary
        ? Colors.blueAccent.withAlpha(isDark ? 38 : 22)
        : (isDark ? Colors.white.withAlpha(5) : const Color(0xFFF9FAFB));
    final Color borderColor = primary
        ? Colors.blueAccent.withAlpha(isDark ? 90 : 70)
        : (isDark ? Colors.white.withAlpha(5) : const Color(0xFFF3F4F6));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: primary ? Colors.blueAccent : textSecondary, size: 20),
            const SizedBox(width: 12),
            // Expanded so a long label wraps instead of overflowing at large
            // Dynamic Type - these labels were previously unconstrained.
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (primary)
              const Icon(Icons.arrow_forward_rounded, color: Colors.blueAccent, size: 16),
          ],
        ),
      ),
    );
  }
}
