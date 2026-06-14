import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../core/audio/player.dart';
import '../core/audio/recorder.dart';

/// A single round floating microphone button rendered on top of other apps
/// (e.g. the phone's call screen). Press and hold to record, release to play
/// the recording back loudly — on speakerphone the call mic picks it up and
/// the other party hears the amplified voice.
///
/// Runs in its own Flutter engine via `flutter_overlay_window`.
class CallOverlayApp extends StatelessWidget {
  const CallOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CallMicButton()),
      ),
    );
  }
}

enum _MicState { idle, recording, playing }

class CallMicButton extends StatefulWidget {
  const CallMicButton({super.key});

  @override
  State<CallMicButton> createState() => _CallMicButtonState();
}

class _CallMicButtonState extends State<CallMicButton> {
  final _recorder = VoiceRecorder();
  final _player = LoudPlayer();

  _MicState _state = _MicState.idle;

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_state != _MicState.idle) return;
    // Flip to recording synchronously so a quick release always stops it.
    setState(() => _state = _MicState.recording);
    try {
      await _recorder.start();
    } catch (_) {
      // Mic unavailable (e.g. permission denied or busy during a call).
      if (mounted) setState(() => _state = _MicState.idle);
    }
  }

  Future<void> _stopAndPlay() async {
    if (_state != _MicState.recording) return;
    final file = await _recorder.stop();
    if (file == null) {
      if (mounted) setState(() => _state = _MicState.idle);
      return;
    }
    if (mounted) setState(() => _state = _MicState.playing);
    await _player.playFile(file.path, volume: 1.0);
    _player.onPlayerStateChanged
        .firstWhere((s) =>
            s == PlayerState.completed || s == PlayerState.stopped)
        .then((_) {
      if (mounted) setState(() => _state = _MicState.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (_state) {
      _MicState.idle => (const Color(0xFF6750A4), Icons.mic_none),
      _MicState.recording => (Colors.red, Icons.mic),
      _MicState.playing => (const Color(0xFF2E7D32), Icons.volume_up),
    };

    // Listener (pointer events) responds the instant the finger touches down,
    // unlike a long-press which needs a hold delay.
    return Listener(
      onPointerDown: (_) => _startRecording(),
      onPointerUp: (_) => _stopAndPlay(),
      onPointerCancel: (_) => _stopAndPlay(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 38),
      ),
    );
  }
}
