import 'dart:math';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  final SettingsService _settings = SettingsService();
  late final String _sessionUuid;

  factory AnalyticsService() => _instance;

  AnalyticsService._internal() {
    _sessionUuid = _generateV4UUID();
  }

  String _generateV4UUID() {
    try {
      final Random random = Random.secure();
      final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 0x0F) | 0x40;
      bytes[8] = (bytes[8] & 0x3F) | 0x80;
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < 16; i++) {
        if (i == 4 || i == 6 || i == 8 || i == 10) {
          buffer.write('-');
        }
        buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      }
      return buffer.toString();
    } catch (_) {
      final Random random = Random();
      final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 0x0F) | 0x40;
      bytes[8] = (bytes[8] & 0x3F) | 0x80;
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < 16; i++) {
        if (i == 4 || i == 6 || i == 8 || i == 10) {
          buffer.write('-');
        }
        buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      }
      return buffer.toString();
    }
  }

  bool get isTelemetryEnabled => false;

  void logEvent(String eventName, {Map<String, dynamic>? properties}) {
    if (!isTelemetryEnabled) {
      // Dormant/Parked: Zero telemetry event logging occurs.
      return;
    }

    if (!_settings.shareAnalytics) {
      debugPrint('[Analytics] Dropping event "$eventName" (analytics disabled)');
      return;
    }

    final cleanProperties = <String, dynamic>{};
    if (properties != null) {
      properties.forEach((key, value) {
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('amount') ||
            lowerKey.contains('note') ||
            lowerKey.contains('user') ||
            lowerKey.contains('email') ||
            lowerKey.contains('id') ||
            lowerKey.contains('payload') ||
            lowerKey.contains('url') ||
            lowerKey.contains('webhook')) {
          // Strict PII protection filter: drop sensitive financial details
          return;
        }
        cleanProperties[key] = value;
      });
    }

    final payload = {
      'event': eventName,
      'session_uuid': _sessionUuid,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': {
        'platform': defaultTargetPlatform.name,
        'app_version': '1.0.0',
      },
      'properties': cleanProperties,
    };

    debugPrint('[Analytics] Logged Event: $payload');
  }
}
