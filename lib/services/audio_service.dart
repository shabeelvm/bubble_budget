import 'package:flutter/services.dart';
import 'settings_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final SettingsService _settings = SettingsService();

  factory AudioService() => _instance;

  AudioService._internal();

  void playTap() {
    if (!_settings.soundEnabled) return;
    SystemSound.play(SystemSoundType.click);
  }

  void playSuccess() {
    if (!_settings.soundEnabled) return;
    SystemSound.play(SystemSoundType.click);
  }

  void triggerHapticLight() {
    if (!_settings.hapticsEnabled) return;
    HapticFeedback.lightImpact();
  }

  void triggerHapticMedium() {
    if (!_settings.hapticsEnabled) return;
    HapticFeedback.mediumImpact();
  }

  void triggerHapticHeavy() {
    if (!_settings.hapticsEnabled) return;
    HapticFeedback.heavyImpact();
  }
}
