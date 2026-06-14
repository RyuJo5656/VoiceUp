import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../core/services/system_stt_service.dart';
import '../core/services/system_tts_service.dart';
import '../core/theme/app_theme.dart';
import '../features/phrase_pad/phrase_store.dart';

/// The floating panel rendered *on top of other apps* (e.g. the phone's call
/// screen) while a call is on speakerphone. Tapping a phrase or the mic plays
/// a loud voice through the speaker, which the call microphone then transmits
/// to the other party.
///
/// Runs in its own Flutter engine via [FlutterOverlayWindow], so it is fully
/// self-contained and reuses the same system STT/TTS services as the main app.
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
  final _tts = SystemTtsService();
  final _stt = SystemSttService();
  final _store = PhraseStore();

  List<Phrase> _phrases = const [];
  bool _listening = false;
  String _status = '문장을 누르거나 마이크로 말하세요';

  @override
  void initState() {
    super.initState();
    _loadPhrases();
  }

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadPhrases() async {
    final all = await _store.load();
    if (!mounted) return;
    setState(() => _phrases = all.take(8).toList());
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _status = '재생 중…');
    try {
      await _tts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _status = '재생 실패');
    }
    if (mounted) setState(() => _status = '문장을 누르거나 마이크로 말하세요');
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      await _stt.start(
        onPartial: (t) {
          if (mounted) setState(() => _status = '듣는 중: $t');
        },
        onFinal: (t) {
          if (!mounted) return;
          setState(() => _listening = false);
          if (t.trim().isNotEmpty) _speak(t);
        },
      );
      if (mounted) setState(() => _listening = true);
      if (mounted) setState(() => _status = '듣는 중… 작게 말하세요');
    } catch (_) {
      if (mounted) {
        setState(() {
          _listening = false;
          _status = '마이크 인식을 사용할 수 없어요';
        });
      }
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
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _listening ? Colors.red : cs.primary,
                  ),
                  onPressed: _toggleMic,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Text(
                    _listening ? '멈추기' : '작게 말하기 → 크게 재생',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_phrases.isEmpty)
                const SizedBox.shrink()
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _phrases
                      .map(
                        (p) => ActionChip(
                          label: Text(p.text, style: const TextStyle(fontSize: 15)),
                          onPressed: () => _speak(p.text),
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
