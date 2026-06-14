import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

/// Controls the floating "call assist" overlay shown on top of other apps.
///
/// Usage during a call: enable speakerphone, then [launch] the overlay and
/// switch to the phone app. The overlay's loud playback is picked up by the
/// call microphone and heard by the other party.
class CallAssist {
  const CallAssist._();

  static Future<bool> isPermissionGranted() =>
      FlutterOverlayWindow.isPermissionGranted();

  static Future<bool?> requestPermission() =>
      FlutterOverlayWindow.requestPermission();

  static Future<bool> isActive() => FlutterOverlayWindow.isActive();

  static Future<void> close() => FlutterOverlayWindow.closeOverlay();

  /// Ensures permissions, then shows the overlay. Returns a result describing
  /// what the caller should tell the user.
  static Future<CallAssistResult> launch() async {
    // The mic FGS type requires RECORD_AUDIO to be granted before the overlay
    // service starts; phrases still work without it, but ask up front.
    await Permission.microphone.request();

    if (!await isPermissionGranted()) {
      final granted = await requestPermission();
      if (granted != true) return CallAssistResult.permissionDenied;
    }

    if (await isActive()) return CallAssistResult.alreadyActive;

    // Small square window just big enough for the round button. Drag is off
    // so a press-and-hold records instead of being swallowed as a drag.
    await FlutterOverlayWindow.showOverlay(
      height: 320,
      width: 320,
      alignment: OverlayAlignment.centerRight,
      flag: OverlayFlag.defaultFlag,
      enableDrag: false,
      positionGravity: PositionGravity.none,
      overlayTitle: 'VoiceUp 통화 보조',
      overlayContent: '통화 중 큰 소리로 재생할 수 있어요',
    );
    return CallAssistResult.launched;
  }
}

enum CallAssistResult { launched, alreadyActive, permissionDenied }
