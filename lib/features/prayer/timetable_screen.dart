import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/hijri_service.dart';
import '../../services/location_service.dart';
import '../../services/prayer_calc.dart';
import '../../services/prayer_service.dart';
import 'prayer_widgets.dart';

/// Monthly timetable (imsakiya): one row per day with Hijri date, today highlighted.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late DateTime _month;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _rowH = 46.0;

  void _scrollToToday() {
    final n = DateTime.now();
    if (!_scroll.hasClients || n.year != _month.year || n.month != _month.month) return;
    final target = ((n.day - 3) * _rowH).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  void _shift(int d) {
    setState(() => _month = DateTime(_month.year, _month.month + d));
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  List<DayPrayers> _days() {
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    return [for (var i = 1; i <= count; i++) PrayerService.forDate(DateTime(_month.year, _month.month, i))];
  }

  String _hijriRange() {
    final a = HijriService.of(_month);
    final b = HijriService.of(DateTime(_month.year, _month.month + 1, 0));
    if (a.month == b.month) return '${a.monthName} ${a.year} هـ';
    return a.year == b.year ? '${a.monthName} – ${b.monthName} ${b.year} هـ' : '${a.monthName} ${a.year} – ${b.monthName} ${b.year} هـ';
  }

  Future<void> _share(List<DayPrayers> days) async {
    final city = LocationService.current.value?.city ?? '';
    final loc = city.isEmpty ? '' : ' — $city';
    final b = StringBuffer()
      ..writeln('إمساكية ${Fmt.months[_month.month - 1]} ${_month.year}$loc')
      ..writeln(_hijriRange())
      ..writeln(PrayerCalc.method(PrayerService.effectiveMethod()).name)
      ..writeln()
      ..writeln('اليوم | الهجري | الفجر | الشروق | الظهر | العصر | المغرب | العشاء');
    for (final d in days) {
      final h = HijriService.of(d.date);
      b.writeln([
        '${Fmt.weekdaysShort[d.date.weekday - 1]} ${d.date.day}',
        '${h.day} ${h.monthName}',
        for (final e in d.entries) Fmt.time(e.time, h24: true),
      ].join(' | '));
    }
    b.writeln();
    b.writeln('— تطبيق نور');
    await SharePlus.instance.share(ShareParams(text: b.toString(), subject: 'إمساكية ${Fmt.months[_month.month - 1]} ${_month.year}'));
  }

  @override
  Widget build(BuildContext context) {
    return PrayerDataBuilder(builder: (context, loc, s) {
      final p = context.noor;
      final days = _days();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return NoorPage(
        title: 'إمساكية الشهر',
        subtitle: loc.city,
        scroll: false,
        actions: [GlassIconButton(icon: PhosphorIconsRegular.shareNetwork, onTap: () => _share(days))],
        child: Column(children: [
          Glass(
            radius: 24,
            strong: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              GlassIconButton(icon: PhosphorIconsRegular.caretRight, size: 38, onTap: () => _shift(-1)),
              Expanded(
                child: Column(children: [
                  Text('${Fmt.months[_month.month - 1]} ${_month.year}', style: NoorText.h3(context)),
                  Text(_hijriRange(), style: NoorText.caption(context).copyWith(color: p.gold)),
                ]),
              ),
              GlassIconButton(icon: PhosphorIconsRegular.caretLeft, size: 38, onTap: () => _shift(1)),
            ]),
          ),
          const SizedBox(height: 12),
          _HeaderRow(),
          const SizedBox(height: 6),
          Expanded(
            child: Glass(
              radius: 22,
              padding: EdgeInsets.zero,
              child: ListView.builder(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: days.length,
                itemExtent: _rowH,
                itemBuilder: (context, i) => _DayRow(day: days[i], isToday: days[i].date == today),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('الإمساك قبل الفجر بـ 10 دقائق · ${PrayerCalc.method(PrayerService.effectiveMethod(s, loc)).name}',
                style: NoorText.caption(context), textAlign: TextAlign.center),
          ),
        ]),
      );
    });
  }
}

const _cols = [PrayerName.fajr, PrayerName.sunrise, PrayerName.dhuhr, PrayerName.asr, PrayerName.maghrib, PrayerName.isha];

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final st = NoorText.caption(context).copyWith(fontWeight: FontWeight.w600, color: context.noor.textSoft);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        SizedBox(width: 44, child: Text('اليوم', style: st, textAlign: TextAlign.center)),
        SizedBox(width: 56, child: Text('الهجري', style: st, textAlign: TextAlign.center)),
        for (final c in _cols) Expanded(child: Text(c.ar, style: st, textAlign: TextAlign.center, maxLines: 1)),
      ]),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.isToday});
  final DayPrayers day;
  final bool isToday;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final h = HijriService.of(day.date);
    final fri = day.isFriday;
    final num = NoorText.number(context, size: 12.5, w: isToday ? FontWeight.w700 : FontWeight.w500).copyWith(color: isToday ? p.onAccent : p.text);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isToday ? p.accent : (day.date.day.isEven ? p.glass.withValues(alpha: p.isDark ? 0.35 : 0.5) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isToday ? [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Row(children: [
        SizedBox(
          width: 44,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${day.date.day}', style: num.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(Fmt.weekdaysShort[day.date.weekday - 1],
                style: NoorText.caption(context).copyWith(fontSize: 9.5, color: isToday ? p.onAccent : (fri ? p.gold : p.textFaint))),
          ]),
        ),
        SizedBox(
          width: 56,
          child: Text('${h.day} ${h.monthName}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NoorText.caption(context).copyWith(fontSize: 9.5, color: isToday ? p.onAccent : p.gold)),
        ),
        for (final c in _cols) Expanded(child: Text(Fmt.time(day.timeOf(c)), style: num, textAlign: TextAlign.center)),
      ]),
    );
  }
}
