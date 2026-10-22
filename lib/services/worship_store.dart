import 'package:flutter/foundation.dart';

import 'storage.dart';

/// Per-feature persistence for the Worship suite: favourites, azkar progress,
/// tasbih counters and the fasting log. All keys are prefixed with `w_`.
class WorshipStore {
  WorshipStore._();

  /// Bumped on any change so open screens can rebuild.
  static final ValueNotifier<int> changes = ValueNotifier(0);
  static void _bump() => changes.value++;

  // ---------- favourites ----------
  static String _favKey(String kind) => 'w_fav_$kind';
  static Set<String> favourites(String kind) => Store.getList(_favKey(kind)).toSet();
  static bool isFavourite(String kind, String id) => favourites(kind).contains(id);
  static Future<bool> toggleFavourite(String kind, String id) async {
    final s = favourites(kind);
    final added = !s.remove(id);
    if (added) s.add(id);
    await Store.setList(_favKey(kind), s.toList());
    _bump();
    return added;
  }

  // ---------- azkar progress (per day) ----------
  static String _progKey(String cat, DateTime d) => 'w_az_${cat}_${Store.dayKey(d)}';
  static List<int> azkarProgress(String cat, int length, [DateTime? day]) {
    final raw = Store.getList(_progKey(cat, day ?? DateTime.now()));
    return List<int>.generate(length, (i) => i < raw.length ? int.tryParse(raw[i]) ?? 0 : 0);
  }

  static Future<void> saveAzkarProgress(String cat, List<int> counts) async {
    await Store.setList(_progKey(cat, DateTime.now()), counts.map((e) => '$e').toList());
    _bump();
  }

  static Future<void> resetAzkar(String cat) async {
    await Store.prefs.remove(_progKey(cat, DateTime.now()));
    await Store.prefs.remove('w_azdone_${cat}_${Store.dayKey(DateTime.now())}');
    _bump();
  }

  static bool azkarDone(String cat, [DateTime? day]) => Store.getBool('w_azdone_${cat}_${Store.dayKey(day ?? DateTime.now())}');
  static Future<void> markAzkarDone(String cat) async {
    await Store.setBool('w_azdone_${cat}_${Store.dayKey(DateTime.now())}', true);
    _bump();
  }

  /// Consecutive days (ending today or yesterday) on which [cat] was completed.
  static int azkarStreak(String cat) {
    var d = DateTime.now();
    if (!azkarDone(cat, d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (azkarDone(cat, d) && n < 3650) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---------- tasbih ----------
  static int get tasbihLifetime => Store.getInt('w_tasbih_total');
  static int tasbihOn(DateTime d) => Store.getInt('w_tasbih_${Store.dayKey(d)}');
  static Future<void> addTasbih(int n) async {
    await Store.setInt('w_tasbih_total', tasbihLifetime + n);
    final k = 'w_tasbih_${Store.dayKey(DateTime.now())}';
    await Store.setInt(k, Store.getInt(k) + n);
  }

  static List<String> get customDhikr => Store.getList('w_tasbih_custom');
  static Future<void> setCustomDhikr(List<String> v) async {
    await Store.setList('w_tasbih_custom', v);
    _bump();
  }

  // ---------- fasting log ----------
  static Set<String> get fastedDays => Store.getList('w_fasted').toSet();
  static bool fasted(DateTime d) => fastedDays.contains(Store.dayKey(d));
  static Future<void> toggleFasted(DateTime d) async {
    final s = fastedDays;
    final k = Store.dayKey(d);
    if (!s.remove(k)) s.add(k);
    await Store.setList('w_fasted', s.toList());
    _bump();
  }

  /// Removes every key written by the Worship suite.
  static Future<void> clearAll() async {
    for (final k in Store.prefs.getKeys().where((k) => k.startsWith('w_')).toList()) {
      await Store.prefs.remove(k);
    }
    _bump();
  }
}
