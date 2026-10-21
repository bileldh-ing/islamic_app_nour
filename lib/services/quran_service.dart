import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';

class Ayah {
  Ayah(this.text, this.tafsir, this.page, this.juz, this.sajda, this.globalNumber, this.numberInSurah);
  final String text;
  final String tafsir; // التفسير الميسر
  final int page;
  final int juz;
  final bool sajda;
  final int globalNumber;
  final int numberInSurah;
}

class Surah {
  Surah(this.number, this.name, this.englishName, this.revelation, this.ayahs);
  final int number;
  final String name;
  final String englishName;
  final String revelation;
  final List<Ayah> ayahs;

  String get shortName => name.replaceFirst('سُورَةُ ', '');
  bool get hasBasmala => number != 1 && number != 9;
}

class Bookmark {
  Bookmark(this.surah, this.ayah, this.time);
  final int surah;
  final int ayah;
  final DateTime time;
  String get key => '$surah:$ayah';
}

List<Surah> _parse(String raw) {
  final list = jsonDecode(raw) as List;
  return list.map((s) {
    final ays = <Ayah>[];
    var i = 0;
    for (final a in s['a'] as List) {
      i++;
      ays.add(Ayah(a[0], a[1], a[2], a[3], a[4] == 1, a[5], i));
    }
    return Surah(s['n'], s['name'], s['en'], s['type'], ays);
  }).toList();
}

class QuranService {
  QuranService._();
  static List<Surah>? _surahs;
  static Future<List<Surah>>? _loading;

  static Future<List<Surah>> load() {
    if (_surahs != null) return Future.value(_surahs);
    return _loading ??= () async {
      final raw = await rootBundle.loadString('assets/data/quran.json');
      _surahs = await compute(_parse, raw);
      return _surahs!;
    }();
  }

  static List<Surah> get surahs => _surahs ?? const [];

  /// Remove tashkeel for search matching.
  static String normalize(String s) => s
      .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  static Future<List<(Surah, Ayah)>> search(String q) async {
    final all = await load();
    final nq = normalize(q.trim());
    if (nq.length < 2) return [];
    final out = <(Surah, Ayah)>[];
    for (final s in all) {
      for (final a in s.ayahs) {
        if (normalize(a.text).contains(nq)) {
          out.add((s, a));
          if (out.length >= 150) return out;
        }
      }
    }
    return out;
  }

  // ---------- reading progress ----------
  static final ValueNotifier<(int, int)?> lastRead = ValueNotifier(_readLast());

  static (int, int)? _readLast() {
    final s = Store.prefs.getString('lastRead');
    if (s == null) return null;
    final p = s.split(':');
    return (int.parse(p[0]), int.parse(p[1]));
  }

  static Future<void> setLastRead(int surah, int ayah) async {
    lastRead.value = (surah, ayah);
    await Store.setString('lastRead', '$surah:$ayah');
  }

  // ---------- bookmarks ----------
  static final ValueNotifier<List<Bookmark>> bookmarks = ValueNotifier(_readBookmarks());

  static List<Bookmark> _readBookmarks() => Store.getList('bookmarks').map((e) {
        final p = e.split('|');
        final k = p[0].split(':');
        return Bookmark(int.parse(k[0]), int.parse(k[1]), DateTime.fromMillisecondsSinceEpoch(int.parse(p[1])));
      }).toList();

  static bool isBookmarked(int s, int a) => bookmarks.value.any((b) => b.surah == s && b.ayah == a);

  static Future<void> toggleBookmark(int s, int a) async {
    final l = [...bookmarks.value];
    final i = l.indexWhere((b) => b.surah == s && b.ayah == a);
    if (i >= 0) {
      l.removeAt(i);
    } else {
      l.insert(0, Bookmark(s, a, DateTime.now()));
    }
    bookmarks.value = l;
    await Store.setList('bookmarks', l.map((b) => '${b.key}|${b.time.millisecondsSinceEpoch}').toList());
  }

  // ---------- online translations (cached) ----------
  static const translations = {
    'none': 'بدون',
    'en.sahih': 'English — Saheeh International',
    'fr.hamidullah': 'Français — Hamidullah',
  };

  static Future<List<String>?> translation(int surah, String edition) async {
    if (edition == 'none') return null;
    final key = 'tr_${edition}_$surah';
    final cached = Store.getString(key);
    if (cached != null) return List<String>.from(jsonDecode(cached));
    try {
      final r = await http
          .get(Uri.parse('https://api.alquran.cloud/v1/surah/$surah/$edition'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final ays = (jsonDecode(r.body)['data']['ayahs'] as List).map((e) => e['text'] as String).toList();
      await Store.setString(key, jsonEncode(ays));
      return ays;
    } catch (_) {
      return null;
    }
  }

  /// Verse-by-verse recitation audio (Islamic Network CDN).
  static String audioUrl(int globalAyah, String reciter) =>
      'https://cdn.islamic.network/quran/audio/128/$reciter/$globalAyah.mp3';

  static const reciters = {
    'ar.alafasy': 'مشاري راشد العفاسي',
    'ar.abdulsamad': 'عبد الباسط عبد الصمد',
    'ar.husary': 'محمود خليل الحصري',
    'ar.abdurrahmaansudais': 'عبد الرحمن السديس',
    'ar.mahermuaiqly': 'ماهر المعيقلي',
    'ar.saoodshuraym': 'سعود الشريم',
  };

  /// A deterministic "ayah of the day".
  static (Surah, Ayah)? ayahOfDay() {
    if (_surahs == null) return null;
    final now = DateTime.now();
    final seed = now.year * 372 + now.month * 31 + now.day;
    final g = (seed * 7919) % 6236;
    var count = 0;
    for (final s in _surahs!) {
      if (g < count + s.ayahs.length) return (s, s.ayahs[g - count]);
      count += s.ayahs.length;
    }
    return null;
  }
}
