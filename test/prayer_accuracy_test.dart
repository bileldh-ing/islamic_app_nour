// Prayer-time & qibla accuracy against an independent reference (Aladhan API).
//
// Expected values were fetched on 2026-10-22T23:21:01+00:00 from
// https://api.aladhan.com/v1/timings/DD-MM-YYYY?latitude=..&longitude=..&method=N&school=0&latitudeAdjustmentMethod=1
// by scripts/verify/verify_prayer_times.py (fixture: scripts/verify/aladhan_expected.json),
// converted to UTC minutes after 00:00 UTC of the civil date (Isha may exceed 1440).
// Aladhan method ids: Tunisia 18, Umm al-Qura 4, Egypt 5, Turkey 13, MWL 3, ISNA 2, KEMENAG 20, Karachi 1
// (see https://api.aladhan.com/v1/methods). Qibla bearings from https://api.aladhan.com/v1/qibla/LAT/LNG.
// Magnetic declination checked against NOAA's official WMM2025_TestValues.txt.
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/services/geomag.dart';
import 'package:noor/services/location_service.dart';
import 'package:noor/services/prayer_calc.dart';
import 'package:noor/services/prayer_service.dart';
import 'package:noor/services/storage.dart';

class _Case {
  const _Case(this.id, this.lat, this.lng, this.y, this.m, this.d, this.method, this.expected);
  final String id;
  final double lat, lng;
  final int y, m, d;
  final String method;
  final List<int> expected; // fajr, sunrise, dhuhr, asr, maghrib, isha (UTC minutes)
}

const _cases = [
  _Case('tunis-20260320', 36.8065, 10.1815, 2026, 3, 20, 'tunisia', [237, 323, 687, 893, 1051, 1138]),
  _Case('tunis-20260621', 36.8065, 10.1815, 2026, 6, 21, 'tunisia', [128, 241, 681, 913, 1122, 1234]),
  _Case('tunis-20261023', 36.8065, 10.1815, 2026, 10, 23, 'tunisia', [247, 334, 664, 848, 993, 1079]),
  _Case('makkah-20260320', 21.4225, 39.8262, 2026, 3, 20, 'ummAlQura', [129, 205, 568, 772, 932, 1022]),
  _Case('makkah-20260621', 21.4225, 39.8262, 2026, 6, 21, 'ummAlQura', [71, 159, 562, 762, 966, 1056]),
  _Case('makkah-20261023', 21.4225, 39.8262, 2026, 10, 23, 'ummAlQura', [123, 200, 545, 744, 890, 980]),
  _Case('cairo-20260320', 30.0444, 31.2357, 2026, 3, 20, 'egyptian', [152, 239, 603, 809, 966, 1044]),
  _Case('cairo-20260621', 30.0444, 31.2357, 2026, 6, 21, 'egyptian', [68, 174, 597, 812, 1019, 1113]),
  _Case('cairo-20261023', 30.0444, 31.2357, 2026, 10, 23, 'egyptian', [155, 242, 579, 772, 916, 994]),
  _Case('istanbul-20260320', 41.0082, 28.9784, 2026, 3, 20, 'turkiye', [156, 241, 617, 820, 983, 1063]),
  _Case('istanbul-20260621', 41.0082, 28.9784, 2026, 6, 21, 'turkiye', [24, 145, 611, 851, 1067, 1178]),
  _Case('istanbul-20261023', 41.0082, 28.9784, 2026, 10, 23, 'turkiye', [172, 257, 593, 771, 919, 999]),
  _Case('london-20260320', 51.5074, -0.1278, 2026, 3, 20, 'muslimWorldLeague', [250, 363, 728, 924, 1094, 1200]),
  _Case('london-20260621', 51.5074, -0.1278, 2026, 6, 21, 'muslimWorldLeague', [2, 223, 722, 985, 1222, 1442]),
  _Case('london-20261023', 51.5074, -0.1278, 2026, 10, 23, 'muslimWorldLeague', [286, 398, 705, 861, 1011, 1116]),
  _Case('newyork-20260320', 40.7128, -74.006, 2026, 3, 20, 'northAmerica', [584, 659, 1023, 1228, 1388, 1464]),
  _Case('newyork-20260621', 40.7128, -74.006, 2026, 6, 21, 'northAmerica', [465, 565, 1018, 1258, 1471, 1571]),
  _Case('newyork-20261023', 40.7128, -74.006, 2026, 10, 23, 'northAmerica', [600, 676, 1000, 1179, 1324, 1400]),
  _Case('jakarta-20260320', -6.2088, 106.8456, 2026, 3, 20, 'indonesian', [-140, -63, 300, 491, 663, 733]),
  _Case('jakarta-20260621', -6.2088, 106.8456, 2026, 6, 21, 'indonesian', [-142, -59, 294, 496, 647, 722]),
  _Case('jakarta-20261023', -6.2088, 106.8456, 2026, 10, 23, 'indonesian', [-170, -91, 277, 469, 645, 716]),
  _Case('karachi-20260320', 24.8607, 67.0011, 2026, 3, 20, 'karachi', [20, 96, 460, 665, 823, 899]),
  _Case('karachi-20260621', 24.8607, 67.0011, 2026, 6, 21, 'karachi', [-46, 43, 454, 655, 864, 953]),
  _Case('karachi-20261023', 24.8607, 67.0011, 2026, 10, 23, 'karachi', [17, 94, 436, 633, 778, 855]),
];

void main() {
  group('prayer times vs Aladhan (|diff| <= 2 min)', () {
    for (final c in _cases) {
      test(c.id, () {
        final day = PrayerService.forDate(
          DateTime(c.y, c.m, c.d),
          loc: UserLocation(lat: c.lat, lng: c.lng, city: c.id),
          settings: AppSettings(method: c.method, methodAuto: false),
        );
        final base = DateTime.utc(c.y, c.m, c.d);
        final ours = [for (final e in day.entries) e.time.toUtc().difference(base).inMinutes];
        if (ours[5] < ours[4]) ours[5] += 1440;
        for (var i = 0; i < 6; i++) {
          expect((ours[i] - c.expected[i]).abs(), lessThanOrEqualTo(2), reason: '${c.id} ${PrayerName.values[i].name}: ours ${ours[i]} vs ${c.expected[i]}');
        }
      });
    }
  });

  group('qibla bearing vs Aladhan (±0.5°)', () {
    const expected = [
    ('tunis', 36.8065, 10.1815, 112.6657),
    ('cairo', 30.0444, 31.2357, 136.1373),
    ('istanbul', 41.0082, 28.9784, 151.6207),
    ('london', 51.5074, -0.1278, 118.9872),
    ('newyork', 40.7128, -74.006, 58.4817),
    ('jakarta', -6.2088, 106.8456, 295.1517),
    ('karachi', 24.8607, 67.0011, 267.7411),
    ];
    for (final (name, lat, lng, deg) in expected) {
      test(name, () => expect(PrayerCalc.qibla(lat, lng), closeTo(deg, 0.5)));
    }
    test('reference values from the brief', () {
      expect(PrayerCalc.qibla(36.8065, 10.1815), closeTo(112.7, 0.5)); // Tunis
      expect(PrayerCalc.qibla(51.5074, -0.1278), closeTo(118.99, 0.5)); // London
      expect(PrayerCalc.qibla(40.7128, -74.0060), closeTo(58.48, 0.5)); // New York
    });
    test('distance Tunis -> Kaaba is about 3,330 km (great-circle)', () {
      expect(PrayerCalc.distanceToKaabaKm(36.8065, 10.1815), inInclusiveRange(3280, 3380));
    });
  });

  group('WMM2025 declination vs NOAA test values (±0.01°)', () {
    const pts = [
    (2025.0, 28.0, 89.0, -121.0, -99.77),
    (2025.5, 6.0, -36.0, -137.0, 20.28),
    (2026.0, 74.0, -57.0, 3.0, -22.51),
    (2026.5, 14.0, 0.0, 80.0, -3.1),
    (2027.0, 37.0, -66.0, -5.0, -17.22),
    (2027.5, 8.0, 62.0, 53.0, 19.39),
    (2028.0, 49.0, 20.0, 167.0, 5.1),
    (2028.5, 28.0, 54.0, -120.0, 15.43),
    (2029.0, 95.0, -60.0, -59.0, 8.58),
    (2029.5, 31.0, 13.0, -132.0, 9.04),
    ];
    for (final (year, alt, lat, lng, decl) in pts) {
      test('$lat,$lng @ $year', () => expect(MagneticModel.declination(lat, lng, altKm: alt, year: year), closeTo(decl, 0.01)));
    }
  });

  group('method auto-selection', () {
    test('country defaults', () {
      expect(PrayerCalc.defaultMethodFor('TN'), 'tunisia');
      expect(PrayerCalc.defaultMethodFor('sa'), 'ummAlQura');
      expect(PrayerCalc.defaultMethodFor('EG'), 'egyptian');
      expect(PrayerCalc.defaultMethodFor('PK'), 'karachi');
      expect(PrayerCalc.defaultMethodFor('IN'), 'karachi');
      expect(PrayerCalc.defaultMethodFor('US'), 'northAmerica');
      expect(PrayerCalc.defaultMethodFor('CA'), 'northAmerica');
      expect(PrayerCalc.defaultMethodFor('AE'), 'dubai');
      expect(PrayerCalc.defaultMethodFor('QA'), 'qatar');
      expect(PrayerCalc.defaultMethodFor('KW'), 'kuwait');
      expect(PrayerCalc.defaultMethodFor('TR'), 'turkiye');
      expect(PrayerCalc.defaultMethodFor('DE'), 'muslimWorldLeague');
    });
    test('Tunisia method is 18°/18° (Aladhan id 18)', () {
      final p = PrayerCalc.params(method: 'tunisia');
      expect(p.fajrAngle, 18);
      expect(p.ishaAngle, 18);
      expect(PrayerCalc.method('tunisia').aladhanId, 18);
    });
    test('auto uses the country, a manual pick overrides it', () {
      const tunis = UserLocation(lat: 36.8065, lng: 10.1815, city: 'تونس', country: 'تونس');
      expect(PrayerService.effectiveMethod(AppSettings(), tunis), 'tunisia');
      expect(PrayerService.effectiveMethod(AppSettings(method: 'egyptian', methodAuto: false), tunis), 'egyptian');
      const unknown = UserLocation(lat: 10, lng: 10, city: 'x');
      expect(PrayerService.effectiveMethod(AppSettings(method: 'karachi'), unknown), 'karachi');
    });
  });

  group('sunnah times', () {
    test('imsak, duha, night thirds are ordered', () {
      const tunis = UserLocation(lat: 36.8065, lng: 10.1815, city: 'تونس', countryCode: 'TN');
      final d = PrayerService.forDate(DateTime(2026, 10, 23), loc: tunis, settings: AppSettings());
      expect(d.timeOf(PrayerName.fajr).difference(d.imsak).inMinutes, 10);
      expect(d.duhaStart.difference(d.timeOf(PrayerName.sunrise)).inMinutes, 15);
      expect(d.middleOfNight.isAfter(d.timeOf(PrayerName.maghrib)), isTrue);
      expect(d.lastThird.isAfter(d.middleOfNight), isTrue);
    });
  });
}
