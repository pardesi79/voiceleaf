import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'app_prefs.dart';
import 'models.dart';
import 'ui_text.dart';
import 'l10n.dart';

/// Shows a progress dialog while [job] runs. The Cancel button flips cancelled().
Future<T?> runWithProgress<T>(
  BuildContext context,
  String title,
  Future<T?> Function(void Function(String) update, bool Function() cancelled) job,
) async {
  final msg = ValueNotifier<String>('Starting...');
  var cancel = false;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Tx(title),
        content: ValueListenableBuilder<String>(
          valueListenable: msg,
          builder: (_, v, __) =>
              Semantics(liveRegion: true, child: Tx(v)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancel = true;
              msg.value = 'Cancelling...';
            },
            child: const Tx('Cancel'),
          ),
        ],
      ),
    ),
  );
  try {
    return await job((m) => msg.value = m, () => cancel);
  } catch (_) {
    return null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

class _Wav {
  final Uint8List fmt; // first 16 bytes of the "fmt " chunk
  final Uint8List pcm;
  _Wav(this.fmt, this.pcm);
}

_Wav? _parseWav(Uint8List b) {
  if (b.length < 44) return null;
  final bd = ByteData.sublistView(b);
  Uint8List? fmt;
  var off = 12;
  while (off + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(off, off + 4));
    var size = bd.getUint32(off + 4, Endian.little);
    final start = off + 8;
    if (id == 'fmt ') {
      fmt = Uint8List.fromList(b.sublist(start, start + 16));
    } else if (id == 'data') {
      if (size == 0 || size == 0xFFFFFFFF || start + size > b.length) {
        size = b.length - start;
      }
      if (fmt == null) return null;
      return _Wav(fmt, Uint8List.sublistView(b, start, start + size));
    }
    off = start + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

Uint8List _buildWav(Uint8List fmt, List<Uint8List> parts) {
  final total = parts.fold<int>(0, (a, p) => a + p.length);
  final out = BytesBuilder();
  final h = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  h.setUint32(4, 36 + total, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  for (var i = 0; i < 16; i++) {
    h.setUint8(20 + i, fmt[i]);
  }
  tag(36, 'data');
  h.setUint32(40, total, Endian.little);
  out.add(h.buffer.asUint8List());
  for (final p in parts) {
    out.add(p);
  }
  return out.toBytes();
}

/// Reads the whole audiobook with the voice, speed and pitch you chose
/// and joins every page into one WAV file.
Future<Uint8List?> buildAudioWav(
    Book b, void Function(String) update, bool Function() cancelled) async {
  final p = AppPrefs.I;
  final tts = FlutterTts();
  final eng = p.str('engine');
  if (eng != null) {
    try {
      await tts.setEngine(eng);
    } catch (_) {}
  }
  final lang = p.str('lang');
  if (lang != null) {
    try {
      await tts.setLanguage(lang);
    } catch (_) {}
  }
  final vn = p.str('voiceName');
  final vl = p.str('voiceLocale');
  if (vn != null && vl != null) {
    try {
      await tts.setVoice({'name': vn, 'locale': vl});
    } catch (_) {}
  }
  await tts.setSpeechRate(p.dbl('rate', 0.5));
  await tts.setPitch(p.dbl('pitch', 1.0));
  await tts.awaitSynthCompletion(true);

  final tmp = await getTemporaryDirectory();
  final ext = await getExternalStorageDirectory();
  final parts = <Uint8List>[];
  Uint8List? fmt;
  for (var i = 0; i < b.pages.length; i++) {
    if (cancelled()) return null;
    update('Creating audio: page ${i + 1} of ${b.pages.length}');
    final text = b.applySkips(b.pages[i]).trim();
    if (text.isEmpty) continue;
    final f = File('${tmp.path}/tts_part_$i.wav');
    if (await f.exists()) await f.delete();
    await tts
        .synthesizeToFile(text, f.path, true)
        .timeout(const Duration(minutes: 3));
    var src = f;
    if (!await src.exists() && ext != null) {
      src = File('${ext.path}/tts_part_$i.wav'); // some engines ignore the full path
    }
    if (!await src.exists()) continue;
    final bytes = await src.readAsBytes();
    await src.delete();
    final w = _parseWav(bytes);
    if (w == null) continue;
    fmt ??= w.fmt;
    parts.add(w.pcm);
  }
  if (fmt == null || parts.isEmpty) return null;
  return _buildWav(fmt, parts);
}
