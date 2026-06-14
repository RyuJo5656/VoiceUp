import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../core/audio/player.dart';
import '../core/audio/recorder.dart';
import '../core/services/system_tts_service.dart';
import '../core/theme/app_theme.dart';
import '../features/phrase_pad/phrase_store.dart';

/// The floating panel rendered *on top of other apps* (e.g. the phone's call
/// screen) while a call is on speakerphone. Recording a short clip and playing
/// it back loudly lets the other party hear the user's own amplified voice;
/// the call microphone picks up the speaker output and transmits it.
///
/// Runs in its own Flutter engine via [FlutterOverlayWindow], so it is fully
/// self-contained and reuses the same recorder / player / TTS as the main app.
class CallOverlayApp extends StatelessWidget {
  const CallOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: CallOverlayPanel(),
      ),
    );
  }
}

class CallOverlayPanel extends StatefulWidget {
  const CallOverlayPanel({super.key});

  @override
  State<CallOverlayPanel> createState() => _CallOverlayPanelState();
}

class _CallOverlayPanelState extends State<CallOverlayPanel> {
  final _recorder = VoiceRecorder();
  final _player = LoudPlayer();
  final _tts = SystemTtsService();
  final _store = PhraseStore();

  List<Phrase> _phrases = const [];
  bool _recording = false;
  bool _playing = false;
  String _status = '버튼을 누른 채 말하고, 떼면 크게 재생돼요';

  @override
  void initState() {
    super.initState();
    _loadPhrases();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadPhrases() async {
    final all = await _store.load();
    if (!mounted) return;
    setState(() => _phrases = all.take(8).toList());
  }

  Future<void> _startRecording() async {
    if (_recording || _playing) return;
    try {
      await _recorder.start();
      if (mounted) {
        setState(() {
          _recording = true;
          _status = '녹음 중… 말하세요';
        });
      }
    } on MicPermissionDeniedException {
      if (mounted) setState(() => _status = '마이크 권한이 필요해요');
    } catch (_) {
      if (mounted) setState(() => _status = '녹음을 시작할 수 없어요 (통화 중 제한일 수 있음)');
    }
  }

  Future<void> _stopAndPlay() async {
    if (!_recording) return;
    final file = await _recorder.stop();
    if (mounted) setState(() => _recording = false);
    if (file == null) return;

    if (mounted) {
      setState(() {
        _playing = true;
        _status = '크게 재생 중…';
      });
    }
    await _player.playFile(file.path, volume: 1.0);
    _player.onPlayerStateChanged
        .firstWhere((s) =>
            s == PlayerState.completed || s == PlayerState.stopped)
        .then((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _status = '버튼을 누른 채 말하고, 떼면 크게 재생돼요';
        });
      }
    });
  }

  Future<void> _speakPhrase(String text) async {
    if (text.trim().isEmpty || _recording) return;
    setState(() => _status = '재생 중…');
    try {
      await _tts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _status = '재생 실패');
    }
    if (mounted) {
      setState(() => _status = '버튼을 누른 채 말하고, 떼면 크게 재생돼요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.record_voice_over, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'VoiceUp 통화 보조',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => FlutterOverlayWindow.closeOverlay(),
                    icon: const Icon(Icons.close),
                    tooltip: '닫기',
                  ),
                ],
              ),
              Text(
                _status,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // 누르고 있는 동안 녹음, 떼면 크게 재생.
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopAndPlay(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 64,
                  decoration: BoxDecoration(
                    color: _recording ? Colors.red : cs.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _recording ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _recording ? '말하는 중… (떼면 재생)' : '누르고 말하기',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_phrases.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _phrases
                      .map(
                        (p) => ActionChip(
                          label: Text(p.text, style: const TextStyle(fontSize: 15)),
                          onPressed: () => _speakPhrase(p.text),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
