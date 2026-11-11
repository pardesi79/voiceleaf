import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'app_prefs.dart';
import 'exporter.dart';
import 'lang_detect.dart';
import 'models.dart';
import 'preferences_page.dart';
import 'storage.dart';
import 'tools.dart';
import 'tts_settings.dart';
import 'voice_notes.dart';
import 'widgets.dart';
import 'ui_text.dart';
import 'l10n.dart';

class PlayerPage extends StatefulWidget {
  final Book book;
  final bool autoStart;
  const PlayerPage({super.key, required this.book, this.autoStart = false});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  final FlutterTts tts = FlutterTts();
  final TextEditingController gotoCtrl = TextEditingController();
  late int page;
  String _text = '';
  int cur = 0; // start of the word being spoken
  int curEnd = 0; // end of that word
  int base = 0; // where the current speak() call started
  bool playing = false;
  double rate = 0.5, pitch = 1.0;
  int fontPct = 16;
  String navMode = 'sentence'; // word | sentence | paragraph | page
  String? _autoLang;

  Book get book => widget.book;
  String get text => _text;
  AppPrefs get prefs => AppPrefs.I;
  double get font => 12 + 48 * fontPct / 100;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    page = book.page.clamp(0, book.pages.length - 1).toInt();
    _refreshText();
    cur = book.offset.clamp(0, _text.length).toInt();
    curEnd = cur;
    _initTts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gotoCtrl.dispose();
    playing = false;
    _save();
    tts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused && playing && !prefs.flag('continueBg')) {
      _pause();
    }
  }

  void _refreshText() => _text = book.applySkips(book.pages[page]);

  void _save() {
    book.page = page;
    book.offset = cur;
    Storage.save(book);
  }

  Future<void> _initTts() async {
    rate = prefs.dbl('rate', 0.5);
    pitch = prefs.dbl('pitch', 1.0);
    fontPct = prefs.intv('fontPct', 16);
    navMode = prefs.str('navMode') ?? 'sentence';
    final eng = prefs.str('engine');
    if (eng != null) {
      try {
        await tts.setEngine(eng);
      } catch (_) {}
    }
    final lang = prefs.str('lang');
    if (lang != null) {
      try {
        await tts.setLanguage(lang);
      } catch (_) {}
    }
    final vn = prefs.str('voiceName');
    final vl = prefs.str('voiceLocale');
    if (vn != null && vl != null) {
      try {
        await tts.setVoice({'name': vn, 'locale': vl});
      } catch (_) {}
    }
    await tts.setSpeechRate(rate);
    await tts.setPitch(pitch);
    tts.setProgressHandler((String t, int start, int end, String word) {
      if (!mounted || !playing) return;
      setState(() {
        cur = base + start;
        curEnd = base + end;
      });
    });
    tts.setCompletionHandler(_onDone);
    if (mounted) setState(() {});
    if (widget.autoStart && prefs.flag('readAuto') && mounted) _play(cur);
  }

  void _onDone() {
    if (!playing || !mounted) return;
    if (page < book.pages.length - 1) {
      if (prefs.flag('pageTurn')) SystemSound.play(SystemSoundType.click);
      setState(() {
        page++;
        _refreshText();
        cur = 0;
        curEnd = 0;
      });
      _play(0);
    } else {
      setState(() {
        playing = false;
        cur = 0;
        curEnd = 0;
      });
      _save();
    }
  }

  Future<void> _play([int? from]) async {
    var start = from ?? cur;
    if (start >= text.length) start = 0;
    base = start;
    setState(() {
      cur = start;
      curEnd = start;
      playing = true;
    });
    if (prefs.str('lang') == null) {
      final code = detectTtsLang(text);
      if (code != _autoLang) {
        try {
          await tts.setLanguage(code);
          _autoLang = code;
        } catch (_) {}
      }
    }
    await tts.stop();
    if (text.isEmpty) {
      _onDone();
      return;
    }
    await tts.speak(text.substring(start));
  }

  Future<void> _pause() async {
    setState(() => playing = false);
    await tts.stop();
    _save();
  }

  void _jump(int off) {
    if (playing) {
      _play(off);
    } else {
      setState(() {
        cur = off;
        curEnd = off;
      });
      _save();
    }
  }

  void _goPage(int p, {int offset = 0}) {
    if (p < 0 || p >= book.pages.length) return;
    if (playing && prefs.flag('pageTurn')) {
      SystemSound.play(SystemSoundType.click);
    }
    setState(() {
      page = p;
      _refreshText();
      cur = offset.clamp(0, _text.length).toInt();
      curEnd = cur;
    });
    if (playing) {
      _play(cur);
    } else {
      _save();
    }
  }

  // ---- navigation by word / sentence / paragraph / page ----

  RegExp get _unitRe {
    switch (navMode) {
      case 'word':
        return RegExp(r'\s+');
      case 'paragraph':
        return RegExp(r'\n+');
      default:
        return RegExp(r'[.!?।]\s+|\n');
    }
  }

  List<int> get _unitStarts =>
      <int>[0, ..._unitRe.allMatches(text).map((m) => m.end)];

  void _next() {
    if (navMode == 'page') {
      _goPage(page + 1);
      return;
    }
    final m = _unitRe.allMatches(text, cur).firstOrNull;
    if (m == null || m.end >= text.length) {
      _goPage(page + 1);
    } else {
      _jump(m.end);
    }
  }

  void _prev() {
    if (navMode == 'page') {
      _goPage(page - 1);
      return;
    }
    final slack = navMode == 'word' ? 0 : 2;
    final before = _unitStarts.where((s) => s < cur - slack).toList();
    if (before.isNotEmpty) {
      _jump(before.last);
    } else if (page > 0) {
      _goPage(page - 1);
    } else {
      _jump(0);
    }
  }

  void _replay() {
    if (navMode == 'page') {
      _jump(0);
      return;
    }
    _jump(_unitStarts.where((s) => s <= cur).last);
  }

  void _skipSecs(int secs) {
    final n = (secs.abs() * charsPerSecond(rate)).round();
    if (secs > 0) {
      final t = cur + n;
      if (t >= text.length) {
        _goPage(page + 1);
      } else {
        final i = text.indexOf(RegExp(r'\s'), t);
        _jump(i < 0 ? t : i + 1);
      }
    } else {
      final t = cur - n;
      if (t <= 0) {
        if (page > 0) {
          _goPage(page - 1);
        } else {
          _jump(0);
        }
      } else {
        _jump(text.lastIndexOf(RegExp(r'\s'), t) + 1);
      }
    }
  }

  // ---- seek bar ----

  double _secs(int chars) => chars / charsPerSecond(rate);

  // ---- menus ----

  void _gearMenu() {
    showMenuSheet(context, [
      MenuEntry(Icons.chrome_reader_mode, 'Change Reading Navigation mode', _pickNavMode),
      MenuEntry(Icons.language, 'Set Audiobook Language', _pickLanguage),
      MenuEntry(Icons.record_voice_over, 'TTS and Voice Settings', _ttsSettings),
      MenuEntry(Icons.speed, 'Adjust Audio Speed', _speedSheet),
      MenuEntry(Icons.music_note, 'Adjust Audio Pitch', _pitchSheet),
      MenuEntry(Icons.format_size, 'Adjust Font Size', _fontSheet),
      MenuEntry(Icons.toggle_on, 'Preferences', () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PreferencesPage()));
        if (mounted) setState(() {});
      }),
    ]);
  }

  Future<void> _pickNavMode() async {
    final modes = {
      'word': 'Word',
      'sentence': 'Sentence',
      'paragraph': 'Paragraph',
      'page': 'Page',
    };
    final m = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Tx('Reading Navigation mode'),
        children: [
          for (final e in modes.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Tx(e.value + (e.key == navMode ? '  (selected)' : ''),
                  style: const TextStyle(fontSize: 18)),
            ),
        ],
      ),
    );
    if (m != null) {
      setState(() => navMode = m);
      await prefs.setStr('navMode', m);
    }
  }

  Future<void> _pickLanguage() async {
    var langs = <String>[];
    try {
      langs = ((await tts.getLanguages) as List).map((x) => x.toString()).toList();
    } catch (_) {}
    if (!mounted) return;
    final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                LanguagePage(languages: langs, current: prefs.str('lang'))));
    if (code != null) {
      if (code.isEmpty) {
        await prefs.remove('lang');
        _autoLang = null;
      } else {
        await tts.setLanguage(code);
        await prefs.setStr('lang', code);
      }
      await prefs.remove('voiceName');
      await prefs.remove('voiceLocale');
      if (playing) _play(cur);
    }
  }

  Future<void> _ttsSettings() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => TtsSettingsPage(tts: tts)));
    if (playing && mounted) _play(cur);
  }

  void _speedSheet() {
    showStepperSheet(context,
        title: 'Adjust Audio Speed',
        value: (rate * 100).round(),
        min: 10,
        max: 100,
        onChanged: (v) {
          rate = v / 100;
          tts.setSpeechRate(rate);
          prefs.setDbl('rate', rate);
        }).then((_) {
      if (playing && mounted) _play(cur);
    });
  }

  void _pitchSheet() {
    showStepperSheet(context,
        title: 'Adjust Audio Pitch',
        value: ((pitch - 0.5) / 1.5 * 100).round(),
        onChanged: (v) {
          pitch = 0.5 + v / 100 * 1.5;
          tts.setPitch(pitch);
          prefs.setDbl('pitch', pitch);
        }).then((_) {
      if (playing && mounted) _play(cur);
    });
  }

  void _fontSheet() {
    showStepperSheet(context,
        title: 'Adjust Font Size',
        value: fontPct,
        onChanged: (v) {
          setState(() => fontPct = v);
          prefs.setInt('fontPct', v);
        });
  }

  void _toolsMenu() {
    showMenuSheet(context, [
      MenuEntry(Icons.share, 'Share', () => showFormatSheet(context, book, share: true)),
      MenuEntry(Icons.download, 'Download', () => showFormatSheet(context, book, share: false)),
      MenuEntry(Icons.note_add, 'Notes', _notesMenu),
      MenuEntry(Icons.bookmark, 'Bookmark', _bookmarkMenu),
      MenuEntry(Icons.search, 'Search Text', _search),
      MenuEntry(Icons.track_changes, 'Track Reading', _track),
      MenuEntry(Icons.translate, 'Translate', _translate),
      MenuEntry(Icons.edit, 'Edit Current Page Text', _editPage),
      MenuEntry(Icons.copy, 'Copy Audiobook Text', _copyAll),
      MenuEntry(Icons.skip_next, 'Skip Text', _skipText),
    ]);
  }

  void _notesMenu() {
    showMenuSheet(context, [
      MenuEntry(Icons.text_fields, 'Text Notes', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => NotesPage(book: book)));
      }),
      MenuEntry(Icons.mic, 'Voice Notes', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => VoiceNotesPage(book: book)));
      }),
    ]);
  }

  void _bookmarkMenu() {
    showMenuSheet(context, [
      MenuEntry(Icons.add, 'Bookmark Current Page and Word', () {
        final end = (cur + 40).clamp(0, text.length).toInt();
        book.bookmarks.add(Bookmark(
            page, cur, text.substring(cur, end).replaceAll('\n', ' ')));
        Storage.save(book);
        toast(context, 'Bookmark added on page ${page + 1}.');
      }),
      MenuEntry(Icons.bookmarks, 'View Bookmarks', () async {
        final b = await Navigator.push<Bookmark>(context,
            MaterialPageRoute(builder: (_) => BookmarksPage(book: book)));
        if (b != null) _goPage(b.page, offset: b.offset);
      }),
    ]);
  }

  Future<void> _search() async {
    final r = await Navigator.push<List<int>>(
        context, MaterialPageRoute(builder: (_) => SearchPage(book: book)));
    if (r != null) _goPage(r[0], offset: r[1]);
  }

  void _track() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TrackReadingPage(
                book: book, page: page, cur: cur, rate: rate)));
  }

  Future<void> _translate() async {
    final nb = await Navigator.push<Book>(
        context, MaterialPageRoute(builder: (_) => TranslatePage(book: book)));
    if (nb != null && mounted) {
      toast(context, 'Translated audiobook "${nb.title}" added to your list.');
    }
  }

  Future<void> _editPage() async {
    final t = await askText(context, 'Edit Current Page Text', 'Page text',
        multiline: true, initial: book.pages[page], okLabel: 'Save');
    if (t == null) return;
    await _pause();
    book.pages[page] = t;
    await Storage.save(book);
    setState(() {
      _refreshText();
      cur = 0;
      curEnd = 0;
    });
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: bookText(book)));
    if (mounted) toast(context, 'Audiobook text copied.');
  }

  Future<void> _skipText() async {
    final t = await askText(
        context, 'Skip Text', 'One phrase per line (headers, footers...)',
        multiline: true, initial: book.skips.join('\n'), okLabel: 'Save');
    if (t == null) return;
    await _pause();
    book.skips = t.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await Storage.save(book);
    setState(() {
      _refreshText();
      cur = cur.clamp(0, _text.length).toInt();
      curEnd = cur;
    });
  }

  Future<void> _saveBook() async {
    final t = await askText(context, 'Save audiobook', 'Title',
        initial: book.title, okLabel: 'Save');
    if (t == null || t.isEmpty) return;
    setState(() => book.title = t);
    await Storage.save(book);
    if (mounted) toast(context, 'Audiobook saved!');
  }

  // ---- build ----

  Widget _round(IconData icon, String tip, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: IconButton.filled(
          style: IconButton.styleFrom(
              backgroundColor: kPurple, foregroundColor: Colors.white),
          tooltip: tip,
          icon: Icon(icon),
          onPressed: f,
        ),
      );

  Widget _ctl(IconData icon, String tip, VoidCallback f) => IconButton.filled(
        style: IconButton.styleFrom(
            backgroundColor: kPurple, foregroundColor: Colors.white),
        iconSize: 28,
        tooltip: tip,
        icon: Icon(icon),
        onPressed: f,
      );

  @override
  Widget build(BuildContext context) {
    final t = text;
    final s = cur.clamp(0, t.length).toInt();
    final e = curEnd.clamp(s, t.length).toInt();
    final cs = Theme.of(context).colorScheme;
    final style =
        DefaultTextStyle.of(context).style.copyWith(fontSize: font, height: 1.5);
    final unit = navMode;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Semantics(
              header: true,
              child: Txf('{1}/{2} | {3}',
                  ['${page + 1}', '${book.pages.length}', book.title],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: gotoCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.go,
                  decoration: InputDecoration(
                      hintText: tr('Go to Page'),
                      border: OutlineInputBorder(),
                      isDense: true),
                  onSubmitted: (v) {
                    final n = int.tryParse(v);
                    gotoCtrl.clear();
                    if (n != null) _goPage(n - 1);
                  },
                ),
              ),
              _round(Icons.settings, 'Reading settings', _gearMenu),
              _round(Icons.build, 'Tools', _toolsMenu),
              _round(Icons.save, 'Save audiobook', _saveBook),
            ]),
          ),
          Expanded(
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v < -250) _next();
                    if (v > 250) _prev();
                  },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: ExcludeSemantics(
                    excluding: !prefs.flag('screenReaderText'),
                    child: Text.rich(TextSpan(style: style, children: [
                      TextSpan(text: t.substring(0, s)),
                      TextSpan(
                        text: t.substring(s, e),
                        style: TextStyle(
                          backgroundColor: cs.primaryContainer,
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: t.substring(e)),
                    ])),
                  ),
                ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Column(children: [
                  Tx(fmtClock(_secs(s).round()),
                      style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Slider(
                        value: t.isEmpty ? 0 : s / t.length,
                        activeColor: kYellow,
                        thumbColor: kPurple,
                        semanticFormatterCallback: (v) =>
                            'Reading position ${(v * 100).round()} percent',
                        onChanged: (v) => setState(() {
                          cur = (v * t.length).floor();
                          curEnd = cur;
                        }),
                        onChangeEnd: (v) => _jump((v * t.length).floor()),
                      ),
                    ),
                  ),
                  Tx(fmtClock(_secs(t.length).round()),
                      style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ctl(Icons.arrow_back, 'Previous page', () => _goPage(page - 1)),
                _ctl(Icons.replay_10, 'Rewind 10 seconds', () => _skipSecs(-10)),
                _ctl(Icons.replay, 'Repeat $unit', _replay),
                IconButton.filled(
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.lightGreenAccent.shade100,
                      foregroundColor: kPurple),
                  iconSize: 40,
                  tooltip: playing ? 'Pause' : 'Play',
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: playing ? _pause : () => _play(),
                ),
                _ctl(Icons.forward_10, 'Forward 10 seconds', () => _skipSecs(10)),
                _ctl(Icons.arrow_forward, 'Next page', () => _goPage(page + 1)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
