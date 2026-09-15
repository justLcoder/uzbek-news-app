import 'package:flutter/material.dart';

import '../features/news/presentation/news_feed_screen.dart';

class UzbekNewsApp extends StatelessWidget {
  const UzbekNewsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Uzbek News',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: const NewsFeedScreen(),
  );
}
