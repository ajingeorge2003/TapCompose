import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // Use a single player instance, as low-latency mode handles overlaps.
  final AudioPlayer _player = AudioPlayer();

  AudioService() {
    // Set the release mode to 'release' to free up resources after a sound plays.
    // This is crucial for performance in a drum machine.
    _player.setReleaseMode(ReleaseMode.release);
  }

  /// Pre-loads a list of audio files into the cache for instant playback.
  Future<void> loadSounds(List<String> soundAssets) async {
    try {
      // **FIX**: Removed 'const' from AudioContext and its children, and corrected the AndroidAudioFocus enum.
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      ));
    } catch (e) {
      print("Error setting audio context: $e");
    }
  }

  /// Plays a sound from the provided asset path.
  Future<void> playSound(String assetPath) async {
    try {
      // Set the source and play. The low-latency mode is handled by the
      // global audio context configuration.
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  /// Releases all resources associated with the audio player.
  void dispose() {
    _player.dispose();
  }
}
