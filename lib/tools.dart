import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'models.dart';
import 'storage.dart';
import 'widgets.dart';
import 'ui_text.dart';
import 'l10n.dart';

/// Saved bookmarks list.
class BookmarksPage extends StatefulWidget {
  final Book book;
  const BookmarksPage({super.key, required this.book});
  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  @override
  Widget build(BuildContext context) {
    final list = widget.book.bookmarks;
    return Scaffold(
      appBar: AppBar(title: const Tx('Bookmarks')),
      body: list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Tx('No bookmarks yet.',
                    style: TextStyle(fontSize: 18)),
              ),
            )
          : ListView(children: [
              for (final b in List<Bookmark>.from(list))
                ListTile(
                  title: Txf('Page {1}', ['${b.page + 1}'],
                      style: const TextStyle(fontSize: 18)),
                  subtitle: Tx(b.label),
                  onTap: () => Navigator.pop(context, b),
                  trailing: IconButton(
                    tooltip: tr('Delete bookmark'),
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() => widget.book.bookmarks.remove(b));
                      Storage.save(widget.book);
                    },
                  ),
                ),
            ]),
    );
  }
}

class _Hit {
  final int page;
  final int offset;
  final String snippet;
  _Hit(this.page, this.offset, this.snippet);
}

/// Search the whole audiobook. Returns [page, offset].
class SearchPage extends StatefulWidget {
  final Book book;
  const SearchPage({super.key, required this.book});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<_Hit> hits = [];
  bool searched = false;

  void _run(String q) {
    final needle = q.trim().toLowerCase();
    final out = <_Hit>[];
    if (needle.isNotEmpty) {
      final book = widget.book;
      for (var p = 0; p < book.pages.length && out.length < 300; p++) {
        final t = book.applySkips(book.pages[p]);
        final low = t.toLowerCase();
        var i = low.indexOf(needle);
        while (i >= 0 && out.length < 300) {
          final a = max(0, i - 20);
          final b = min(t.length, i + needle.length + 40);
          out.add(_Hit(p, i, t.substring(a, b).replaceAll('\n', ' ')));
          i = low.indexOf(needle, i + needle.length);
        }
      }
    }
    setState(() {
      hits = out;
      searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('Search Text')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: tr('Type a word or phrase'),
                border: OutlineInputBorder()),
            onSubmitted: _run,
          ),
        ),
        if (searched)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Semantics(
                liveRegion: true,
                child: Txf('{1} result(s)', ['${hits.length}'],
                    style: const TextStyle(fontSize: 16))),
          ),
        Expanded(
          child: ListView(children: [
            for (final h in hits)
              ListTile(
                title: Tx(h.snippet),
                subtitle: Txf('Page {1}', ['${h.page + 1}']),
                onTap: () => Navigator.pop(context, [h.page, h.offset]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Reading statistics for the audiobook and the current page.
class TrackReadingPage extends StatelessWidget {
  final Book book;
  final int page;
  final int cur;
  final double rate;
  const TrackReadingPage(
      {super.key,
      required this.book,
      required this.page,
      required this.cur,
      required this.rate});

  @override
  Widget build(BuildContext context) {
    final cps = charsPerSecond(rate);
    final text = book.applySkips(book.pages[page]);
    final c = cur.clamp(0, text.length).toInt();
    var total = 0, left = 0;
    for (var i = 0; i < book.pages.length; i++) {
      final len = book.applySkips(book.pages[i]).length;
      total += len;
      if (i > page) left += len;
      if (i == page) left += len - c;
    }
    final pageLeft = text.length - c;
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final curWord = text
            .substring(0, c)
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length +
        1;
    final paras = text.split('\n').where((l) => l.trim().isNotEmpty).length;
    final curPara = text
            .substring(0, c)
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .length
            .clamp(1, max(1, paras))
            .toInt();

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Semantics(
            container: true,
            child: Row(children: [
              Expanded(child: Tx(k, style: const TextStyle(fontSize: 18))),
              Tx(v, style: const TextStyle(fontSize: 18)),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Tx('Track Reading')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Tx('Audiobook Stats',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        row('Total Reading Time', fmtLong((total / cps).round())),
        row('Reading Time left', fmtLong((left / cps).round())),
        row('Total Pages', '${book.pages.length}'),
        row('Current Page', '${page + 1}'),
        const SizedBox(height: 16),
        Txf('Page {1} stats', ['${page + 1}'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        row('Total Reading Time', fmtLong((text.length / cps).round())),
        row('Reading Time left', fmtLong((pageLeft / cps).round())),
        row('Total words', '$words'),
        row('Current word', '$curWord'),
        row('Total Paragraphs', '$paras'),
        row('Current Paragraph', '$curPara'),
      ]),
    );
  }
}

/// Text notes for the audiobook (saved automatically).
class NotesPage extends StatefulWidget {
  final Book book;
  const NotesPage({super.key, required this.book});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final TextEditingController c =
      TextEditingController(text: widget.book.notes);

  @override
  void dispose() {
    widget.book.notes = c.text;
    Storage.save(widget.book);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('Text Notes')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: c,
          expands: true,
          maxLines: null,
          minLines: null,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
              hintText: tr('Write your notes (saved automatically)'),
              border: OutlineInputBorder()),
        ),
      ),
    );
  }
}

/// Translate the whole audiobook on the phone (ML Kit). Returns the new Book.
class TranslatePage extends StatefulWidget {
  final Book book;
  const TranslatePage({super.key, required this.book});
  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  TranslateLanguage from = TranslateLanguage.english;
  TranslateLanguage to = TranslateLanguage.hindi;
  bool busy = false;
  String status = '';

  String _name(TranslateLanguage l) =>
      l.name[0].toUpperCase() + l.name.substring(1);

  Future<void> _go() async {
    final book = widget.book;
    setState(() {
      busy = true;
      status = 'Preparing language models...';
    });
    try {
      final mm = OnDeviceTranslatorModelManager();
      for (final l in [from, to]) {
        if (!await mm.isModelDownloaded(l.bcpCode)) {
          if (mounted) {
            setState(() =>
                status = 'Downloading ${_name(l)} model (internet needed once)...');
          }
          await mm.downloadModel(l.bcpCode, isWifiRequired: false);
        }
      }
      final tr = OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);
      final out = <String>[];
      try {
        for (var i = 0; i < book.pages.length; i++) {
          if (mounted) {
            setState(() => status = 'Translating page ${i + 1} of ${book.pages.length}...');
          }
          out.add(await tr.translateText(book.applySkips(book.pages[i])));
        }
      } finally {
        await tr.close();
      }
      final nb = Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${book.title} (${_name(to)})',
        pages: out,
      );
      await Storage.save(nb);
      if (mounted) Navigator.pop(context, nb);
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _drop(String label, TranslateLanguage v, void Function(TranslateLanguage) f) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<TranslateLanguage>(
          value: v,
          isExpanded: true,
          decoration:
              InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: [
            for (final l in TranslateLanguage.values)
              DropdownMenuItem(value: l, child: Tx(_name(l))),
          ],
          onChanged: busy
              ? null
              : (x) {
                  if (x != null) setState(() => f(x));
                },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('Translate')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _drop('Translate From Language', from, (x) => from = x),
        _drop('Translate To Language', to, (x) => to = x),
        if (busy)
          Semantics(
            liveRegion: true,
            child: Column(children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Tx(status, style: const TextStyle(fontSize: 16)),
            ]),
          ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: kPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52)),
          onPressed: busy ? null : _go,
          child: const Tx('Translate audiobook', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 12),
        const Tx(
            'A new audiobook is created with the translated text. Language models download once, then work offline.'),
      ]),
    );
  }
}
