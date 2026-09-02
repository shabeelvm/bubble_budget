import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  late SharedPreferences _prefs;
  bool _initialized = false;

  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  String _webhookUrl = '';
  String _sheetTag = '';
  String _webhookLastVerifiedAt = '';

  factory SettingsService() => _instance;

  SettingsService._internal();

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    // Migration and cleanup of legacy plaintext webhook URL
    if (_prefs.containsKey('sheetsWebhookUrl')) {
      final legacyUrl = _prefs.getString('sheetsWebhookUrl') ?? '';
      if (legacyUrl.isNotEmpty) {
        _webhookUrl = legacyUrl;
        await _safeWrite('webhook_url', legacyUrl);
      }
      await _prefs.remove('sheetsWebhookUrl');
    } else {
      _webhookUrl = await _safeRead('webhook_url');
    }

    _sheetTag = await _safeRead('sheet_tag');
    _webhookLastVerifiedAt = await _safeRead('webhook_last_verified_at');

    _initialized = true;
  }

  // Getters for webhook configuration
  String get sheetsWebhookUrl => _webhookUrl;
  String get webhookUrl => _webhookUrl;
  String get sheetTag => _sheetTag;
  String get webhookLastVerifiedAt => _webhookLastVerifiedAt;

  // Save full connection credentials securely
  Future<void> saveConnection({
    required String url,
    required String tag,
    required String lastVerifiedAt,
  }) async {
    _webhookUrl = url;
    _sheetTag = tag;
    _webhookLastVerifiedAt = lastVerifiedAt;
    await _safeWrite('webhook_url', url);
    await _safeWrite('sheet_tag', tag);
    await _safeWrite('webhook_last_verified_at', lastVerifiedAt);
  }

  // Clear/wipe stored connection credentials from storage
  Future<void> disconnect() async {
    _webhookUrl = '';
    _sheetTag = '';
    _webhookLastVerifiedAt = '';
    await _safeDelete('webhook_url');
    await _safeDelete('sheet_tag');
    await _safeDelete('webhook_last_verified_at');
  }

  bool get _isTestEnv {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  // Helper safe read from FlutterSecureStorage
  Future<String> _safeRead(String key) async {
    if (_isTestEnv) return '';
    try {
      return await _secureStorage.read(key: key) ?? '';
    } catch (_) {
      return '';
    }
  }

  // Helper safe write to FlutterSecureStorage
  Future<void> _safeWrite(String key, String value) async {
    if (_isTestEnv) return;
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
  }

  // Helper safe delete from FlutterSecureStorage
  Future<void> _safeDelete(String key) async {
    if (_isTestEnv) return;
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }

  // Existing plaintext configurations (SharedPreferences)
  String get currencySymbol => _prefs.getString('currencySymbol') ?? '\$';
  set currencySymbol(String value) => _prefs.setString('currencySymbol', value);

  bool get soundEnabled => _prefs.getBool('soundEnabled') ?? true;
  set soundEnabled(bool value) => _prefs.setBool('soundEnabled', value);

  bool get hapticsEnabled => _prefs.getBool('hapticsEnabled') ?? true;
  set hapticsEnabled(bool value) => _prefs.setBool('hapticsEnabled', value);

  bool get showTotalBudgetHeader => _prefs.getBool('showTotalBudgetHeader') ?? false;
  set showTotalBudgetHeader(bool value) => _prefs.setBool('showTotalBudgetHeader', value);

  void setShowTotalBudgetHeader(bool value) {
    showTotalBudgetHeader = value;
  }

  bool get hasAcceptedPrivacy => _prefs.getBool('has_accepted_privacy') ?? false;
  set hasAcceptedPrivacy(bool value) => _prefs.setBool('has_accepted_privacy', value);

  bool get hasSeenWelcome => _prefs.getBool('has_seen_welcome') ?? false;
  set hasSeenWelcome(bool value) => _prefs.setBool('has_seen_welcome', value);

  String get themeModeStr => _prefs.getString('themeMode') ?? 'dark';
  set themeModeStr(String value) => _prefs.setString('themeMode', value);
}
