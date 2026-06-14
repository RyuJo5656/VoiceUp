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
  bool _assistActive = false;
  int _gainMb = CallAssist.defaultGainMb;
  String _partial = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGain();
  }

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    _textCtl.dispose();
    super.dispose();
  }

  Future<void> _loadGain() async {
    final gain = await CallAssist.getPlaybackGain();
    if (mounted) setState(() => _gainMb = gain);
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

  Future<void> _toggleCallAssist() async {
    // Turn the button off.
    if (_assistActive) {
      await CallAssist.setButton(false);
      if (!mounted) return;
      setState(() => _assistActive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('통화 보조 버튼을 껐어요.')),
      );
      return;
    }

    // Needs the accessibility service enabled first.
    if (!await CallAssist.isAccessibilityEnabled()) {
      if (!mounted) return;
      final go = await _showEnableDialog();
      if (go == true) await CallAssist.openAccessibilitySettings();
      return;
    }

    final applied = await CallAssist.setButton(true);
    if (!mounted) return;
    if (applied) {
      setState(() => _assistActive = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('화면에 마이크 버튼을 띄웠어요. 스피커폰 통화 중 눌러서 사용하세요.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('접근성 권한을 켠 뒤 다시 눌러 주세요.')),
      );
      await CallAssist.openAccessibilitySettings();
    }
  }

  Future<bool?> _showEnableDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('통화 보조 버튼 켜기'),
        content: const Text(
          '통화 화면 위에서도 눌리는 버튼을 띄우려면 "접근성" 권한이 필요해요.\n\n'
          '설정 → 접근성 → VoiceUp 통화 보조 버튼 → 켜기\n\n'
          'VoiceUp은 화면 내용을 읽지 않고, 버튼 표시 용도로만 사용합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
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
              onPressed: _toggleCallAssist,
              icon: Icon(_assistActive
                  ? Icons.close
                  : Icons.picture_in_picture_alt),
              label: Text(_assistActive
                  ? '통화 보조 버튼 닫기'
                  : '통화 중 띄우기 (화면 위 버튼)'),
            ),
            Row(
              children: [
                const Icon(Icons.volume_up, size: 18),
                const SizedBox(width: 4),
                Text('통화 보조 재생 음량  +${(_gainMb / 100).round()}dB',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            Slider(
              value: _gainMb.toDouble(),
              min: 0,
              max: CallAssist.maxGainMb.toDouble(),
              divisions: CallAssist.maxGainMb ~/ 250,
              label: '+${(_gainMb / 100).round()}dB',
              onChanged: (v) => setState(() => _gainMb = v.round()),
              onChangeEnd: (v) => CallAssist.setPlaybackGain(v.round()),
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
