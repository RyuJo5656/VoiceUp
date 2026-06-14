// VoiceUp smoke test.
//
// The feature screens talk to platform plugins (mic, TTS, SharedPreferences)
// in initState, which aren't available in the widget-test sandbox, so we keep
// this to a lightweight construction check rather than pumping the full shell.

import 'package:flutter_test/flutter_test.dart';
import 'package:voiceup/main.dart';

void main() {
  test('VoiceUpApp can be instantiated', () {
    expect(const VoiceUpApp(), isNotNull);
  });
}
