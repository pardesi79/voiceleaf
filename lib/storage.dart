import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// Every audiobook is one JSON file on the phone. No cloud, no sign-in.
class Storage {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/books');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<List<Book>> all() async {
    final d = await _dir();
    final out = <Book>[];
    await for (final f in d.list()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          out.add(Book.fromJson(jsonDecode(await f.readAsString())));
        } catch (_) {}
      }
    }
    out.sort((a, b) => b.created.compareTo(a.created));
    return out;
  }

  static Future<void> save(Book b) async {
    final d = await _dir();
    await File('${d.path}/${b.id}.json').writeAsString(jsonEncode(b.toJson()));
  }

  static Future<void> delete(String id) async {
    final d = await _dir();
    final f = File('${d.path}/$id.json');
    if (await f.exists()) await f.delete();
  }
}
