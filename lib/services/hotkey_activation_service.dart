import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../features/translation/translation_provider.dart';

/// Clipboard polling (no Ctrl+C hook). User copies with Ctrl+C normally, then
/// presses Ctrl+<activationKey> (default L) to translate the most recent
/// clipboard text. Optionally enforces a sequence window.
class HotkeyActivationService {
  HotkeyActivationService._();
  static final instance = HotkeyActivationService._();

  String activationKey = 'L';
  int sequenceWindowMs = 3000;      // Max age of clipboard change for sequence
  int pollIntervalMs = 350;         // Clipboard poll frequency
  int cooldownMs = 600;             // Prevent rapid duplicate activations

  HotKey? _activationHotKey;
  Timer? _pollTimer;

  String? _lastClipboard;
  DateTime? _lastClipboardAt;
  DateTime _lastTrigger = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> register(TranslationProvider provider) async {
    // Clean previous
    await _stop();
    try { await hotKeyManager.unregisterAll(); } catch (_) {}

    // Start polling clipboard (non-blocking)
    _pollTimer = Timer.periodic(Duration(milliseconds: pollIntervalMs), (_) async {
      try {
        final data = await Clipboard.getData('text/plain');
        final txt = data?.text?.trim();
        if (txt != null && txt.isNotEmpty && txt != _lastClipboard) {
          _lastClipboard = txt;
          _lastClipboardAt = DateTime.now();
        }
      } catch (_) {}
    });

    // Register only activation hotkey
    _activationHotKey = HotKey(
      key: _mapLetterKey(activationKey),
      modifiers: const [HotKeyModifier.control],
      scope: HotKeyScope.system,
    );

    try {
      await hotKeyManager.register(_activationHotKey!, keyDownHandler: (_) async {
        final now = DateTime.now();
        if (now.difference(_lastTrigger).inMilliseconds < cooldownMs) return;
        _lastTrigger = now;

        final txt = _lastClipboard;
        if (txt == null || txt.isEmpty) return;

        // Enforce sequence window if set (>0)
        if (_lastClipboardAt != null &&
            now.difference(_lastClipboardAt!).inMilliseconds > sequenceWindowMs) {
          return; // Clipboard change too old
        }

        if (!await windowManager.isVisible()) await windowManager.show();
        await windowManager.focus();

        provider.setSourceText(txt);
        await provider.performTranslate(text: txt);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Activation hotkey failed: $e');
      }
    }
  }

  void updateConfig({
    String? newActivationKey,
    int? newSequenceWindowMs,
    int? newPollIntervalMs,
    int? newCooldownMs,
    required TranslationProvider provider,
  }) {
    if (newActivationKey != null && newActivationKey.isNotEmpty) {
      activationKey = newActivationKey.toUpperCase();
    }
    if (newSequenceWindowMs != null && newSequenceWindowMs > 0) {
      sequenceWindowMs = newSequenceWindowMs;
    }
    if (newPollIntervalMs != null && newPollIntervalMs >= 150) {
      pollIntervalMs = newPollIntervalMs;
    }
    if (newCooldownMs != null && newCooldownMs > 0) {
      cooldownMs = newCooldownMs;
    }
    register(provider);
  }

  Future<void> dispose() async => _stop();

  Future<void> _stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    try { await hotKeyManager.unregisterAll(); } catch (_) {}
    _activationHotKey = null;
  }

  LogicalKeyboardKey _mapLetterKey(String ch) {
    switch (ch.toUpperCase()) {
      case 'A': return LogicalKeyboardKey.keyA;
      case 'B': return LogicalKeyboardKey.keyB;
      case 'C': return LogicalKeyboardKey.keyC;
      case 'D': return LogicalKeyboardKey.keyD;
      case 'E': return LogicalKeyboardKey.keyE;
      case 'F': return LogicalKeyboardKey.keyF;
      case 'G': return LogicalKeyboardKey.keyG;
      case 'H': return LogicalKeyboardKey.keyH;
      case 'I': return LogicalKeyboardKey.keyI;
      case 'J': return LogicalKeyboardKey.keyJ;
      case 'K': return LogicalKeyboardKey.keyK;
      case 'L': return LogicalKeyboardKey.keyL;
      case 'M': return LogicalKeyboardKey.keyM;
      case 'N': return LogicalKeyboardKey.keyN;
      case 'O': return LogicalKeyboardKey.keyO;
      case 'P': return LogicalKeyboardKey.keyP;
      case 'Q': return LogicalKeyboardKey.keyQ;
      case 'R': return LogicalKeyboardKey.keyR;
      case 'S': return LogicalKeyboardKey.keyS;
      case 'T': return LogicalKeyboardKey.keyT;
      case 'U': return LogicalKeyboardKey.keyU;
      case 'V': return LogicalKeyboardKey.keyV;
      case 'W': return LogicalKeyboardKey.keyW;
      case 'X': return LogicalKeyboardKey.keyX;
      case 'Y': return LogicalKeyboardKey.keyY;
      case 'Z': return LogicalKeyboardKey.keyZ;
      default:  return LogicalKeyboardKey.keyL;
    }
  }
}