import 'package:flutter_test/flutter_test.dart';
import 'package:noor/services/hijri_service.dart';

/// Expected values fetched on 2026-10-22 from
/// https://api.aladhan.com/v1/gToH/DD-MM-YYYY?calendarMethod=UAQ (Umm al-Qura).
/// All 11 dates matched the `hijri` package before this test was written.
void main() {
  const cases = <(int, int, int, int, int, int)>[
    // gYear, gMonth, gDay, hDay, hMonth, hYear
    (2025, 1, 1, 1, 7, 1446), // 1 Rajab 1446
    (2025, 3, 1, 1, 9, 1446), // 1 Ramadan 1446
    (2025, 3, 30, 1, 10, 1446), // Eid al-Fitr 1446
    (2025, 6, 6, 10, 12, 1446), // Eid al-Adha 1446
    (2025, 6, 26, 1, 1, 1447), // Hijri new year 1447
    (2026, 2, 18, 1, 9, 1447), // 1 Ramadan 1447
    (2026, 3, 20, 1, 10, 1447), // Eid al-Fitr 1447
    (2026, 5, 27, 10, 12, 1447), // Eid al-Adha 1447
    (2026, 6, 16, 1, 1, 1448), // Hijri new year 1448
    (2026, 10, 22, 11, 5, 1448), // 11 Jumada al-Ula 1448
    (2027, 2, 8, 1, 9, 1448), // 1 Ramadan 1448
  ];

  group('Umm al-Qura accuracy (aladhan.com reference)', () {
    for (final c in cases) {
      test('${c.$1}-${c.$2}-${c.$3} -> ${c.$4}/${c.$5}/${c.$6}', () {
        final h = HijriService.of(DateTime(c.$1, c.$2, c.$3), adjust: 0);
        expect((h.day, h.month, h.year), (c.$4, c.$5, c.$6));
        final back = HijriService.toGregorian(c.$6, c.$5, c.$4, adjust: 0);
        expect(back, DateTime(c.$1, c.$2, c.$3));
      });
    }

    test('user adjustment shifts by whole days', () {
      final base = HijriService.of(DateTime(2026, 2, 18), adjust: 0);
      final plus = HijriService.of(DateTime(2026, 2, 18), adjust: 1);
      expect((base.day, base.month), (1, 9));
      expect((plus.day, plus.month), (2, 9));
    });

    test('events cover both Eids and Arafah', () {
      expect(HijriService.events[(10, 1)], contains('الفطر'));
      expect(HijriService.events[(12, 10)], contains('الأضحى'));
      expect(HijriService.events[(12, 9)], contains('عرفة'));
    });

    test('fasting is forbidden on Eid days', () {
      expect(HijriService.fastingForbidden(DateTime(2026, 3, 20)), isTrue); // Eid al-Fitr 1447 (adjust 0 default)
      expect(HijriService.sunnahFast(DateTime(2026, 3, 20)), isNull);
    });
  });
}
