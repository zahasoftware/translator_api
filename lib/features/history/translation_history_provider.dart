import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationEntry {
  final String sourceText;
  final String resultText;
  final String sourceLang;
  final String targetLang;
  final DateTime timestamp;

  TranslationEntry({
    required this.sourceText,
    required this.resultText,
    required this.sourceLang,
    required this.targetLang,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        's': sourceText,
        'r': resultText,
        'sl': sourceLang,
        'tl': targetLang,
        't': timestamp.toIso8601String(),
      };

  factory TranslationEntry.fromJson(Map<String, dynamic> j) => TranslationEntry(
        sourceText: j['s'] as String? ?? '',
        resultText: j['r'] as String? ?? '',
        sourceLang: j['sl'] as String? ?? 'auto',
        targetLang: j['tl'] as String? ?? '',
        timestamp: DateTime.tryParse(j['t'] as String? ?? '') ?? DateTime.now(),
      );
}

class TranslationHistoryProvider extends ChangeNotifier {
  static const _prefsKey = 'translation_history_v1';
  static const _maxEntries = 200;

  final List<TranslationEntry> _entries = [];
  bool _loaded = false;

  List<TranslationEntry> get entries => List.unmodifiable(_entries);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            if (e is Map<String, dynamic>) {
              _entries.add(TranslationEntry.fromJson(e));
            } else if (e is Map) {
              _entries.add(TranslationEntry.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))));
            }
          }
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(TranslationEntry entry) async {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
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
    final data = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, data);
  }
}
