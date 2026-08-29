import 'dart:convert';
import 'package:http/http.dart' as http;
import 'db_service.dart';
import 'settings_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  final DBService _dbService = DBService();
  final SettingsService _settings = SettingsService();

  factory SyncService() => _instance;

  SyncService._internal();

  Future<void> syncAllPending() async {
    final url = _settings.sheetsWebhookUrl;
    if (url.isEmpty) return;

    final unsynced = await _dbService.getUnsyncedExpenses();
    for (final expense in unsynced) {
      await syncExpense(expense);
    }
  }

  Future<bool> syncExpense(Map<String, dynamic> expense) async {
    final url = _settings.sheetsWebhookUrl;
    if (url.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': expense['id'],
          'category': expense['category_name'],
          'amount': expense['amount'],
          'note': expense['note'],
          'timestamp': expense['timestamp'],
          'currency': _settings.currencySymbol,
          'type': 'expense',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 400) {
        await _dbService.markExpenseAsSynced(expense['id']);
        return true;
      }
    } catch (e) {
      // Sync failed (offline or invalid URL)
    }
    return false;
  }

  Future<bool> testWebhook(String url) async {
    if (url.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'ping'}),
      );
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      return false;
    }
  }

  // Mandatory Verification Contract ("Verify & Connect")
  Future<bool> verifyAndConnect(String url, String sheetTag) async {
    if (url.isEmpty || sheetTag.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'ping',
          'client': 'bubble_budget',
          'version': '1.0.0',
          'sheetTag': sheetTag,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final bodyJson = jsonDecode(response.body);
        if (bodyJson is Map &&
            bodyJson['status'] == 'success' &&
            bodyJson['message'] == 'pong') {
          return true;
        }
      }
    } catch (_) {
      // Zero plaintext logging of the webhook URL
    }
    return false;
  }
}
