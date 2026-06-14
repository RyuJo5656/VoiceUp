import 'package:flutter/services.dart';

/// Controls the native accessibility floating mic button used during calls.
///
/// Because it is rendered as a TYPE_ACCESSIBILITY_OVERLAY by
/// [VoiceUpAccessibilityService], it keeps receiving touches even over the
/// phone's in-call screen — unlike a normal app overlay.
class CallAssist {
  const CallAssist._();

  static const _channel = MethodChannel('voiceup/call_button');

  /// Whether the user has enabled the VoiceUp accessibility service.
  static Future<bool> isAccessibilityEnabled() async =>
      await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  /// Opens the system Accessibility settings so the user can enable VoiceUp.
  static Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  /// Shows/hides the floating button. Returns `true` if applied immediately,
  /// or `false` if the accessibility service isn't running yet (the intent is
  /// remembered and applied once the user enables it).
  static Future<bool> setButton(bool show) async =>
      await _channel.invokeMethod<bool>('setCallButton', {'show': show}) ??
      false;

  /// Playback boost applied to the recorded voice, in millibels (100 mB = 1 dB).
  static const int defaultGainMb = 2500;
  static const int maxGainMb = 3500;

  static Future<int> getPlaybackGain() async =>
      await _channel.invokeMethod<int>('getPlaybackGain') ?? defaultGainMb;

  static Future<void> setPlaybackGain(int gainMb) =>
      _channel.invokeMethod('setPlaybackGain', {'gainMb': gainMb});
}
