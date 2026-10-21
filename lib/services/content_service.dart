import 'dart:convert';

import 'package:flutter/services.dart';

class Zikr {
  Zikr(this.text, this.count, this.description, this.reference);
  final String text;
  final int count;
  final String description;
  final String reference;
}

class ZikrCategory {
  ZikrCategory(this.title, this.items);
  final String title;
  final List<Zikr> items;
}

class AllahName {
  AllahName(this.number, this.arabic, this.transliteration, this.meaningEn);
  final int number;
  final String arabic;
  final String transliteration;
  final String meaningEn;
}

/// Hisn al-Muslim azkar & duas + the 99 Names, bundled offline.
class ContentService {
  ContentService._();
  static List<ZikrCategory>? _azkar;
  static List<AllahName>? _names;

  static Future<List<ZikrCategory>> azkar() async {
    if (_azkar != null) return _azkar!;
    final raw = jsonDecode(await rootBundle.loadString('assets/data/azkar.json')) as List;
    _azkar = raw
        .map((c) => ZikrCategory(
              c['title'],
              (c['items'] as List).map((z) => Zikr(z['t'], z['c'], z['d'] ?? '', z['r'] ?? '')).toList(),
            ))
        .toList();
    return _azkar!;
  }

  static const duaCategories = ['أدعية قرآنية', 'أدعية الأنبياء'];

  static Future<List<ZikrCategory>> azkarOnly() async =>
      (await azkar()).where((c) => !duaCategories.contains(c.title)).toList();

  static Future<List<ZikrCategory>> duas() async =>
      (await azkar()).where((c) => duaCategories.contains(c.title)).toList();

  static Future<List<AllahName>> names() async {
    if (_names != null) return _names!;
    final raw = jsonDecode(await rootBundle.loadString('assets/data/names.json')) as List;
    _names = raw.map((n) => AllahName(n['n'], n['ar'], n['tr'], n['en'])).toList();
    return _names!;
  }
}
