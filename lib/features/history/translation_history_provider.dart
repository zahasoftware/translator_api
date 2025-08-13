import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationEntry {
  TranslationEntry({required this.sourceText, required this.resultText, required this.sourceLang, required this.targetLang, required this.timestamp});
  final String sourceText;
  final String resultText;
  final String sourceLang;
  final String targetLang;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        's': sourceText,
        'r': resultText,
        'sl': sourceLang,
        'tl': targetLang,
        't': timestamp.toIso8601String(),
      };
  static TranslationEntry fromJson(Map<String, dynamic> json) => TranslationEntry(
        sourceText: json['s'] as String,
        resultText: json['r'] as String,
        sourceLang: json['sl'] as String,
        targetLang: json['tl'] as String,
        timestamp: DateTime.parse(json['t'] as String),
      );
}

class TranslationHistoryProvider extends ChangeNotifier {
  final List<TranslationEntry> _entries = [];
  List<TranslationEntry> get entries => List.unmodifiable(_entries);
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('translation_history');
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as List<dynamic>;
        _entries.addAll(data.map((e) => TranslationEntry.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(TranslationEntry entry) async {
    _entries.insert(0, entry);
    if (_entries.length > 200) _entries.removeLast();
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _entries.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString('translation_history', jsonList);
  }
}
