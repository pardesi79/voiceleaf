int _count(String t, int a, int b) {
  var n = 0;
  for (final r in t.runes) {
    if (r >= a && r <= b) n++;
  }
  return n;
}

const _ranges = <List<Object>>[
  ['hi-IN', 0x0900, 0x097F],
  ['bn-IN', 0x0980, 0x09FF],
  ['pa-IN', 0x0A00, 0x0A7F],
  ['gu-IN', 0x0A80, 0x0AFF],
  ['or-IN', 0x0B00, 0x0B7F],
  ['ta-IN', 0x0B80, 0x0BFF],
  ['te-IN', 0x0C00, 0x0C7F],
  ['kn-IN', 0x0C80, 0x0CFF],
  ['ml-IN', 0x0D00, 0x0D7F],
  ['ar', 0x0600, 0x06FF],
  ['ru-RU', 0x0400, 0x04FF],
  ['th-TH', 0x0E00, 0x0E7F],
  ['el-GR', 0x0370, 0x03FF],
  ['he-IL', 0x0590, 0x05FF],
  ['ko-KR', 0xAC00, 0xD7AF],
  ['ja-JP', 0x3040, 0x30FF],
  ['zh-CN', 0x4E00, 0x9FFF],
];

/// Guesses the voice language from the script of the text.
String detectTtsLang(String text) {
  final s = text.length > 600 ? text.substring(0, 600) : text;
  var best = 'en-US', bestN = 0, letters = 0;
  for (final r in s.runes) {
    if (r > 0x40) letters++;
  }
  for (final e in _ranges) {
    final n = _count(s, e[1] as int, e[2] as int);
    if (n > bestN) {
      bestN = n;
      best = e[0] as String;
    }
  }
  if (bestN < 3 || (letters > 0 && bestN / letters < 0.15)) return 'en-US';
  if (best == 'zh-CN' && _count(s, 0x3040, 0x30FF) > 0) return 'ja-JP';
  return best;
}
