import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translator_app/features/translation/translation_provider.dart';
import 'package:translator_app/features/settings/theme_provider.dart';
import 'package:translator_app/features/history/translation_history_provider.dart';

void main() {
  runApp(const TranslatorRoot());
}

class TranslatorRoot extends StatelessWidget {
  const TranslatorRoot({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TranslationProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => TranslationHistoryProvider()..init()),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Translator',
      themeMode: themeProvider.mode,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark)),
      home: const TranslatorScreen(),
    );
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

  Future<void> _doTranslate() async {
    final provider = context.read<TranslationProvider>();
    final history = context.read<TranslationHistoryProvider>();
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await provider.translate(text: text, targetLang: _targetLang, sourceLang: _sourceLang);
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
      if (mounted) setState(() { _loading = false; });
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
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: provider.initialized ? _buildBody() : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        final content = wide ? _wideLayout() : _narrowLayout();
        return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: content);
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
            setState(() { final tmp = _sourceLang; _sourceLang = _targetLang; _targetLang = tmp; });
          },
        ),
        const SizedBox(width: 12),
        Expanded(child: _langDropdown(false)),
      ],
    );
  }

  Widget _editorCard(TextEditingController controller, String label, bool readOnly) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          readOnly: readOnly,
          decoration: InputDecoration(border: InputBorder.none, labelText: label),
        ),
      ),
    );
  }

  Widget _actionRow() {
    return Row(children: [
      ElevatedButton.icon(onPressed: _loading ? null : _doTranslate, icon: const Icon(Icons.translate), label: const Text('Translate')),
      const SizedBox(width: 12),
      if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      if (_error != null) Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red)))
    ]);
  }

  Widget _langDropdown(bool source) {
    final items = <String>['auto','English','Spanish','French','German','Italian','Portuguese','Chinese','Japanese','Korean','Arabic','Russian'];
    final value = source ? _sourceLang : _targetLang;
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) { if (v==null) return; setState(() { if (source) _sourceLang = v; else _targetLang = v; }); },
      decoration: InputDecoration(labelText: source ? 'From' : 'To', border: const OutlineInputBorder()),
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
          children: ThemeMode.values.map((m) => RadioListTile<ThemeMode>(
            title: Text(m.name),
            value: m,
            groupValue: themeProvider.mode,
            onChanged: (v) { if (v!=null) { themeProvider.setMode(v); Navigator.of(context).pop(); } },
          )).toList(),
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
                const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_forever),
                  tooltip: 'Clear',
                  onPressed: history.entries.isEmpty ? null : () => history.clear(),
                ),
              ],
            ),
            const Divider(),
            if (!history.loaded) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
            if (history.loaded && history.entries.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No history yet.')),
            if (history.entries.isNotEmpty)
              SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: history.entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = history.entries[i];
                    return ListTile(
                      title: Text(e.resultText, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${e.sourceLang} -> ${e.targetLang}\n${e.sourceText}', maxLines: 2, overflow: TextOverflow.ellipsis),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TranslationProvider>();
    _baseUrlController = TextEditingController(text: provider.baseUrl);
    _modelController = TextEditingController(text: provider.model);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; });
    await context.read<TranslationProvider>().updateSettings(
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );
    if (mounted) setState(() { _saving = false; });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(labelText: 'Ollama Base URL', hintText: 'http://localhost:11434'),
          ),
          const SizedBox(height: 12),
            TextField(
            controller: _modelController,
            decoration: const InputDecoration(labelText: 'Model', hintText: 'llama3'),
          ),
          const Spacer(),
          ElevatedButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: _saving ? const Text('Saving...') : const Text('Save'))
        ]),
      ),
    );
  }
}
