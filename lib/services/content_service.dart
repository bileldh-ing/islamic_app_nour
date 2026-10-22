import 'dart:convert';

import 'package:flutter/services.dart';

/// One dhikr / dua entry.
class Zikr {
  Zikr(this.text, this.count, this.description, this.reference, {this.note = '', this.id = ''});

  /// Arabic text.
  final String text;

  /// How many times it is said.
  final int count;

  /// Virtue (fadl) or who said it (for prophets' duas). May be empty.
  final String description;

  /// Source reference ("حصن المسلم", "سورة البقرة: 201").
  final String reference;

  /// Instruction such as "ثلاث مرات إذا أصبح". May be empty.
  final String note;

  /// Stable id `category:index` used for favourites.
  final String id;
}

class ZikrCategory {
  ZikrCategory(this.title, this.items, {this.id = '', this.group = ''});
  final String id;
  final String title;
  final String group;
  final List<Zikr> items;
}

class DuaGroup {
  const DuaGroup(this.id, this.title);
  final String id;
  final String title;
}

class AllahName {
  AllahName(this.number, this.arabic, this.transliteration, this.meaningEn, this.meaning);
  final int number;
  final String arabic;
  final String transliteration;
  final String meaningEn;

  /// Short Arabic explanation.
  final String meaning;
}

/// Hisn al-Muslim azkar & duas, Quranic duas and the 99 Names — bundled offline.
/// Sources are listed in docs/DATA_SOURCES.md.
class ContentService {
  ContentService._();
  static List<ZikrCategory>? _azkar;
  static List<ZikrCategory>? _duas;
  static List<DuaGroup>? _duaGroups;
  static List<AllahName>? _names;

  static List<Zikr> _items(String catId, List raw) => [
        for (var i = 0; i < raw.length; i++)
          Zikr(
            raw[i]['t'] as String,
            (raw[i]['c'] as num?)?.toInt() ?? 1,
            (raw[i]['d'] ?? '') as String,
            (raw[i]['r'] ?? '') as String,
            note: (raw[i]['n'] ?? '') as String,
            id: '$catId:$i',
          ),
      ];

  /// Azkar categories (morning, evening, after prayer, sleep, waking, ...).
  static Future<List<ZikrCategory>> azkar() async {
    if (_azkar != null) return _azkar!;
    final raw = jsonDecode(await rootBundle.loadString('assets/data/azkar.json')) as List;
    _azkar = raw.map((c) {
      final id = (c['id'] ?? c['title']) as String;
      return ZikrCategory(c['title'] as String, _items(id, c['items'] as List), id: id);
    }).toList();
    return _azkar!;
  }

  static Future<List<ZikrCategory>> azkarOnly() => azkar();

  static Future<ZikrCategory?> azkarCategory(String id) async {
    for (final c in await azkar()) {
      if (c.id == id) return c;
    }
    return null;
  }

  static Future<void> _loadDuas() async {
    if (_duas != null) return;
    final raw = jsonDecode(await rootBundle.loadString('assets/data/duas.json')) as Map<String, dynamic>;
    _duaGroups = (raw['groups'] as List).map((g) => DuaGroup(g['id'] as String, g['title'] as String)).toList();
    _duas = (raw['categories'] as List).map((c) {
      final id = c['id'] as String;
      return ZikrCategory(c['title'] as String, _items(id, c['items'] as List), id: id, group: c['group'] as String);
    }).toList();
  }

  /// Quranic duas, prophets' duas and Hisn al-Muslim situational duas.
  static Future<List<ZikrCategory>> duas() async {
    await _loadDuas();
    return _duas!;
  }

  static Future<List<DuaGroup>> duaGroups() async {
    await _loadDuas();
    return _duaGroups!;
  }

  static Future<List<AllahName>> names() async {
    if (_names != null) return _names!;
    final raw = jsonDecode(await rootBundle.loadString('assets/data/names.json')) as List;
    _names = raw
        .map((n) => AllahName(n['n'] as int, n['ar'] as String, (n['tr'] ?? '') as String, (n['en'] ?? '') as String,
            (n['meaning'] ?? '') as String))
        .toList();
    return _names!;
  }

  /// Strips tashkeel/tatweel and unifies letter variants for search.
  static String normalize(String s) => s
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
