import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/news_article.dart';

class NewsApi {
  NewsApi({http.Client? client, this.timeout = const Duration(seconds: 30)})
    : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  static final _endpoint = Uri.parse(
    'https://kun-news-summarizer.onrender.com/api/v1/news',
  );
  Future<List<NewsArticle>> fetchNews() async {
    final response = await _client
        .get(_endpoint, headers: {'Accept': 'application/json'})
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw NewsApiException(
        'News request returned HTTP ${response.statusCode}.',
      );
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('News response must be an object.');
      }
      final items = decoded['items'];
      if (items is! List) {
        throw const FormatException('News response items must be a list.');
      }
      return [
        for (var i = 0; i < items.length; i++) _parseArticle(items[i], i),
      ];
    } on FormatException catch (error) {
      throw NewsApiException('Invalid news response: ${error.message}');
    }
  }

  NewsArticle _parseArticle(dynamic item, int index) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('items[$index] must be an object.');
    }
    try {
      return NewsArticle.fromJson(item);
    } on FormatException catch (error) {
      throw FormatException('items[$index]: ${error.message}');
    }
  }

  /// Closes the supplied client or the internally created client.
  void close() => _client.close();
}

class NewsApiException implements Exception {
  const NewsApiException(this.message);
  final String message;
  @override
  String toString() => 'NewsApiException: $message';
}
