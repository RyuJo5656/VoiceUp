import 'package:flutter/material.dart';

import '../../core/audio/call_mode_bar.dart';
import '../../core/services/system_tts_service.dart';
import 'phrase_store.dart';

/// Mode 3 — Quick phrase pad. Tap a phrase to speak it aloud.
class PhrasePadScreen extends StatefulWidget {
  const PhrasePadScreen({super.key});

  @override
  State<PhrasePadScreen> createState() => _PhrasePadScreenState();
}

class _PhrasePadScreenState extends State<PhrasePadScreen> {
  final _store = PhraseStore();
  final _tts = SystemTtsService();

  List<Phrase> _phrases = const [];
  String? _speakingId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final list = await _store.load();
    if (!mounted) return;
    setState(() {
      _phrases = list;
      _loading = false;
    });
  }

  Future<void> _speak(Phrase p) async {
    setState(() => _speakingId = p.id);
    try {
      await _tts.speak(p.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('재생 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _speakingId = null);
    }
  }

  Future<void> _addDialog() async {
    final ctl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('문장 추가'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '자주 쓰는 말'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _store.add(result.trim());
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('빠른 문장')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: CallModeBar(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: _phrases.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final p = _phrases[i];
                        final speaking = _speakingId == p.id;
                        return Material(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: speaking ? null : () => _speak(p),
                            onLongPress: () async {
                              await _store.remove(p.id);
                              await _refresh();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.text,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  if (speaking)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.volume_up),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
