import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/nav.dart';
import '../../core/open.dart';
import '../../core/theme.dart';
import '../../services/hijri_service.dart';
import '../../services/location_service.dart';
import '../../services/prayer_service.dart';
import '../../services/quran_service.dart';
import '../../services/storage.dart';

/// Icon for each prayer, used across the app.
IconData prayerIcon(PrayerName n, {bool fill = false}) => switch (n) {
      PrayerName.fajr => fill ? PhosphorIconsFill.cloudMoon : PhosphorIconsRegular.cloudMoon,
      PrayerName.sunrise => fill ? PhosphorIconsFill.sunHorizon : PhosphorIconsRegular.sunHorizon,
      PrayerName.dhuhr => fill ? PhosphorIconsFill.sun : PhosphorIconsRegular.sun,
      PrayerName.asr => fill ? PhosphorIconsFill.cloudSun : PhosphorIconsRegular.cloudSun,
      PrayerName.maghrib => fill ? PhosphorIconsFill.sunHorizon : PhosphorIconsRegular.sunHorizon,
      PrayerName.isha => fill ? PhosphorIconsFill.moonStars : PhosphorIconsRegular.moonStars,
    };

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
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
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Scaffold(
      backgroundColor: p.bgBottom,
      body: NoorBackground(
        child: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<UserLocation?>(
            valueListenable: LocationService.current,
            builder: (context, loc, _) => ValueListenableBuilder<AppSettings>(
              valueListenable: Store.settings,
              builder: (context, s, _) {
                final day = PrayerService.forDate(_now);
                final next = PrayerService.next(_now);
                final cur = PrayerService.current(_now);
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    _Header(city: loc?.city ?? 'تحديد الموقع'),
                    _Greeting(now: _now),
                    const SizedBox(height: 18),
                    _PrayerStrip(day: day, highlight: next.name),
                    const SizedBox(height: 18),
                    _HeroCarousel(now: _now, next: next, current: cur),
                    SectionHeader('الخدمات', onAction: () => rootTab.value = 4),
                    const _Services(),
                    SectionHeader('متابعة الصلوات اليوم', action: 'السجل', onAction: () => openRoute(context, 'tracker')),
                    _TodayTracker(day: day, now: _now),
                    const _ContinueReading(),
                    SectionHeader(_isMorning(_now, day) ? 'أذكار الصباح' : 'أذكار المساء'),
                    _AzkarCard(morning: _isMorning(_now, day)),
                    const SectionHeader('آية اليوم'),
                    const _AyahOfDay(),
                    const SectionHeader('المناسبات القادمة'),
                    _UpcomingEvents(now: _now),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool _isMorning(DateTime n, DayPrayers d) => n.isAfter(d.timeOf(PrayerName.fajr)) && n.isBefore(d.timeOf(PrayerName.asr));
}

class _Header extends StatelessWidget {
  const _Header({required this.city});
  final String city;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final s = Store.settings.value;
    final dark = p.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Pressable(
              onTap: () => rootTab.value = 1,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(PhosphorIconsRegular.mapPin, size: 22, color: p.text),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(city, style: NoorText.h3(context).copyWith(fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                Icon(PhosphorIconsRegular.caretDown, size: 16, color: p.textSoft),
              ]),
            ),
          ),
        ),
        GlassIconButton(
          icon: dark ? PhosphorIconsRegular.sun : PhosphorIconsRegular.moon,
          onTap: () => Store.saveSettings(s.copyWith(themeMode: dark ? 'light' : 'dark')),
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: PhosphorIconsRegular.bell,
          onTap: () => openRoute(context, 'adhan-settings'),
        ),
      ]),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.now});
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final h = HijriService.of(now);
    final hour = now.hour;
    final hello = hour < 12 ? 'صباح الخير' : (hour < 18 ? 'مساء النور' : 'مساء الخير');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('السلام عليكم، $hello', style: NoorText.label(context).copyWith(fontSize: 14)),
        const SizedBox(height: 4),
        Text(Fmt.hijri(h.day, h.month, h.year), style: NoorText.h1(context)),
        const SizedBox(height: 2),
        Text(Fmt.dateLong(now), style: NoorText.caption(context).copyWith(fontSize: 13)),
      ]),
    );
  }
}

/// Horizontal pills with each prayer's icon, name and time (reference-style).
class _PrayerStrip extends StatelessWidget {
  const _PrayerStrip({required this.day, required this.highlight});
  final DayPrayers day;
  final PrayerName highlight;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final isFriday = day.date.weekday == DateTime.friday;
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: day.entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final e = day.entries[i];
          final sel = e.name == highlight;
          final name = (isFriday && e.name == PrayerName.dhuhr) ? 'الجمعة' : e.name.ar;
          final pill = AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 74,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: sel
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: p.isDark
                          ? [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.06)]
                          : [Colors.white, Colors.white.withValues(alpha: 0.7)],
                    )
                  : null,
              border: Border.all(color: sel ? (p.isDark ? Colors.white.withValues(alpha: 0.35) : Colors.white) : Colors.transparent),
              boxShadow: sel ? [BoxShadow(color: p.shadow, blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -6)] : null,
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(prayerIcon(e.name, fill: sel), size: 26, color: sel ? p.accent : p.text),
              const SizedBox(height: 8),
              Text(name, style: NoorText.label(context).copyWith(color: p.text, fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
              const SizedBox(height: 2),
              Text(Fmt.time(e.time), style: NoorText.number(context, size: 13, w: FontWeight.w500).copyWith(color: p.textSoft)),
            ]),
          );
          return Pressable(onTap: () => rootTab.value = 1, child: pill);
        },
      ),
    );
  }
}

/// Swipeable hero cards: next prayer, Quran, night prayer (with page dots).
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.now, required this.next, required this.current});
  final DateTime now;
  final PrayerEntry next;
  final PrayerEntry? current;
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _pc = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final n = widget.now;
    final next = widget.next;
    final cur = widget.current;
    final left = next.time.difference(n);
    final span = cur == null ? const Duration(hours: 6) : next.time.difference(cur.time);
    final progress = span.inSeconds <= 0 ? 0.0 : 1 - left.inSeconds / span.inSeconds;
    final day = PrayerService.forDate(n);
    final night = n.hour >= 18 || n.hour < 5;

    final cards = <Widget>[
      _HeroCard(
        image: night ? 'assets/images/hero_night.jpg' : 'assets/images/hero_dusk.jpg',
        tag: 'الصلاة القادمة',
        title: next.name.ar,
        big: Fmt.time(next.time),
        bigSuffix: Fmt.period(next.time),
        footer: Row(children: [
          Icon(PhosphorIconsRegular.timer, size: 16, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text('متبقٍ ${Fmt.countdown(left)}', style: const TextStyle(fontFamily: NoorFonts.ui, color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 12),
          Expanded(child: GlassProgress(progress, height: 5, color: p.accentSoft)),
        ]),
        button: 'المواقيت',
        onTap: () => rootTab.value = 1,
      ),
      _HeroCard(
        image: 'assets/images/hero_quran.jpg',
        tag: 'وِرد اليوم',
        title: 'اقرأ ${Store.settings.value.dailyGoalPages} صفحات اليوم',
        subtitle: '«خيركم من تعلّم القرآن وعلّمه» — رواه البخاري',
        button: 'ابدأ القراءة',
        onTap: () => rootTab.value = 2,
      ),
      _HeroCard(
        image: 'assets/images/hero_night.jpg',
        tag: 'قيام الليل',
        title: 'الثلث الأخير ${Fmt.timeFull(day.lastThird)}',
        subtitle: 'منتصف الليل ${Fmt.timeFull(day.middleOfNight)}',
        button: 'الأذكار',
        onTap: () => openRoute(context, 'azkar'),
      ),
    ];

    return Column(children: [
      SizedBox(
        height: 214,
        child: PageView.builder(
          controller: _pc,
          physics: const BouncingScrollPhysics(),
          itemCount: cards.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: cards[i]),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(cards.length, (i) {
          final sel = i == _page;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: sel ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(color: sel ? p.text : p.textFaint.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
          );
        }),
      ),
    ]);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.image, required this.tag, required this.title, this.big, this.bigSuffix, this.subtitle, this.footer, required this.button, required this.onTap});
  final String image;
  final String tag;
  final String title;
  final String? big;
  final String? bigSuffix;
  final String? subtitle;
  final Widget? footer;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 26, offset: const Offset(0, 12), spreadRadius: -8)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(image, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x1A000000), Color(0x66000000), Color(0xD9000000)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: Text(tag, style: TextStyle(fontFamily: NoorFonts.ui, color: p.isDark ? p.accentSoft : const Color(0xFFF5D894), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(title, style: const TextStyle(fontFamily: NoorFonts.ui, color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.2)),
                      if (big != null)
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text(big!, style: const TextStyle(fontFamily: NoorFonts.ui, color: Colors.white, fontSize: 42, fontWeight: FontWeight.w600, height: 1.1, fontFeatures: [FontFeature.tabularFigures()])),
                          if (bigSuffix != null && bigSuffix!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(bigSuffix!, style: const TextStyle(fontFamily: NoorFonts.ui, color: Colors.white70, fontSize: 18)),
                          ],
                        ]),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, style: TextStyle(fontFamily: NoorFonts.ui, color: Colors.white.withValues(alpha: 0.82), fontSize: 13)),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Text(button, style: const TextStyle(fontFamily: NoorFonts.ui, color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ),
                  ),
                ]),
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Services extends StatelessWidget {
  const _Services();
  static const items = [
    (PhosphorIconsRegular.bookOpen, 'القرآن', '#quran'),
    (PhosphorIconsRegular.handsPraying, 'الأذكار', 'azkar'),
    (PhosphorIconsRegular.circleNotch, 'التسبيح', 'tasbih'),
    (PhosphorIconsRegular.chatCenteredText, 'الأدعية', 'duas'),
    (PhosphorIconsRegular.scroll, 'الحديث', 'hadith'),
    (PhosphorIconsRegular.mosque, 'المساجد', 'mosques'),
    (PhosphorIconsRegular.calendarDots, 'التقويم', 'calendar'),
    (PhosphorIconsRegular.coins, 'الزكاة', 'zakat'),
    (PhosphorIconsRegular.sparkle, 'الأسماء', 'names'),
    (PhosphorIconsRegular.compass, 'القبلة', '#qibla'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final it = items[i];
          return Glass(
            radius: 40,
            width: 82,
            padding: const EdgeInsets.symmetric(vertical: 16),
            onTap: () {
              if (it.$3 == '#quran') {
                rootTab.value = 2;
              } else if (it.$3 == '#qibla') {
                rootTab.value = 3;
              } else {
                openRoute(context, it.$3);
              }
            },
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(it.$1, size: 26, color: p.text),
              const SizedBox(height: 8),
              Text(it.$2, style: NoorText.label(context).copyWith(color: p.text, fontSize: 12.5)),
            ]),
          );
        },
      ),
    );
  }
}

class _TodayTracker extends StatefulWidget {
  const _TodayTracker({required this.day, required this.now});
  final DayPrayers day;
  final DateTime now;
  @override
  State<_TodayTracker> createState() => _TodayTrackerState();
}

class _TodayTrackerState extends State<_TodayTracker> {
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final done = PrayerService.doneOn(widget.now);
    final fard = widget.day.entries.where((e) => e.name.isFard).toList();
    final count = fard.where((e) => done.contains(e.name.name)).length;
    return Glass(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(children: [
        Row(children: [
          Text('$count / 5', style: NoorText.number(context, size: 22, w: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(child: GlassProgress(count / 5, height: 7)),
          const SizedBox(width: 10),
          Text(count == 5 ? 'ما شاء الله' : 'صلوات', style: NoorText.label(context)),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: fard.map((e) {
            final isDone = done.contains(e.name.name);
            final upcoming = e.time.isAfter(widget.now);
            return Pressable(
              onTap: upcoming
                  ? () {}
                  : () async {
                      await PrayerService.toggleDone(widget.now, e.name);
                      tick(true);
                      if (mounted) setState(() {});
                    },
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? p.accent : p.glass,
                    border: Border.all(color: isDone ? p.accent : p.glassBorder.withValues(alpha: p.isDark ? 0.6 : 1)),
                    boxShadow: isDone ? [BoxShadow(color: p.accent.withValues(alpha: 0.4), blurRadius: 14)] : null,
                  ),
                  child: Icon(isDone ? PhosphorIconsBold.check : prayerIcon(e.name),
                      size: 20, color: isDone ? p.onAccent : (upcoming ? p.textFaint : p.text)),
                ),
                const SizedBox(height: 6),
                Text(e.name.ar, style: NoorText.caption(context).copyWith(color: upcoming ? p.textFaint : p.textSoft)),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _ContinueReading extends StatelessWidget {
  const _ContinueReading();
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return ValueListenableBuilder<(int, int)?>(
      valueListenable: QuranService.lastRead,
      builder: (context, last, _) {
        final surahs = QuranService.surahs;
        if (surahs.isEmpty) return const SizedBox();
        final s = surahs[(last?.$1 ?? 1) - 1];
        final ayah = last?.$2 ?? 1;
        final a = s.ayahs[(ayah - 1).clamp(0, s.ayahs.length - 1)];
        final pct = a.page / 604;
        return Column(children: [
          SectionHeader(last == null ? 'ابدأ الختمة' : 'تابع القراءة', action: 'المصحف', onAction: () => rootTab.value = 2),
          Glass(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            radius: 26,
            padding: const EdgeInsets.all(14),
            onTap: () => openRoute(context, 'reader-last') || _toQuran(),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset('assets/images/hero_quran.jpg', width: 86, height: 96, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('سورة ${s.shortName}', style: NoorText.h2(context).copyWith(fontFamily: NoorFonts.arabic, fontSize: 22, height: 1.3)),
                  Text('الآية $ayah  ·  صفحة ${a.page}  ·  الجزء ${a.juz}', style: NoorText.caption(context).copyWith(fontSize: 12.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: GlassProgress(pct, height: 6)),
                    const SizedBox(width: 8),
                    Text(Fmt.percent(pct), style: NoorText.number(context, size: 12.5, w: FontWeight.w600).copyWith(color: p.accent)),
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent),
                child: Icon(PhosphorIconsFill.play, size: 18, color: p.onAccent),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  bool _toQuran() {
    rootTab.value = 2;
    return true;
  }
}

class _AzkarCard extends StatelessWidget {
  const _AzkarCard({required this.morning});
  final bool morning;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Glass(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      radius: 26,
      padding: const EdgeInsets.all(16),
      onTap: () => openRoute(context, morning ? 'azkar-morning' : 'azkar-evening') || openRoute(context, 'azkar'),
      child: Row(children: [
        IconBadge(morning ? PhosphorIconsRegular.sunHorizon : PhosphorIconsRegular.moonStars, size: 52, color: p.gold),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(morning ? 'ابدأ يومك بذكر الله' : 'اختم يومك بذكر الله', style: NoorText.h3(context)),
            const SizedBox(height: 3),
            Text(morning ? 'من بعد الفجر حتى طلوع الشمس' : 'من بعد العصر حتى الليل', style: NoorText.caption(context).copyWith(fontSize: 12.5)),
          ]),
        ),
        Icon(PhosphorIconsRegular.caretLeft, color: p.textFaint, size: 18),
      ]),
    );
  }
}

class _AyahOfDay extends StatelessWidget {
  const _AyahOfDay();
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final v = QuranService.ayahOfDay();
    if (v == null) return const SizedBox();
    final (s, a) = v;
    return Glass(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(PhosphorIconsRegular.quotes, color: p.gold, size: 22),
          const Spacer(),
          Text('${s.shortName} · ${a.numberInSurah}', style: NoorText.label(context).copyWith(color: p.gold)),
        ]),
        const SizedBox(height: 8),
        Text(a.text, style: NoorText.quran(context, 22), textAlign: TextAlign.center),
        if (a.tafsir.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(a.tafsir, style: NoorText.body(context).copyWith(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}

class _UpcomingEvents extends StatelessWidget {
  const _UpcomingEvents({required this.now});
  final DateTime now;

  List<(String, DateTime, int)> _events() {
    final out = <(String, DateTime, int)>[];
    final today = DateTime(now.year, now.month, now.day);
    final h = HijriService.of(today);
    for (final y in [h.year, h.year + 1]) {
      HijriService.events.forEach((k, name) {
        if (name == 'أيام التشريق' && k.$2 != 11) return;
        final g = HijriService.toGregorian(y, k.$1, k.$2);
        final d = g.difference(today).inDays;
        if (d >= 0) out.add((name, g, d));
      });
    }
    out.sort((a, b) => a.$3.compareTo(b.$3));
    return out.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final ev = _events();
    return Column(
      children: ev.map((e) {
        final hd = HijriService.of(e.$2);
        return GlassTile(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          icon: PhosphorIconsRegular.calendarStar,
          iconColor: p.gold,
          title: e.$1,
          subtitle: '${Fmt.hijri(hd.day, hd.month, hd.year)}  ·  ${Fmt.dateMedium(e.$2)}',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
            child: Text(e.$3 == 0 ? 'اليوم' : '${e.$3} يوم', style: NoorText.label(context).copyWith(color: p.accent, fontWeight: FontWeight.w600)),
          ),
          onTap: () => openRoute(context, 'calendar'),
        );
      }).toList(),
    );
  }
}
