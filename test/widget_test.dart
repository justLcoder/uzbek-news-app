import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uzbek_news/features/news/data/news_api.dart';
import 'package:uzbek_news/features/news/models/news_article.dart';
import 'package:uzbek_news/features/news/presentation/news_feed_screen.dart';

Map<String, dynamic> article() => {
  'id': 1,
  'title': 'News title',
  'summary': 'First paragraph.\n\nSecond paragraph.',
  'source': 'another_source',
  'source_url': 'https://example.com/news/1',
  'published_at': '2026-09-15T09:33:00Z',
};
http.Response feed() => http.Response(
  jsonEncode({
    'items': [article()],
  }),
  200,
);
void main() {
  test('model parses all fields and preserves paragraphs', () {
    final parsed = NewsArticle.fromJson(article());
    expect(parsed.id, 1);
    expect(parsed.title, 'News title');
    expect(parsed.summary, 'First paragraph.\n\nSecond paragraph.');
    expect(parsed.source, 'another_source');
    expect(parsed.sourceUrl, Uri.parse('https://example.com/news/1'));
    expect(parsed.publishedAt, DateTime.utc(2026, 9, 15, 9, 33));
  });
  for (final key in article().keys) {
    test('model rejects missing $key', () {
      expect(
        () => NewsArticle.fromJson(article()..remove(key)),
        throwsFormatException,
      );
    });
  }
  for (final entry in <String, dynamic>{
    'id': '1',
    'title': ' ',
    'summary': 3,
    'source': [],
    'source_url': '/relative',
    'published_at': '2026-02-30T09:33:00Z',
  }.entries) {
    test('model rejects invalid ${entry.key}', () {
      expect(
        () => NewsArticle.fromJson(article()..[entry.key] = entry.value),
        throwsFormatException,
      );
    });
  }
  test('API requests production endpoint and decodes UTF-8', () async {
    var attempts = 0;
    final api = NewsApi(
      client: MockClient((request) async {
        attempts++;
        expect(
          request.url.toString(),
          'https://kun-news-summarizer.onrender.com/api/v1/news',
        );
        expect(request.method, 'GET');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'items': [article()..['title'] = 'O‘zbekiston'],
            }),
          ),
          200,
        );
      }),
    );
    addTearDown(api.close);
    expect((await api.fetchNews()).single.title, 'O‘zbekiston');
    expect(attempts, 1);
  });
  for (final body in [
    'invalid',
    '[]',
    '{}',
    '{"items":{}}',
    '{"items":[null]}',
    '{"items":[{}]}',
  ]) {
    test('API rejects malformed response $body', () async {
      var attempts = 0;
      final api = NewsApi(
        client: MockClient((_) async {
          attempts++;
          return http.Response(body, 200);
        }),
      );
      addTearDown(api.close);
      await expectLater(api.fetchNews(), throwsA(isA<NewsApiException>()));
      expect(attempts, 1);
    });
  }
  for (final statusCode in [404, 503]) {
    test('API rejects HTTP $statusCode without retrying', () async {
      var attempts = 0;
      final api = NewsApi(
        client: MockClient((_) async {
          attempts++;
          return http.Response('{}', statusCode);
        }),
      );
      addTearDown(api.close);
      await expectLater(api.fetchNews(), throwsA(isA<NewsApiException>()));
      expect(attempts, 1);
    });
  }
  test('API surfaces non-socket client failures without retrying', () async {
    var attempts = 0;
    final api = NewsApi(
      client: MockClient((_) async {
        attempts++;
        throw http.ClientException('offline');
      }),
    );
    addTearDown(api.close);
    await expectLater(api.fetchNews(), throwsA(isA<http.ClientException>()));
    expect(attempts, 1);
  });
  test('API retries one timeout and then succeeds', () async {
    var attempts = 0;
    final api = NewsApi(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) {
        attempts++;
        return attempts == 1
            ? Completer<http.Response>().future
            : Future.value(feed());
      }),
    );
    addTearDown(api.close);
    expect((await api.fetchNews()).single.title, 'News title');
    expect(attempts, 2);
  });
  test('API retries one socket failure and then succeeds', () async {
    var attempts = 0;
    final api = NewsApi(
      client: MockClient((_) async {
        attempts++;
        if (attempts == 1) throw const SocketException('offline');
        return feed();
      }),
    );
    addTearDown(api.close);
    expect((await api.fetchNews()).single.title, 'News title');
    expect(attempts, 2);
  });
  test('API stops after two transient failures', () async {
    var attempts = 0;
    final api = NewsApi(
      client: MockClient((_) async {
        attempts++;
        throw const SocketException('offline');
      }),
    );
    addTearDown(api.close);
    await expectLater(api.fetchNews(), throwsA(isA<SocketException>()));
    expect(attempts, 2);
  });
  for (final error in [
    const HandshakeException('bad certificate'),
    StateError('programming error'),
  ]) {
    test('API does not retry ${error.runtimeType}', () async {
      var attempts = 0;
      final api = NewsApi(
        client: MockClient((_) async {
          attempts++;
          throw error;
        }),
      );
      addTearDown(api.close);
      await expectLater(api.fetchNews(), throwsA(same(error)));
      expect(attempts, 1);
    });
  }
  testWidgets(
    'loading then real layout, refresh replaces feed with empty state',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final api = NewsApi(
        client: MockClient((_) {
          calls++;
          return calls == 1
              ? pending.future
              : Future.value(http.Response('{"items":[]}', 200));
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(MaterialApp(home: NewsFeedScreen(api: api)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(feed());
      await tester.pumpAndSettle();
      expect(find.text('News title'), findsOneWidget);
      expect(
        find.text('First paragraph.\n\nSecond paragraph.'),
        findsOneWidget,
      );
      expect(find.textContaining('another_source'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('No news is currently available.'), findsOneWidget);
      expect(find.text('News title'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(calls, 3);
    },
  );
  testWidgets('error hides internals and retry succeeds', (tester) async {
    var calls = 0;
    final api = NewsApi(
      client: MockClient((_) async {
        if (++calls == 1) {
          throw http.ClientException('private internal details');
        }
        return feed();
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: NewsFeedScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to load news'), findsOneWidget);
    expect(find.textContaining('private internal details'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('News title'), findsOneWidget);
  });
  testWidgets('completion after disposal is safe', (tester) async {
    final pending = Completer<http.Response>();
    final api = NewsApi(client: MockClient((_) => pending.future));
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: NewsFeedScreen(api: api)));
    await tester.pumpWidget(const SizedBox());
    pending.complete(feed());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
