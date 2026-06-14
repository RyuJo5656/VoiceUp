import 'package:audioplayers/audioplayers.dart';

/// Plays audio at maximum volume through the loudspeaker.
/// Used both for the Amplifier mode (raw recording playback) and for
/// playing TTS output.
class LoudPlayer {
  LoudPlayer() : _player = AudioPlayer() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  final AudioPlayer _player;

  Future<void> playFile(String path, {double volume = 1.0}) async {
    await _player.stop();
    await _player.setVolume(volume.clamp(0.0, 1.0));
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stop() => _player.stop();

  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  Future<void> dispose() => _player.dispose();
}
