import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  late SharedPreferences _prefs;
  bool _initialized = false;

  factory SettingsService() => _instance;

  SettingsService._internal();

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  String get sheetsWebhookUrl => _prefs.getString('sheetsWebhookUrl') ?? '';
  set sheetsWebhookUrl(String value) => _prefs.setString('sheetsWebhookUrl', value);

  String get currencySymbol => _prefs.getString('currencySymbol') ?? '\$';
  set currencySymbol(String value) => _prefs.setString('currencySymbol', value);

  bool get soundEnabled => _prefs.getBool('soundEnabled') ?? true;
  set soundEnabled(bool value) => _prefs.setBool('soundEnabled', value);

  bool get hapticsEnabled => _prefs.getBool('hapticsEnabled') ?? true;
  set hapticsEnabled(bool value) => _prefs.setBool('hapticsEnabled', value);
}
