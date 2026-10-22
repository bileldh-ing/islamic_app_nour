import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/services/hijri_service.dart';
import 'package:noor/services/location_service.dart';
import 'package:noor/services/prayer_service.dart';
import 'package:noor/services/quran_service.dart';
import 'package:noor/services/storage.dart';
import 'package:noor/widgets/glass.dart';

void main() {
  const tunis = UserLocation(lat: 36.8065, lng: 10.1815, city: 'تونس');

  group('Prayer times', () {
    test('five prayers plus sunrise, in chronological order', () {
      final d = PrayerService.forDate(DateTime(2026, 10, 21), loc: tunis, settings: AppSettings(method: 'tunisia'));
      expect(d.entries.length, 6);
      for (var i = 1; i < d.entries.length; i++) {
        expect(d.entries[i].time.isAfter(d.entries[i - 1].time), isTrue, reason: '${d.entries[i].name} order');
      }
    });

    test('dhuhr in Tunis is close to solar noon (UTC 11:00-11:40)', () {
      final d = PrayerService.forDate(DateTime(2026, 10, 21), loc: tunis, settings: AppSettings());
      final dhuhrUtc = d.timeOf(PrayerName.dhuhr).toUtc();
      expect(dhuhrUtc.hour, 11);
      expect(dhuhrUtc.minute, lessThan(40));
    });

    test('hanafi asr is later than majority asr', () {
      final day = DateTime(2026, 6, 1);
      final shafi = PrayerService.forDate(day, loc: tunis, settings: AppSettings(madhab: 'shafi'));
      final hanafi = PrayerService.forDate(day, loc: tunis, settings: AppSettings(madhab: 'hanafi'));
      expect(hanafi.timeOf(PrayerName.asr).isAfter(shafi.timeOf(PrayerName.asr)), isTrue);
    });

    test('manual adjustment shifts the time', () {
      final day = DateTime(2026, 3, 1);
      final base = PrayerService.forDate(day, loc: tunis, settings: AppSettings());
      final adj = PrayerService.forDate(day, loc: tunis, settings: AppSettings(adjustments: {'isha': 5}));
      expect(adj.timeOf(PrayerName.isha).difference(base.timeOf(PrayerName.isha)).inMinutes, 5);
    });

    test('qibla from Tunis points east-south-east (~110°)', () {
      final q = PrayerService.qibla(tunis);
      expect(q, inInclusiveRange(105, 116));
    });
  });

  group('Hijri', () {
    test('known conversion: 1 Ramadan 1447 is around 18-19 Feb 2026', () {
      final g = HijriService.toGregorian(1447, 9, 1);
      expect(g.year, 2026);
      expect(g.month, 2);
      expect(g.day, inInclusiveRange(17, 20));
    });

    test('events include both Eids', () {
      expect(HijriService.events[(10, 1)], contains('الفطر'));
      expect(HijriService.events[(12, 10)], contains('الأضحى'));
    });
  });

  group('Utilities', () {
    test('arabic digits', () => expect(toArabicDigits(2026), '٢٠٢٦'));

    test('normalize strips tashkeel', () {
      expect(QuranService.normalize('ٱلْحَمْدُ'), 'الحمد');
    });

    test('settings json round trip', () {
      final s = AppSettings(method: 'ummAlQura', madhab: 'hanafi', preReminderMinutes: 15, translation: 'fr.hamidullah');
      final r = AppSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(r.method, 'ummAlQura');
      expect(r.madhab, 'hanafi');
      expect(r.preReminderMinutes, 15);
      expect(r.translation, 'fr.hamidullah');
    });

    test('day key format', () => expect(Store.dayKey(DateTime(2026, 1, 5)), '2026-01-05'));
  });

  group('Bundled data integrity', () {
    test('quran has 114 surahs and 6236 ayahs with tafsir', () {
      final q = jsonDecode(File('assets/data/quran.json').readAsStringSync()) as List;
      expect(q.length, 114);
      var total = 0;
      for (final s in q) {
        for (final a in s['a'] as List) {
          total++;
          expect((a[0] as String).isNotEmpty, isTrue);
          expect((a[1] as String).isNotEmpty, isTrue);
        }
      }
      expect(total, 6236);
      expect((q[1]['a'] as List).first[0], startsWith('الٓمٓ'));
    });

    test('azkar and names present', () {
      final z = jsonDecode(File('assets/data/azkar.json').readAsStringSync()) as List;
      expect(z.length, greaterThanOrEqualTo(6));
      final n = jsonDecode(File('assets/data/names.json').readAsStringSync()) as List;
      expect(n.length, 99);
    });
  });
}
