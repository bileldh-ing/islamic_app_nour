import '../services/storage.dart';

/// All user-visible numbers use Western digits (0-9) — never Arabic-Indic.
/// Dates and times are formatted by hand so no locale can swap the digits.
class Fmt {
  Fmt._();

  static const weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد']; // DateTime.weekday 1..7
  static const weekdaysShort = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];
  static const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static const hijriMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', //
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  static String two(int n) => n.toString().padLeft(2, '0');

  /// Converts any Arabic-Indic / Persian digits in [s] to Western digits.
  static String western(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in s.runes) {
      final c = String.fromCharCode(ch);
      final i = ar.indexOf(c);
      final j = fa.indexOf(c);
      b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : c));
    }
    return b.toString();
  }

  static bool get use24h => Store.settings.value.use24h;

  /// 05:07 (24h) or 5:07 (12h, period returned separately by [period]).
  static String time(DateTime t, {bool? h24}) {
    final is24 = h24 ?? use24h;
    if (is24) return '${two(t.hour)}:${two(t.minute)}';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${two(t.minute)}';
  }

  /// "ص" / "م" in 12h mode, empty in 24h mode.
  static String period(DateTime t, {bool? h24}) => (h24 ?? use24h) ? '' : (t.hour < 12 ? 'ص' : 'م');

  static String timeFull(DateTime t) {
    final p = period(t);
    return p.isEmpty ? time(t) : '${time(t)} $p';
  }

  /// 02:14:09 countdown.
  static String countdown(Duration d) {
    if (d.isNegative) d = Duration.zero;
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  /// "2 س 14 د" style.
  static String durationShort(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h == 0) return '$m د';
    return '$h س $m د';
  }

  static String weekday(DateTime d) => weekdays[d.weekday - 1];

  /// الخميس، 22 أكتوبر 2026
  static String dateLong(DateTime d) => '${weekday(d)}، ${d.day} ${months[d.month - 1]} ${d.year}';
  static String dateMedium(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
  static String dateShort(DateTime d) => '${d.day} ${months[d.month - 1]}';

  static String hijri(int day, int month, int year) => '$day ${hijriMonths[month - 1]} $year هـ';

  /// Thousands separators: 6236 -> 6,236.
  static String number(num n, {int decimals = 0}) {
    final neg = n < 0;
    final s = n.abs().toStringAsFixed(decimals);
    final parts = s.split('.');
    final b = StringBuffer();
    final digits = parts[0];
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    final out = parts.length > 1 ? '$b.${parts[1]}' : b.toString();
    return neg ? '-$out' : out;
  }

  static String percent(double v) => '${(v * 100).round()}%';

  static String distanceKm(double km) => km >= 100 ? '${number(km)} كم' : (km >= 1 ? '${km.toStringAsFixed(1)} كم' : '${(km * 1000).round()} م');
}
