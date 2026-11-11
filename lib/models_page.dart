import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'audio_export.dart';
import 'l10n.dart';
import 'ui_text.dart';
import 'widgets.dart';

String langName(TranslateLanguage l) =>
    l.name[0].toUpperCase() + l.name.substring(1);

/// Change the language of buttons, menus and messages.
class UiLanguagePage extends StatelessWidget {
  const UiLanguagePage({super.key});

  Future<void> _pick(BuildContext context, TranslateLanguage l) async {
    final ok = await runWithProgress<bool>(context, 'Changing language',
        (update, cancelled) async {
      await L10n.I.setLanguage(l, update);
      return true;
    });
    if (!context.mounted) return;
    if (ok != true) {
      toast(context,
          'Could not change the language. Internet is needed once to download it.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('Select App Display Language')),
      body: ListView(children: [
        for (final l in TranslateLanguage.values)
          ListTile(
            title: Tx(langName(l), style: const TextStyle(fontSize: 18)),
            selected: l.bcpCode == L10n.I.code,
            onTap: () => _pick(context, l),
          ),
      ]),
    );
  }
}

/// Offline language dictionaries (ML Kit translation models).
class ModelsPage extends StatefulWidget {
  const ModelsPage({super.key});
  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  final mm = OnDeviceTranslatorModelManager();
  final Map<String, bool> have = {};
  final Set<String> working = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    for (final l in TranslateLanguage.values) {
      have[l.bcpCode] = await mm.isModelDownloaded(l.bcpCode);
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggle(TranslateLanguage l) async {
    setState(() => working.add(l.bcpCode));
    try {
      if (have[l.bcpCode] == true) {
        await mm.deleteModel(l.bcpCode);
        have[l.bcpCode] = false;
      } else {
        await mm.downloadModel(l.bcpCode, isWifiRequired: false);
        have[l.bcpCode] = true;
      }
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    }
    if (mounted) setState(() => working.remove(l.bcpCode));
  }

  Future<void> _all() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Download all languages?'),
        content: const Tx(
            'Every language is about 30 MB, so all of them need over 1 GB of space and internet. You can cancel any time.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Tx('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Tx('Download')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runWithProgress<bool>(context, 'Downloading languages', (update, cancelled) async {
      final all = TranslateLanguage.values;
      for (var i = 0; i < all.length; i++) {
        if (cancelled()) break;
        final l = all[i];
        if (have[l.bcpCode] == true) continue;
        update('${langName(l)} (${i + 1} of ${all.length})');
        try {
          await mm.downloadModel(l.bcpCode, isWifiRequired: false);
          have[l.bcpCode] = true;
        } catch (_) {}
      }
      return true;
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('Languages and offline dictionaries')),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Tx(
              'Text recognition for Latin, Hindi, Chinese, Japanese and Korean is built into the app. Translation languages download the first time you use them, or you can download them here.'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: kPurple, foregroundColor: Colors.white),
            onPressed: _all,
            child: const Tx('Download all languages'),
          ),
        ),
        for (final l in TranslateLanguage.values)
          ListTile(
            title: Tx(langName(l), style: const TextStyle(fontSize: 18)),
            subtitle: Tx(have[l.bcpCode] == true ? 'Downloaded' : 'Not downloaded'),
            trailing: working.contains(l.bcpCode)
                ? const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    tooltip: have[l.bcpCode] == true
                        ? 'Delete ${langName(l)}'
                        : 'Download ${langName(l)}',
                    icon: Icon(have[l.bcpCode] == true ? Icons.delete : Icons.download),
                    onPressed: () => _toggle(l),
                  ),
          ),
      ]),
    );
  }
}
