class Bookmark {
  final int page;
  final int offset;
  final String label;
  Bookmark(this.page, this.offset, this.label);

  Map<String, dynamic> toJson() => {'p': page, 'o': offset, 'l': label};
  factory Bookmark.fromJson(Map<String, dynamic> j) =>
      Bookmark(j['p'] as int, j['o'] as int, j['l'] as String);
}

class Book {
  final String id;
  String title;
  final List<String> pages;
  int page;
  int offset;
  final List<Bookmark> bookmarks;
  String notes;
  List<String> skips;
  final List<String> voices;
  final DateTime created;

  Book({
    required this.id,
    required this.title,
    required this.pages,
    this.page = 0,
    this.offset = 0,
    List<Bookmark>? bookmarks,
    this.notes = '',
    List<String>? skips,
    List<String>? voices,
    DateTime? created,
  })  : bookmarks = bookmarks ?? [],
        skips = skips ?? [],
        voices = voices ?? [],
        created = created ?? DateTime.now();

  /// Removes the "Skip Text" phrases (headers, footers, page numbers...).
  String applySkips(String t) {
    var r = t;
    for (final s in skips) {
      if (s.trim().isNotEmpty) r = r.replaceAll(s, '');
    }
    return r;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pages': pages,
        'page': page,
        'offset': offset,
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'notes': notes,
        'skips': skips,
        'voices': voices,
        'created': created.toIso8601String(),
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        pages: (j['pages'] as List).cast<String>(),
        page: (j['page'] as int?) ?? 0,
        offset: (j['offset'] as int?) ?? 0,
        bookmarks: ((j['bookmarks'] as List?) ?? [])
            .map((e) => Bookmark.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        notes: (j['notes'] as String?) ?? '',
        skips: ((j['skips'] as List?) ?? []).cast<String>(),
        voices: ((j['voices'] as List?) ?? []).cast<String>(),
        created: DateTime.tryParse((j['created'] as String?) ?? ''),
      );
}
