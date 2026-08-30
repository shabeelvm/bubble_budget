import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'db_service.dart';
import 'settings_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  final DBService _dbService = DBService();
  final SettingsService _settings = SettingsService();

  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> syncCompletedNotifier = ValueNotifier<int>(0);

  void notifySyncCompleted() {
    syncCompletedNotifier.value++;
  }

  factory SyncService() => _instance;

  SyncService._internal();

  Future<http.Response> _postWithRedirects(Uri uri, String body) async {
    debugPrint('POST Redirect Flow: Starting request to $uri');
    final client = http.Client();
    var currentUri = uri;
    var request = http.Request('POST', currentUri)
      ..headers['Content-Type'] = 'application/json'
      ..body = body
      ..followRedirects = false;

    var streamedResponse = await client.send(request);
    var response = await http.Response.fromStream(streamedResponse);

    debugPrint('POST Initial Status: ${response.statusCode}');

    int redirectCount = 0;
    while ((response.statusCode == 301 ||
            response.statusCode == 302 ||
            response.statusCode == 303 ||
            response.statusCode == 307 ||
            response.statusCode == 308) &&
        redirectCount < 5) {
      final location = response.headers['location'];
      if (location == null || location.isEmpty) {
        debugPrint('POST Redirect Flow: Redirect response missing Location header.');
        break;
      }

      currentUri = currentUri.resolve(location);
      debugPrint('POST Redirect Flow: Following redirect #$redirectCount to $currentUri');

      final isGetRedirect = response.statusCode == 301 || 
                            response.statusCode == 302 || 
                            response.statusCode == 303;
      final nextMethod = isGetRedirect ? 'GET' : 'POST';

      request = http.Request(nextMethod, currentUri)
        ..followRedirects = false;

      if (!isGetRedirect) {
        request.headers['Content-Type'] = 'application/json';
        request.body = body;
      }

      streamedResponse = await client.send(request);
      response = await http.Response.fromStream(streamedResponse);
      debugPrint('POST Redirect Status: ${response.statusCode}');
      redirectCount++;
    }
    client.close();
    return response;
  }

  Future<void> syncAllPending() async {
    final url = _settings.sheetsWebhookUrl;
    if (url.isEmpty) return;

    isSyncingNotifier.value = true;
    try {
      final unsynced = await _dbService.getUnsyncedExpenses();
      for (final expense in unsynced) {
        await syncExpense(expense);
      }
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  Future<bool> syncExpense(Map<String, dynamic> expense) async {
    final url = _settings.sheetsWebhookUrl;
    if (url.isEmpty) return false;

    // Prevent double-syncing if already synced
    final id = expense['id'];
    if (id != null) {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> res = await db.query(
        'expenses',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (res.isNotEmpty && res.first['is_synced'] == 1) {
        debugPrint('syncExpense: Expense $id is already marked as synced. Skipping...');
        return true;
      }
    }

    isSyncingNotifier.value = true;
    try {
      final response = await _postWithRedirects(
        Uri.parse(url),
        jsonEncode({
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
        if (id != null) {
          await _dbService.markExpenseAsSynced(id);
        }
        notifySyncCompleted();
        return true;
      }
    } catch (e) {
      // Sync failed (offline or invalid URL)
      debugPrint('syncExpense Error: $e');
    } finally {
      isSyncingNotifier.value = false;
    }
    return false;
  }

  Future<bool> testWebhook(String url) async {
    if (url.isEmpty) return false;
    try {
      final response = await _postWithRedirects(
        Uri.parse(url),
        jsonEncode({'type': 'ping'}),
      );
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      return false;
    }
  }

  // Mandatory Verification Contract ("Verify & Connect")
  Future<bool> verifyAndConnect(String url, String sheetTag) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || sheetTag.isEmpty) return false;

    // Auto-correct URL if it ends with /dev or /edit instead of /exec
    var correctedUrl = trimmedUrl;
    if (correctedUrl.endsWith('/dev')) {
      correctedUrl = '${correctedUrl.substring(0, correctedUrl.length - 4)}/exec';
    } else if (correctedUrl.endsWith('/edit')) {
      correctedUrl = '${correctedUrl.substring(0, correctedUrl.length - 5)}/exec';
    }

    final uri = Uri.parse(correctedUrl);

    // 1. Attempt GET first (cleanly follows redirects natively for GET)
    try {
      debugPrint('GET Verification: Attempting GET request to $uri');
      final getResponse = await http.get(uri).timeout(const Duration(seconds: 15));
      debugPrint('GET Response Code: ${getResponse.statusCode}');
      debugPrint('GET Response Body: ${getResponse.body}');

      if (getResponse.statusCode == 200) {
        final bodyJson = jsonDecode(getResponse.body);
        if (bodyJson is Map && bodyJson['status'] == 'success') {
          debugPrint('GET Verification Succeeded!');
          return true;
        }
      }
    } catch (e) {
      debugPrint('GET Verification failed with error: $e. Falling back to POST...');
    }

    // 2. Fallback: Attempt POST verification with manual redirects
    try {
      debugPrint('POST Verification: Attempting POST request to $uri');
      final payload = jsonEncode({
        'action': 'ping',
        'client': 'bubble_budget',
        'version': '1.0.0',
        'sheetTag': sheetTag,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      final postResponse = await _postWithRedirects(uri, payload).timeout(const Duration(seconds: 15));
      debugPrint('POST Response Code: ${postResponse.statusCode}');
      debugPrint('POST Response Body: ${postResponse.body}');

      if (postResponse.statusCode == 200) {
        final bodyJson = jsonDecode(postResponse.body);
        if (bodyJson is Map && bodyJson['status'] == 'success') {
          debugPrint('POST Verification Succeeded!');
          return true;
        }
      }
    } catch (e) {
      debugPrint('POST Verification failed with error: $e.');
    }

    return false;
  }
}