/// Firestore cannot do "contains" search, so each book stores `searchKeywords`:
/// lowercase word prefixes (length 2..6) plus whole long words, from title + author.
/// Searching then uses `array-contains` on ONE keyword. Max 40 entries (security rule limit).
List<String> buildSearchKeywords(String title, String author) {
  final words = '$title $author'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 2)
      .toList();
  final seenWords = <String>{};
  final unique = <String>[];
  for (final w in words) {
    if (seenWords.add(w)) unique.add(w);
    if (unique.length >= 5) break;
  }
  final out = <String>{};
  for (final w in unique) {
    final max = w.length < 6 ? w.length : 6;
    for (var i = 2; i <= max; i++) {
      out.add(w.substring(0, i));
    }
    if (w.length > 6) out.add(w);
  }
  return out.take(40).toList();
}

/// The single keyword used to query Firestore for what the user typed (null = nothing to search).
String? queryKeyword(String typed) {
  final words = typed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 2)
      .toList();
  if (words.isEmpty) return null;
  final first = words.first;
  return first.length > 6 ? first.substring(0, 6) : first;
}

/// Client-side refinement after the keyword query (all typed words must appear).
bool matchesQuery(String typed, String title, String author) {
  final hay = '${title.toLowerCase()} ${author.toLowerCase()}';
  final words = typed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  return words.every(hay.contains);
}
