import 'package:flutter/material.dart';

import '../data/news_api.dart';
import '../models/news_article.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key, this.api});

  /// A supplied API remains owned by the caller.
  final NewsApi? api;
  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  late final NewsApi _api;
  List<NewsArticle> _articles = [];
  bool _loading = true;
  bool _failed = false;
  bool _fetching = false;
  @override
  void initState() {
    super.initState();
    _api = widget.api ?? NewsApi();
    _load();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (showLoading) setState(() => _loading = true);
    try {
      final articles = await _api.fetchNews();
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Uzbek News')),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _failed || _articles.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _failed
                                        ? 'Unable to load news. Please check your connection and try again.'
                                        : 'No news is currently available.',
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_failed) ...[
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed: () => _load(showLoading: true),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _articles.length,
                      itemBuilder: (context, index) {
                        final article = _articles[index];
                        final theme = Theme.of(context);
                        final localDate = article.publishedAt.toLocal();
                        final locale = MaterialLocalizations.of(context);
                        final date = locale.formatMediumDate(localDate);
                        final time = locale.formatTimeOfDay(
                          TimeOfDay.fromDateTime(localDate),
                          alwaysUse24HourFormat:
                              MediaQuery.alwaysUse24HourFormatOf(context),
                        );
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article.title,
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  article.summary,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '${article.source} / $date / $time',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    ),
  );
}
