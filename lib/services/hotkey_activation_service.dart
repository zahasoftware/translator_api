import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../features/translation/translation_provider.dart';

/// Clipboard polling (no Ctrl+C hook). User copies with Ctrl+C normally, then
/// presses Ctrl+<activationKey> (default L) to translate the most recent
/// clipboard text.
///
/// Reliability improvements:
/// - Hotkey fires read clipboard fresh (avoids 350 ms poll lag / race condition).
/// - A watchdog timer re-registers the hotkey every [_watchdogIntervalMs] ms
///   to recover from silent Win32 RegisterHotKey drops.
class HotkeyActivationService {
  HotkeyActivationService._();
  static final instance = HotkeyActivationService._();

  String activationKey = 'L';
  int sequenceWindowMs = 3000; // Max age of clipboard change for sequence
  int pollIntervalMs =
      350; // Clipboard poll frequency (keeps _lastClipboard warm)
  int cooldownMs = 600; // Prevent rapid duplicate activations

  static const int _watchdogIntervalMs = 8000; // Re-register hotkey every 8 s

  HotKey? _activationHotKey;
  Timer? _pollTimer;
  Timer? _watchdogTimer;
  TranslationProvider? _provider;

  String? _lastClipboard;
  DateTime? _lastClipboardAt;
  DateTime _lastTrigger = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> register(TranslationProvider provider) async {
    _provider = provider;
    await _stop();

    // Start polling clipboard to keep _lastClipboard warm as a fallback.
    _startClipboardPoll();

    // Register the system hotkey.
    await _registerHotkey(provider);

    // Watchdog: re-registers the hotkey regularly to recover from silent drops.
    _watchdogTimer = Timer.periodic(
      const Duration(milliseconds: _watchdogIntervalMs),
      (_) => _watchdog(),
    );
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  void _startClipboardPoll() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(Duration(milliseconds: pollIntervalMs), (_) async {
      try {
        final data = await Clipboard.getData('text/plain');
        final txt = data?.text?.trim();
        if (txt != null && txt.isNotEmpty && txt != _lastClipboard) {
          _lastClipboard = txt;
          _lastClipboardAt = DateTime.now();
        }
      } catch (_) {}
    });
  }

  Future<void> _registerHotkey(TranslationProvider provider) async {
    // Always start from a clean slate to avoid duplicate registrations.
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {}

    _activationHotKey = HotKey(
      key: _mapLetterKey(activationKey),
      modifiers: const [HotKeyModifier.control],
      scope: HotKeyScope.system,
    );

    try {
      await hotKeyManager.register(
        _activationHotKey!,
        keyDownHandler: (_) => _onHotkeyFired(provider),
      );
      if (kDebugMode) debugPrint('[Hotkey] Registered Ctrl+$activationKey');
    } catch (e) {
      if (kDebugMode) debugPrint('[Hotkey] Registration failed: $e');
    }
  }

  Future<void> _onHotkeyFired(TranslationProvider provider) async {
    final now = DateTime.now();
    if (now.difference(_lastTrigger).inMilliseconds < cooldownMs) return;
    _lastTrigger = now;

    // Read clipboard *fresh* right now instead of relying on the poll result.
    // This fixes the race condition where the user copies and immediately
    // presses the hotkey before the 350 ms poll timer fires.
    String? txt;
    try {
      final data = await Clipboard.getData('text/plain');
      txt = data?.text?.trim();
      if (txt != null && txt.isNotEmpty) {
        _lastClipboard = txt;
        _lastClipboardAt = now;
      }
    } catch (_) {
      // Fall back to last polled value if a fresh read fails.
      txt = _lastClipboard;
    }

    if (txt == null || txt.isEmpty) return;

    // Enforce sequence window only against the polled timestamp, not the
    // fresh-read (which always sets _lastClipboardAt = now above).
    if (_lastClipboardAt != null &&
        now.difference(_lastClipboardAt!).inMilliseconds > sequenceWindowMs) {
      return;
    }

    if (!await windowManager.isVisible()) await windowManager.show();
    await windowManager.focus();

    provider.setSourceText(txt);
    await provider.performTranslate(
      text: txt,
      sourceLang: provider.sourceLang,
      targetLang: provider.targetLang,
    );
  }

  /// Called every [_watchdogIntervalMs] ms to silently re-register the hotkey
  /// in case Windows silently dropped the registration.
  void _watchdog() {
    final p = _provider;
    if (p == null) return;
    if (kDebugMode)
      debugPrint('[Hotkey] Watchdog re-registering Ctrl+$activationKey');
    _registerHotkey(p); // async fire-and-forget; errors are swallowed inside
  }

  // ── Public API ────────────────────────────────────────────────────────────

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
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {}
    _activationHotKey = null;
  }

  // ── Key mapping ───────────────────────────────────────────────────────────

  LogicalKeyboardKey _mapLetterKey(String ch) {
    switch (ch.toUpperCase()) {
      case 'A':
        return LogicalKeyboardKey.keyA;
      case 'B':
        return LogicalKeyboardKey.keyB;
      case 'C':
        return LogicalKeyboardKey.keyC;
      case 'D':
        return LogicalKeyboardKey.keyD;
      case 'E':
        return LogicalKeyboardKey.keyE;
      case 'F':
        return LogicalKeyboardKey.keyF;
      case 'G':
        return LogicalKeyboardKey.keyG;
      case 'H':
        return LogicalKeyboardKey.keyH;
      case 'I':
        return LogicalKeyboardKey.keyI;
      case 'J':
        return LogicalKeyboardKey.keyJ;
      case 'K':
        return LogicalKeyboardKey.keyK;
      case 'L':
        return LogicalKeyboardKey.keyL;
      case 'M':
        return LogicalKeyboardKey.keyM;
      case 'N':
        return LogicalKeyboardKey.keyN;
      case 'O':
        return LogicalKeyboardKey.keyO;
      case 'P':
        return LogicalKeyboardKey.keyP;
      case 'Q':
        return LogicalKeyboardKey.keyQ;
      case 'R':
        return LogicalKeyboardKey.keyR;
      case 'S':
        return LogicalKeyboardKey.keyS;
      case 'T':
        return LogicalKeyboardKey.keyT;
      case 'U':
        return LogicalKeyboardKey.keyU;
      case 'V':
        return LogicalKeyboardKey.keyV;
      case 'W':
        return LogicalKeyboardKey.keyW;
      case 'X':
        return LogicalKeyboardKey.keyX;
      case 'Y':
        return LogicalKeyboardKey.keyY;
      case 'Z':
        return LogicalKeyboardKey.keyZ;
      default:
        return LogicalKeyboardKey.keyL;
    }
  }
}
