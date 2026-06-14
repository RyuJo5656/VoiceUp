import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../core/audio/player.dart';
import '../../core/audio/recorder.dart';

/// Mode 1 — Press-to-talk amplifier.
///
/// Hold the big button while speaking softly. On release, the recording is
/// played back through the loudspeaker (max volume). For real-time live
/// amplification we'd need a native low-latency audio loopback; this MVP
/// uses record-then-replay which is good enough for face-to-face
/// conversations and avoids platform-specific code.
class AmplifierScreen extends StatefulWidget {
  const AmplifierScreen({super.key});

  @override
  State<AmplifierScreen> createState() => _AmplifierScreenState();
}

class _AmplifierScreenState extends State<AmplifierScreen> {
  final _recorder = VoiceRecorder();
  final _player = LoudPlayer();

  bool _recording = false;
  bool _playing = false;
  double _level = 0;
  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    try {
      await _recorder.start();
      _amplitudeSub = _recorder.amplitudeStream().listen((amp) {
        // -60 dB ~ 0 dB → 0.0 ~ 1.0
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        if (mounted) setState(() => _level = normalized);
      });
      if (mounted) setState(() => _recording = true);
    } on MicPermissionDeniedException catch (e) {
      if (mounted) _showSnack(e.toString());
    } catch (e) {
      if (mounted) _showSnack('녹음 시작 실패: $e');
    }
  }

  Future<void> _stopAndPlay() async {
    if (!_recording) return;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final file = await _recorder.stop();
    if (mounted) setState(() => _recording = false);
    if (file == null) return;

    setState(() => _playing = true);
    await _player.playFile(file.path, volume: 1.0);
    _player.onPlayerStateChanged.firstWhere((s) => s == PlayerState.completed
            || s == PlayerState.stopped).then((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('실시간 증폭')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '버튼을 누르고 있는 동안 작게 말하세요.\n손을 떼면 큰 소리로 재생됩니다.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const Spacer(),
            _LevelMeter(level: _level, recording: _recording),
            const SizedBox(height: 32),
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopAndPlay(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _recording
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  boxShadow: [
                    if (_recording)
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 24 + _level * 32,
                        spreadRadius: _level * 16,
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _recording ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _recording
                  ? '녹음 중…'
                  : (_playing ? '재생 중…' : '버튼을 길게 누르세요'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.level, required this.recording});

  final double level;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: recording ? level : 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
