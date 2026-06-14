import 'package:speech_to_text/speech_to_text.dart';

class SystemSttException implements Exception {
  SystemSttException(this.message);
  final String message;
  @override
  String toString() => 'SystemSttException: $message';
}

/// Streaming STT via Android `SpeechRecognizer` (free, system-provided).
///
/// Notes for Korean:
/// - Locale id must be 'ko_KR'.
/// - Quality varies by the installed recognition service. Modern devices
///   ship Google Speech which handles Korean well, but soft / breathy voices
///   may be dropped — that's why Clova remains the upgrade path.
class SystemSttService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  Future<bool> _ensureInit() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onError: (e) {
        // Surface to console; UI is already in stop state.
        // ignore: avoid_print
        print('[stt] error: ${e.errorMsg}');
      },
    );
    return _initialized;
  }

  /// Starts listening. The [onPartial] callback fires with intermediate
  /// recognition while speaking; [onFinal] fires once recognition completes.
  Future<void> start({
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
  }) async {
    final ok = await _ensureInit();
    if (!ok) {
      throw SystemSttException(
        '시스템 음성 인식을 사용할 수 없습니다. 기기 설정에서 Google 음성 서비스를 확인하세요.',
      );
    }
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'ko_KR',
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (result) {
        if (result.finalResult) {
          onFinal(result.recognizedWords);
        } else {
          onPartial(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stop() => _stt.stop();
  Future<void> cancel() => _stt.cancel();

  bool get isListening => _stt.isListening;
}
