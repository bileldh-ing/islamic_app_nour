import 'dart:convert';

import 'package:flutter/services.dart';

class Hadith {
  Hadith(this.number, this.title, this.narrator, this.text, this.source);
  final int number;

  /// Short topic label taken from the hadith wording.
  final String title;

  /// "عن ... رضي الله عنه" — may be empty for a few entries.
  final String narrator;

  /// Full Arabic text (isnad opening + matn) without the takhrij.
  final String text;

  /// Takhrij as stated by an-Nawawi ("رواه البخاري ومسلم").
  final String source;

  String get shareText => '$title\n\n$text\n\n$source\n\nالأربعون النووية — الحديث $number';
}

/// An-Nawawi's Forty (42) Hadith, bundled offline (assets/data/hadith_nawawi.json).
class HadithService {
  HadithService._();
  static List<Hadith>? _all;

  static Future<List<Hadith>> all() async {
    if (_all != null) return _all!;
    final raw = jsonDecode(await rootBundle.loadString('assets/data/hadith_nawawi.json')) as List;
    _all = raw
        .map((h) => Hadith(h['n'] as int, h['title'] as String, h['narrator'] as String, h['text'] as String, h['source'] as String))
        .toList();
    return _all!;
  }

  /// Rotates one hadith per calendar day.
  static Future<Hadith> daily([DateTime? day]) async {
    final list = await all();
    final d = day ?? DateTime.now();
    final idx = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024, 1, 1)).inDays % list.length;
    return list[idx];
  }
}
