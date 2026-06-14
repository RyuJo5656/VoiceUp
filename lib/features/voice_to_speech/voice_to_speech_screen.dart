import 'package:flutter/material.dart';

import '../../core/audio/call_mode_bar.dart';
import '../../core/overlay/call_assist.dart';
import '../../core/services/system_stt_service.dart';
import '../../core/services/system_tts_service.dart';

/// Mode 2 — Whisper → Loud voice (STT → TTS).
///
/// Tap mic, speak softly. Live partial recognition is shown. Tap stop or
/// stay silent for a moment to finalize, then the recognized sentence is
/// spoken back via system TTS at high volume.
class VoiceToSpeechScreen extends StatefulWidget {
  const VoiceToSpeechScreen({super.key});

  @override
  State<VoiceToSpeechScreen> createState() => _VoiceToSpeechScreenState();
}

class _VoiceToSpeechScreenState extends State<VoiceToSpeechScreen> {
  final _stt = SystemSttService();
  final _tts = SystemTtsService();
  final _textCtl = TextEditingController();

  bool _listening = false;
  bool _speaking = false;
  String _partial = '';
  String? _error;

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    _textCtl.dispose();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_speaking) return;
    if (_listening) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _partial = '';
    });
    try {
      await _stt.start(
        onPartial: (t) {
          if (mounted) setState(() => _partial = t);
        },
        onFinal: (t) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _partial = '';
            _textCtl.text = t;
          });
          if (t.trim().isNotEmpty) _speak(t);
        },
      );
      if (mounted) setState(() => _listening = true);
    } on SystemSttException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '인식 시작 실패: $e');
    }
  }

  Future<void> _stop() async {
    await _stt.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _speak(String text) async {
    setState(() => _speaking = true);
    try {
      await _tts.speak(text);
    } catch (e) {
      if (mounted) setState(() => _error = '재생 실패: $e');
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _launchCallAssist() async {
    final result = await CallAssist.launch();
    if (!mounted) return;
    final msg = switch (result) {
      CallAssistResult.launched =>
        '화면 위에 버튼을 띄웠어요. 통화를 스피커폰으로 켜고 사용하세요.',
      CallAssistResult.alreadyActive => '이미 떠 있어요. 화면 위 버튼을 사용하세요.',
      CallAssistResult.permissionDenied =>
        "'다른 앱 위에 표시' 권한이 필요해요. 설정에서 허용해 주세요.",
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final liveText = _listening && _partial.isNotEmpty ? _partial : null;
    return Scaffold(
      appBar: AppBar(title: const Text('작은 목소리 → 큰 목소리')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CallModeBar(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _launchCallAssist,
              icon: const Icon(Icons.picture_in_picture_alt),
              label: const Text('통화 중 띄우기 (화면 위 버튼)'),
            ),
            const SizedBox(height: 16),
            const Text(
              '마이크를 누르고 작게 말하세요.\n인식된 문장이 큰 목소리로 재생됩니다.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _textCtl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    liveText ?? '인식된 문장이 여기에 표시됩니다.\n직접 입력해 재생할 수도 있어요.',
                hintStyle: liveText != null
                    ? TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_speaking || _textCtl.text.trim().isEmpty)
                  ? null
                  : () => _speak(_textCtl.text),
              icon: const Icon(Icons.volume_up),
              label: Text(_speaking ? '재생 중…' : '큰 목소리로 재생'),
            ),
            const Spacer(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.tonalIcon(
              onPressed: _speaking ? null : _toggleListen,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(_listening ? '듣는 중… (탭하여 종료)' : '녹음 시작'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
