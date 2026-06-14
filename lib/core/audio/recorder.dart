import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart';

class MicPermissionDeniedException implements Exception {
  const MicPermissionDeniedException();
  @override
  String toString() => '마이크 권한이 거부되었습니다.';
}

/// Thin wrapper around `record` that:
/// - Ensures mic permission.
/// - Records to AAC m4a (Clova CSR accepts m4a).
/// - Returns the saved file path.
class VoiceRecorder {
  VoiceRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentPath;

  Future<bool> ensurePermission() async {
    final status = await ph.Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<String> start() async {
    final granted = await ensurePermission();
    if (!granted) throw const MicPermissionDeniedException();

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/voiceup_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _currentPath = path;
    return path;
  }

  Future<File?> stop() async {
    final path = await _recorder.stop();
    final saved = path ?? _currentPath;
    _currentPath = null;
    if (saved == null) return null;
    return File(saved);
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _currentPath = null;
  }

  /// Polls amplitude on each call. Yields a fresh async generator so it
  /// can be re-listened across multiple recording sessions (the underlying
  /// `record` package's `onAmplitudeChanged` returns a single-subscription
  /// stream that errors on re-listen).
  Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 200),
  }) async* {
    while (true) {
      if (!await _recorder.isRecording()) break;
      yield await _recorder.getAmplitude();
      await Future.delayed(interval);
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
