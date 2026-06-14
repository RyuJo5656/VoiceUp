import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/audio/player.dart';
import '../../core/audio/recorder.dart';
import 'voice_journal_store.dart';

/// Mode 4 — Voice journal (record only).
///
/// Records a 5 second sustained vowel ("아—") for daily tracking.
/// Phase 2 will analyze jitter / shimmer / HNR / MPT.
class VoiceJournalScreen extends StatefulWidget {
  const VoiceJournalScreen({super.key});

  @override
  State<VoiceJournalScreen> createState() => _VoiceJournalScreenState();
}

class _VoiceJournalScreenState extends State<VoiceJournalScreen> {
  static const _targetSeconds = 5;

  final _recorder = VoiceRecorder();
  final _player = LoudPlayer();
  final _store = JournalStore();

  Timer? _timer;
  int _elapsed = 0;
  bool _recording = false;
  List<JournalEntry> _entries = const [];
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final entries = await _store.loadAll();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _toggle() async {
    if (_recording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    try {
      await _recorder.start();
      setState(() {
        _recording = true;
        _elapsed = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _elapsed++);
        if (_elapsed >= _targetSeconds) _stop();
      });
    } on MicPermissionDeniedException catch (e) {
      _showSnack(e.toString());
    } catch (e) {
      _showSnack('녹음 시작 실패: $e');
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    final file = await _recorder.stop();
    setState(() => _recording = false);
    if (file == null) return;
    await _store.add(JournalEntry(
      recordedAt: DateTime.now(),
      filePath: file.path,
      durationMs: _elapsed * 1000,
    ));
    await _refresh();
  }

  Future<void> _play(JournalEntry e) async {
    setState(() => _playingPath = e.filePath);
    await _player.playFile(e.filePath);
    _player.onPlayerStateChanged.firstWhere((s) => s.toString().endsWith('completed')
            || s.toString().endsWith('stopped')).then((_) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('M월 d일 HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('음성 일지')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  '"아—" 5초간 길게 발성하세요.\n매일 같은 시간에 녹음하면 변화 추세를 볼 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 24),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: _recording ? _elapsed / _targetSeconds : 0,
                        strokeWidth: 8,
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        minimumSize: const Size(110, 110),
                        backgroundColor: _recording ? Colors.red : null,
                      ),
                      onPressed: _toggle,
                      child: Icon(
                        _recording ? Icons.stop : Icons.mic,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _recording ? '$_elapsed / $_targetSeconds 초' : '눌러서 시작',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _entries.isEmpty
                ? const Center(child: Text('아직 기록이 없어요'))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      final playing = _playingPath == e.filePath;
                      return ListTile(
                        title: Text(df.format(e.recordedAt)),
                        subtitle: Text('${(e.durationMs / 1000).toStringAsFixed(1)}초'),
                        trailing: IconButton(
                          icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                          onPressed: playing
                              ? () => _player.stop()
                              : () => _play(e),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
