import 'package:flutter/material.dart';

String formatArticleDateTime(BuildContext context, DateTime publishedAt) {
  final localDate = publishedAt.toLocal();
  final locale = MaterialLocalizations.of(context);
  final date = locale.formatMediumDate(localDate);
  final time = locale.formatTimeOfDay(
    TimeOfDay.fromDateTime(localDate),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$date / $time';
}
