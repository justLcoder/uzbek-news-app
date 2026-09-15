class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.sourceUrl,
    required this.publishedAt,
  });
  final int id;
  final String title;
  final String summary;
  final String source;
  final Uri sourceUrl;
  final DateTime publishedAt;
  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Article $key must be a non-empty string.');
      }
      return value;
    }

    final id = json['id'];
    if (id is! int) {
      throw const FormatException('Article id must be an integer.');
    }
    final url = Uri.tryParse(requiredString('source_url'));
    if (url == null ||
        !['https', 'http'].contains(url.scheme) ||
        url.host.isEmpty) {
      throw const FormatException('Article source_url must be an HTTP(S) URL.');
    }
    final timestamp = requiredString('published_at');
    final date = DateTime.tryParse(timestamp);
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$',
    ).firstMatch(timestamp);
    if (date == null || match == null) {
      throw const FormatException(
        'Article published_at must be an ISO timestamp with timezone.',
      );
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime.utc(year, month + 1, 0).day ||
        int.parse(match[4]!) > 23 ||
        int.parse(match[5]!) > 59 ||
        int.parse(match[6]!) > 59 ||
        (match[7] != null && int.parse(match[7]!) > 23) ||
        (match[8] != null && int.parse(match[8]!) > 59)) {
      throw const FormatException(
        'Article published_at has invalid date/time components.',
      );
    }
    return NewsArticle(
      id: id,
      title: requiredString('title'),
      summary: requiredString('summary'),
      source: requiredString('source'),
      sourceUrl: url,
      publishedAt: date,
    );
  }
}
