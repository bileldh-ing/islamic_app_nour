import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/hijri_service.dart';
import '../services/prayer_service.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});
  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  Set<String> get _fasted => Store.getList('fasted').toSet();

  Future<void> _toggle(DateTime d) async {
    final s = _fasted;
    final k = Store.dayKey(d);
    if (!s.remove(k)) s.add(k);
    await Store.setList('fasted', s.toList());
    HapticFeedback.selectionClick();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final p = PrayerService.forDate(today);
    final suhoor = p.timeOf(PrayerName.fajr);
    final iftar = p.timeOf(PrayerName.maghrib);
    final fastedSet = _fasted;
    final upcoming = <(DateTime, String)>[];
    for (var i = 0; i < 30 && upcoming.length < 6; i++) {
      final d = today.add(Duration(days: i));
      final f = HijriService.sunnahFast(d);
      if (f != null) upcoming.add((d, f));
    }
    final month = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));
    final countMonth = month.where((d) => fastedSet.contains(Store.dayKey(d))).length;
    final fastingNow = now.isAfter(suhoor) && now.isBefore(iftar);
    final toIftar = iftar.difference(now);

    return GlassPage(
      title: 'الصيام',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        children: [
          GlassCard(
            glow: true,
            borderGold: true,
            child: Column(children: [
              Row(children: [
                Expanded(child: _time('السحور (الإمساك)', fmtTime(suhoor), Icons.wb_twilight_rounded)),
                Container(width: 1, height: 50, color: Colors.white12),
                Expanded(child: _time('الإفطار', fmtTime(iftar), Icons.nights_stay_rounded)),
              ]),
              if (fastingNow) ...[
                const Divider(color: Colors.white12, height: 26),
                Text('متبقٍ على الإفطار ${fmtDuration(toIftar)}',
                    style: const TextStyle(color: AppColors.aqua, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          GlassCard(
            onTap: () => _toggle(today),
            child: Row(children: [
              Icon(fastedSet.contains(Store.dayKey(today)) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: AppColors.gold, size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('أنا صائم اليوم', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
              ),
              Text('${toArabicDigits(countMonth)} يوم / ٣٠', style: const TextStyle(color: AppColors.textSoft)),
            ]),
          ),
          const SectionTitle('سجل آخر ٣٠ يومًا'),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: month.map((d) {
                final ok = fastedSet.contains(Store.dayKey(d));
                return GestureDetector(
                  onTap: () => _toggle(d),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: ok ? AppColors.goldGradient : null,
                      color: ok ? null : Colors.white.withValues(alpha: 0.06),
                    ),
                    alignment: Alignment.center,
                    child: Text(toArabicDigits(d.day),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ok ? AppColors.midnight : AppColors.textSoft)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SectionTitle('أيام الصيام المسنونة القادمة'),
          ...upcoming.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    const Icon(Icons.event_available_rounded, color: AppColors.aqua),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${HijriService.gregorianLabel(u.$1)} · ${HijriService.of(u.$1).formatted}',
                            style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5)),
                      ]),
                    ),
                  ]),
                ),
              )),
          const SizedBox(height: 6),
          const GlassCard(
            child: Text(
              'دعاء الإفطار: «ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ» — رواه أبو داود',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 18, height: 1.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _time(String l, String v, IconData i) => Column(children: [
        Icon(i, color: AppColors.gold),
        const SizedBox(height: 6),
        Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.gold)),
        Text(l, style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5)),
      ]);
}
