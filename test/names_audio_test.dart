import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('99 Names recitation timings are complete, ordered and inside the track', () {
    final j = jsonDecode(File('assets/data/names_timings.json').readAsStringSync()) as Map<String, dynamic>;
    final starts = (j['starts'] as List).map((e) => (e as num).toDouble()).toList();
    expect(starts.length, 99);
    for (var i = 1; i < starts.length; i++) {
      expect(starts[i] > starts[i - 1], isTrue, reason: 'name ${i + 1} starts before name $i');
      expect(starts[i] - starts[i - 1] < 6, isTrue, reason: 'gap before name ${i + 1} is too long');
    }
    final closing = (j['closing_start'] as num).toDouble();
    expect(closing > starts.last, isTrue);
    expect(closing < 185.4, isTrue); // track length 185.3 s
    expect(File(j['audio'] as String).existsSync(), isTrue);
  });
}
