import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/hijri_service.dart';
import '../../services/location_service.dart';
import '../../services/prayer_service.dart';
import '../../services/worship_store.dart';
import 'worship_widgets.dart';

/// Fasting: Ramadan countdown, today's suhoor/iftar, sunnah fasts, personal log.
class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});
  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NoorPage(
      title: 'الصيام',
      child: ValueListenableBuilder<int>(
        valueListenable: WorshipStore.changes,
        builder: (context, _, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ramadan(context),
          const SizedBox(height: 14),
          _today(context),
          const SizedBox(height: 12),
          _logToday(context),
          const SectionHeader('سجل الصيام · آخر 30 يومًا', padding: EdgeInsets.fromLTRB(0, 24, 0, 12)),
          _log(context),
          const SectionHeader('أيام الصيام المسنونة القادمة', padding: EdgeInsets.fromLTRB(0, 24, 0, 12)),
          ..._upcoming(context),
          const SectionHeader('من سنن الصيام', padding: EdgeInsets.fromLTRB(0, 24, 0, 12)),
          _info(context),
        ]),
      ),
    );
  }

  Widget _ramadan(BuildContext context) {
    final today = DateTime(_now.year, _now.month, _now.day);
    final start = HijriService.nextRamadan(_now);
    final h = HijriService.of(today);
    final inRamadan = h.month == 9;
    final days = DateTime.utc(start.year, start.month, start.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return HeroPhotoCard(
      image: 'assets/images/hero_dusk.jpg',
      height: 176,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(PhosphorIconsRegular.moonStars, color: Colors.white, size: 24),
        const Spacer(),
        Text(inRamadan ? 'رمضان مبارك' : 'متبقٍ على رمضان',
            style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
        if (inRamadan)
          Text('اليوم ${h.day} من رمضان ${h.year}',
              style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white))
        else
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('$days', style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 6),
            const Text('يومًا', style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 16, color: Colors.white)),
          ]),
        Text(inRamadan ? Fmt.dateLong(today) : 'يبدأ تقريبًا ${Fmt.dateLong(start)}',
            style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
      ]),
    );
  }

  Widget _today(BuildContext context) {
    final p = context.noor;
    final d = PrayerService.forDate(_now);
    final suhoor = d.timeOf(PrayerName.fajr);
    final iftar = d.timeOf(PrayerName.maghrib);
    final fastingNow = _now.isAfter(suhoor) && _now.isBefore(iftar);
    final city = LocationService.current.value?.city;
    return Glass(
      radius: 26,
      child: Column(children: [
        Row(children: [
          Expanded(child: _time(context, 'الإمساك (الفجر)', suhoor, PhosphorIconsRegular.sunHorizon)),
          Container(width: 1, height: 54, color: p.hairline),
          Expanded(child: _time(context, 'الإفطار (المغرب)', iftar, PhosphorIconsRegular.moon)),
        ]),
        if (fastingNow) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: p.hairline),
          const SizedBox(height: 10),
          Text('متبقٍ على الإفطار', style: NoorText.caption(context)),
          Text(Fmt.countdown(iftar.difference(_now)), style: NoorText.number(context, size: 26, w: FontWeight.w700).copyWith(color: p.accent)),
        ],
        if (city != null) ...[const SizedBox(height: 6), Text(city, style: NoorText.caption(context))],
      ]),
    );
  }

  Widget _time(BuildContext context, String l, DateTime t, IconData i) => Column(children: [
        Icon(i, color: context.noor.gold),
        const SizedBox(height: 6),
        Text(Fmt.timeFull(t), style: NoorText.number(context, size: 22, w: FontWeight.w700)),
        Text(l, style: NoorText.caption(context)),
      ]);

  Widget _logToday(BuildContext context) {
    final p = context.noor;
    final today = DateTime(_now.year, _now.month, _now.day);
    final forbidden = HijriService.fastingForbidden(today);
    final done = WorshipStore.fasted(today);
    return Glass(
      radius: 22,
      tint: done ? p.success : null,
      onTap: forbidden ? null : () => WorshipStore.toggleFasted(today),
      child: Row(children: [
        Icon(done ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle, color: done ? p.success : p.textFaint, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(forbidden ? 'يوم عيد — يحرم الصيام' : 'أنا صائم اليوم', style: NoorText.h3(context)),
            Text(HijriService.sunnahFast(today) ?? 'سجّل صيامك لمتابعة إنجازك', style: NoorText.caption(context)),
          ]),
        ),
      ]),
    );
  }

  Widget _log(BuildContext context) {
    final p = context.noor;
    final today = DateTime(_now.year, _now.month, _now.day);
    final days = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));
    final count = days.where(WorshipStore.fasted).length;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        GridView.count(
          crossAxisCount: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final d in days)
              GestureDetector(
                onTap: HijriService.fastingForbidden(d) ? null : () => WorshipStore.toggleFasted(d),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: WorshipStore.fasted(d) ? p.accent : p.glassStrong,
                  ),
                  alignment: Alignment.center,
                  child: Text('${d.day}',
                      style: NoorText.caption(context).copyWith(
                          fontSize: 10.5, fontWeight: FontWeight.w600, color: WorshipStore.fasted(d) ? p.onAccent : p.textSoft)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('صمت $count يومًا من آخر 30 يومًا · اضغط على يوم لتسجيله', style: NoorText.caption(context)),
      ]),
    );
  }

  List<Widget> _upcoming(BuildContext context) {
    final today = DateTime(_now.year, _now.month, _now.day);
    final out = <(DateTime, String)>[];
    for (var i = 0; i < 60 && out.length < 8; i++) {
      final d = today.add(Duration(days: i));
      final f = HijriService.sunnahFast(d);
      if (f != null) out.add((d, f));
    }
    return [
      for (final u in out)
        Glass(
          margin: const EdgeInsets.only(bottom: 10),
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            IconBadge(u.$2.contains('عرفة') || u.$2.contains('عاشوراء') ? PhosphorIconsRegular.star : PhosphorIconsRegular.calendarCheck),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.$2, style: NoorText.h3(context).copyWith(fontSize: 15)),
                Text('${Fmt.dateLong(u.$1)} · ${HijriService.of(u.$1).formatted}', style: NoorText.caption(context)),
              ]),
            ),
            if (u.$1 == today) InfoPill('اليوم', color: context.noor.success),
          ]),
        ),
    ];
  }

  Widget _info(BuildContext context) {
    const items = [
      (PhosphorIconsRegular.calendarCheck, 'صيام الإثنين والخميس', 'كان النبي صلى الله عليه وسلم يتحرى صيامهما (رواه الترمذي والنسائي).'),
      (PhosphorIconsRegular.moon, 'الأيام البيض', '13 و14 و15 من كل شهر هجري (رواه النسائي والترمذي).'),
      (PhosphorIconsRegular.mountains, 'يوم عرفة', '«أحتسب على الله أن يكفر السنة التي قبله والسنة التي بعده» (رواه مسلم).'),
      (PhosphorIconsRegular.star, 'يوم عاشوراء', '«أحتسب على الله أن يكفر السنة التي قبله» (رواه مسلم)، ويستحب صيام التاسع معه.'),
    ];
    return Column(children: [
      for (final it in items) GlassTile(title: it.$2, subtitle: it.$3, icon: it.$1),
      Glass(
        radius: 22,
        child: Column(children: [
          Text('دعاء الإفطار', style: NoorText.label(context)),
          const SizedBox(height: 6),
          Text('ذَهَبَ الظَّمَأُ وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
              textAlign: TextAlign.center, style: NoorText.arabic(context, 20)),
          Text('رواه أبو داود (2357)', style: NoorText.caption(context)),
        ]),
      ),
    ]);
  }
}
