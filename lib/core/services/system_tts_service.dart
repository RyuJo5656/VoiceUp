import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// System TTS via `flutter_tts` (free).
///
/// On Android this uses the device's TTS engine (Google TTS, Samsung TTS).
/// Picks a Korean MALE voice if available; falls back to lowering pitch.
class SystemTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    // Critical: makes `_tts.speak()` resolve on completion.
    await _tts.awaitSpeakCompletion(true);
    final pickedMale = await _selectKoreanMaleVoice();
    // If no male voice is available, simulate lower-pitched voice.
    await _tts.setPitch(pickedMale ? 1.0 : 0.7);
    _configured = true;
  }

  /// Tries to select a Korean male voice from the system TTS engine.
  /// Returns true if a male-tagged voice was successfully set.
  Future<bool> _selectKoreanMaleVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return false;

      final korean = voices
          .whereType<Map>()
          .where((v) =>
              (v['locale']?.toString().toLowerCase() ?? '').startsWith('ko'))
          .toList();

      if (kDebugMode) debugPrint('[tts] korean voices: $korean');

      Map? hit = korean.firstWhere(
        (v) {
          final hay = v.values.join(' ').toLowerCase();
          return hay.contains('male') && !hay.contains('female');
        },
        orElse: () => const {},
      );
      if (hit.isEmpty) hit = null;

      hit ??= () {
        final patterns = ['ko-kr-x-kob', 'ko-kr-x-kod'];
        for (final p in patterns) {
          final found = korean.firstWhere(
            (v) =>
                (v['name']?.toString().toLowerCase() ?? '').contains(p),
            orElse: () => const {},
          );
          if (found.isNotEmpty) return found;
        }
        return null;
      }();

      if (hit == null) return false;

      await _tts.setVoice({
        'name': hit['name'].toString(),
        'locale': hit['locale'].toString(),
      });
      if (kDebugMode) debugPrint('[tts] selected male voice: $hit');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[tts] voice selection failed: $e');
      return false;
    }
  }

  /// Speaks [text] and resolves when playback finishes.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _configure();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
