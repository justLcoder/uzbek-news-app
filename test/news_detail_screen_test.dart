import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uzbek_news/features/news/data/news_api.dart';
import 'package:uzbek_news/features/news/models/news_article.dart';
import 'package:uzbek_news/features/news/presentation/news_detail_screen.dart';
import 'package:uzbek_news/features/news/presentation/news_feed_screen.dart';

NewsArticle sample({String summary = 'First paragraph.\n\nLast paragraph.'}) =>
    NewsArticle(
      id: 7,
      title: 'Article title',
      summary: summary,
      source: 'future_publisher',
      sourceUrl: Uri.parse('https://example.org/story?a=1&b=two#section'),
      publishedAt: DateTime.utc(2026, 9, 15, 9, 33),
    );

void main() {
  for (final source in ['kun_uz', 'future_publisher']) {
    testWidgets('compact preview opens full summary for $source', (
      tester,
    ) async {
      final summary = List.filled(
        12,
        'A full paragraph of news that must be preserved.',
      ).join('\n\n');
      final api = NewsApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'title': 'The complete article title',
                  'summary': summary,
                  'source': source,
                  'source_url': 'https://example.org/news',
                  'published_at': '2026-09-15T09:33:00Z',
                },
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(MaterialApp(home: NewsFeedScreen(api: api)));
      await tester.pumpAndSettle();
      final preview = tester.widget<Text>(find.text(summary));
      expect(preview.maxLines, 3);
      expect(preview.overflow, TextOverflow.ellipsis);
      expect(preview.data, summary);
      expect(
        tester.widget<Text>(find.text('The complete article title')).maxLines,
        isNull,
      );
      expect(find.text('AI summary').hitTestable(), findsOneWidget);
      final displayName = source == 'kun_uz' ? 'Kun.uz' : source;
      expect(
        find.textContaining('$displayName /').hitTestable(),
        findsOneWidget,
      );
      await tester.tapAt(
        tester.getTopLeft(find.byType(Card)) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();
      final detail = tester.widget<NewsDetailScreen>(
        find.byType(NewsDetailScreen),
      );
      expect(detail.article.summary, summary);
      expect(detail.article.source, source);
      expect(tester.widget<Text>(find.text(summary)).maxLines, isNull);
      expect(find.textContaining('Publisher: $displayName /'), findsOneWidget);
      expect(find.text('AI-generated summary'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'whole card opens detail and back preserves feed without fetching',
    (tester) async {
      var requests = 0;
      final article = sample();
      final api = NewsApi(
        client: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': article.id,
                  'title': article.title,
                  'summary': article.summary,
                  'source': article.source,
                  'source_url': article.sourceUrl.toString(),
                  'published_at': article.publishedAt.toIso8601String(),
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(MaterialApp(home: NewsFeedScreen(api: api)));
      await tester.pumpAndSettle();
      final metadata = tester
          .widget<Text>(find.textContaining('future_publisher'))
          .data;
      // Tap the card's padding, outside its text.
      await tester.tapAt(
        tester.getTopLeft(find.byType(Card)) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NewsDetailScreen), findsOneWidget);
      expect(find.text(article.title), findsOneWidget);
      expect(find.text(article.summary), findsOneWidget);
      expect(find.text('Publisher: $metadata').hitTestable(), findsOneWidget);
      expect(find.text('AI-generated summary').hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('AI-generated summary')).dy,
        lessThan(tester.getTopLeft(find.text(article.summary)).dy),
      );
      expect(find.text('Read original'), findsOneWidget);
      expect(requests, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(NewsDetailScreen), findsNothing);
      expect(find.byType(Card), findsOneWidget);
      expect(requests, 1);
    },
  );

  testWidgets('complete multiline summary scrolls to original action', (
    tester,
  ) async {
    final article = sample(
      summary: List.filled(50, 'A complete paragraph.').join('\n\n'),
    );
    await tester.pumpWidget(
      MaterialApp(home: NewsDetailScreen(article: article)),
    );
    expect(find.text(article.title), findsOneWidget);
    expect(
      find.textContaining('Publisher: future_publisher').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('AI-generated summary').hitTestable(), findsOneWidget);
    final summary = tester.widget<Text>(find.text(article.summary));
    expect(summary.data, article.summary);
    expect(summary.maxLines, isNull);
    expect(find.text('Read original').hitTestable(), findsNothing);
    await tester.scrollUntilVisible(find.text('Read original'), 500);
    expect(find.text('Read original').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('original action passes unchanged URI and external mode', (
    tester,
  ) async {
    final article = sample();
    Uri? opened;
    LaunchMode? requestedMode;
    await tester.pumpWidget(
      MaterialApp(
        home: NewsDetailScreen(
          article: article,
          openUrl: (url, {mode = LaunchMode.platformDefault}) async {
            opened = url;
            requestedMode = mode;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Read original'));
    await tester.pumpAndSettle();
    expect(opened, same(article.sourceUrl));
    expect(requestedMode, LaunchMode.externalApplication);
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final throws in [false, true]) {
    testWidgets(
      'launch ${throws ? 'exception' : 'false result'} shows friendly failure',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NewsDetailScreen(
              article: sample(),
              openUrl: (_, {mode = LaunchMode.platformDefault}) async {
                if (throws) throw Exception('internal platform details');
                return false;
              },
            ),
          ),
        );
        await tester.tap(find.text('Read original'));
        await tester.pumpAndSettle();
        expect(
          find.text('Unable to open the original article.'),
          findsOneWidget,
        );
        expect(find.textContaining('internal platform details'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('launch failure after leaving detail is safe', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: NewsDetailScreen(
          article: sample(),
          openUrl: (_, {mode = LaunchMode.platformDefault}) => pending.future,
        ),
      ),
    );
    await tester.tap(find.text('Read original'));
    await tester.pumpWidget(const SizedBox());
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
