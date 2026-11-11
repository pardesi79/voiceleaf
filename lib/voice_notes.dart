import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'models.dart';
import 'storage.dart';
import 'widgets.dart';
import 'ui_text.dart';
import 'l10n.dart';

/// Record and play voice notes for one audiobook.
class VoiceNotesPage extends StatefulWidget {
  final Book book;
  const VoiceNotesPage({super.key, required this.book});
  @override
  State<VoiceNotesPage> createState() => _VoiceNotesPageState();
}

class _VoiceNotesPageState extends State<VoiceNotesPage> {
  final AudioRecorder _rec = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool recording = false;
  String? playingPath;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playingPath = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (recording) {
      final path = await _rec.stop();
      setState(() => recording = false);
      if (path != null) {
        widget.book.voices.add(path);
        await Storage.save(widget.book);
        if (mounted) setState(() {});
      }
      return;
    }
    if (!await _rec.hasPermission()) {
      if (mounted) toast(context, 'Microphone permission is needed.');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/voice');
    if (!await d.exists()) await d.create(recursive: true);
    final path =
        '${d.path}/${widget.book.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _player.stop();
    playingPath = null;
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (mounted) setState(() => recording = true);
  }

  Future<void> _togglePlay(String path) async {
    if (playingPath == path) {
      await _player.stop();
      setState(() => playingPath = null);
    } else {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      setState(() => playingPath = path);
    }
  }

  Future<void> _delete(String path) async {
    if (playingPath == path) await _player.stop();
    widget.book.voices.remove(path);
    await Storage.save(widget.book);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (mounted) setState(() => playingPath = null);
  }

  String _label(String path, int i) {
    final m = RegExp(r'_(\d{10,})\.m4a$').firstMatch(path);
    if (m == null) return 'Voice note ${i + 1}';
    final t = DateTime.fromMillisecondsSinceEpoch(int.parse(m.group(1)!));
    return 'Voice note ${i + 1} - ${t.toString().substring(0, 16)}';
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.book.voices;
    return Scaffold(
      appBar: AppBar(title: const Tx('Voice Notes')),
      body: list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Tx(
                    'Voice notes are empty.\nTap the Record Voice button to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18)),
              ),
            )
          : ListView(children: [
              for (var i = 0; i < list.length; i++)
                ListTile(
                  leading: IconButton(
                    tooltip: playingPath == list[i] ? 'Stop' : 'Play',
                    icon: Icon(playingPath == list[i] ? Icons.stop : Icons.play_arrow),
                    onPressed: () => _togglePlay(list[i]),
                  ),
                  title: Tx(_label(list[i], i)),
                  trailing: IconButton(
                    tooltip: tr('Delete voice note'),
                    icon: const Icon(Icons.delete),
                    onPressed: () => _delete(list[i]),
                  ),
                ),
            ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: recording ? Colors.red.shade700 : kPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56)),
            onPressed: _toggleRecord,
            icon: Icon(recording ? Icons.stop : Icons.mic),
            label: Tx(recording ? 'Stop Recording' : 'Record Voice',
                style: const TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }
}
