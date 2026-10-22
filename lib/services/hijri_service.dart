import 'package:hijri/hijri_calendar.dart';

import 'storage.dart';

class HijriDate {
  HijriDate(this.day, this.month, this.year, this.lengthOfMonth);
  final int day;
  final int month;
  final int year;
  final int lengthOfMonth;

  static const months = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', //
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  String get monthName => months[month - 1];
  String get formatted => '$day $monthName $year هـ';
}

/// An Islamic occasion on a fixed Hijri date.
class HijriEvent {
  const HijriEvent(this.month, this.day, this.title, this.note, {this.major = false});
  final int month;
  final int day;
  final String title;
  final String note;
  final bool major;
}

/// An event occurrence resolved to a Gregorian date.
class EventOccurrence {
  EventOccurrence(this.event, this.date, this.hijriYear);
  final HijriEvent event;
  final DateTime date;
  final int hijriYear;
  int daysFrom(DateTime from) => DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

/// Umm al-Qura calendar (via the `hijri` package), shifted by the user's
/// `hijriAdjust` setting (+/- days) to follow local moon sighting.
class HijriService {
  HijriService._();

  /// Range supported by the Umm al-Qura tables of the `hijri` package.
  static const minYear = 1356;
  static const maxYear = 1499;

  static const weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const gregMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', //
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static int get _adj => Store.settings.value.hijriAdjust;

  static HijriDate of(DateTime g, {int? adjust}) {
    final h = HijriCalendar.fromDate(DateTime(g.year, g.month, g.day).add(Duration(days: adjust ?? _adj)));
    return HijriDate(h.hDay, h.hMonth, h.hYear, h.lengthOfMonth);
  }

  static HijriDate today() => of(DateTime.now());

  /// Gregorian date of a given Hijri day (respecting user adjustment).
  static DateTime toGregorian(int y, int m, int d, {int? adjust}) {
    final g = HijriCalendar().hijriToGregorian(y, m, d);
    return DateTime(g.year, g.month, g.day).subtract(Duration(days: adjust ?? _adj));
  }

  static int monthLength(int y, int m) => HijriCalendar().getDaysInMonth(y, m);

  static String gregorianLabel(DateTime d) => '${weekdays[d.weekday - 1]}، ${d.day} ${gregMonths[d.month - 1]} ${d.year}';

  /// Islamic occasions. Dates are the widely observed Hijri dates; the
  /// Mawlid and Isra' entries are marked as commemorations (their exact
  /// historical date is debated by scholars).
  static const eventList = <HijriEvent>[
    HijriEvent(1, 1, 'رأس السنة الهجرية', 'بداية العام الهجري الجديد', major: true),
    HijriEvent(1, 9, 'تاسوعاء', 'يُستحب صيامه مع يوم عاشوراء'),
    HijriEvent(1, 10, 'يوم عاشوراء', 'صيامه يكفّر السنة التي قبله', major: true),
    HijriEvent(3, 12, 'ذكرى المولد النبوي', 'على المشهور في تحديد التاريخ'),
    HijriEvent(7, 27, 'ذكرى الإسراء والمعراج', 'على المشهور في تحديد التاريخ'),
    HijriEvent(8, 15, 'النصف من شعبان', 'من الأيام البيض'),
    HijriEvent(9, 1, 'بداية شهر رمضان', 'شهر الصيام والقيام', major: true),
    HijriEvent(9, 21, 'العشر الأواخر من رمضان', 'تُلتمس فيها ليلة القدر في الليالي الوتر'),
    HijriEvent(10, 1, 'عيد الفطر المبارك', 'يحرم صيامه', major: true),
    HijriEvent(12, 1, 'العشر الأوائل من ذي الحجة', 'أفضل أيام الدنيا'),
    HijriEvent(12, 8, 'يوم التروية', 'يتوجه الحجاج إلى منى'),
    HijriEvent(12, 9, 'يوم عرفة', 'صيامه لغير الحاج يكفّر سنتين', major: true),
    HijriEvent(12, 10, 'عيد الأضحى المبارك', 'يوم النحر، يحرم صيامه', major: true),
    HijriEvent(12, 11, 'أيام التشريق', 'أيام أكل وشرب وذكر لله'),
    HijriEvent(12, 12, 'أيام التشريق', 'أيام أكل وشرب وذكر لله'),
    HijriEvent(12, 13, 'أيام التشريق', 'أيام أكل وشرب وذكر لله'),
  ];

  /// Islamic occasions keyed by (month, day).
  static final Map<(int, int), String> events = {for (final e in eventList) (e.month, e.day): e.title};

  static String? eventFor(HijriDate h) => events[(h.month, h.day)];
  static HijriEvent? eventOf(HijriDate h) {
    for (final e in eventList) {
      if (e.month == h.month && e.day == h.day) return e;
    }
    return null;
  }

  /// Upcoming occurrences (today included), sorted by date.
  static List<EventOccurrence> upcoming({DateTime? from, int count = 12, bool collapseTashreeq = true}) {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final h = of(today);
    final out = <EventOccurrence>[];
    for (var y = h.year; y <= h.year + 2 && y <= maxYear; y++) {
      for (final e in eventList) {
        if (collapseTashreeq && e.month == 12 && (e.day == 12 || e.day == 13)) continue;
        final g = toGregorian(y, e.month, e.day);
        if (!g.isBefore(today)) out.add(EventOccurrence(e, g, y));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out.take(count).toList();
  }

  /// First day of the next (or current) Ramadan.
  static DateTime nextRamadan([DateTime? from]) {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final h = of(today);
    final start = toGregorian(h.year, 9, 1);
    final end = toGregorian(h.year, 10, 1);
    if (today.isBefore(end) && !today.isBefore(start)) return start;
    return today.isBefore(start) ? start : toGregorian(h.year + 1, 9, 1);
  }

  /// Fasting is prohibited on both Eids and the days of Tashreeq.
  static bool fastingForbidden(DateTime g) {
    final h = of(g);
    return (h.month == 10 && h.day == 1) || (h.month == 12 && h.day >= 10 && h.day <= 13);
  }

  /// Sunnah fasting suggestion for a Gregorian day.
  static String? sunnahFast(DateTime g) {
    final h = of(g);
    if (h.month == 9) return 'صيام رمضان';
    if (fastingForbidden(g)) return null;
    if (h.month == 12 && h.day == 9) return 'صيام يوم عرفة';
    if (h.month == 1 && h.day == 9) return 'صيام تاسوعاء';
    if (h.month == 1 && h.day == 10) return 'صيام يوم عاشوراء';
    if (h.day >= 13 && h.day <= 15) return 'صيام الأيام البيض';
    if (g.weekday == DateTime.monday) return 'صيام يوم الإثنين';
    if (g.weekday == DateTime.thursday) return 'صيام يوم الخميس';
    return null;
  }
}
