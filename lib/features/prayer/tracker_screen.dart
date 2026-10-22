import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/prayer_service.dart';
import 'prayer_widgets.dart';

/// Prayer tracker: weekly grid, 30-day statistics, streak and qada (missed prayers) counters.
class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});
  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<DateTime> get _week => List.generate(7, (i) => _today.subtract(Duration(days: 6 - i)));

  /// done / total for the last 30 days (today counts only prayers whose time has come).
  (int, int, Map<PrayerName, int>) _stats() {
    final now = DateTime.now();
    var done = 0, total = 0;
    final per = {for (final p in fardPrayers) p: 0};
    final todayTimes = PrayerService.forDate(now);
    for (var i = 0; i < 30; i++) {
      final d = _today.subtract(Duration(days: i));
      final set = PrayerService.doneOn(d);
      for (final p in fardPrayers) {
        if (i == 0 && todayTimes.timeOf(p).isAfter(now)) continue;
        total++;
        if (set.contains(p.name)) {
          done++;
          per[p] = per[p]! + 1;
        }
      }
    }
    return (done, total, per);
  }

  Future<void> _toggle(DateTime d, PrayerName p) async {
    await PrayerService.toggleDone(d, p);
    tick();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final (done, total, per) = _stats();
    final pct = total == 0 ? 0.0 : done / total;
    final streak = PrayerService.streak();
    final todayCount = PrayerService.doneCount(_today);
    return NoorPage(
      title: 'متابعة الصلاة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Glass(
              radius: 26,
              tint: p.gold,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: StatBlock(value: '$streak', label: streak == 1 ? 'يوم متتالٍ' : 'أيام متتالية', icon: PhosphorIconsFill.flame, color: p.gold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Glass(
              radius: 26,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(value: pct, strokeWidth: 6, backgroundColor: p.glassStrong, strokeCap: StrokeCap.round),
                    ),
                    Text(Fmt.percent(pct), style: NoorText.number(context, size: 15, w: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 6),
                Text('آخر 30 يومًا', style: NoorText.caption(context)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Glass(
              radius: 26,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: StatBlock(value: '$todayCount/5', label: 'صلوات اليوم', icon: PhosphorIconsFill.checkCircle, color: p.success),
            ),
          ),
        ]),
        SectionHeader('هذا الأسبوع', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
        Glass(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
          child: Column(children: [
            Row(children: [
              const SizedBox(width: 64),
              for (final d in _week)
                Expanded(
                  child: Column(children: [
                    Text(Fmt.weekdaysShort[d.weekday - 1],
                        style: NoorText.caption(context).copyWith(color: d == _today ? p.accent : p.textFaint, fontWeight: FontWeight.w600)),
                    Text('${d.day}', style: NoorText.number(context, size: 13).copyWith(color: d == _today ? p.accent : p.textSoft)),
                  ]),
                ),
            ]),
            const SizedBox(height: 6),
            for (final pr in fardPrayers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                    width: 64,
                    child: Row(children: [
                      Icon(prayerIcon(pr), size: 15, color: p.textSoft),
                      const SizedBox(width: 4),
                      Text(pr.ar, style: NoorText.label(context).copyWith(fontSize: 12)),
                    ]),
                  ),
                  for (final d in _week) Expanded(child: Center(child: _Cell(day: d, prayer: pr, onTap: () => _toggle(d, pr)))),
                ]),
              ),
          ]),
        ),
        SectionHeader('الالتزام بكل صلاة', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
        Glass(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (final pr in fardPrayers) ...[
              Row(children: [
                SizedBox(width: 56, child: Text(pr.ar, style: NoorText.label(context))),
                Expanded(child: GlassProgress(per[pr]! / 30, height: 8)),
                SizedBox(
                  width: 52,
                  child: Text('${per[pr]}/30', textAlign: TextAlign.end, style: NoorText.number(context, size: 12.5).copyWith(color: p.textSoft)),
                ),
              ]),
              if (pr != PrayerName.isha) const SizedBox(height: 12),
            ],
          ]),
        ),
        SectionHeader('القضاء (صلوات فائتة)', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
        Glass(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(children: [
            for (final pr in fardPrayers) _QadaRow(prayer: pr, onChanged: () => setState(() {})),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Text('سجّل عدد الصلوات التي فاتتك، وأنقص العداد كلما قضيت صلاة.', style: NoorText.caption(context), textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.prayer, required this.onTap});
  final DateTime day;
  final PrayerName prayer;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final done = PrayerService.doneOn(day).contains(prayer.name);
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final future = isToday && PrayerService.forDate(day).timeOf(prayer).isAfter(now);
    final cell = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? p.success : (future ? Colors.transparent : p.glassStrong),
        border: Border.all(color: done ? p.success : p.glassBorder.withValues(alpha: future ? 0.3 : 0.6)),
        boxShadow: done ? [BoxShadow(color: p.success.withValues(alpha: 0.35), blurRadius: 8)] : null,
      ),
      child: done ? Icon(PhosphorIconsBold.check, size: 15, color: p.onAccent) : null,
    );
    return future ? cell : Pressable(onTap: onTap, child: cell);
  }
}

class _QadaRow extends StatelessWidget {
  const _QadaRow({required this.prayer, required this.onChanged});
  final PrayerName prayer;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final v = PrayerService.qada(prayer);
    Future<void> set(int n) async {
      await PrayerService.setQada(prayer, n);
      onChanged();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        IconBadge(prayerIcon(prayer), size: 36, color: v > 0 ? p.gold : p.textSoft),
        const SizedBox(width: 10),
        Expanded(child: Text(prayer.ar, style: NoorText.h3(context).copyWith(fontSize: 15))),
        GlassIconButton(icon: PhosphorIconsRegular.minus, size: 34, onTap: v > 0 ? () => set(v - 1) : () {}),
        SizedBox(
          width: 56,
          child: Text('$v', textAlign: TextAlign.center, style: NoorText.number(context, size: 18, w: FontWeight.w700).copyWith(color: v > 0 ? p.gold : p.textFaint)),
        ),
        GlassIconButton(icon: PhosphorIconsRegular.plus, size: 34, onTap: () => set(v + 1)),
      ]),
    );
  }
}
