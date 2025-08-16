import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/translation/translation_provider.dart';

class TrayStartupProvider extends ChangeNotifier
    with TrayListener, WindowListener {
  static const _kTray = 'enable_tray';
  static const _kAuto = 'enable_autostart';

  bool _trayEnabled = true;
  bool _autoStart = false;
  bool _inited = false;

  // New: user option to close-to-tray
  bool _closeToTray = true;

  TranslationProvider? _tp;

  bool get trayEnabled => _trayEnabled;
  bool get autoStartEnabled => _autoStart;
  bool get closeToTray => _closeToTray;

  void attach(TranslationProvider tp) => _tp = tp;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _trayEnabled = p.getBool(_kTray) ?? true;
    _autoStart = p.getBool(_kAuto) ?? false;
    if (_trayEnabled) await _initTray();
    if (_autoStart) await _applyAuto(true);
    notifyListeners();
  }

  Future<void> setTrayEnabled(bool v) async {
    if (v == _trayEnabled) return;
    _trayEnabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTray, v);
    if (v) {
      await _initTray();
    } else if (_inited) {
      await trayManager.destroy();
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      windowManager.setPreventClose(false);
      _inited = false;
    }
    notifyListeners();
  }

  Future<void> setAutoStartEnabled(bool v) async {
    if (v == _autoStart) return;
    _autoStart = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAuto, v);
    await _applyAuto(v);
    notifyListeners();
  }

  void setCloseToTray(bool v) {
    if (_closeToTray == v) return;
    _closeToTray = v;
    notifyListeners();
  }

  Future<void> _applyAuto(bool enable) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    LaunchAtStartup.instance.setup(
      appName: 'Translator',
      appPath: _appLaunchPath(),
      args: const [],
    );
    final ok = enable
        ? await LaunchAtStartup.instance.enable()
        : await LaunchAtStartup.instance.disable();
    if (!ok) {
      debugPrint('LaunchAtStartup: failed to ${enable ? 'enable' : 'disable'}');
    }
  }

  String _appLaunchPath() {
    if (Platform.isWindows) {
      final exe = File('build/windows/x64/runner/Release/translator_app.exe');
      if (exe.existsSync()) return exe.absolute.path;
    }
    return Platform.resolvedExecutable;
  }

  Future<void> _initTray() async {
    if (_inited) return;
    trayManager.addListener(this);
    windowManager.addListener(this);
    final icon = Platform.isWindows
        ? 'windows/runner/resources/app_icon.ico'
        : 'assets/icon.png';
    try {
      await trayManager.setIcon(icon);
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(label: 'Show'),
        MenuItem(label: 'Translate Clipboard'),
        MenuItem.separator(),
        MenuItem(label: 'Quit'),
      ]));
      windowManager.setPreventClose(true);
      _inited = true;
    } catch (_) {}
  }

  // Tray icon click
  @override
  void onTrayIconMouseDown() async {
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    await windowManager.focus();
  }

  // Tray menu actions
  @override
  void onTrayMenuItemClick(MenuItem item) async {
    switch (item.label) {
      case 'Show':
        if (!await windowManager.isVisible()) await windowManager.show();
        await windowManager.focus();
        break;
      case 'Translate Clipboard':
        await _tp?.translateFromClipboard();
        break;
      case 'Quit':
        windowManager.setPreventClose(false);
        await windowManager.close();
        break;
    }
  }

  // Window close interception
  @override
  Future<void> onWindowClose() async {
    // If tray enabled and close-to-tray is on, hide instead of quitting.
    if (_trayEnabled && _closeToTray) {
      await windowManager.hide();
      // Keep app running; do not propagate close.
      return;
    }
    // Allow actual close
    windowManager.setPreventClose(false);
    await windowManager.close();
  }
}