// Checks lib/services/geomag.dart against NOAA's official WMM2025 test values.
// Run: dart run scripts/verify/wmm_check.dart   (exit code 1 on failure)
import 'dart:io';

import 'package:noor/services/geomag.dart';

void main() {
  var maxErr = 0.0;
  var count = 0;
  for (final l in File('scripts/verify/WMM2025_TestValues.txt').readAsLinesSync()) {
    if (l.startsWith('#') || l.trim().isEmpty) continue;
    final p = l.trim().split(RegExp(r'\s+')).map(double.parse).toList();
    final d = MagneticModel.declination(p[2], p[3], altKm: p[1], year: p[0]);
    final e = (d - p[4]).abs();
    if (e > maxErr) maxErr = e;
    count++;
  }
  stdout.writeln('WMM2025: $count official test points, max declination error ${maxErr.toStringAsFixed(4)} deg');
  if (maxErr > 0.01) exit(1);
}
