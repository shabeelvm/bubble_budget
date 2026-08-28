import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/export_service.dart';
import 'google_sheets_sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
              title: const Text('Sync with Google Sheets', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Connect your automated spreadsheet', style: TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoogleSheetsSyncScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined, color: Colors.white70),
              title: const Text('Export All Data (CSV)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Save or share a CSV of all transactions', style: TextStyle(color: Colors.white54)),
              onTap: () => ExportService().exportToCsv(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Preferences', [
            _buildDropdownTile('Currency Symbol', _settings.currencySymbol, ['\$', '€', '£', '₹', '¥', 'A\$'], (val) {
              setState(() => _settings.currencySymbol = val!);
            }),
            SwitchListTile(
              title: const Text('Sound Effects', style: TextStyle(color: Colors.white)),
              value: _settings.soundEnabled,
              onChanged: (val) => setState(() => _settings.soundEnabled = val),
              activeThumbColor: Colors.blueAccent,
            ),
            SwitchListTile(
              title: const Text('Haptic Feedback', style: TextStyle(color: Colors.white)),
              value: _settings.hapticsEnabled,
              onChanged: (val) => setState(() => _settings.hapticsEnabled = val),
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
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF1A1A1A),
        style: const TextStyle(color: Colors.white),
        items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
        underline: Container(),
      ),
    );
  }
}
