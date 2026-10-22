import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/hijri_service.dart';
import '../../services/storage.dart';
import 'worship_widgets.dart';

/// Hijri calendar (Umm al-Qura, adjustable) with Gregorian dates, occasions and a converter.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int _y;
  late int _m;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final h = HijriService.today();
    _y = h.year;
    _m = h.month;
  }

  void _shift(int d) {
    var m = _m + d, y = _y;
    if (m > 12) {
      m = 1;
      y++;
    } else if (m < 1) {
      m = 12;
      y--;
    }
    if (y < HijriService.minYear || y > HijriService.maxYear) return;
    setState(() {
      _m = m;
      _y = y;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final adj = Store.settings.value.hijriAdjust;
    return NoorPage(
      title: 'التقويم الهجري',
      subtitle: 'أم القرى${adj == 0 ? '' : ' · تعديل ${adj > 0 ? '+' : ''}$adj يوم'}',
      actions: [GlassIconButton(icon: PhosphorIconsRegular.arrowsLeftRight, onTap: () => _converter(context))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _todayCard(context),
        const SizedBox(height: 14),
        _month(context),
        if (_selected != null) ...[const SizedBox(height: 12), _dayInfo(context, _selected!)],
        const SectionHeader('المناسبات القادمة', padding: EdgeInsets.fromLTRB(0, 24, 0, 12)),
        ..._upcoming(context),
        const SizedBox(height: 8),
        Text('تُحسب التواريخ وفق تقويم أم القرى، وقد تختلف بيوم عن رؤية الهلال في بلدك. يمكنك ضبط الفرق من الإعدادات.',
            textAlign: TextAlign.center, style: NoorText.caption(context).copyWith(height: 1.7)),
      ]),
    );
  }

  Widget _todayCard(BuildContext context) {
    final now = DateTime.now();
    final h = HijriService.of(now);
    final ev = HijriService.eventOf(h);
    return HeroPhotoCard(
      image: 'assets/images/hero_night.jpg',
      height: 150,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('اليوم', style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
        Text(Fmt.hijri(h.day, h.month, h.year),
            style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(Fmt.dateLong(now), style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
        if (ev != null) ...[
          const SizedBox(height: 6),
          Text(ev.title, style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF5D894))),
        ],
      ]),
    );
  }

  Widget _month(BuildContext context) {
    final p = context.noor;
    final len = HijriService.monthLength(_y, _m);
    final first = HijriService.toGregorian(_y, _m, 1);
    // Week starts Saturday (common in the Arab world): Sat=0 ... Fri=6.
    final lead = (first.weekday + 1) % 7;
    final today = DateTime.now();
    final todayKey = Store.dayKey(today);
    const heads = ['سبت', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع'];
    final last = first.add(Duration(days: len - 1));
    return Glass(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(children: [
        Row(children: [
          GlassIconButton(icon: PhosphorIconsRegular.caretRight, size: 38, onTap: () => _shift(-1)),
          Expanded(
            child: Column(children: [
              Text('${Fmt.hijriMonths[_m - 1]} $_y هـ', style: NoorText.h3(context)),
              Text(
                first.month == last.month
                    ? '${Fmt.months[first.month - 1]} ${first.year}'
                    : '${Fmt.months[first.month - 1]} - ${Fmt.months[last.month - 1]} ${last.year}',
                style: NoorText.caption(context),
              ),
            ]),
          ),
          GlassIconButton(icon: PhosphorIconsRegular.caretLeft, size: 38, onTap: () => _shift(1)),
        ]),
        const SizedBox(height: 12),
        Row(children: [for (final h in heads) Expanded(child: Center(child: Text(h, style: NoorText.caption(context))))]),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lead + len,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.82),
          itemBuilder: (context, i) {
            if (i < lead) return const SizedBox();
            final d = i - lead + 1;
            final g = first.add(Duration(days: d - 1));
            final isToday = Store.dayKey(g) == todayKey;
            final ev = HijriService.events[(_m, d)];
            final white = d >= 13 && d <= 15;
            final sel = _selected != null && Store.dayKey(_selected!) == Store.dayKey(g);
            return GestureDetector(
              onTap: () {
                tick();
                setState(() => _selected = g);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isToday ? p.accent : (sel ? p.accent.withValues(alpha: 0.16) : (ev != null ? p.gold.withValues(alpha: 0.12) : null)),
                  border: sel && !isToday ? Border.all(color: p.accent.withValues(alpha: 0.6)) : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$d', style: NoorText.number(context, size: 15).copyWith(color: isToday ? p.onAccent : p.text)),
                  Text('${g.day}', style: NoorText.caption(context).copyWith(fontSize: 10, color: isToday ? p.onAccent.withValues(alpha: 0.8) : p.textFaint)),
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ev != null ? p.gold : (white ? p.accent.withValues(alpha: 0.6) : Colors.transparent),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(context, p.gold, 'مناسبة'),
          const SizedBox(width: 14),
          _legend(context, p.accent.withValues(alpha: 0.6), 'الأيام البيض'),
        ]),
      ]),
    );
  }

  Widget _legend(BuildContext context, Color c, String l) => Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
        const SizedBox(width: 5),
        Text(l, style: NoorText.caption(context)),
      ]);

  Widget _dayInfo(BuildContext context, DateTime g) {
    final h = HijriService.of(g);
    final ev = HijriService.eventOf(h);
    final fast = HijriService.sunnahFast(g);
    return Glass(
      radius: 22,
      child: Row(children: [
        IconBadge(ev != null ? PhosphorIconsRegular.star : PhosphorIconsRegular.calendarBlank, color: ev != null ? context.noor.gold : null),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Fmt.hijri(h.day, h.month, h.year), style: NoorText.h3(context).copyWith(fontSize: 15)),
            Text(Fmt.dateLong(g), style: NoorText.caption(context)),
            if (ev != null) Text('${ev.title} — ${ev.note}', style: NoorText.label(context).copyWith(color: context.noor.gold)),
            if (HijriService.fastingForbidden(g))
              Text('يحرم صيام هذا اليوم', style: NoorText.label(context).copyWith(color: context.noor.danger))
            else if (fast != null)
              Text(fast, style: NoorText.label(context).copyWith(color: context.noor.accent)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _upcoming(BuildContext context) {
    final now = DateTime.now();
    final list = HijriService.upcoming(count: 10);
    if (list.isEmpty) return [const EmptyState(icon: PhosphorIconsRegular.calendarBlank, title: 'لا توجد مناسبات قريبة')];
    return [
      for (final e in list)
        Glass(
          margin: const EdgeInsets.only(bottom: 10),
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            IconBadge(e.event.major ? PhosphorIconsRegular.star : PhosphorIconsRegular.calendarDots, color: e.event.major ? context.noor.gold : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.event.title, style: NoorText.h3(context).copyWith(fontSize: 15)),
                Text('${Fmt.hijri(e.event.day, e.event.month, e.hijriYear)} · ${Fmt.dateMedium(e.date)}', style: NoorText.caption(context)),
              ]),
            ),
            _daysLeft(context, e.daysFrom(now)),
          ]),
        ),
    ];
  }

  Widget _daysLeft(BuildContext context, int d) {
    final p = context.noor;
    if (d == 0) return InfoPill('اليوم', color: p.success);
    if (d == 1) return const InfoPill('غدًا');
    return Column(children: [
      Text('$d', style: NoorText.number(context, size: 18).copyWith(color: p.accent)),
      Text('يوم', style: NoorText.caption(context)),
    ]);
  }

  void _converter(BuildContext context) => showGlassSheet(context, title: 'تحويل التاريخ', builder: (_) => const _Converter());
}

class _Converter extends StatefulWidget {
  const _Converter();
  @override
  State<_Converter> createState() => _ConverterState();
}

class _ConverterState extends State<_Converter> {
  int _mode = 0; // 0 greg -> hijri, 1 hijri -> greg
  DateTime _g = DateTime.now();
  late int _hy, _hm, _hd;

  @override
  void initState() {
    super.initState();
    final h = HijriService.today();
    _hy = h.year;
    _hm = h.month;
    _hd = h.day;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    String result;
    if (_mode == 0) {
      final h = HijriService.of(_g);
      result = Fmt.hijri(h.day, h.month, h.year);
    } else {
      final len = HijriService.monthLength(_hy, _hm);
      if (_hd > len) _hd = len;
      result = Fmt.dateLong(HijriService.toGregorian(_hy, _hm, _hd));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChipBar(labels: const ['ميلادي ← هجري', 'هجري ← ميلادي'], index: _mode, onChanged: (i) => setState(() => _mode = i), padding: EdgeInsets.zero),
        const SizedBox(height: 16),
        if (_mode == 0)
          Row(children: [
            Expanded(child: _stepper(context, 'اليوم', '${_g.day}', () => _setG(_g.subtract(const Duration(days: 1))), () => _setG(_g.add(const Duration(days: 1))))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _stepper(context, 'الشهر', Fmt.months[_g.month - 1], () => _setG(_addMonths(_g, -1)), () => _setG(_addMonths(_g, 1)))),
            const SizedBox(width: 8),
            Expanded(child: _stepper(context, 'السنة', '${_g.year}', () => _setG(_addMonths(_g, -12)), () => _setG(_addMonths(_g, 12)))),
          ])
        else
          Row(children: [
            Expanded(child: _stepper(context, 'اليوم', '$_hd', () => setState(() => _hd = _hd > 1 ? _hd - 1 : HijriService.monthLength(_hy, _hm)), () => setState(() => _hd = _hd < HijriService.monthLength(_hy, _hm) ? _hd + 1 : 1))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _stepper(context, 'الشهر', Fmt.hijriMonths[_hm - 1], () => setState(() => _hm = _hm > 1 ? _hm - 1 : 12), () => setState(() => _hm = _hm < 12 ? _hm + 1 : 1))),
            const SizedBox(width: 8),
            Expanded(
              child: _stepper(context, 'السنة', '$_hy', () => setState(() => _hy = (_hy - 1).clamp(HijriService.minYear, HijriService.maxYear)),
                  () => setState(() => _hy = (_hy + 1).clamp(HijriService.minYear, HijriService.maxYear))),
            ),
          ]),
        const SizedBox(height: 16),
        Glass(
          radius: 22,
          tint: p.accent,
          child: Column(children: [
            Text('النتيجة', style: NoorText.caption(context)),
            const SizedBox(height: 4),
            Text(result, textAlign: TextAlign.center, style: NoorText.h2(context)),
          ]),
        ),
        const SizedBox(height: 10),
        MiniAction(icon: PhosphorIconsRegular.copy, onTap: () => copyText(context, result)),
      ]),
    );
  }

  static DateTime _addMonths(DateTime d, int n) {
    final m0 = d.month - 1 + n;
    final y = d.year + (m0 / 12).floor();
    final m = m0 % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.day > last ? last : d.day);
  }

  void _setG(DateTime d) {
    final min = HijriService.toGregorian(HijriService.minYear, 1, 1, adjust: 0);
    final max = HijriService.toGregorian(HijriService.maxYear, 12, 1, adjust: 0);
    if (d.isBefore(min) || d.isAfter(max)) return;
    setState(() => _g = d);
  }

  Widget _stepper(BuildContext context, String label, String value, VoidCallback dec, VoidCallback inc) => Glass(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shadow: false,
        child: Column(children: [
          Text(label, style: NoorText.caption(context)),
          FittedBox(child: Text(value, style: NoorText.h3(context))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            GestureDetector(onTap: inc, child: Icon(PhosphorIconsRegular.plus, size: 18, color: context.noor.accent)),
            GestureDetector(onTap: dec, child: Icon(PhosphorIconsRegular.minus, size: 18, color: context.noor.accent)),
          ]),
        ]),
      );
}
