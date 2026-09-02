import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubble_budget/services/settings_service.dart';
import 'package:bubble_budget/services/sync_service.dart';
import 'package:bubble_budget/services/db_service.dart';
import 'package:bubble_budget/providers/bubble_provider.dart';

class MockDBService implements DBService {
  @override
  Future<List<Map<String, dynamic>>> getCategoriesWithMonthlySpend(DateTime month) async => [];

  @override
  Future<int> getExpenseCount() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
    // Start clean for each test
    await SettingsService().disconnect();
  });

  group('SettingsService - Secure Vaulting', () {
    test('initial state should be empty', () {
      final settings = SettingsService();
      expect(settings.webhookUrl, isEmpty);
      expect(settings.sheetTag, isEmpty);
      expect(settings.webhookLastVerifiedAt, isEmpty);
    });

    test('saveConnection securely persists parameters in memory', () async {
      final settings = SettingsService();
      const testUrl = 'https://script.google.com/macros/s/12345/exec';
      const testTag = 'Bubble Budget 2026 Test';
      final testTime = '2026-08-29T12:00:00Z';

      await settings.saveConnection(
        url: testUrl,
        tag: testTag,
        lastVerifiedAt: testTime,
      );

      expect(settings.webhookUrl, testUrl);
      expect(settings.sheetsWebhookUrl, testUrl);
      expect(settings.sheetTag, testTag);
      expect(settings.webhookLastVerifiedAt, testTime);
    });

    test('disconnect clears connection parameters', () async {
      final settings = SettingsService();
      await settings.saveConnection(
        url: 'https://test.url',
        tag: 'My Sheet',
        lastVerifiedAt: '2026-08-29',
      );

      expect(settings.webhookUrl, 'https://test.url');

      await settings.disconnect();

      expect(settings.webhookUrl, isEmpty);
      expect(settings.sheetTag, isEmpty);
      expect(settings.webhookLastVerifiedAt, isEmpty);
    });
  });

  group('SyncService - Verification Contract', () {
    test('verifyAndConnect returns false on empty URL or Sheet Tag', () async {
      final syncService = SyncService();
      final success = await syncService.verifyAndConnect('', 'My Tag');
      expect(success, isFalse);

      final success2 = await syncService.verifyAndConnect('https://test.url', '');
      expect(success2, isFalse);
    });
  });

  group('Theme Configurations & State Persistence', () {
    test('default themeModeStr should be dark and default themeMode should be ThemeMode.dark', () {
      final settings = SettingsService();
      expect(settings.themeModeStr, 'dark');

      final provider = BubbleProvider(dbService: MockDBService());
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('setting themeModeStr updates value and provider notifies updates', () {
      final settings = SettingsService();
      final provider = BubbleProvider(dbService: MockDBService());

      provider.setThemeMode(ThemeMode.light);
      expect(settings.themeModeStr, 'light');
      expect(provider.themeMode, ThemeMode.light);

      provider.setThemeMode(ThemeMode.dark);
      expect(settings.themeModeStr, 'dark');
      expect(provider.themeMode, ThemeMode.dark);
    });
  });

  group('SyncService - Synchronization Lifecycles', () {
    test('Successful sync flags the expense as synced and pending count drops to 0', () async {
      // Set up a mock settings connection
      final settings = SettingsService();
      await settings.saveConnection(
        url: 'https://script.google.com/macros/s/123/exec',
        tag: 'Test Tag',
        lastVerifiedAt: '2026-08-30',
      );

      // Create a test db and insert an unsynced expense
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dbService = DBService(customPath: inMemoryDatabasePath);
      final db = await dbService.database;
      await db.delete('expenses');
      await db.delete('categories');
      await dbService.insertCategory('cat1', 'Groceries', 100.0, 'FFFFFFFF');

      final expenseId = await dbService.insertExpense('cat1', 10.0);
      
      // Before sync, pending count is 1
      var count = await dbService.getUnsyncedExpenseCount();
      expect(count, 1);

      // Setup global HTTP mock overrides so the sync POST request succeeds
      HttpOverrides.global = _MockHttpOverrides();

      final syncService = SyncService();
      final success = await syncService.syncExpense({
        'id': expenseId,
        'category_name': 'Groceries',
        'amount': 10.0,
        'note': '',
        'timestamp': DateTime.now().toIso8601String(),
      });

      expect(success, isTrue);

      // After successful sync, is_synced should be 1
      final expenses = await dbService.getExpenses();
      expect(expenses.first['is_synced'], 1);

      // Unsynced count should drop to 0
      count = await dbService.getUnsyncedExpenseCount();
      expect(count, 0);

      // Re-triggering syncExpense on already synced expense skips or does not re-send
      final success2 = await syncService.syncExpense({
        'id': expenseId,
        'category_name': 'Groceries',
        'amount': 10.0,
        'note': '',
        'timestamp': DateTime.now().toIso8601String(),
      });
      expect(success2, isTrue);

      // Clean up global HTTP overrides
      HttpOverrides.global = null;
      await dbService.close();
    });
  });
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  void write(Object? object) {}

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => -1;

  @override
  bool get persistentConnection => false;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final data = utf8.encode('{"status": "success", "message": "pong"}');
    return Stream<List<int>>.fromIterable([data]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  String? value(String name) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
