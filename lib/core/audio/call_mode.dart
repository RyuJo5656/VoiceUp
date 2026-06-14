import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum CallMode {
  off('off', '꺼짐', '일반 사용'),
  private('private', '혼자', '집·차 안. 스피커폰 ON'),
  public('public', '공공', '카페·사무실. 통화는 이어폰/BT, TTS만 폰 스피커');

  const CallMode(this.id, this.label, this.hint);
  final String id;
  final String label;
  final String hint;
}

/// Global call-mode state. Screens listen via [notifier] and set via [set].
class CallModeController {
  CallModeController._();
  static final CallModeController instance = CallModeController._();

  static const _channel = MethodChannel('voiceup/audio_route');

  final ValueNotifier<CallMode> notifier = ValueNotifier(CallMode.off);

  Future<void> set(CallMode mode) async {
    notifier.value = mode;
    try {
      await _channel.invokeMethod('setCallMode', {'mode': mode.id});
    } on PlatformException catch (e) {
      debugPrint('[call-mode] platform error: $e');
    }
  }
}
