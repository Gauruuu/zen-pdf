import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    try {
      _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      _initialized = true;
    } catch (_) {}
  }

  /// Plays the completion sound effect & provides subtle haptic feedback
  static Future<void> playSuccess() async {
    try {
      // 1. Subtle Haptic Feedback
      HapticFeedback.mediumImpact();

      // 2. Play clean completion chime audio
      await _player.stop();
      await _player.play(AssetSource('sounds/success_chime.wav'), volume: 0.8);
    } catch (_) {
      // Fallback to system click if sound asset playback is unavailable
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }
}
