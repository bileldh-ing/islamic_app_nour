import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/format.dart';
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

/// A reciter with verified verse-by-verse audio sources.
/// Primary: Islamic Network CDN (`cdn.islamic.network/quran/audio/<bitrate>/<id>/<global>.mp3`).
/// Fallback: EveryAyah (`everyayah.com/data/<folder>/<SSSAAA>.mp3`).
/// Each pattern was checked to return HTTP 200/206 for ayah 1 (2026-10-23).
class Reciter {
  const Reciter(this.id, this.name, this.bitrate, this.everyAyahFolder, this.style);
  final String id;
  final String name;
  final int bitrate;
  final String everyAyahFolder;
  final String style;
}

/// Start of a juz in the Madani mushaf.
class JuzInfo {
  const JuzInfo(this.number, this.surah, this.ayah, this.page, this.endPage);
  final int number;
  final int surah;
  final int ayah;
  final int page;
  final int endPage;
}

/// A khatma (complete reading) plan, persisted under `quran.khatma`.
class KhatmaPlan {
  KhatmaPlan({required this.days, required this.start, required this.donePortions, required this.doneDays});
  final int days; // target duration
  final DateTime start;
  final int donePortions; // portions completed so far
  final List<String> doneDays; // Store.dayKey of days a portion was completed

  int get pagesPerDay => (QuranService.totalPages / days).ceil();
  int get totalPortions => (QuranService.totalPages / pagesPerDay).ceil();
  bool get finished => donePortions >= totalPortions;
  int get pagesDone => math.min(QuranService.totalPages, donePortions * pagesPerDay);
  double get progress => pagesDone / QuranService.totalPages;

  /// Next portion to read (1-based start/end pages).
  (int, int) get nextPortion {
    final st = math.min(QuranService.totalPages, donePortions * pagesPerDay + 1);
    return (st, math.min(QuranService.totalPages, st + pagesPerDay - 1));
  }

  int get dayNumber => DateTime.now().difference(DateTime(start.year, start.month, start.day)).inDays + 1;

  /// Portions that should be done by the end of today if on schedule.
  int get expectedPortions => math.min(totalPortions, dayNumber);

  bool get doneToday => doneDays.contains(Store.dayKey(DateTime.now()));

  int get streak {
    final set = doneDays.toSet();
    var d = DateTime.now();
    if (!set.contains(Store.dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (set.contains(Store.dayKey(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  DateTime get targetEnd => DateTime(start.year, start.month, start.day).add(Duration(days: days - 1));

  KhatmaPlan copyWith({int? donePortions, List<String>? doneDays}) =>
      KhatmaPlan(days: days, start: start, donePortions: donePortions ?? this.donePortions, doneDays: doneDays ?? this.doneDays);

  Map<String, dynamic> toJson() => {'days': days, 'start': start.millisecondsSinceEpoch, 'done': donePortions, 'doneDays': doneDays};

  static KhatmaPlan? fromJson(Map<String, dynamic>? j) {
    if (j == null || j['days'] == null) return null;
    return KhatmaPlan(
      days: j['days'] as int,
      start: DateTime.fromMillisecondsSinceEpoch(j['start'] as int),
      donePortions: (j['done'] ?? 0) as int,
      doneDays: List<String>.from((j['doneDays'] ?? const []) as List),
    );
  }
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
      .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640\u08D3-\u08FF\uFEFF]'), '')
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  static List<List<String>>? _normIndex;
  static List<List<String>>? _normIndexAlif;

  /// Uthmani writes many long vowels with a dagger alif (ٰ) instead of a full alif;
  /// this variant spells them out so "الكتاب" or "الصلاة" also match.
  static String normalizeAlif(String s) => normalize(s.replaceAll('وٰ', 'ا').replaceAll('ىٰ', 'ى').replaceAll('\u0670', 'ا'));

  static Future<List<(Surah, Ayah)>> search(String q) async {
    final all = await load();
    final nq = normalize(q.trim()).replaceAll(RegExp(r'\s+'), ' ');
    if (nq.length < 2) return [];
    _normIndex ??= [for (final s in all) [for (final a in s.ayahs) normalize(a.text)]];
    _normIndexAlif ??= [for (final s in all) [for (final a in s.ayahs) normalizeAlif(a.text)]];
    final out = <(Surah, Ayah)>[];
    for (var si = 0; si < all.length; si++) {
      final ns = _normIndex![si];
      final na = _normIndexAlif![si];
      for (var ai = 0; ai < ns.length; ai++) {
        if (ns[ai].contains(nq) || na[ai].contains(nq)) {
          out.add((all[si], all[si].ayahs[ai]));
          if (out.length >= 150) return out;
        }
      }
    }
    return out;
  }

  /// Surahs whose Arabic or transliterated name (or number) matches [q].
  static List<Surah> searchSurahs(String q) {
    final t = q.trim();
    if (t.isEmpty) return surahs;
    final n = int.tryParse(Fmt.western(t));
    if (n != null) return surahs.where((s) => s.number == n).toList();
    final nq = normalize(t).replaceAll('ال', '');
    final lq = t.toLowerCase().replaceAll(RegExp(r"[-' ]"), '');
    return surahs.where((s) {
      final an = normalize(s.shortName).replaceAll('ال', '');
      final en = s.englishName.toLowerCase().replaceAll(RegExp(r"[-' ]"), '');
      return (nq.isNotEmpty && an.contains(nq)) || (lq.isNotEmpty && en.contains(lq));
    }).toList();
  }

  // ---------- structure: pages & juz ----------
  static const totalPages = 604;
  static const totalAyahs = 6236;

  static Surah? surah(int n) => (n >= 1 && n <= surahs.length) ? surahs[n - 1] : null;

  static Ayah? ayah(int surahNo, int ayahNo) {
    final s = surah(surahNo);
    if (s == null || ayahNo < 1 || ayahNo > s.ayahs.length) return null;
    return s.ayahs[ayahNo - 1];
  }

  static List<(int, int)>? _pageStarts;
  static List<JuzInfo>? _juzs;

  /// First (surah, ayah) on each mushaf page, index 0 = page 1.
  static List<(int, int)> get pageStarts {
    if (_pageStarts != null || surahs.isEmpty) return _pageStarts ?? const [];
    final out = List<(int, int)>.filled(totalPages, (1, 1));
    final seen = List<bool>.filled(totalPages + 1, false);
    for (final s in surahs) {
      for (final a in s.ayahs) {
        if (!seen[a.page]) {
          seen[a.page] = true;
          out[a.page - 1] = (s.number, a.numberInSurah);
        }
      }
    }
    return _pageStarts = out;
  }

  static (int, int) pageStart(int page) => pageStarts.isEmpty ? (1, 1) : pageStarts[page.clamp(1, totalPages) - 1];

  /// Surahs that have at least one ayah on [page].
  static List<Surah> surahsOnPage(int page) => surahs.where((s) => s.ayahs.first.page <= page && s.ayahs.last.page >= page).toList();

  /// The 30 juz with their start surah:ayah and page range (derived from the verified data).
  static List<JuzInfo> get juzs {
    if (_juzs != null || surahs.isEmpty) return _juzs ?? const [];
    final starts = <int, (int, int, int)>{};
    for (final s in surahs) {
      for (final a in s.ayahs) {
        starts.putIfAbsent(a.juz, () => (s.number, a.numberInSurah, a.page));
      }
    }
    final out = <JuzInfo>[];
    for (var j = 1; j <= 30; j++) {
      final st = starts[j]!;
      var end = totalPages;
      if (j < 30) {
        final nx = starts[j + 1]!;
        // If the next juz opens its page, this juz ends on the page before.
        end = pageStart(nx.$3) == (nx.$1, nx.$2) ? nx.$3 - 1 : nx.$3;
      }
      out.add(JuzInfo(j, st.$1, st.$2, st.$3, end));
    }
    return _juzs = out;
  }

  /// Fraction of the mushaf reached at the last-read position (by page).
  static double mushafProgress() {
    final lr = lastRead.value;
    final a = lr == null ? null : ayah(lr.$1, lr.$2);
    return a == null ? 0 : a.page / totalPages;
  }

  /// Plain-text share/copy form: ﴿text﴾ [Surah: n].
  static String shareText(Surah s, Ayah a, {bool tafsir = false}) {
    final b = StringBuffer('﴿${a.text}﴾\n[${s.shortName}: ${a.numberInSurah}]');
    if (tafsir) b.write('\n\nالتفسير الميسر: ${a.tafsir}');
    return b.toString();
  }

  // ---------- daily reading (pages read today) ----------
  static String get _todayKey => 'quran.pages.${Store.dayKey(DateTime.now())}';
  static final ValueNotifier<int> pagesReadToday = ValueNotifier(Store.getList(_todayKey).length);

  /// Records that [page] was read today (unique pages per day).
  static Future<void> markPageRead(int page) async {
    final l = Store.getList(_todayKey);
    final v = '$page';
    if (l.contains(v)) {
      if (pagesReadToday.value != l.length) pagesReadToday.value = l.length;
      return;
    }
    l.add(v);
    pagesReadToday.value = l.length;
    await Store.setList(_todayKey, l);
  }

  // ---------- khatma ----------
  static final ValueNotifier<KhatmaPlan?> khatma = ValueNotifier(KhatmaPlan.fromJson(Store.getJson('quran.khatma')));

  static Future<void> startKhatma(int days) async {
    final p = KhatmaPlan(days: days, start: DateTime.now(), donePortions: 0, doneDays: const []);
    khatma.value = p;
    await Store.setJson('quran.khatma', p.toJson());
  }

  static Future<void> completeKhatmaPortion() async {
    final p = khatma.value;
    if (p == null || p.finished) return;
    final today = Store.dayKey(DateTime.now());
    final n = p.copyWith(donePortions: p.donePortions + 1, doneDays: p.doneDays.contains(today) ? p.doneDays : [...p.doneDays, today]);
    khatma.value = n;
    await Store.setJson('quran.khatma', n.toJson());
  }

  static Future<void> undoKhatmaPortion() async {
    final p = khatma.value;
    if (p == null || p.donePortions == 0) return;
    final today = Store.dayKey(DateTime.now());
    final n = p.copyWith(donePortions: p.donePortions - 1, doneDays: p.doneDays.where((d) => d != today).toList());
    khatma.value = n;
    await Store.setJson('quran.khatma', n.toJson());
  }

  static Future<void> resetKhatma() async {
    khatma.value = null;
    await Store.prefs.remove('quran.khatma');
  }

  // ---------- reader preferences (feature-local) ----------
  static final ValueNotifier<bool> hifzMode = ValueNotifier(Store.getBool('quran.hifz'));
  static Future<void> setHifz(bool v) async {
    hifzMode.value = v;
    await Store.setBool('quran.hifz', v);
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
    if (lastRead.value == (surah, ayah)) return;
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
      final expected = surah >= 1 && surah <= surahs.length ? surahs[surah - 1].ayahs.length : ays.length;
      if (ays.length != expected) return null;
      await Store.setString(key, jsonEncode(ays));
      return ays;
    } catch (_) {
      return null;
    }
  }

  static const reciterList = [
    Reciter('ar.alafasy', 'مشاري راشد العفاسي', 128, 'Alafasy_128kbps', 'مرتل'),
    Reciter('ar.abdulsamad', 'عبد الباسط عبد الصمد', 64, 'Abdul_Basit_Murattal_192kbps', 'مرتل'),
    Reciter('ar.husary', 'محمود خليل الحصري', 128, 'Husary_128kbps', 'مرتل'),
    Reciter('ar.abdurrahmaansudais', 'عبد الرحمن السديس', 192, 'Abdurrahmaan_As-Sudais_192kbps', 'مرتل'),
    Reciter('ar.mahermuaiqly', 'ماهر المعيقلي', 128, 'MaherAlMuaiqly128kbps', 'مرتل'),
    Reciter('ar.saoodshuraym', 'سعود الشريم', 64, 'Saood_ash-Shuraym_128kbps', 'مرتل'),
  ];

  static Reciter reciterById(String id) => reciterList.firstWhere((r) => r.id == id, orElse: () => reciterList.first);

  /// id -> Arabic name (kept for existing callers).
  static final Map<String, String> reciters = {for (final r in reciterList) r.id: r.name};

  /// Verse-by-verse recitation audio (Islamic Network CDN, per-reciter verified bitrate).
  static String audioUrl(int globalAyah, String reciter) {
    final r = reciterById(reciter);
    return 'https://cdn.islamic.network/quran/audio/${r.bitrate}/${r.id}/$globalAyah.mp3';
  }

  /// Fallback source (EveryAyah) addressed by surah/ayah.
  static String audioFallbackUrl(int surah, int ayah, String reciter) {
    final r = reciterById(reciter);
    return 'https://everyayah.com/data/${r.everyAyahFolder}/${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';
  }

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
