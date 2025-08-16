import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../features/translation/translation_provider.dart';

/// Reverted version: requires sequence Ctrl+C then Ctrl+<activationKey>
/// within [sequenceWindowMs]. Falls back to single Ctrl+<activationKey>
/// if Ctrl+C global registration fails (some platforms disallow).
class HotkeyActivationService {
  HotkeyActivationService._();
  static final instance = HotkeyActivationService._();

  String activationKey = 'L';
  int sequenceWindowMs = 3000;

  HotKey? _copyHotKey;
  HotKey? _activationHotKey;

  DateTime? _lastCopyAt;
  String? _cachedCopied;
  bool _copyRegistered = false;

  Future<void> register(TranslationProvider provider) async {
    await hotKeyManager.unregisterAll();
    _copyRegistered = false;

    // Try to register global Ctrl+C (may fail on some platforms)
    _copyHotKey = HotKey(
      key: LogicalKeyboardKey.keyC,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.system,
    );
    try {
      await hotKeyManager.register(_copyHotKey!, keyDownHandler: (_) async {
        // Let the normal copy finish
        await Future.delayed(const Duration(milliseconds: 40));
        final data = await Clipboard.getData('text/plain');
        final txt = data?.text?.trim();
        if (txt == null || txt.isEmpty) return;
        _cachedCopied = txt;
        _lastCopyAt = DateTime.now();
      });
      _copyRegistered = true;
    } catch (_) {
      // Ignore – fallback will work (single key translation)
      _copyRegistered = false;
    }

    _activationHotKey = HotKey(
      key: _mapLetterKey(activationKey),
      modifiers: const [HotKeyModifier.control],
      scope: HotKeyScope.system,
    );

    try {
      await hotKeyManager.register(_activationHotKey!, keyDownHandler: (_) async {
        // If copy hotkey registered, enforce sequence window.
        if (_copyRegistered) {
            if (_lastCopyAt == null) return;
            if (DateTime.now().difference(_lastCopyAt!).inMilliseconds > sequenceWindowMs) return;
        }
        // Read clipboard (fresh – user might have copied without our capture if registration failed)
        final data = await Clipboard.getData('text/plain');
        final txt = data?.text?.trim();
        if (txt == null || txt.isEmpty) return;
        if (!await windowManager.isVisible()) await windowManager.show();
        await windowManager.focus();
        provider.setSourceText(txt);
        await provider.performTranslate(text: txt);
      });
    } catch (_) {
      // Do nothing if activation registration fails
    }
  }

  void updateConfig({
    String? newActivationKey,
    int? newSequenceWindowMs,
    required TranslationProvider provider,
  }) {
    if (newActivationKey != null) activationKey = newActivationKey.toUpperCase();
    if (newSequenceWindowMs != null && newSequenceWindowMs > 0) {
      sequenceWindowMs = newSequenceWindowMs;
    }
    register(provider);
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