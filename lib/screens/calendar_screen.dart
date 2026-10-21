import 'package:flutter/material.dart';

import '../services/hijri_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int _hy;
  late int _hm;

  @override
  void initState() {
    super.initState();
    final t = HijriService.today();
    _hy = t.year;
    _hm = t.month;
  }

  void _shift(int d) => setState(() {
        _hm += d;
        if (_hm > 12) {
          _hm = 1;
          _hy++;
        } else if (_hm < 1) {
          _hm = 12;
          _hy--;
        }
      });

  @override
  Widget build(BuildContext context) {
    final len = HijriService.monthLength(_hy, _hm);
    final first = HijriService.toGregorian(_hy, _hm, 1);
    // Week starts Saturday (common in the Arab world).
    final lead = (first.weekday + 1) % 7; // Sat=0 ... Fri=6
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final events = <(int, String, DateTime)>[];
    for (var d = 1; d <= len; d++) {
      final e = HijriService.events[(_hm, d)];
      if (e != null) events.add((d, e, first.add(Duration(days: d - 1))));
    }
    const heads = ['سبت', 'أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];

    return GlassPage(
      title: 'التقويم الهجري',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        children: [
          GlassCard(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_right_rounded)),
                Expanded(
                  child: Column(children: [
                    Text('${HijriDate.months[_hm - 1]} ${toArabicDigits(_hy)} هـ',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.gold)),
                    Text(
                      '${HijriService.gregMonths[first.month - 1]} ${toArabicDigits(first.year)}',
                      style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5),
                    ),
                  ]),
                ),
                IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_left_rounded)),
              ]),
              const SizedBox(height: 8),
              Row(
                children: heads
                    .map((h) => Expanded(
                        child: Text(h, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5))))
                    .toList(),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.82),
                itemCount: lead + len,
                itemBuilder: (context, i) {
                  if (i < lead) return const SizedBox.shrink();
                  final d = i - lead + 1;
                  final g = first.add(Duration(days: d - 1));
                  final isToday = g == todayKey;
                  final ev = HijriService.events[(_hm, d)] != null;
                  final white = d >= 13 && d <= 15;
                  return Container(
                    margin: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: isToday ? AppColors.goldGradient : null,
                      color: isToday ? null : (ev ? AppColors.aqua.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.04)),
                      border: Border.all(color: ev ? AppColors.aqua.withValues(alpha: 0.6) : Colors.white10),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(toArabicDigits(d),
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15, color: isToday ? AppColors.midnight : AppColors.ivory)),
                      Text(toArabicDigits(g.day),
                          style: TextStyle(fontSize: 10, color: isToday ? AppColors.midnight : AppColors.textFaint)),
                      if (white && !isToday)
                        Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.ivory, shape: BoxShape.circle)),
                    ]),
                  );
                },
              ),
            ]),
          ),
          const SectionTitle('مناسبات هذا الشهر'),
          if (events.isEmpty)
            const GlassCard(
              child: Text('لا توجد مناسبات خاصة. لا تنسَ صيام الأيام البيض (١٣، ١٤، ١٥).',
                  style: TextStyle(color: AppColors.textSoft, height: 1.7)),
            )
          else
            ...events.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Row(children: [
                      AyahMedallion(number: e.$1, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(HijriService.gregorianLabel(e.$3), style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ),
                )),
          const SizedBox(height: 8),
          const Text(
            'التواريخ الهجرية محسوبة فلكيًا (أم القرى) وقد تختلف يومًا عن الرؤية المحلية. يمكنك تعديلها من الإعدادات.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textFaint, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}
