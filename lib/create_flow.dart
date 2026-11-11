import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'app_prefs.dart';
import 'extractors.dart';
import 'models.dart';
import 'storage.dart';
import 'widgets.dart';
import 'ui_text.dart';
import 'l10n.dart';

typedef StatusFn = void Function(String message, {bool speak});

class _Outcome {
  final Extracted? ex;
  final String? error;
  _Outcome(this.ex, this.error);
}

/// "Creating AudioBook - Please Wait" screen.
class ProcessingPage extends StatefulWidget {
  final Future<Extracted?> Function(StatusFn status) job;
  const ProcessingPage({super.key, required this.job});
  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  String status = 'Starting...';
  bool _cancel = false;
  FlutterTts? voice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  @override
  void dispose() {
    voice?.stop();
    super.dispose();
  }

  Future<void> _go() async {
    try {
      final r = await widget.job((m, {bool speak = false}) {
        if (_cancel) throw 'cancelled';
        if (!mounted) return;
        setState(() => status = m);
        if (speak && AppPrefs.I.flag('pageVoice')) {
          voice ??= FlutterTts();
          voice!.speak(m);
        }
      });
      if (mounted) Navigator.pop(context, _Outcome(r, null));
    } catch (e) {
      if (mounted) Navigator.pop(context, _Outcome(null, e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kPurple,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Semantics(
                liveRegion: true,
                child: const Tx('Creating AudioBook\nPlease Wait',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: kYellow, fontSize: 30, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: kYellow),
              const SizedBox(height: 24),
              Tx(status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: kYellow),
                onPressed: () {
                  _cancel = true;
                  setState(() => status = 'Cancelling...');
                },
                child: const Tx('Cancel'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Choose Pages" screen shown for PDFs.
class ChoosePagesPage extends StatefulWidget {
  final int total;
  const ChoosePagesPage({super.key, required this.total});
  @override
  State<ChoosePagesPage> createState() => _ChoosePagesPageState();
}

class _ChoosePagesPageState extends State<ChoosePagesPage> {
  late final TextEditingController from = TextEditingController(text: '1');
  late final TextEditingController to =
      TextEditingController(text: '${widget.total}');
  bool includeNum = false;

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    super.dispose();
  }

  void _ok() {
    final a = int.tryParse(from.text) ?? 1;
    final b = int.tryParse(to.text) ?? widget.total;
    if (a < 1 || b > widget.total || a > b) {
      toast(context, 'Enter pages between 1 and ${widget.total}.');
      return;
    }
    Navigator.pop(context, [a, b, includeNum ? 1 : 0]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('Choose Pages')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Txf('This PDF has {1} pages.', ['${widget.total}'],
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: from,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: tr('From Page'), border: OutlineInputBorder()),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.chevron_right, semanticLabel: 'to'),
            ),
            Expanded(
              child: TextField(
                controller: to,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: tr('To Page'), border: OutlineInputBorder()),
              ),
            ),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Tx('Include Page Number'),
            value: includeNum,
            onChanged: (v) => setState(() => includeNum = v ?? false),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: kPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _ok,
              child: const Tx('OK', style: TextStyle(fontSize: 20)),
            ),
          ),
        ]),
      ),
    );
  }
}

String _stamp() => DateTime.now().toString().substring(0, 16);

String _baseName(String path) =>
    path.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.[^.]+$'), '');

const _imageExt = {'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'};

/// Runs one of: upload | camera | web | text. Returns the new book or null.
Future<Book?> runCreate(BuildContext context, String choice) async {
  final ocr = AppPrefs.I.ocr;

  Future<Book?> process(
      String defaultTitle, Future<Extracted?> Function(StatusFn) job) async {
    final out = await Navigator.push<_Outcome>(
        context, MaterialPageRoute(builder: (_) => ProcessingPage(job: job)));
    if (!context.mounted || out == null) return null;
    if (out.error != null) {
      toast(context,
          out.error == 'cancelled' ? 'Creating audiobook cancelled.' : 'Failed: ${out.error}');
      return null;
    }
    final ex = out.ex;
    if (ex == null) return null;
    if (ex.pages.isEmpty) {
      toast(context, 'No readable text was found.');
      return null;
    }
    final b = Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: ex.title.isEmpty ? defaultTitle : ex.title,
      pages: ex.pages,
    );
    await Storage.save(b);
    if (AppPrefs.I.flag('completeSound')) {
      SystemSound.play(SystemSoundType.alert);
    }
    return b;
  }

  switch (choice) {
    case 'camera':
      final shots = <String>[];
      while (true) {
        final x = await ImagePicker().pickImage(source: ImageSource.camera);
        if (x == null || !context.mounted) break;
        shots.add(x.path);
        final more = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Tx('Photo added'),
            content: Txf('{1} photo(s) ready.', ['${shots.length}']),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Tx('Done')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Tx('Add Next Photo')),
            ],
          ),
        );
        if (more != true || !context.mounted) break;
      }
      if (shots.isEmpty || !context.mounted) return null;
      return process('Photo ${_stamp()}', (st) async {
        final pages = await Extractors.images(shots, ocr,
            onProgress: (d, t) => st('Reading photo $d of $t...', speak: true));
        return Extracted('Photo ${_stamp()}', pages);
      });

    case 'web':
      final url = await askText(context, 'Web page link', 'https://...');
      if (url == null || url.isEmpty || !context.mounted) return null;
      return process(url, (st) async {
        st('Fetching web page...');
        return Extractors.web(url);
      });

    case 'text':
      final t = await askText(context, 'Read text', 'Paste or type here',
          multiline: true);
      if (t == null || t.isEmpty || !context.mounted) return null;
      return process('Text ${_stamp()}', (st) async {
        return Extracted('Text ${_stamp()}', paginate(t));
      });

    default: // upload
      final r = await FilePicker.platform
          .pickFiles(type: FileType.any, allowMultiple: true);
      if (r == null || r.files.isEmpty || !context.mounted) return null;
      final paths = r.files.map((f) => f.path).whereType<String>().toList();
      if (paths.isEmpty) return null;
      final first = paths.first;
      final ext = first.split('.').last.toLowerCase();

      if (_imageExt.contains(ext)) {
        final imgs = paths
            .where((p) => _imageExt.contains(p.split('.').last.toLowerCase()))
            .toList();
        return process('Photos ${_stamp()}', (st) async {
          final pages = await Extractors.images(imgs, ocr,
              onProgress: (d, t) => st('Reading photo $d of $t...', speak: true));
          return Extracted('Photos ${_stamp()}', pages);
        });
      }
      switch (ext) {
        case 'pdf':
          int count;
          try {
            count = await Extractors.pdfPageCount(first);
          } catch (_) {
            if (context.mounted) {
              toast(context,
                  'Could not open this PDF (it may be password protected).');
            }
            return null;
          }
          if (!context.mounted) return null;
          final range = await Navigator.push<List<int>>(context,
              MaterialPageRoute(builder: (_) => ChoosePagesPage(total: count)));
          if (range == null || !context.mounted) return null;
          return process(_baseName(first), (st) async {
            final pages = await Extractors.pdf(first, ocr, range[0], range[1],
                (d, t, c) => st(
                    c < 0
                        ? 'Page $d of $t, reading'
                        : c == 0
                            ? 'Page $d of $t, no text found'
                            : 'Page $d of $t, $c characters',
                    speak: true),
                pageNumbers: range[2] == 1);
            return Extracted(_baseName(first), pages);
          });
        case 'docx':
          return process(_baseName(first), (st) async {
            st('Reading document...');
            return Extracted(_baseName(first), await Extractors.docx(first));
          });
        case 'pptx':
          return process(_baseName(first), (st) async {
            st('Reading slides...');
            return Extracted(_baseName(first), await Extractors.pptx(first));
          });
        case 'xlsx':
          return process(_baseName(first), (st) async {
            st('Reading spreadsheet...');
            return Extracted(_baseName(first), await Extractors.xlsx(first));
          });
        case 'txt':
          return process(_baseName(first), (st) async {
            st('Reading text file...');
            return Extracted(_baseName(first), await Extractors.txt(first));
          });
        case 'zip':
          final b = await Extractors.restoreZip(first);
          if (b == null) {
            if (context.mounted) toast(context, 'This is not an Voiceleaf audiobook zip.');
            return null;
          }
          await Storage.save(b);
          if (context.mounted) toast(context, 'Audiobook restored.');
          return b;
        default:
          if (context.mounted) {
            toast(context,
                'Unsupported file type. Use PDF, photos, DOCX, TXT, PPTX, XLSX or a zip backup.');
          }
          return null;
      }
  }
}
