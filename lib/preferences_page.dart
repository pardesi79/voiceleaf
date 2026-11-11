import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'extractors.dart';
import 'app_prefs.dart';
import 'ui_text.dart';
import 'l10n.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  static const _items = <List<String>>[
    ['dark', 'Dark Theme'],
    ['readAuto', 'Read Automatically'],
    ['screenReaderText', 'Access audiobook current page text with Screen reader'],
    ['continueBg', 'Continue Audiobook Reading when switching app or screen turned off'],
    ['processingSound', 'Processing Sound'],
    ['completeSound', 'Process Complete Indicator Sound'],
    ['pageVoice', 'Page processing voice update'],
    ['pageTurn', 'Page Turn Sound'],
  ];

  /// Reads two pictures that ship with the app. If these come back with
  /// words in them, text recognition works and any failure is elsewhere.
  Future<void> _testOcr(BuildContext context) async {
    final dir = await getTemporaryDirectory();
    final out = <String>[];
    for (final e in <List<String>>[
      ['assets/ocr_test_en.png', 'latin', 'English'],
      ['assets/ocr_test_hi.png', 'devanagari', 'Hindi'],
    ]) {
      try {
        final data = await rootBundle.load(e[0]);
        final f = File('${dir.path}/${e[0].split('/').last}');
        await f.writeAsBytes(data.buffer.asUint8List());
        final t = await Extractors.ocrFile(f, e[1]);
        final clean = t.trim().replaceAll('\n', ' ');
        out.add('${e[2]}: ${clean.isEmpty ? 'nothing found' : clean}');
      } catch (err) {
        out.add('${e[2]}: failed ($err)');
      }
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Text recognition test'),
        content: SingleChildScrollView(child: SelectableText(out.join('\n\n'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Tx('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('Preferences')),
      body: ListenableBuilder(
        listenable: AppPrefs.I,
        builder: (_, __) => ListView(
          children: [
            for (final it in _items)
              SwitchListTile(
                title: Tx(it[1], style: const TextStyle(fontSize: 18)),
                value: AppPrefs.I.flag(it[0]),
                onChanged: (v) => AppPrefs.I.setFlag(it[0], v),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: AppPrefs.I.ocr,
                decoration: InputDecoration(
                    labelText: tr('Text recognition language (photos, scanned PDFs)'),
                    border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Tx('Auto (detects the script)')),
                  DropdownMenuItem(value: 'latin', child: Tx('English / Latin only')),
                  DropdownMenuItem(value: 'devanagari', child: Tx('Hindi / Devanagari only')),
                  DropdownMenuItem(value: 'chinese', child: Tx('Chinese only')),
                  DropdownMenuItem(value: 'japanese', child: Tx('Japanese only')),
                  DropdownMenuItem(value: 'korean', child: Tx('Korean only')),
                ],
                onChanged: (v) {
                  if (v != null) AppPrefs.I.setOcr(v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.text_fields),
                label: const Tx('Test text recognition'),
                onPressed: () => _testOcr(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
