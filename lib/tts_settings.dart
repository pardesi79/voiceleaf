import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'app_prefs.dart';
import 'ui_text.dart';
import 'l10n.dart';

const _names = <String, String>{
  'en': 'English', 'hi': 'Hindi', 'bn': 'Bengali', 'ta': 'Tamil',
  'te': 'Telugu', 'mr': 'Marathi', 'gu': 'Gujarati', 'kn': 'Kannada',
  'ml': 'Malayalam', 'pa': 'Punjabi', 'ur': 'Urdu', 'ne': 'Nepali',
  'as': 'Assamese', 'or': 'Odia', 'ar': 'Arabic', 'fr': 'French',
  'de': 'German', 'es': 'Spanish', 'pt': 'Portuguese', 'ru': 'Russian',
  'ja': 'Japanese', 'zh': 'Chinese', 'ko': 'Korean', 'it': 'Italian',
  'id': 'Indonesian', 'tr': 'Turkish', 'th': 'Thai', 'vi': 'Vietnamese',
  'nl': 'Dutch', 'pl': 'Polish', 'sv': 'Swedish', 'fa': 'Persian',
  'he': 'Hebrew', 'el': 'Greek',
};

String languageLabel(String code) {
  final base = code.split(RegExp(r'[-_]')).first.toLowerCase();
  final n = _names[base];
  return n == null ? code : '$n ($code)';
}

/// "Select Language" list with search.
class LanguagePage extends StatefulWidget {
  final List<String> languages;
  final String? current;
  const LanguagePage({super.key, required this.languages, this.current});
  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  bool searching = false;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.languages
        .where((c) => languageLabel(c).toLowerCase().contains(q.toLowerCase()))
        .toList()
      ..sort((a, b) => languageLabel(a).compareTo(languageLabel(b)));
    return Scaffold(
      appBar: AppBar(
        title: searching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                    hintText: tr('Search language'),
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none),
                onChanged: (v) => setState(() => q = v),
              )
            : const Tx('Select Language'),
        actions: [
          IconButton(
            tooltip: searching ? 'Close search' : 'Search',
            icon: Icon(searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              searching = !searching;
              q = '';
            }),
          ),
        ],
      ),
      body: list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Tx('No languages found for the current voice engine.',
                    style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
              ),
            )
          : ListView(children: [
              ListTile(
                title: const Tx('Detect Automatically', style: TextStyle(fontSize: 18)),
                selected: widget.current == null,
                onTap: () => Navigator.pop(context, ''),
              ),
              for (final c in list)
                ListTile(
                  title: Tx(languageLabel(c), style: const TextStyle(fontSize: 18)),
                  selected: c == widget.current,
                  onTap: () => Navigator.pop(context, c),
                ),
            ]),
    );
  }
}

/// Choose ANY installed TTS engine and voice.
class TtsSettingsPage extends StatefulWidget {
  final FlutterTts tts;
  const TtsSettingsPage({super.key, required this.tts});
  @override
  State<TtsSettingsPage> createState() => _TtsSettingsPageState();
}

class _TtsSettingsPageState extends State<TtsSettingsPage> {
  List<String> engines = [];
  String? engine;
  List<Map<String, String>> voices = [];
  String? voiceName;
  bool loading = true;

  FlutterTts get tts => widget.tts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final p = AppPrefs.I;
    try {
      engines = ((await tts.getEngines) as List).map((e) => e.toString()).toList();
    } catch (_) {}
    final saved = p.str('engine');
    if (saved != null && engines.contains(saved)) {
      engine = saved;
    } else {
      try {
        engine = (await tts.getDefaultEngine)?.toString();
      } catch (_) {}
    }
    await _loadVoices();
    voiceName = p.str('voiceName');
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadVoices() async {
    try {
      final v = await tts.getVoices;
      voices = (v as List)
          .map((e) => Map<String, String>.from(
              (e as Map).map((k, val) => MapEntry(k.toString(), val.toString()))))
          .toList();
      final lang = AppPrefs.I.str('lang');
      if (lang != null) {
        final base = lang.split(RegExp(r'[-_]')).first.toLowerCase();
        final f = voices
            .where((m) => (m['locale'] ?? '').toLowerCase().startsWith(base))
            .toList();
        if (f.isNotEmpty) voices = f;
      }
      voices.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    } catch (_) {
      voices = [];
    }
  }

  Future<void> _setEngine(String e) async {
    await tts.stop();
    await tts.setEngine(e);
    engine = e;
    await AppPrefs.I.setStr('engine', e);
    await AppPrefs.I.remove('voiceName');
    await AppPrefs.I.remove('voiceLocale');
    voiceName = null;
    await tts.setSpeechRate(AppPrefs.I.dbl('rate', 0.5));
    await tts.setPitch(AppPrefs.I.dbl('pitch', 1.0));
    await _loadVoices();
    if (mounted) setState(() {});
  }

  Future<void> _setVoice(String name) async {
    final v = voices.firstWhere((m) => m['name'] == name);
    await tts.setVoice({'name': name, 'locale': v['locale'] ?? ''});
    voiceName = name;
    await AppPrefs.I.setStr('voiceName', name);
    await AppPrefs.I.setStr('voiceLocale', v['locale'] ?? '');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('TTS and Voice Settings')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Tx('Voice engine', style: TextStyle(fontSize: 18)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: engines.contains(engine) ? engine : null,
                  hint: const Tx('Default engine'),
                  items: [
                    for (final e in engines) DropdownMenuItem(value: e, child: Tx(e)),
                  ],
                  onChanged: (e) {
                    if (e != null) _setEngine(e);
                  },
                ),
                const SizedBox(height: 16),
                const Tx('Voice', style: TextStyle(fontSize: 18)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: voices.any((m) => m['name'] == voiceName) ? voiceName : null,
                  hint: const Tx('Default voice'),
                  items: [
                    for (final m in voices)
                      DropdownMenuItem(
                          value: m['name'],
                          child: Txf('{1} ({2})', ['${m['name']}', '${m['locale']}'],
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (n) {
                    if (n != null) _setVoice(n);
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Tx('Test voice'),
                  onPressed: () async {
                    await tts.stop();
                    await tts.speak('This is a test of the selected voice.');
                  },
                ),
                const SizedBox(height: 16),
                const Tx(
                  'Install any text-to-speech app on your phone and it will appear in the engine list.',
                ),
              ],
            ),
    );
  }
}
