import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Phrase {
  Phrase({required this.id, required this.text});

  factory Phrase.create(String text) =>
      Phrase(id: const Uuid().v4(), text: text);

  factory Phrase.fromJson(Map<String, dynamic> json) =>
      Phrase(id: json['id'] as String, text: json['text'] as String);

  final String id;
  final String text;

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

class PhraseStore {
  static const _key = 'voiceup_phrases_v1';
  static const _defaults = [
    '네, 안녕하세요',
    '잠시만 기다려 주세요',
    '감사합니다',
    '죄송합니다',
    '괜찮아요',
    '커피 한 잔 주세요',
    '얼마예요?',
    '카드로 결제할게요',
    '천천히 말씀해 주세요',
    '도와주셔서 감사합니다',
  ];

  Future<List<Phrase>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      final seed = _defaults.map(Phrase.create).toList();
      await _save(seed);
      return seed;
    }
    final list = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(Phrase.fromJson)
        .toList();
    return list;
  }

  Future<void> add(String text) async {
    final phrases = await load();
    phrases.insert(0, Phrase.create(text));
    await _save(phrases);
  }

  Future<void> remove(String id) async {
    final phrases = await load();
    phrases.removeWhere((p) => p.id == id);
    await _save(phrases);
  }

  Future<void> _save(List<Phrase> phrases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(phrases.map((p) => p.toJson()).toList()),
    );
  }
}
