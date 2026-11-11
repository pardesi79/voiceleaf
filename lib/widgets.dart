import 'package:flutter/material.dart';
import 'app_prefs.dart';
import 'models.dart';
import 'ui_text.dart';
import 'l10n.dart';

const kPurple = Color(0xFF2B0A3D);
const kYellow = Color(0xFFFFE066);

void toast(BuildContext c, String m) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Tx(m)));
}

String fmtClock(int secs) {
  final m = secs ~/ 60, s = secs % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String fmtLong(int secs) {
  final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
  if (h > 0) return '$h hr $m min';
  if (m > 0) return '$m min $s sec';
  return '$s sec';
}

/// Rough speaking speed: characters per second at the saved speed.
double charsPerSecond([double? rate]) {
  final r = rate ?? AppPrefs.I.dbl('rate', 0.5);
  return 14.0 * (r * 2).clamp(0.2, 2.0);
}

String leftLabel(Book b) {
  var chars = 0;
  for (var i = b.page; i < b.pages.length; i++) {
    chars += b.pages[i].length - (i == b.page ? b.offset : 0);
  }
  if (chars < 0) chars = 0;
  return '${fmtLong((chars / charsPerSecond()).round())} left';
}

Future<String?> askText(BuildContext context, String title, String hint,
    {bool multiline = false, String initial = '', String okLabel = 'OK'}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Tx(title),
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 10 : 1,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Tx('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: Tx(okLabel)),
      ],
    ),
  );
}

class MenuEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  MenuEntry(this.icon, this.label, this.onTap);
}

class MenuCard extends StatelessWidget {
  final MenuEntry entry;
  final VoidCallback onTap;
  const MenuCard({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.amber.shade300, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(entry.icon),
              const SizedBox(width: 16),
              Expanded(
                  child: Tx(entry.label,
                      style: const TextStyle(fontSize: 18))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet of big cards with a Close button, like the original.
Future<void> showMenuSheet(BuildContext context, List<MenuEntry> items,
    {String? title}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                  header: true,
                  child: Tx(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              children: [
                for (final e in items)
                  MenuCard(
                      entry: e,
                      onTap: () {
                        Navigator.pop(ctx);
                        e.onTap();
                      }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: kPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.pop(ctx),
                child: const Tx('Close', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

/// "- 33% +" sheet used for speed, pitch and font size.
Future<void> showStepperSheet(BuildContext context,
    {required String title,
    required int value,
    int min = 0,
    int max = 100,
    int step = 5,
    required void Function(int) onChanged}) {
  var v = value;
  final style =
      IconButton.styleFrom(backgroundColor: kPurple, foregroundColor: Colors.white);
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Tx(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filled(
                style: style,
                iconSize: 36,
                tooltip: tr('Decrease'),
                icon: const Icon(Icons.remove),
                onPressed: () {
                  v = (v - step).clamp(min, max).toInt();
                  onChanged(v);
                  set(() {});
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Semantics(
                    liveRegion: true,
                    child: Tx('$v%', style: const TextStyle(fontSize: 28))),
              ),
              IconButton.filled(
                style: style,
                iconSize: 36,
                tooltip: tr('Increase'),
                icon: const Icon(Icons.add),
                onPressed: () {
                  v = (v + step).clamp(min, max).toInt();
                  onChanged(v);
                  set(() {});
                },
              ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: kPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.pop(ctx),
                child: const Tx('Close', style: TextStyle(fontSize: 18)),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}
