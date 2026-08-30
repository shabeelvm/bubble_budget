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
}
