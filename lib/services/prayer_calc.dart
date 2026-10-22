import 'dart:math' as math;

import 'package:adhan_dart/adhan_dart.dart';

/// Pure-Dart prayer-time engine (no Flutter imports) so it can be verified
/// from the command line (`scripts/verify/engine_dump.dart`) and unit tests.
///
/// All computations return UTC instants; the UI converts with `toLocal()`.

/// One selectable calculation method.
class CalcMethod {
  const CalcMethod(this.id, this.name, this.detail, {this.aladhanId});
  final String id;
  final String name;
  final String detail;

  /// Matching method id of the Aladhan API (https://api.aladhan.com/v1/methods), used for verification.
  final int? aladhanId;
}

/// UTC times of one day plus the sunnah times derived from them.
class CalcDay {
  CalcDay({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.middleOfNight,
    required this.lastThird,
  });
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha, middleOfNight, lastThird;

  List<DateTime> get six => [fajr, sunrise, dhuhr, asr, maghrib, isha];
}

class PrayerCalc {
  PrayerCalc._();

  static const kaabaLat = 21.4225241;
  static const kaabaLng = 39.8261818;

  static const methods = <CalcMethod>[
    CalcMethod('tunisia', 'تونس — وزارة الشؤون الدينية', 'الفجر 18° · العشاء 18°', aladhanId: 18),
    CalcMethod('algerian', 'الجزائر — وزارة الشؤون الدينية', 'الفجر 18° · العشاء 17°', aladhanId: 19),
    CalcMethod('morocco', 'المغرب — وزارة الأوقاف', 'الفجر 19° · العشاء 17°', aladhanId: 21),
    CalcMethod('ummAlQura', 'أم القرى — مكة المكرمة', 'الفجر 18.5° · العشاء بعد المغرب بـ 90 دقيقة', aladhanId: 4),
    CalcMethod('egyptian', 'الهيئة المصرية العامة للمساحة', 'الفجر 19.5° · العشاء 17.5°', aladhanId: 5),
    CalcMethod('muslimWorldLeague', 'رابطة العالم الإسلامي', 'الفجر 18° · العشاء 17°', aladhanId: 3),
    CalcMethod('karachi', 'جامعة العلوم الإسلامية، كراتشي', 'الفجر 18° · العشاء 18°', aladhanId: 1),
    CalcMethod('northAmerica', 'أمريكا الشمالية (ISNA)', 'الفجر 15° · العشاء 15°', aladhanId: 2),
    CalcMethod('dubai', 'دبي — الإمارات', 'الفجر 18.2° · العشاء 18.2°', aladhanId: 16),
    CalcMethod('qatar', 'قطر', 'الفجر 18° · العشاء بعد المغرب بـ 90 دقيقة', aladhanId: 10),
    CalcMethod('kuwait', 'الكويت', 'الفجر 18° · العشاء 17.5°', aladhanId: 9),
    CalcMethod('gulfRegion', 'منطقة الخليج', 'الفجر 19.5° · العشاء بعد المغرب بـ 90 دقيقة', aladhanId: 8),
    CalcMethod('jordan', 'الأردن — وزارة الأوقاف', 'الفجر 18° · العشاء 18°', aladhanId: 23),
    CalcMethod('turkiye', 'تركيا — رئاسة الشؤون الدينية (ديانت)', 'الفجر 18° · العشاء 17°', aladhanId: 13),
    CalcMethod('tehran', 'معهد الجيوفيزياء، جامعة طهران', 'الفجر 17.7° · العشاء 14°', aladhanId: 7),
    CalcMethod('singapore', 'سنغافورة', 'الفجر 20° · العشاء 18°', aladhanId: 11),
    CalcMethod('indonesian', 'إندونيسيا — وزارة الشؤون الدينية', 'الفجر 20° · العشاء 18°', aladhanId: 20),
    CalcMethod('france', 'فرنسا (UOIF)', 'الفجر 12° · العشاء 12°', aladhanId: 12),
    CalcMethod('russia', 'روسيا — الإدارة الدينية للمسلمين', 'الفجر 16° · العشاء 15°', aladhanId: 14),
    CalcMethod('portugal', 'البرتغال — الجالية الإسلامية في لشبونة', 'الفجر 18° · العشاء بعد المغرب بـ 77 دقيقة', aladhanId: 22),
    CalcMethod('moonsightingCommittee', 'لجنة رؤية الهلال (Moonsighting)', 'الفجر 18° · العشاء 18° مع تعديل موسمي', aladhanId: 15),
  ];

  static CalcMethod method(String id) => methods.firstWhere((m) => m.id == id, orElse: () => methods[5]);

  /// Default method for an ISO-3166 alpha-2 country code (upper or lower case).
  static String defaultMethodFor(String countryCode) {
    final c = countryCode.toUpperCase();
    const map = {
      'TN': 'tunisia',
      'DZ': 'algerian',
      'MA': 'morocco',
      'SA': 'ummAlQura',
      'YE': 'ummAlQura',
      'EG': 'egyptian',
      'SD': 'egyptian',
      'LY': 'egyptian',
      'SY': 'egyptian',
      'LB': 'egyptian',
      'IQ': 'muslimWorldLeague',
      'PS': 'jordan',
      'JO': 'jordan',
      'PK': 'karachi',
      'IN': 'karachi',
      'BD': 'karachi',
      'AF': 'karachi',
      'US': 'northAmerica',
      'CA': 'northAmerica',
      'MX': 'northAmerica',
      'AE': 'dubai',
      'QA': 'qatar',
      'KW': 'kuwait',
      'BH': 'gulfRegion',
      'OM': 'gulfRegion',
      'TR': 'turkiye',
      'IR': 'tehran',
      'SG': 'singapore',
      'MY': 'singapore',
      'BN': 'singapore',
      'ID': 'indonesian',
      'FR': 'france',
      'RU': 'russia',
      'PT': 'portugal',
    };
    return map[c] ?? 'muslimWorldLeague';
  }

  /// Best-effort ISO code from a country name (Arabic or English), used when
  /// a stored location has only a name.
  static String countryCodeFromName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return '';
    const map = {
      'تونس': 'TN', 'tunisia': 'TN', 'tunisie': 'TN',
      'الجزائر': 'DZ', 'algeria': 'DZ', 'algérie': 'DZ',
      'المغرب': 'MA', 'morocco': 'MA', 'maroc': 'MA',
      'السعودية': 'SA', 'المملكة العربية السعودية': 'SA', 'saudi arabia': 'SA',
      'مصر': 'EG', 'egypt': 'EG',
      'ليبيا': 'LY', 'libya': 'LY',
      'الأردن': 'JO', 'jordan': 'JO',
      'فلسطين': 'PS', 'palestine': 'PS',
      'باكستان': 'PK', 'pakistan': 'PK',
      'الهند': 'IN', 'india': 'IN',
      'بنغلاديش': 'BD', 'bangladesh': 'BD',
      'الولايات المتحدة': 'US', 'الولايات المتحدة الأمريكية': 'US', 'united states': 'US', 'usa': 'US',
      'كندا': 'CA', 'canada': 'CA',
      'الإمارات': 'AE', 'الإمارات العربية المتحدة': 'AE', 'united arab emirates': 'AE',
      'قطر': 'QA', 'qatar': 'QA',
      'الكويت': 'KW', 'kuwait': 'KW',
      'البحرين': 'BH', 'bahrain': 'BH',
      'عمان': 'OM', 'عُمان': 'OM', 'oman': 'OM',
      'تركيا': 'TR', 'turkey': 'TR', 'türkiye': 'TR',
      'إيران': 'IR', 'iran': 'IR',
      'سنغافورة': 'SG', 'singapore': 'SG',
      'ماليزيا': 'MY', 'malaysia': 'MY',
      'إندونيسيا': 'ID', 'indonesia': 'ID',
      'فرنسا': 'FR', 'france': 'FR',
      'روسيا': 'RU', 'russia': 'RU',
      'المملكة المتحدة': 'GB', 'united kingdom': 'GB',
      'العراق': 'IQ', 'iraq': 'IQ',
      'سوريا': 'SY', 'syria': 'SY',
      'لبنان': 'LB', 'lebanon': 'LB',
      'اليمن': 'YE', 'yemen': 'YE',
      'السودان': 'SD', 'sudan': 'SD',
    };
    return map[n] ?? '';
  }

  static CalculationParameters params({
    required String method,
    String madhab = 'shafi',
    String highLatitude = 'middleOfTheNight',
    Map<String, int> adjustments = const {},
  }) {
    final p = switch (method) {
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
      'tehran' => CalculationMethodParameters.tehran(),
      'northAmerica' => CalculationMethodParameters.northAmerica(),
      'france' => CalculationMethodParameters.france(),
      'singapore' => CalculationMethodParameters.singapore(),
      'indonesian' => CalculationMethodParameters.indonesian(),
      'russia' => CalculationMethodParameters.russia(),
      'portugal' => CalculationMethodParameters.portugal(),
      'moonsightingCommittee' => CalculationMethodParameters.moonsightingCommittee(),
      _ => CalculationMethodParameters.muslimWorldLeague(),
    };
    p.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    p.highLatitudeRule = switch (highLatitude) {
      'seventhOfTheNight' => HighLatitudeRule.seventhOfTheNight,
      'twilightAngle' => HighLatitudeRule.twilightAngle,
      _ => HighLatitudeRule.middleOfTheNight,
    };
    int adj(String k) => adjustments[k] ?? 0;
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

  /// Times (UTC) for the civil date [y]-[m]-[d] at the given coordinates.
  static CalcDay compute(int y, int m, int d, double lat, double lng, CalculationParameters p) {
    final date = DateTime(y, m, d, 12);
    final pt = PrayerTimes(date: date, coordinates: Coordinates(lat, lng), calculationParameters: p);
    final sunnah = SunnahTimes(pt);
    return CalcDay(
      fajr: pt.fajr.toUtc(),
      sunrise: pt.sunrise.toUtc(),
      dhuhr: pt.dhuhr.toUtc(),
      asr: _asr(y, m, d, lat, lng, p) ?? pt.asr.toUtc(),
      maghrib: pt.maghrib.toUtc(),
      isha: pt.isha.toUtc(),
      middleOfNight: sunnah.middleOfTheNight.toUtc(),
      lastThird: sunnah.lastThirdOfTheNight.toUtc(),
    );
  }

  /// Asr computed with the Sun's declination at the Asr instant itself (iterated),
  /// and the noon shadow from the declination at solar noon. adhan_dart evaluates
  /// both at 0h UT of the date, which drifts up to 3 min at mid/high latitudes
  /// around the equinoxes; this matches Aladhan / PrayTimes.org within 1 min.
  /// Returns null when the Sun never reaches the Asr altitude (polar regions).
  static DateTime? _asr(int y, int m, int d, double lat, double lng, CalculationParameters p) {
    final jd0 = _julianDay(y, m, d);
    final factor = p.madhab == Madhab.hanafi ? 2.0 : 1.0;
    double rad(double x) => x * math.pi / 180;
    final phi = rad(lat);
    var t = 12 - lng / 15; // first guess: solar noon (hours UT)
    final noon = _sun(jd0 + t / 24);
    final noonT = 12 - lng / 15 - noon.$2;
    final dNoon = _sun(jd0 + noonT / 24).$1;
    final alt = math.atan(1 / (factor + math.tan((phi - dNoon).abs())));
    t = noonT + 3;
    for (var i = 0; i < 4; i++) {
      final (dec, eqt) = _sun(jd0 + t / 24);
      final c = (math.sin(alt) - math.sin(phi) * math.sin(dec)) / (math.cos(phi) * math.cos(dec));
      if (c.abs() > 1) return null;
      final h = math.acos(c) * 180 / math.pi / 15;
      t = 12 - lng / 15 - eqt + h;
    }
    final adj = (p.adjustments[Prayer.asr] ?? 0) + (p.methodAdjustments[Prayer.asr] ?? 0);
    final secs = (t * 3600).round() + adj * 60;
    final raw = DateTime.utc(y, m, d).add(Duration(seconds: secs));
    final s = raw.second;
    final up = p.rounding == Rounding.up ? (s > 0) : s >= 30;
    final floor = raw.subtract(Duration(seconds: s));
    return up ? floor.add(const Duration(minutes: 1)) : floor;
  }

  static double _julianDay(int y, int m, int d) {
    var yy = y, mm = m;
    if (mm <= 2) {
      yy -= 1;
      mm += 12;
    }
    final a = (yy / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (yy + 4716)).floor() + (30.6001 * (mm + 1)).floor() + d + b - 1524.5;
  }

  /// Sun declination (radians) and equation of time (hours) at Julian day [jd]
  /// (Astronomical Almanac low-precision formulae, ~1 arc-minute).
  static (double, double) _sun(double jd) {
    double rad(double x) => x * math.pi / 180;
    double fix(double a, double b) => a - b * (a / b).floor();
    final dd = jd - 2451545.0;
    final g = rad(fix(357.529 + 0.98560028 * dd, 360));
    final q = fix(280.459 + 0.98564736 * dd, 360);
    final l = rad(fix(q + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g), 360));
    final e = rad(23.439 - 0.00000036 * dd);
    final ra = fix(math.atan2(math.cos(e) * math.sin(l), math.cos(l)) * 180 / math.pi / 15, 24);
    final dec = math.asin(math.sin(e) * math.sin(l));
    var eqt = q / 15 - ra;
    eqt = eqt - 24 * ((eqt + 12) / 24).floor();
    return (dec, eqt);
  }

  /// Initial great-circle bearing to the Kaaba, degrees clockwise from true north.
  static double qibla(double lat, double lng) => Qibla.qibla(Coordinates(lat, lng));

  /// Great-circle distance to the Kaaba in kilometres (haversine, mean Earth radius 6371.0088 km).
  static double distanceToKaabaKm(double lat, double lng) => distanceKm(lat, lng, kaabaLat, kaabaLng);

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0088;
    double rad(double x) => x * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a.toDouble())));
  }

  /// Points along the great circle from (lat,lng) to the Kaaba (for drawing on a map).
  static List<(double, double)> greatCircle(double lat, double lng, {int steps = 64}) {
    double rad(double x) => x * math.pi / 180;
    double deg(double x) => x * 180 / math.pi;
    final f1 = rad(lat), l1 = rad(lng), f2 = rad(kaabaLat), l2 = rad(kaabaLng);
    final dist = distanceKm(lat, lng, kaabaLat, kaabaLng) / 6371.0088;
    if (dist < 1e-6) return [(lat, lng)];
    final out = <(double, double)>[];
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final a = math.sin((1 - f) * dist) / math.sin(dist);
      final b = math.sin(f * dist) / math.sin(dist);
      final x = a * math.cos(f1) * math.cos(l1) + b * math.cos(f2) * math.cos(l2);
      final y = a * math.cos(f1) * math.sin(l1) + b * math.cos(f2) * math.sin(l2);
      final z = a * math.sin(f1) + b * math.sin(f2);
      out.add((deg(math.atan2(z, math.sqrt(x * x + y * y))), deg(math.atan2(y, x))));
    }
    return out;
  }
}
