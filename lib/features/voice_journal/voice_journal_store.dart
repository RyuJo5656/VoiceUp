import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class JournalEntry {
  JournalEntry({
    required this.recordedAt,
    required this.filePath,
    required this.durationMs,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        recordedAt: DateTime.fromMillisecondsSinceEpoch(json['recordedAt'] as int),
        filePath: json['filePath'] as String,
        durationMs: json['durationMs'] as int,
      );

  final DateTime recordedAt;
  final String filePath;
  final int durationMs;

  Map<String, dynamic> toJson() => {
        'recordedAt': recordedAt.millisecondsSinceEpoch,
        'filePath': filePath,
        'durationMs': durationMs,
      };
}

class JournalStore {
  static const _key = 'voiceup_journal_v1';

  Future<List<JournalEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(JournalEntry.fromJson)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Future<void> add(JournalEntry entry) async {
    final all = await loadAll();
    all.insert(0, entry);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }
}
