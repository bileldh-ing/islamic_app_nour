import 'package:adhan_dart/adhan_dart.dart';

import 'location_service.dart';
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

  bool get isFard => this != PrayerName.sunrise;
}

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
}

class PrayerService {
  PrayerService._();

  static const methods = <String, String>{
    'muslimWorldLeague': 'رابطة العالم الإسلامي',
    'ummAlQura': 'أم القرى — مكة المكرمة',
    'egyptian': 'الهيئة المصرية العامة للمساحة',
    'tunisia': 'تونس',
    'algerian': 'الجزائر',
    'morocco': 'المغرب',
    'karachi': 'جامعة العلوم الإسلامية، كراتشي',
    'dubai': 'دبي',
    'qatar': 'قطر',
    'kuwait': 'الكويت',
    'gulfRegion': 'منطقة الخليج',
    'jordan': 'الأردن',
    'turkiye': 'تركيا (ديانت)',
    'northAmerica': 'أمريكا الشمالية (ISNA)',
    'france': 'فرنسا (UOIF)',
    'singapore': 'سنغافورة',
    'indonesian': 'إندونيسيا',
    'russia': 'روسيا',
    'moonsightingCommittee': 'لجنة رؤية الهلال',
  };

  static CalculationParameters _params(AppSettings s) {
    final p = switch (s.method) {
      'ummAlQura' => CalculationMethodParameters.ummAlQura(),
      'egyptian' => CalculationMethodParameters.egyptian(),
      'tunisia' => CalculationMethodParameters.tunisia(),
      'algerian' => CalculationMethodParameters.algerian(),
      'morocco' => CalculationMethodParameters.morocco(),
      'karachi' => CalculationMethodParameters.karachi(),
      'dubai' => CalculationMethodParameters.dubai(),
      'qatar' => CalculationMethodParameters.qatar(),
      'kuwait' => CalculationMethodParameters.kuwait(),
      'gulfRegion' => CalculationMethodParameters.gulfRegion(),
      'jordan' => CalculationMethodParameters.jordan(),
      'turkiye' => CalculationMethodParameters.turkiye(),
      'northAmerica' => CalculationMethodParameters.northAmerica(),
      'france' => CalculationMethodParameters.france(),
      'singapore' => CalculationMethodParameters.singapore(),
      'indonesian' => CalculationMethodParameters.indonesian(),
      'russia' => CalculationMethodParameters.russia(),
      'moonsightingCommittee' => CalculationMethodParameters.moonsightingCommittee(),
      _ => CalculationMethodParameters.muslimWorldLeague(),
    };
    p.madhab = s.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    p.highLatitudeRule = switch (s.highLatitude) {
      'seventhOfTheNight' => HighLatitudeRule.seventhOfTheNight,
      'twilightAngle' => HighLatitudeRule.twilightAngle,
      _ => HighLatitudeRule.middleOfTheNight,
    };
    int adj(String k) => s.adjustments[k] ?? 0;
    p.adjustments = {
      Prayer.fajr: adj('fajr'),
      Prayer.sunrise: adj('sunrise'),
      Prayer.dhuhr: adj('dhuhr'),
      Prayer.asr: adj('asr'),
      Prayer.maghrib: adj('maghrib'),
      Prayer.isha: adj('isha'),
    };
    return p;
  }

  static DayPrayers forDate(DateTime day, {UserLocation? loc, AppSettings? settings}) {
    final l = loc ?? LocationService.current.value ?? UserLocation.makkah;
    final s = settings ?? Store.settings.value;
    final date = DateTime(day.year, day.month, day.day, 12);
    final pt = PrayerTimes(
      date: date,
      coordinates: Coordinates(l.lat, l.lng),
      calculationParameters: _params(s),
    );
    final sunnah = SunnahTimes(pt);
    return DayPrayers(
      DateTime(day.year, day.month, day.day),
      [
        PrayerEntry(PrayerName.fajr, pt.fajr.toLocal()),
        PrayerEntry(PrayerName.sunrise, pt.sunrise.toLocal()),
        PrayerEntry(PrayerName.dhuhr, pt.dhuhr.toLocal()),
        PrayerEntry(PrayerName.asr, pt.asr.toLocal()),
        PrayerEntry(PrayerName.maghrib, pt.maghrib.toLocal()),
        PrayerEntry(PrayerName.isha, pt.isha.toLocal()),
      ],
      sunnah.middleOfTheNight.toLocal(),
      sunnah.lastThirdOfTheNight.toLocal(),
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
  static double qibla(UserLocation l) => Qibla.qibla(Coordinates(l.lat, l.lng));

  // ---------- prayer tracker ----------
  static Set<String> doneOn(DateTime d) => Store.getList('done_${Store.dayKey(d)}').toSet();

  static Future<void> toggleDone(DateTime d, PrayerName p) async {
    final set = doneOn(d);
    if (!set.remove(p.name)) set.add(p.name);
    await Store.setList('done_${Store.dayKey(d)}', set.toList());
  }
}
