import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_article.dart';
import 'article_date_time.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({
    super.key,
    required this.article,
    this.openUrl = launchUrl,
  });

  final NewsArticle article;
  final Future<bool> Function(Uri url, {LaunchMode mode}) openUrl;

  Future<void> _readOriginal(BuildContext context) async {
    var opened = false;
    try {
      opened = await openUrl(
        article.sourceUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Platform failures receive the same user-facing message as a false result.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the original article.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'Publisher: ${article.source} / ${formatArticleDateTime(context, article.publishedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const Chip(label: Text('AI-generated summary')),
              const SizedBox(height: 8),
              Text(article.summary, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _readOriginal(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Read original'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
