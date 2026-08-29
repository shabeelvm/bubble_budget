import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final SettingsService _settings = SettingsService();
  final AudioPlayer _player = AudioPlayer();
  final List<AudioPlayer> _chimePool = List.generate(3, (_) => AudioPlayer());
  
  int _chimeIndex = 0;
  DateTime _lastChimeTime = DateTime.fromMillisecondsSinceEpoch(0);

  factory AudioService() => _instance;

  AudioService._internal() {
    _initPlayer();
  }

  void _initPlayer() {
    try {
      final context = AudioContextConfig(
        respectSilence: false,
        focus: AudioContextConfigFocus.duckOthers,
      ).build();
      _player.setAudioContext(context);
      for (final p in _chimePool) {
        p.setAudioContext(context);
      }
    } catch (_) {}
  }

  Future<void> playTap() async {
    if (!_settings.soundEnabled) {
      triggerHapticLight();
      return;
    }
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/touch.wav'));
    } catch (_) {
      triggerHapticLight();
    }
  }

  Future<void> playSuccess() async {
    if (!_settings.soundEnabled) {
      triggerHapticHeavy();
      return;
    }
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/submit.wav'));
    } catch (_) {
      triggerHapticHeavy();
    }
  }

  Future<void> playChime({double volume = 0.2}) async {
    if (!_settings.soundEnabled) return;

    final now = DateTime.now();
    if (now.difference(_lastChimeTime).inMilliseconds < 40) {
      // Microscopic throttle of ~40ms to ignore micro-jitters of the physics loop
      return;
    }
    _lastChimeTime = now;

    try {
      final player = _chimePool[_chimeIndex];
      _chimeIndex = (_chimeIndex + 1) % _chimePool.length;

      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('audio/chime.wav'));
    } catch (_) {}
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
