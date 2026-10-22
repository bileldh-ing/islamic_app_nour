import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/hijri_service.dart';
import '../../services/notification_service.dart';
import '../../services/prayer_calc.dart';
import '../../services/prayer_service.dart';
import 'adhan_settings_screen.dart';
import 'location_sheet.dart';
import 'mosque_finder_screen.dart';
import 'prayer_settings_screen.dart';
import 'prayer_widgets.dart';
import 'timetable_screen.dart';
import 'tracker_screen.dart';

/// Prayer tab root: location, 14-day strip, next prayer, the six times, sunnah times.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  late DateTime _today;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _today = DateTime(n.year, n.month, n.day);
    _selected = _today;
  }

  bool get _isToday => _selected == _today;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Scaffold(
      backgroundColor: p.bgBottom,
      body: NoorBackground(
        child: SafeArea(
          bottom: false,
          child: PrayerDataBuilder(builder: (context, loc, s) {
            final day = PrayerService.forDate(_selected, loc: loc, settings: s);
            final method = PrayerCalc.method(PrayerService.effectiveMethod(s, loc));
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                _header(context),
                _DateStrip(today: _today, selected: _selected, onPick: (d) => setState(() => _selected = d)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _isToday
                      ? NextPrayerCard(onTap: () => push(context, const TimetableScreen()))
                      : _DayBanner(day: _selected, onToday: () => setState(() => _selected = _today)),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Ticker(
                    period: const Duration(seconds: 30),
                    builder: (context) => _Times(day: day, isToday: _isToday),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 0),
                  child: Row(children: [
                    Icon(PhosphorIconsRegular.info, size: 14, color: p.textFaint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${s.methodAuto ? 'تلقائي: ' : ''}${method.name} · ${s.madhab == 'hanafi' ? 'العصر: الحنفي' : 'العصر: الجمهور'}',
                          style: NoorText.caption(context), maxLines: 2),
                    ),
                  ]),
                ),
                SectionHeader('أوقات السنة'),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _SunnahTimes(day: day)),
                SectionHeader('أدوات الصلاة'),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _Tools()),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مواقيت الصلاة', style: NoorText.h1(context)),
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerStart, child: LocationPill(onTap: () => showLocationSheet(context))),
          ]),
        ),
        GlassIconButton(icon: PhosphorIconsRegular.bellRinging, onTap: () => push(context, const AdhanSettingsScreen())),
        const SizedBox(width: 8),
        GlassIconButton(icon: PhosphorIconsRegular.sliders, onTap: () => push(context, const PrayerSettingsScreen())),
      ]),
    );
  }
}

class _DateStrip extends StatefulWidget {
  const _DateStrip({required this.today, required this.selected, required this.onPick});
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onPick;
  @override
  State<_DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<_DateStrip> {
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = widget.today.add(Duration(days: i));
          final sel = d == widget.selected;
          final h = HijriService.of(d);
          final fri = d.weekday == DateTime.friday;
          return Pressable(
            onTap: () => widget.onPick(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: sel ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(p.accent, Colors.white, 0.15)!, p.accent]) : null,
                color: sel ? null : p.glass,
                border: Border.all(color: sel ? p.accent : p.glassBorder.withValues(alpha: p.isDark ? 0.45 : 1)),
                boxShadow: sel ? [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))] : null,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(i == 0 ? 'اليوم' : Fmt.weekdaysShort[d.weekday - 1],
                    style: NoorText.caption(context).copyWith(color: sel ? p.onAccent : (fri ? p.gold : p.textSoft), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${d.day}', style: NoorText.number(context, size: 20, w: FontWeight.w700).copyWith(color: sel ? p.onAccent : p.text)),
                Text('${h.day} ${_shortHijri(h.month)}',
                    style: NoorText.caption(context).copyWith(fontSize: 10, color: sel ? p.onAccent.withValues(alpha: 0.8) : p.textFaint)),
              ]),
            ),
          );
        },
      ),
    );
  }

  static String _shortHijri(int m) => const ['محرم', 'صفر', 'ربيع 1', 'ربيع 2', 'جمادى 1', 'جمادى 2', 'رجب', 'شعبان', 'رمضان', 'شوال', 'القعدة', 'الحجة'][m - 1];
}

class _DayBanner extends StatelessWidget {
  const _DayBanner({required this.day, required this.onToday});
  final DateTime day;
  final VoidCallback onToday;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final h = HijriService.of(day);
    final ev = HijriService.eventFor(h);
    return Glass(
      strong: true,
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        IconBadge(PhosphorIconsRegular.calendarDots, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Fmt.dateLong(day), style: NoorText.h3(context)),
            const SizedBox(height: 2),
            Text(Fmt.hijri(h.day, h.month, h.year), style: NoorText.label(context).copyWith(color: p.gold)),
            if (ev != null) Text(ev, style: NoorText.caption(context).copyWith(color: p.accent)),
          ]),
        ),
        GlassChip(label: 'اليوم', icon: PhosphorIconsRegular.arrowCounterClockwise, onTap: onToday),
      ]),
    );
  }
}

class _Times extends StatefulWidget {
  const _Times({required this.day, required this.isToday});
  final DayPrayers day;
  final bool isToday;
  @override
  State<_Times> createState() => _TimesState();
}

class _TimesState extends State<_Times> {
  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final isToday = widget.isToday;
    final now = DateTime.now();
    final cur = isToday ? PrayerService.current(now) : null;
    final next = isToday ? PrayerService.next(now) : null;
    final done = PrayerService.doneOn(day.date);
    final canMark = !day.date.isAfter(DateTime(now.year, now.month, now.day));
    return Column(children: [
      for (final e in day.entries)
        PrayerTimeRow(
          entry: e,
          day: day.date,
          isCurrent: cur != null && cur.name == e.name && _sameDay(cur.time, e.time),
          isNext: next != null && next.name == e.name && _sameDay(next.time, e.time),
          passed: isToday && e.time.isBefore(now),
          mode: NotificationService.modeOf(e.name),
          onAlert: () async {
            final m = await NotificationService.cycleMode(e.name);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${e.name.arOn(day.date)}: ${alertLabel(m)}${NotificationService.supported ? '' : ' (التنبيهات تعمل في تطبيق الهاتف)'}'),
              duration: const Duration(seconds: 2),
            ));
          },
          done: e.name.isFard ? done.contains(e.name.name) : null,
          onDone: e.name.isFard && canMark && (!isToday || !e.time.isAfter(now))
              ? () async {
                  await PrayerService.toggleDone(day.date, e.name);
                  tick(true);
                  if (mounted) setState(() {});
                }
              : null,
        ),
    ]);
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SunnahTimes extends StatelessWidget {
  const _SunnahTimes({required this.day});
  final DayPrayers day;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final items = [
      (PhosphorIconsRegular.hourglassMedium, 'الإمساك', day.imsak, 'قبل الفجر بـ 10 دقائق'),
      (PhosphorIconsRegular.sun, 'الضحى', day.duhaStart, 'بعد الشروق بنحو 15 دقيقة'),
      (PhosphorIconsRegular.moon, 'منتصف الليل', day.middleOfNight, 'بين المغرب والفجر'),
      (PhosphorIconsRegular.moonStars, 'الثلث الأخير', day.lastThird, 'وقت قيام الليل'),
    ];
    return Column(children: [
      if (day.isFriday)
        Glass(
          margin: const EdgeInsets.only(bottom: 10),
          radius: 22,
          tint: p.gold,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            IconBadge(PhosphorIconsRegular.mosque, color: p.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('يوم الجمعة', style: NoorText.h3(context)),
                Text('صلاة الجمعة ${Fmt.timeFull(day.timeOf(PrayerName.dhuhr))} · سورة الكهف والإكثار من الصلاة على النبي ﷺ',
                    style: NoorText.caption(context)),
              ]),
            ),
          ]),
        ),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.75,
        padding: EdgeInsets.zero,
        children: [
          for (final it in items)
            Glass(
              radius: 22,
              shadow: false,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(it.$1, size: 18, color: p.gold),
                  const SizedBox(width: 6),
                  Text(it.$2, style: NoorText.label(context).copyWith(color: p.text, fontWeight: FontWeight.w600)),
                ]),
                Text(Fmt.timeFull(it.$3), style: NoorText.number(context, size: 20, w: FontWeight.w700)),
                Text(it.$4, style: NoorText.caption(context).copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
        ],
      ),
    ]);
  }
}

class _Tools extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final tools = [
      (PhosphorIconsRegular.table, 'إمساكية الشهر', 'جدول المواقيت الشهري', const TimetableScreen(), p.accent),
      (PhosphorIconsRegular.chartBar, 'متابعة الصلاة', 'الإحصاءات والقضاء', const TrackerScreen(), p.success),
      (PhosphorIconsRegular.mosque, 'المساجد القريبة', 'ضمن 5 كم', const MosqueFinderScreen(), p.gold),
      (PhosphorIconsRegular.speakerHigh, 'الأذان والتنبيهات', 'لكل صلاة على حدة', const AdhanSettingsScreen(), p.accentSoft),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      padding: EdgeInsets.zero,
      children: [
        for (final t in tools)
          Glass(
            radius: 24,
            padding: const EdgeInsets.all(14),
            onTap: () => push(context, t.$4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconBadge(t.$1, color: t.$5, size: 40),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.$2, style: NoorText.h3(context).copyWith(fontSize: 14.5)),
                Text(t.$3, style: NoorText.caption(context)),
              ]),
            ]),
          ),
      ],
    );
  }
}
