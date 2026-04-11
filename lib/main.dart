import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:translator_app/features/translation/translation_provider.dart';
import 'package:translator_app/features/settings/theme_provider.dart';
import 'package:translator_app/features/history/translation_history_provider.dart';
import 'package:translator_app/services/hotkey_activation_service.dart';
import 'package:translator_app/services/tray_startup_provider.dart';
import 'package:translator_app/features/translation/ollama_translation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(1000, 720),
      center: true,
      title: 'Translator',
    );
    windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final translationProvider = TranslationProvider();
  await translationProvider.init();
  final trayProvider = TrayStartupProvider();
  trayProvider.attach(translationProvider);
  await trayProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: translationProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(
            create: (_) => TranslationHistoryProvider()..load()),
        ChangeNotifierProvider.value(value: trayProvider),
      ],
      child: const MyApp(),
    ),
  );

  HotkeyActivationService.instance.register(translationProvider);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Translator',
      themeMode: themeProvider.mode,
      theme:
          ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue, brightness: Brightness.dark)),
      home: const TranslatorScreen(),
    );
  }
}

extension HotkeyActivationServiceUpdate on HotkeyActivationService {
  void update({
    String? newActivationKey,
    int? newWindowMs,
    required TranslationProvider provider,
  }) {
    bool changed = false;
    if (newActivationKey != null && newActivationKey != activationKey) {
      activationKey = newActivationKey;
      changed = true;
    }
    if (newWindowMs != null && newWindowMs != sequenceWindowMs) {
      sequenceWindowMs = newWindowMs;
      changed = true;
    }
    if (changed) {
      // Re-register or refresh hotkey binding after changes.
      register(provider);
    }
  }
}

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});
  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final _inputController = TextEditingController();
  final _outputController = TextEditingController();
  String _sourceLang = 'auto';
  String _targetLang = 'English';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreferences();
  }

  Future<void> _loadLanguagePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sourceLang = prefs.getString('source_lang') ?? 'auto';
      _targetLang = prefs.getString('target_lang') ?? 'English';
    });
    if (mounted) {
      final provider = context.read<TranslationProvider>();
      provider.setLanguages(sourceLang: _sourceLang, targetLang: _targetLang);
    }
  }

  Future<void> _saveLanguagePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('source_lang', _sourceLang);
    await prefs.setString('target_lang', _targetLang);
  }

  Future<void> _doTranslate() async {
    final provider = context.read<TranslationProvider>();
    final history = context.read<TranslationHistoryProvider>();
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await provider.performTranslate(
        text: text,
        targetLang: _targetLang,
        sourceLang: _sourceLang,
      );
      _outputController.text = res.text;
      await history.add(
        TranslationEntry(
          sourceText: text,
          resultText: res.text,
          sourceLang: _sourceLang,
          targetLang: _targetLang,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    // --- Sync provider -> text controllers (hotkey updates) ---
    if (provider.sourceText.isNotEmpty &&
        provider.sourceText != _inputController.text) {
      final atEnd =
          _inputController.selection.end == _inputController.text.length;
      _inputController.text = provider.sourceText;
      if (atEnd) {
        _inputController.selection =
            TextSelection.collapsed(offset: provider.sourceText.length);
      }
    }
    if (provider.lastResult != null &&
        provider.lastResult!.text.isNotEmpty &&
        provider.lastResult!.text != _outputController.text) {
      _outputController.text = provider.lastResult!.text;
    }
    // ----------------------------------------------------------

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const HistorySheet(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.palette),
            tooltip: 'Theme',
            onPressed: () => _showThemeDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: provider.initialized
          ? _buildBody()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        final content = wide ? _wideLayout() : _narrowLayout();
        return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250), child: content);
      },
    );
  }

  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _topBar(),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _editorCard(_inputController, 'Input', false)),
                const SizedBox(width: 12),
                Expanded(child: _editorCard(_outputController, 'Output', true)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _actionRow(),
        ],
      ),
    );
  }

  Widget _narrowLayout() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _topBar(),
        const SizedBox(height: 8),
        Expanded(child: _editorCard(_inputController, 'Input', false)),
        const SizedBox(height: 8),
        _actionRow(),
        const SizedBox(height: 8),
        Expanded(child: _editorCard(_outputController, 'Output', true)),
      ]),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Expanded(child: _langDropdown(true)),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.swap_horiz),
          onPressed: () {
            if (_sourceLang == 'auto') return;
            setState(() {
              final tmp = _sourceLang;
              _sourceLang = _targetLang;
              _targetLang = tmp;
            });
            _saveLanguagePreferences();
            final provider = context.read<TranslationProvider>();
            provider.setLanguages(
                sourceLang: _sourceLang, targetLang: _targetLang);
          },
        ),
        const SizedBox(width: 12),
        Expanded(child: _langDropdown(false)),
      ],
    );
  }

  Widget _editorCard(
      TextEditingController controller, String label, bool readOnly) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          readOnly: readOnly,
          onSubmitted: readOnly ? null : (_) => _doTranslate(),
          decoration:
              InputDecoration(border: InputBorder.none, labelText: label),
        ),
      ),
    );
  }

  Widget _actionRow() {
    return Row(children: [
      ElevatedButton.icon(
          onPressed: _loading ? null : _doTranslate,
          icon: const Icon(Icons.translate),
          label: const Text('Translate')),
      const SizedBox(width: 12),
      ElevatedButton.icon(
        onPressed: _loading ? null : _openFixAndGrammaPage,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Fix & Gramma'),
      ),
      const SizedBox(width: 12),
      if (_loading)
        const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
      if (_error != null)
        Expanded(
            child: Text(_error!, style: const TextStyle(color: Colors.red)))
    ]);
  }

  Widget _langDropdown(bool source) {
    final items = <String>[
      'auto',
      'English',
      'Spanish',
      'French',
      'German',
      'Italian',
      'Portuguese',
      'Chinese',
      'Japanese',
      'Korean',
      'Arabic',
      'Russian'
    ];
    final value = source ? _sourceLang : _targetLang;
    return DropdownButtonFormField<String>(
      value: value,
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          if (source)
            _sourceLang = v;
          else
            _targetLang = v;
        });
        _saveLanguagePreferences();
        final provider = context.read<TranslationProvider>();
        if (source) {
          provider.setLanguages(sourceLang: v);
        } else {
          provider.setLanguages(targetLang: v);
        }
      },
      decoration: InputDecoration(
          labelText: source ? 'From' : 'To',
          border: const OutlineInputBorder()),
    );
  }

  void _showThemeDialog() {
    final themeProvider = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values
              .map((m) => RadioListTile<ThemeMode>(
                    title: Text(m.name),
                    value: m,
                    groupValue: themeProvider.mode,
                    onChanged: (v) {
                      if (v != null) {
                        themeProvider.setMode(v);
                        Navigator.of(context).pop();
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _openFixAndGrammaPage() {
    final provider = context.read<TranslationProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FixAndGrammaScreen(
          initialText: _inputController.text,
          autoFix: provider.fixAndGrammaAutoRun,
          onApply: (text) {
            setState(() {
              _inputController.text = text;
              _inputController.selection =
                  TextSelection.collapsed(offset: text.length);
            });
          },
        ),
      ),
    );
  }
}

class FixAndGrammaScreen extends StatefulWidget {
  const FixAndGrammaScreen({
    super.key,
    required this.initialText,
    required this.onApply,
    this.autoFix = false,
  });
  final String initialText;
  final ValueChanged<String> onApply;
  final bool autoFix;

  @override
  State<FixAndGrammaScreen> createState() => _FixAndGrammaScreenState();
}

class _FixAndGrammaScreenState extends State<FixAndGrammaScreen> {
  late TextEditingController _inputController;
  String? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.initialText);
    if (widget.autoFix) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fix());
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _fix() async {
    final provider = context.read<TranslationProvider>();
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await provider.fixGrammarWithAlternatives(text: text);
      if (mounted) {
        setState(() {
          _result = res.rawOutput;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();
    final supports = provider.service is OllamaTranslationService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix & Gramma - Grammar & Style'),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy result',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _result!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Input Text',
                border: OutlineInputBorder(),
                hintText:
                    'Enter text to fix grammar and get style alternatives...',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: !_loading && supports ? _fix : null,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                      _loading ? 'Processing...' : 'Fix & Get Alternatives'),
                ),
                const SizedBox(width: 12),
                if (!supports)
                  const Expanded(
                    child: Text(
                      'Fix & Gramma not supported for current provider.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_result != null) ...[
              const Text('Result:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: Markdown(
                    data: _result!,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 14, height: 1.5),
                      code: TextStyle(
                        backgroundColor: Colors.grey.shade200,
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onApply(_result!);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Use Result'),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _result = null;
                      _error = null;
                    }),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ] else if (!_loading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Enter text and click "Fix & Get Alternatives"\nto see grammar corrections and style options',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HistorySheet extends StatelessWidget {
  const HistorySheet({super.key});
  @override
  Widget build(BuildContext context) {
    final history = context.watch<TranslationHistoryProvider>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('History',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_forever),
                  tooltip: 'Clear',
                  onPressed:
                      history.entries.isEmpty ? null : () => history.clear(),
                ),
              ],
            ),
            const Divider(),
            if (!history.loaded)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator()),
            if (history.loaded && history.entries.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16), child: Text('No history yet.')),
            if (history.entries.isNotEmpty)
              SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: history.entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = history.entries[i];
                    return ListTile(
                      title: Text(e.resultText,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${e.sourceLang} -> ${e.targetLang}\n${e.sourceText}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.of(context).pop();
                        // Optionally: fill fields
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  late TextEditingController _azureEndpointController;
  late TextEditingController _azureKeyController;
  late TextEditingController _azureRegionController;
  bool _saving = false;
  String _provider = 'ollama';

  @override
  void initState() {
    super.initState();
    final provider = context.read<TranslationProvider>();
    _baseUrlController = TextEditingController(text: provider.baseUrl);
    _modelController = TextEditingController(text: provider.model);
    _azureEndpointController =
        TextEditingController(text: provider.azureEndpoint);
    _azureKeyController = TextEditingController(text: provider.azureKey);
    _azureRegionController = TextEditingController(text: provider.azureRegion);
    _provider = provider.providerId;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _azureEndpointController.dispose();
    _azureKeyController.dispose();
    _azureRegionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });
    final tp = context.read<TranslationProvider>();
    await tp.updateSettings(
      providerId: _provider,
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      azureEndpoint: _azureEndpointController.text.trim(),
      azureKey: _azureKeyController.text.trim(),
      azureRegion: _azureRegionController.text.trim(),
    );
    if (mounted)
      setState(() {
        _saving = false;
      });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          DropdownButtonFormField<String>(
            value: _provider,
            items: const [
              DropdownMenuItem(value: 'ollama', child: Text('Ollama')),
              DropdownMenuItem(value: 'azure', child: Text('Azure Translator')),
            ],
            onChanged: (v) {
              if (v != null)
                setState(() {
                  _provider = v;
                });
            },
            decoration: const InputDecoration(labelText: 'Provider'),
          ),
          const SizedBox(height: 16),
          if (_provider == 'ollama') ...[
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                  labelText: 'Ollama Base URL',
                  hintText: 'http://localhost:11434'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration:
                  const InputDecoration(labelText: 'Model', hintText: 'llama3'),
            ),
          ] else ...[
            TextField(
              controller: _azureEndpointController,
              decoration: const InputDecoration(
                  labelText: 'Azure Endpoint',
                  hintText:
                      'https://your-resource.cognitiveservices.azure.com'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _azureKeyController,
              decoration: const InputDecoration(labelText: 'Azure Key'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _azureRegionController,
              decoration: const InputDecoration(
                  labelText: 'Azure Region', hintText: 'global or region'),
            ),
          ],
          const SizedBox(height: 24),
          StatefulBuilder(builder: (ctx, setInner) {
            final tp = context.read<TranslationProvider>();
            return SwitchListTile(
              title: const Text('Auto-run Fix & Gramma'),
              subtitle: const Text(
                  'When enabled, clicking the button immediately runs the fix. When disabled, it only opens the page.'),
              value: tp.fixAndGrammaAutoRun,
              onChanged: (v) async {
                await tp.setFixAndGrammaAutoRun(v);
                setInner(() {});
              },
            );
          }),
          const SizedBox(height: 24),
          Text('Clipboard Hotkey',
              style: Theme.of(context).textTheme.titleMedium),
          StatefulBuilder(builder: (ctx, setInner) {
            final svc = HotkeyActivationService.instance;
            final tp = context.read<TranslationProvider>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Activation key Ctrl+'),
                  DropdownButton<String>(
                    value: svc.activationKey,
                    items: ['T', 'K', 'L', 'Y', 'H']
                        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      svc.update(newActivationKey: v, provider: tp);
                      setInner(() {});
                    },
                  ),
                  const SizedBox(width: 16),
                  Text('Window: ${svc.sequenceWindowMs} ms'),
                ]),
                Slider(
                  min: 500,
                  max: 6000,
                  divisions: 11,
                  value: svc.sequenceWindowMs.toDouble(),
                  label: '${svc.sequenceWindowMs}',
                  onChanged: (val) {
                    svc.update(newWindowMs: val.round(), provider: tp);
                    setInner(() {});
                  },
                ),
                Text(
                    'Use: Copy text (Ctrl+C) then Ctrl+${svc.activationKey} within ${svc.sequenceWindowMs} ms.')
              ],
            );
          }),
          const Spacer(),
          ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: _saving ? const Text('Saving...') : const Text('Save'))
        ]),
      ),
    );
  }
}
