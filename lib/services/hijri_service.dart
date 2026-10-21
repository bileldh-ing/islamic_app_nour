import 'package:hijri/hijri_calendar.dart';

import '../widgets/glass.dart';
import 'storage.dart';

class HijriDate {
  HijriDate(this.day, this.month, this.year, this.lengthOfMonth);
  final int day;
  final int month;
  final int year;
  final int lengthOfMonth;

  static const months = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  String get monthName => months[month - 1];
  String get formatted => '${toArabicDigits(day)} $monthName ${toArabicDigits(year)} هـ';
}

class HijriService {
  HijriService._();

  static const weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const gregMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static HijriDate of(DateTime g) {
    final adj = Store.settings.value.hijriAdjust;
    final h = HijriCalendar.fromDate(DateTime(g.year, g.month, g.day).add(Duration(days: adj)));
    return HijriDate(h.hDay, h.hMonth, h.hYear, h.lengthOfMonth);
  }

  static HijriDate today() => of(DateTime.now());

  /// Gregorian date of a given Hijri day (respecting user adjustment).
  static DateTime toGregorian(int y, int m, int d) {
    final adj = Store.settings.value.hijriAdjust;
    final g = HijriCalendar().hijriToGregorian(y, m, d);
    return DateTime(g.year, g.month, g.day).subtract(Duration(days: adj));
  }

  static int monthLength(int y, int m) => HijriCalendar().getDaysInMonth(y, m);

  static String gregorianLabel(DateTime d) =>
      '${weekdays[d.weekday - 1]}، ${toArabicDigits(d.day)} ${gregMonths[d.month - 1]} ${toArabicDigits(d.year)}';

  /// Islamic occasions keyed by (month, day).
  static const events = <(int, int), String>{
    (1, 1): 'رأس السنة الهجرية',
    (1, 9): 'تاسوعاء',
    (1, 10): 'يوم عاشوراء',
    (3, 12): 'ذكرى المولد النبوي',
    (7, 27): 'ذكرى الإسراء والمعراج',
    (8, 15): 'ليلة النصف من شعبان',
    (9, 1): 'بداية شهر رمضان',
    (9, 27): 'ليلة القدر (المرجّحة)',
    (10, 1): 'عيد الفطر المبارك',
    (12, 8): 'يوم التروية',
    (12, 9): 'يوم عرفة',
    (12, 10): 'عيد الأضحى المبارك',
    (12, 11): 'أيام التشريق',
    (12, 12): 'أيام التشريق',
    (12, 13): 'أيام التشريق',
  };

  static String? eventFor(HijriDate h) => events[(h.month, h.day)];

  /// Sunnah fasting suggestion for a Gregorian day.
  static String? sunnahFast(DateTime g) {
    final h = of(g);
    if (h.month == 9) return 'صيام رمضان';
    if (h.month == 10 && h.day == 1) return null; // Eid — fasting forbidden
    if (h.month == 12 && h.day >= 10 && h.day <= 13) return null; // Eid & Tashreeq
    if (h.month == 12 && h.day == 9) return 'صيام يوم عرفة';
    if (h.month == 1 && (h.day == 9 || h.day == 10)) return 'صيام تاسوعاء وعاشوراء';
    if (h.day >= 13 && h.day <= 15) return 'صيام الأيام البيض';
    if (g.weekday == DateTime.monday) return 'صيام يوم الإثنين';
    if (g.weekday == DateTime.thursday) return 'صيام يوم الخميس';
    return null;
  }
}
