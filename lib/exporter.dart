import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'audio_export.dart';
import 'models.dart';
import 'widgets.dart';

String _safe(String s) =>
    s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim().isEmpty
        ? 'audiobook'
        : s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String bookText(Book b) => b.pages.map(b.applySkips).join('\n\n');

Uint8List _zip(void Function(void Function(String, String, {bool compress}) add) fill) {
  final arc = Archive();
  void add(String n, String c, {bool compress = true}) {
    final d = utf8.encode(c);
    final f = ArchiveFile(n, d.length, d);
    f.compress = compress;
    arc.addFile(f);
  }

  fill(add);
  return Uint8List.fromList(ZipEncoder().encode(arc)!);
}

Uint8List buildDocx(Book b) {
  final body = StringBuffer();
  body.write(
      '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>${_esc(b.title)}</w:t></w:r></w:p>');
  for (final page in b.pages) {
    for (final line in b.applySkips(page).split('\n')) {
      if (line.trim().isEmpty) continue;
      body.write(
          '<w:p><w:r><w:t xml:space="preserve">${_esc(line)}</w:t></w:r></w:p>');
    }
  }
  const head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  return _zip((add) {
    add('[Content_Types].xml',
        '$head<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>');
    add('_rels/.rels',
        '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');
    add('word/document.xml',
        '$head<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>');
  });
}

Uint8List buildEpub(Book b) {
  final items = StringBuffer(), spine = StringBuffer(), nav = StringBuffer();
  return _zip((add) {
    add('mimetype', 'application/epub+zip', compress: false);
    add('META-INF/container.xml',
        '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>');
    for (var i = 0; i < b.pages.length; i++) {
      final id = 'p${i + 1}';
      items.write('<item id="$id" href="$id.xhtml" media-type="application/xhtml+xml"/>');
      spine.write('<itemref idref="$id"/>');
      nav.write(
          '<navPoint id="n$i" playOrder="${i + 1}"><navLabel><text>Page ${i + 1}</text></navLabel><content src="$id.xhtml"/></navPoint>');
      final paras = b
          .applySkips(b.pages[i])
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => '<p>${_esc(l)}</p>')
          .join();
      add('OEBPS/$id.xhtml',
          '<?xml version="1.0" encoding="UTF-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>Page ${i + 1}</title></head><body><h2>Page ${i + 1}</h2>$paras</body></html>');
    }
    add('OEBPS/toc.ncx',
        '<?xml version="1.0" encoding="UTF-8"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="${b.id}"/></head><docTitle><text>${_esc(b.title)}</text></docTitle><navMap>$nav</navMap></ncx>');
    add('OEBPS/content.opf',
        '<?xml version="1.0" encoding="UTF-8"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="bid"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>${_esc(b.title)}</dc:title><dc:language>en</dc:language><dc:identifier id="bid">${b.id}</dc:identifier></metadata><manifest><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>$items</manifest><spine toc="ncx">$spine</spine></package>');
  });
}

Uint8List buildBackupZip(Book b) =>
    _zip((add) => add('book.json', jsonEncode(b.toJson())));

Future<void> exportBook(BuildContext context, Book b, String fmt,
    {required bool share}) async {
  final name = _safe(b.title);
  Uint8List data;
  String ext;
  switch (fmt) {
    case 'Audio':
      final r = await runWithProgress<Uint8List>(context, 'Creating audio file',
          (update, cancelled) => buildAudioWav(b, update, cancelled));
      if (r == null) {
        toast(context,
            'Audio was not created. Check the engine in TTS and Voice Settings.');
        return;
      }
      data = r;
      ext = 'wav';
      break;
    case 'Text':
      data = Uint8List.fromList(utf8.encode(bookText(b)));
      ext = 'txt';
      break;
    case 'DOCX':
      data = buildDocx(b);
      ext = 'docx';
      break;
    case 'ePub':
      data = buildEpub(b);
      ext = 'epub';
      break;
    case 'ZIP':
      data = buildBackupZip(b);
      ext = 'zip';
      break;
    default:
      return;
  }
  try {
    if (share) {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name.$ext');
      await f.writeAsBytes(data);
      await Share.shareXFiles([XFile(f.path)]);
    } else {
      final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save $name.$ext',
          fileName: '$name.$ext',
          bytes: data);
      if (path != null) toast(context, 'Saved $name.$ext');
    }
  } catch (e) {
    toast(context, 'Failed: $e');
  }
}

void showFormatSheet(BuildContext context, Book b, {required bool share}) {
  Future<void> go(String f) => exportBook(context, b, f, share: share);
  showMenuSheet(
    context,
    [
      MenuEntry(Icons.audiotrack, 'Audio (WAV file, can be large)', () => go('Audio')),
      MenuEntry(Icons.text_snippet, 'Text', () => go('Text')),
      MenuEntry(Icons.menu_book, 'ePub', () => go('ePub')),
      MenuEntry(Icons.description, 'DOCX', () => go('DOCX')),
      MenuEntry(Icons.folder_zip,
          'ZIP (also saves notes, bookmarks and skip text; use it as backup)',
          () => go('ZIP')),
    ],
    title: share ? 'Select Share Format' : 'Select Download Format',
  );
}
