import 'location_service.dart';
import 'prayer_calc.dart';
import 'storage.dart';

enum PrayerName { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerNameX on PrayerName {
  String get ar => const {
        PrayerName.fajr: 'الفجر',
        PrayerName.sunrise: 'الشروق',
        PrayerName.dhuhr: 'الظهر',
        PrayerName.asr: 'العصر',
        PrayerName.maghrib: 'المغرب',
        PrayerName.isha: 'العشاء',
      }[this]!;

  /// Label for [day]: Dhuhr becomes "الجمعة" on Fridays.
  String arOn(DateTime day) => this == PrayerName.dhuhr && day.weekday == DateTime.friday ? 'الجمعة' : ar;

  bool get isFard => this != PrayerName.sunrise;
}

/// Five obligatory prayers in order.
const fardPrayers = [PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr, PrayerName.maghrib, PrayerName.isha];

class PrayerEntry {
  PrayerEntry(this.name, this.time);
  final PrayerName name;
  final DateTime time;
}

class DayPrayers {
  DayPrayers(this.date, this.entries, this.middleOfNight, this.lastThird);
  final DateTime date;
  final List<PrayerEntry> entries;
  final DateTime middleOfNight;
  final DateTime lastThird;

  DateTime timeOf(PrayerName n) => entries.firstWhere((e) => e.name == n).time;

  /// الإمساك: 10 minutes before Fajr (common timetable convention, not a fiqh limit).
  DateTime get imsak => timeOf(PrayerName.fajr).subtract(const Duration(minutes: 10));

  /// Start of Duha: about 15 minutes after sunrise.
  DateTime get duhaStart => timeOf(PrayerName.sunrise).add(const Duration(minutes: 15));

  bool get isFriday => date.weekday == DateTime.friday;
}

class PrayerService {
  PrayerService._();

  /// id -> Arabic name of every supported calculation method.
  static final methods = <String, String>{for (final m in PrayerCalc.methods) m.id: m.name};

  /// The method actually used: the user's pick, or the country default while [AppSettings.methodAuto] is on.
  static String effectiveMethod([AppSettings? settings, UserLocation? loc]) {
    final s = settings ?? Store.settings.value;
    final l = loc ?? LocationService.current.value;
    if (s.methodAuto && l != null && l.isoCode.isNotEmpty) return PrayerCalc.defaultMethodFor(l.isoCode);
    return s.method;
  }

  static DayPrayers forDate(DateTime day, {UserLocation? loc, AppSettings? settings}) {
    final l = loc ?? LocationService.current.value ?? UserLocation.makkah;
    final s = settings ?? Store.settings.value;
    final p = PrayerCalc.params(
      method: effectiveMethod(s, l),
      madhab: s.madhab,
      highLatitude: s.highLatitude,
      adjustments: s.adjustments,
    );
    final c = PrayerCalc.compute(day.year, day.month, day.day, l.lat, l.lng, p);
    return DayPrayers(
      DateTime(day.year, day.month, day.day),
      [
        PrayerEntry(PrayerName.fajr, c.fajr.toLocal()),
        PrayerEntry(PrayerName.sunrise, c.sunrise.toLocal()),
        PrayerEntry(PrayerName.dhuhr, c.dhuhr.toLocal()),
        PrayerEntry(PrayerName.asr, c.asr.toLocal()),
        PrayerEntry(PrayerName.maghrib, c.maghrib.toLocal()),
        PrayerEntry(PrayerName.isha, c.isha.toLocal()),
      ],
      c.middleOfNight.toLocal(),
      c.lastThird.toLocal(),
    );
  }

  static DayPrayers today() => forDate(DateTime.now());

  /// The next prayer (skipping sunrise) from now, possibly tomorrow's Fajr.
  static PrayerEntry next([DateTime? now]) {
    final n = now ?? DateTime.now();
    final t = forDate(n);
    for (final e in t.entries) {
      if (e.name.isFard && e.time.isAfter(n)) return e;
    }
    return forDate(n.add(const Duration(days: 1))).entries.first;
  }

  /// The prayer whose time we are currently in.
  static PrayerEntry? current([DateTime? now]) {
    final n = now ?? DateTime.now();
    final t = forDate(n);
    PrayerEntry? cur;
    for (final e in t.entries) {
      if (e.name.isFard && !e.time.isAfter(n)) cur = e;
    }
    return cur ?? PrayerEntry(PrayerName.isha, forDate(n.subtract(const Duration(days: 1))).timeOf(PrayerName.isha));
  }

  /// Qibla bearing in degrees from true north.
  static double qibla(UserLocation l) => PrayerCalc.qibla(l.lat, l.lng);

  /// Great-circle distance to the Kaaba (km).
  static double distanceToKaaba(UserLocation l) => PrayerCalc.distanceToKaabaKm(l.lat, l.lng);

  // ---------- prayer tracker ----------
  static Set<String> doneOn(DateTime d) => Store.getList('done_${Store.dayKey(d)}').toSet();

  static Future<void> toggleDone(DateTime d, PrayerName p) async {
    final set = doneOn(d);
    if (!set.remove(p.name)) set.add(p.name);
    await Store.setList('done_${Store.dayKey(d)}', set.toList());
  }

  static int doneCount(DateTime d) => doneOn(d).where((e) => e != PrayerName.sunrise.name).length;

  /// Consecutive days (ending today, or yesterday if today is incomplete) with all five prayers done.
  static int streak([DateTime? now]) {
    final t = now ?? DateTime.now();
    var d = DateTime(t.year, t.month, t.day);
    if (doneCount(d) < 5) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (doneCount(d) >= 5 && n < 3650) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---------- qada (missed prayers to make up) ----------
  static int qada(PrayerName p) => Store.getInt('prayer_qada_${p.name}');

  static Future<void> setQada(PrayerName p, int v) => Store.setInt('prayer_qada_${p.name}', v < 0 ? 0 : v);
}
