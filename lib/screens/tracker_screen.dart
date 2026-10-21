import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/prayer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});
  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  static const fard = [PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr, PrayerName.maghrib, PrayerName.isha];

  List<DateTime> get _week {
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  int _streak() {
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);
    var n = 0;
    // today counts if complete, otherwise start from yesterday
    if (PrayerService.doneOn(d).length < 5) d = d.subtract(const Duration(days: 1));
    while (PrayerService.doneOn(d).length >= 5) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  (int, int) _monthStats() {
    final now = DateTime.now();
    var done = 0;
    for (var i = 1; i <= now.day; i++) {
      done += PrayerService.doneOn(DateTime(now.year, now.month, i)).length;
    }
    return (done, now.day * 5);
  }

  @override
  Widget build(BuildContext context) {
    final week = _week;
    final (done, total) = _monthStats();
    final pct = total == 0 ? 0.0 : done / total;
    return GlassPage(
      title: 'متابعة الصلاة',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        children: [
          Row(children: [
            Expanded(
              child: GlassCard(
                glow: true,
                borderGold: true,
                child: Column(children: [
                  const Icon(Icons.local_fire_department_rounded, color: AppColors.gold, size: 30),
                  const SizedBox(height: 6),
                  Text(toArabicDigits(_streak()), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.gold)),
                  const Text('أيام متتالية', style: TextStyle(color: AppColors.textSoft)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                child: Column(children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(AppColors.aqua),
                      ),
                      Text('${toArabicDigits((pct * 100).round())}٪', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text('هذا الشهر ${toArabicDigits(done)}/${toArabicDigits(total)}', style: const TextStyle(color: AppColors.textSoft)),
                ]),
              ),
            ),
          ]),
          const SectionTitle('آخر ٧ أيام'),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
            child: Column(children: [
              Row(children: [
                const SizedBox(width: 62),
                ...week.map((d) => Expanded(
                      child: Column(children: [
                        Text(const ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'][d.weekday - 1],
                            style: const TextStyle(fontSize: 11, color: AppColors.textSoft)),
                        Text(toArabicDigits(d.day), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    )),
              ]),
              const SizedBox(height: 8),
              ...fard.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      SizedBox(width: 62, child: Text(p.ar, style: const TextStyle(fontWeight: FontWeight.w700))),
                      ...week.map((d) {
                        final ok = PrayerService.doneOn(d).contains(p.name);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await PrayerService.toggleDone(d, p);
                              setState(() {});
                            },
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: ok ? AppColors.goldGradient : null,
                                  border: Border.all(color: ok ? Colors.transparent : Colors.white24),
                                ),
                                child: ok ? const Icon(Icons.check_rounded, size: 17, color: AppColors.midnight) : null,
                              ),
                            ),
                          ),
                        );
                      }),
                    ]),
                  )),
            ]),
          ),
          const SizedBox(height: 14),
          const GlassCard(
            child: Text(
              '«إنَّ أوَّلَ ما يُحاسَبُ به العبدُ يومَ القيامةِ من عملِه صلاتُه» — رواه الترمذي',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 18, height: 1.9, color: AppColors.ivory),
            ),
          ),
        ],
      ),
    );
  }
}
