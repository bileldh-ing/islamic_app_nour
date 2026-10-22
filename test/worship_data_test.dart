import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/services/zakat_service.dart';

dynamic _load(String name) => jsonDecode(File('assets/data/$name').readAsStringSync());
final _indic = RegExp('[٠-٩۰-۹]');

void main() {
  test('Nawawi: 42 hadith numbered 1..42 with text, source and title', () {
    final h = _load('hadith_nawawi.json') as List;
    expect(h.length, 42);
    for (var i = 0; i < h.length; i++) {
      expect(h[i]['n'], i + 1);
      for (final k in ['title', 'text', 'source']) {
        expect((h[i][k] as String).trim(), isNotEmpty, reason: 'hadith ${i + 1} $k');
      }
    }
    expect(h[0]['text'], contains('بِالنِّيَّاتِ'));
    expect(h[15]['text'], contains('لَا تَغْضَبْ'));
  });

  test('99 Names: Tirmidhi order, unique, starts with Allah and ends with As-Sabur', () {
    final n = _load('names.json') as List;
    expect(n.length, 99);
    expect(n.map((e) => e['ar']).toSet().length, 99);
    expect(n.first['ar'], 'اللَّهُ');
    expect(n[1]['ar'], 'الرَّحْمَنُ');
    expect(n.last['ar'], 'الصَّبُورُ');
    for (var i = 0; i < 99; i++) {
      expect(n[i]['n'], i + 1);
      expect((n[i]['meaning'] as String).trim(), isNotEmpty);
    }
  });

  test('Azkar library: required categories, counts and references', () {
    final a = _load('azkar.json') as List;
    final ids = a.map((c) => c['id']).toSet();
    for (final id in ['morning', 'evening', 'sleep', 'waking', 'prayer', 'home', 'mosque', 'wudu', 'adhan', 'istikhara', 'travel', 'food',
      'clothing', 'distress', 'sick', 'weather', 'istighfar', 'salawat', 'majlis', 'market', 'anger', 'ruqyah', 'friday', 'qadr']) {
      expect(ids, contains(id));
    }
    for (final c in a) {
      expect((c['items'] as List), isNotEmpty, reason: c['id'] as String);
      for (final z in c['items'] as List) {
        expect((z['t'] as String).trim(), isNotEmpty);
        expect(z['c'] as int, greaterThan(0));
        expect((z['r'] as String).trim(), isNotEmpty, reason: 'reference missing in ${c['id']}');
      }
    }
  });

  test('Duas: groups and categories are consistent', () {
    final d = _load('duas.json') as Map<String, dynamic>;
    final groups = (d['groups'] as List).map((g) => g['id']).toSet();
    for (final c in d['categories'] as List) {
      expect(groups, contains(c['group']));
      expect((c['items'] as List), isNotEmpty);
    }
  });

  test('No Arabic-Indic digits in bundled worship data', () {
    for (final f in ['azkar.json', 'duas.json', 'names.json', 'hadith_nawawi.json']) {
      expect(_indic.hasMatch(File('assets/data/$f').readAsStringSync()), isFalse, reason: f);
    }
  });

  group('Zakat', () {
    test('below nisab -> nothing due', () {
      final r = ZakatService.compute(const ZakatInput(cash: 1000, goldPricePerGram: 300));
      expect(r.due, isFalse);
      expect(r.zakat, 0);
    });
    test('2.5% of net wealth above gold nisab', () {
      final r = ZakatService.compute(const ZakatInput(cash: 40000, debts: 0, goldPricePerGram: 300));
      expect(r.nisab, 85 * 300);
      expect(r.zakat, closeTo(1000, 0.001));
    });
    test('21k gold converted to pure weight', () {
      final r = ZakatService.compute(const ZakatInput(goldGrams: 100, goldKarat: 21, goldPricePerGram: 100));
      expect(r.goldValue, closeTo(8750, 0.001));
      expect(r.due, isTrue);
    });
  });
}
