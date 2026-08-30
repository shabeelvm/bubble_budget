import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bubble_provider.dart';
import '../services/settings_service.dart';
import '../services/export_service.dart';
import '../services/analytics_service.dart';
import 'google_sheets_sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Soft Light';
      case ThemeMode.dark:
      default:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleProvider = Provider.of<BubbleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Cloud Sync & Backup', [
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined, color: Colors.blueAccent),
              title: const Text('Sync with Google Sheets'),
              subtitle: const Text('Connect your automated spreadsheet'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoogleSheetsSyncScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Export All Data (CSV)'),
              subtitle: const Text('Save or share a CSV of all transactions'),
              onTap: () => ExportService().exportToCsv(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Preferences', [
            _buildDropdownTile('Currency Symbol', _settings.currencySymbol, ['\$', '€', '£', '₹', '¥', 'A\$'], (val) {
              setState(() => _settings.currencySymbol = val!);
            }),
            _buildDropdownTile('App Theme', _getThemeLabel(bubbleProvider.themeMode), ['Dark', 'Soft Light'], (val) {
              if (val == 'Dark') {
                bubbleProvider.setThemeMode(ThemeMode.dark);
              } else if (val == 'Soft Light') {
                bubbleProvider.setThemeMode(ThemeMode.light);
              }
            }),
            SwitchListTile(
              title: const Text('Sound Effects'),
              value: _settings.soundEnabled,
              onChanged: (val) => setState(() => _settings.soundEnabled = val),
              activeThumbColor: Colors.blueAccent,
            ),
            SwitchListTile(
              title: const Text('Haptic Feedback'),
              value: _settings.hapticsEnabled,
              onChanged: (val) => setState(() => _settings.hapticsEnabled = val),
              activeThumbColor: Colors.blueAccent,
            ),
            SwitchListTile(
              title: const Text('Show Total Budget Header'),
              subtitle: const Text('Display total monthly budget progress at the top'),
              value: _settings.showTotalBudgetHeader,
              onChanged: (val) => setState(() => _settings.setShowTotalBudgetHeader(val)),
              activeThumbColor: Colors.blueAccent,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Data & Privacy', [
            SwitchListTile(
              title: const Text('Share Anonymous Analytics'),
              subtitle: const Text('Help us improve the app by sharing anonymous usage telemetry'),
              value: _settings.shareAnalytics,
              onChanged: (val) {
                setState(() => _settings.shareAnalytics = val);
                AnalyticsService().logEvent('settings_analytics_toggled', properties: {
                  'enabled': val,
                });
              },
              activeThumbColor: Colors.blueAccent,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildDropdownTile(String title, String value, List<String> options, ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16),
        items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
        underline: Container(),
      ),
    );
  }
}
