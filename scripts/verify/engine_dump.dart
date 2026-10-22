// Prints Noor's engine output (UTC, minutes since midnight UTC of the civil date)
// for the cases given as JSON on stdin: [{"id":..,"lat":..,"lng":..,"y":..,"m":..,"d":..,"method":".."}]
// Used by verify_prayer_times.py. Run: dart run scripts/verify/engine_dump.dart < cases.json
import 'dart:convert';
import 'dart:io';

import 'package:noor/services/prayer_calc.dart';

void main() {
  final cases = (jsonDecode(stdin.readLineSync() ?? '[]') as List).cast<Map<String, dynamic>>();
  final out = <Map<String, dynamic>>[];
  for (final c in cases) {
    final y = c['y'] as int, m = c['m'] as int, d = c['d'] as int;
    final p = PrayerCalc.params(method: c['method'] as String, highLatitude: (c['highLatitude'] ?? 'middleOfTheNight') as String);
    final day = PrayerCalc.compute(y, m, d, (c['lat'] as num).toDouble(), (c['lng'] as num).toDouble(), p);
    final base = DateTime.utc(y, m, d);
    int mins(DateTime t) => t.difference(base).inMinutes;
    out.add({
      'id': c['id'],
      'fajr': mins(day.fajr),
      'sunrise': mins(day.sunrise),
      'dhuhr': mins(day.dhuhr),
      'asr': mins(day.asr),
      'maghrib': mins(day.maghrib),
      'isha': mins(day.isha),
      'qibla': PrayerCalc.qibla((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble()),
    });
  }
  stdout.writeln(jsonEncode(out));
}
