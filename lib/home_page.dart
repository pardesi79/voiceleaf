import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'create_flow.dart';
import 'exporter.dart';
import 'models.dart';
import 'models_page.dart';
import 'player_page.dart';
import 'preferences_page.dart';
import 'storage.dart';
import 'tts_settings.dart';
import 'widgets.dart';
import 'ui_text.dart';
import 'l10n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Book> books = [];
  String query = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await Storage.all();
    if (mounted) {
      setState(() {
        books = b;
        loading = false;
      });
    }
  }

  Future<void> _open(Book b, {bool autoStart = false}) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlayerPage(book: b, autoStart: autoStart)));
    _load();
  }

  void _create() {
    showMenuSheet(context, [
      MenuEntry(Icons.upload_file,
          'Upload PDF, Photos, DOCX, TXT, PPT, EXCEL or Voiceleaf Audiobook Zip',
          () => _do('upload')),
      MenuEntry(Icons.photo_camera, 'Take Photo from Camera', () => _do('camera')),
      MenuEntry(Icons.link, 'Read from web page link', () => _do('web')),
      MenuEntry(Icons.content_paste, 'Read text', () => _do('text')),
    ]);
  }

  Future<void> _do(String choice) async {
    final b = await runCreate(context, choice);
    await _load();
    if (b != null && mounted) _open(b, autoStart: true);
  }

  void _itemMenu(Book b) {
    showMenuSheet(context, [
      MenuEntry(Icons.download, 'Download Audiobook',
          () => showFormatSheet(context, b, share: false)),
      MenuEntry(Icons.share, 'Share Audiobook',
          () => showFormatSheet(context, b, share: true)),
      MenuEntry(Icons.delete, 'Delete Audiobook', () => _delete(b)),
    ]);
  }

  Future<void> _delete(Book b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Delete audiobook?'),
        content: Tx(b.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Tx('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Tx('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await Storage.delete(b.id);
      _load();
    }
  }

  void _howTo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('How to use app'),
        content: const SingleChildScrollView(
          child: Tx(
              '1. Tap "Create new Audiobook" and choose a file, a photo, a web link or text.\n\n'
              '2. The book opens and reads aloud. Use the bottom buttons to go back or forward by word, sentence, paragraph or page.\n\n'
              'Swipe left or right on the text to move by the chosen unit.\n\n'
              '3. The gear button has voice, speed, pitch, font size and language settings. The wrench button has share, download, notes, bookmarks, search, translate and more.\n\n'
              '4. Tap the save button to name your audiobook.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Tx('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = books
        .where((b) => b.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          style: const TextStyle(color: Colors.white, fontSize: 18),
          cursorColor: Colors.white,
          decoration: InputDecoration(
              hintText: tr('Search your Audiobooks'),
              hintStyle: TextStyle(color: Colors.white70)),
          onChanged: (v) => setState(() => query = v),
        ),
        actions: const [
          Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.search, semanticLabel: 'Search')),
        ],
      ),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: kPurple),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Tx('Voiceleaf\nVersion 1.0.0',
                  style: TextStyle(color: Colors.white, fontSize: 22)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Tx('Help',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
              title: const Tx('How to use app'),
              onTap: () {
                Navigator.pop(context);
                _howTo();
              }),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Tx('General',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
              title: const Tx('Preferences'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PreferencesPage()));
              }),
          ListTile(
              title: const Tx('TTS and Voice Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TtsSettingsPage(tts: FlutterTts())));
              }),
          ListTile(
              title: const Tx('Change App Display Language'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UiLanguagePage()));
              }),
          ListTile(
              title: const Tx('Languages and offline dictionaries'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ModelsPage()));
              }),
          ListTile(title: const Tx('Close'), onTap: () => Navigator.pop(context)),
        ]),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : shown.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Tx(
                      'Welcome :)\nYou have no audiobooks yet.\n'
                      'Tap the Create new Audiobook button to make one from a photo, PDF, DOCX, PPT, EXCEL, TXT, web page link or text.\n'
                      'Open the menu button at the top left for help and settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final b = shown[i];
                    return ListTile(
                      leading: const Icon(Icons.menu_book),
                      title: Tx(b.title, style: const TextStyle(fontSize: 18)),
                      subtitle: Tx(leftLabel(b)),
                      onTap: () => _open(b),
                      trailing: IconButton(
                        tooltip: 'More options for ${b.title}',
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => _itemMenu(b),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPurple,
        foregroundColor: Colors.white,
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Tx('Create new Audiobook', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
