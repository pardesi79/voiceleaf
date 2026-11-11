import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'models.dart';

class Extracted {
  final String title;
  final List<String> pages;
  Extracted(this.title, this.pages);
}

/// Splits long text into pages of roughly [maxLen] characters,
/// breaking at paragraph or sentence ends.
List<String> paginate(String raw, {int maxLen = 1800}) {
  final text = raw
      .replaceAll('\r', '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (text.isEmpty) return [];
  final pieces = <String>[];
  for (final line in text.split('\n')) {
    var para = line.trim();
    while (para.length > maxLen) {
      var cut = para.lastIndexOf(RegExp(r'[.!?।]\s'), maxLen);
      if (cut <= 0) cut = para.lastIndexOf(' ', maxLen);
      cut = cut <= 0 ? maxLen : cut + 1;
      pieces.add(para.substring(0, cut).trim());
      para = para.substring(cut).trim();
    }
    if (para.isNotEmpty) pieces.add(para);
  }
  final pages = <String>[];
  var buf = StringBuffer();
  for (final p in pieces) {
    if (buf.length > 0 && buf.length + p.length > maxLen) {
      pages.add(buf.toString().trim());
      buf = StringBuffer();
    }
    buf.writeln(p);
  }
  if (buf.length > 0) pages.add(buf.toString().trim());
  return pages;
}

String _unxml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'");

int _num(String name) =>
    int.parse(RegExp(r'(\d+)\.xml$').firstMatch(name)!.group(1)!);

class Extractors {
  static TextRecognitionScript _script(String m) {
    switch (m) {
      case 'devanagari':
        return TextRecognitionScript.devanagiri;
      case 'chinese':
        return TextRecognitionScript.chinese;
      case 'japanese':
        return TextRecognitionScript.japanese;
      case 'korean':
        return TextRecognitionScript.korean;
      default:
        return TextRecognitionScript.latin;
    }
  }

  static double _share(String t, bool Function(int) inScript) {
    var n = 0, all = 0;
    for (final r in t.runes) {
      if (r <= 32) continue;
      all++;
      if (inScript(r)) n++;
    }
    return all == 0 ? 0 : n / all;
  }

  static int _letters(String t) {
    var n = 0;
    for (final r in t.runes) {
      if (r > 32) n++;
    }
    return n;
  }

  /// Reads one image on the phone with Google ML Kit (offline).
  /// mode: auto | latin | devanagari | chinese | japanese | korean
  static Future<String> ocrFile(File f, String mode) async {
    Future<String> run(String m) async {
      TextRecognizer? rec;
      try {
        rec = TextRecognizer(script: _script(m));
        final t = await rec.processImage(InputImage.fromFile(f));
        return t.text;
      } catch (_) {
        // A script model that is not installed must not kill the page.
        return '';
      } finally {
        try {
          await rec?.close();
        } catch (_) {}
      }
    }

    if (mode != 'auto') return run(mode);

    // Read the page with both scripts and keep whichever found more text.
    // The old rule looked at the share of Latin letters, which threw away
    // Hindi pages whenever the Latin pass returned a little noise.
    var best = await run('latin');
    var bestLen = _letters(best);
    final dev = await run('devanagari');
    if (_letters(dev) > bestLen) {
      best = dev;
      bestLen = _letters(dev);
    }
    if (bestLen < 4) {
      for (final m in ['chinese', 'japanese', 'korean']) {
        final t = await run(m);
        if (_letters(t) > bestLen) {
          best = t;
          bestLen = _letters(t);
        }
      }
    }
    return best;
  }

  static Future<List<String>> images(List<String> paths, String mode,
      {void Function(int, int)? onProgress}) async {
    final pages = <String>[];
    for (var i = 0; i < paths.length; i++) {
      onProgress?.call(i + 1, paths.length);
      pages.addAll(paginate(await ocrFile(File(paths[i]), mode)));
    }
    return pages;
  }

  static Future<int> pdfPageCount(String path) async {
    final doc = await PdfDocument.openFile(path);
    final n = doc.pagesCount;
    await doc.close();
    return n;
  }

  /// PDF pages [from]..[to] (1-based) drawn as images, then read with OCR.
  static Future<List<String>> pdf(String path, String mode, int from, int to,
      void Function(int done, int total, int chars) onProgress,
      {bool pageNumbers = false}) async {
    final doc = await PdfDocument.openFile(path);
    final tmp = await getTemporaryDirectory();
    final pages = <String>[];
    try {
      final total = to - from + 1;
      var empty = 0;
      for (var i = from; i <= to; i++) {
        onProgress(i - from + 1, total, -1);
        final page = await doc.getPage(i);
        final w = page.width;
        final h = page.height;
        var img = await page.render(
          width: w * 2,
          height: h * 2,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        if (img == null || img.bytes.isEmpty) {
          // Some pages refuse the 2x render; one flat attempt is better than none.
          img = await page.render(
            width: w,
            height: h,
            format: PdfPageImageFormat.jpeg,
            quality: 90,
            backgroundColor: '#FFFFFF',
          );
        }
        await page.close();
        if (img == null || img.bytes.isEmpty) {
          empty++;
          onProgress(i - from + 1, total, -2);
          continue;
        }
        final f = File('${tmp.path}/pg_$i.png');
        await f.writeAsBytes(img.bytes);
        final text = await ocrFile(f, mode);
        await f.delete();
        onProgress(i - from + 1, total, text.trim().length);
        if (text.trim().isEmpty) {
          empty++;
        } else {
          pages.addAll(paginate(pageNumbers ? 'Page $i.\n$text' : text));
        }
      }
      if (pages.isEmpty) {
        throw Exception(
            'No text was found in this PDF. $empty page(s) were read but '
            'came back empty. Try Take Photo instead, or set the text '
            'recognition language in Preferences.');
      }
    } finally {
      await doc.close();
    }
    return pages;
  }

  static Future<List<String>> docx(String path) async {
    final a = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final f = a.findFile('word/document.xml');
    if (f == null) return [];
    var xml = utf8.decode(f.content as List<int>, allowMalformed: true);
    xml = xml
        .replaceAll('</w:p>', '\n')
        .replaceAll(RegExp(r'<w:tab\s*/>'), ' ')
        .replaceAll(RegExp(r'<w:br\s*/>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return paginate(_unxml(xml));
  }

  static Future<List<String>> pptx(String path) async {
    final a = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final slides = a.files
        .where((f) =>
            f.isFile && RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((x, y) => _num(x.name).compareTo(_num(y.name)));
    final out = StringBuffer();
    for (final s in slides) {
      var xml = utf8.decode(s.content as List<int>, allowMalformed: true);
      xml = xml.replaceAll('</a:p>', '\n').replaceAll(RegExp(r'<[^>]+>'), '');
      out.writeln('Slide ${_num(s.name)}.');
      out.writeln(_unxml(xml));
      out.writeln();
    }
    return paginate(out.toString());
  }

  static Future<List<String>> xlsx(String path) async {
    final a = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    String read(String name) {
      final f = a.findFile(name);
      return f == null ? '' : utf8.decode(f.content as List<int>, allowMalformed: true);
    }

    final shared = <String>[];
    for (final m
        in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(read('xl/sharedStrings.xml'))) {
      shared.add(_unxml(m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '')));
    }
    final sheets = a.files
        .where((f) =>
            f.isFile && RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((x, y) => _num(x.name).compareTo(_num(y.name)));
    final buf = StringBuffer();
    for (final s in sheets) {
      final xml = utf8.decode(s.content as List<int>, allowMalformed: true);
      buf.writeln('Sheet ${_num(s.name)}.');
      for (final row
          in RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(xml)) {
        final cells = <String>[];
        for (final c in RegExp(r'<c([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true)
            .allMatches(row.group(1)!)) {
          final attrs = c.group(1) ?? '';
          final inner = c.group(2) ?? '';
          final v = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(inner)?.group(1);
          var val = '';
          if (attrs.contains('t="s"') && v != null) {
            final i = int.tryParse(v);
            if (i != null && i < shared.length) val = shared[i];
          } else if (attrs.contains('t="inlineStr"')) {
            val = _unxml(inner.replaceAll(RegExp(r'<[^>]+>'), ''));
          } else if (v != null) {
            val = _unxml(v);
          }
          if (val.trim().isNotEmpty) cells.add(val.trim());
        }
        if (cells.isNotEmpty) buf.writeln('${cells.join(', ')}.');
      }
      buf.writeln();
    }
    return paginate(buf.toString());
  }

  static Future<List<String>> txt(String path) async {
    final bytes = await File(path).readAsBytes();
    return paginate(utf8.decode(bytes, allowMalformed: true));
  }

  /// Restores a backup made with Download > ZIP.
  static Future<Book?> restoreZip(String path) async {
    final a = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final f = a.findFile('book.json');
    if (f == null) return null;
    final j = jsonDecode(utf8.decode(f.content as List<int>)) as Map<String, dynamic>;
    final b = Book.fromJson(j);
    return Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: b.title,
      pages: b.pages,
      page: b.page,
      offset: b.offset,
      bookmarks: b.bookmarks,
      notes: b.notes,
      skips: b.skips,
    );
  }

  static Future<Extracted> web(String url) async {
    var u = url.trim();
    if (!u.startsWith('http')) u = 'https://$u';
    final res = await http.get(Uri.parse(u));
    final doc =
        html_parser.parse(utf8.decode(res.bodyBytes, allowMalformed: true));
    for (final e in doc.querySelectorAll('script,style,nav,footer,noscript')) {
      e.remove();
    }
    final text = doc
        .querySelectorAll('h1,h2,h3,p,li')
        .map((e) => e.text.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
    final title = doc.querySelector('title')?.text.trim();
    return Extracted((title == null || title.isEmpty) ? u : title, paginate(text));
  }
}
