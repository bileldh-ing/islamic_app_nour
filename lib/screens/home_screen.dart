import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../services/hijri_service.dart';
import '../services/location_service.dart';
import '../services/prayer_service.dart';
import '../services/quran_service.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'azkar_screen.dart';
import 'calendar_screen.dart';
import 'duas_screen.dart';
import 'fasting_screen.dart';
import 'names_screen.dart';
import 'shahada_screen.dart';
import 'surah_reader_screen.dart';
import 'tasbih_screen.dart';
import 'tracker_screen.dart';

String fmtTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final suffix = t.hour < 12 ? 'ص' : 'م';
  return '${toArabicDigits(h.toString().padLeft(2, '0'))}:${toArabicDigits(t.minute.toString().padLeft(2, '0'))} $suffix';
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return toArabicDigits('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
}

IconData prayerIcon(PrayerName p) => switch (p) {
      PrayerName.fajr => Icons.wb_twilight_rounded,
      PrayerName.sunrise => Icons.wb_sunny_outlined,
      PrayerName.dhuhr => Icons.light_mode_rounded,
      PrayerName.asr => Icons.sunny_snowing,
      PrayerName.maghrib => Icons.nights_stay_outlined,
      PrayerName.isha => Icons.dark_mode_rounded,
    };

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;
  DateTime _now = DateTime.now();
  int _dayOffset = 0;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    QuranService.load().then((_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LocationService.current,
      builder: (context, loc, _) => ValueListenableBuilder(
        valueListenable: Store.settings,
        builder: (context, _, _) => _body(loc),
      ),
    );
  }

  Widget _body(UserLocation? loc) {
    final viewDay = DateTime(_now.year, _now.month, _now.day).add(Duration(days: _dayOffset));
    final day = PrayerService.forDate(viewDay);
    final next = PrayerService.next(_now);
    final current = PrayerService.current(_now);
    final remaining = next.time.difference(_now);
    final hijri = HijriService.of(viewDay);
    final done = PrayerService.doneOn(viewDay);
    final event = HijriService.eventFor(hijri);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(loc),
                  const SizedBox(height: 14),
                  _heroCard(current, next, remaining),
                  const SizedBox(height: 16),
                  _dayCard(viewDay, hijri, day, done, event),
                  const SectionTitle('العبادات'),
                  _featuresGrid(),
                  const SectionTitle('آية اليوم'),
                  _ayahOfDay(),
                  const SizedBox(height: 130),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar(UserLocation? loc) => Row(
        children: [
          Expanded(
            child: GlassCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onTap: () async {
                HapticFeedback.mediumImpact();
                await LocationService.refresh();
              },
              child: Row(children: [
                const Icon(Icons.location_on_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    loc == null ? 'تحديد الموقع…' : loc.city,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                const Icon(Icons.my_location_rounded, color: AppColors.textSoft, size: 18),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          GlassIconButton(
            icon: Icons.calendar_month_rounded,
            onTap: () => Navigator.push(context, glassRoute(const CalendarScreen())),
          ),
        ],
      );

  Widget _heroCard(PrayerEntry? current, PrayerEntry next, Duration remaining) {
    return GlassCard(
      radius: 32,
      glow: true,
      borderGold: true,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Stack(
        children: [
          Positioned(
            left: -10,
            bottom: -18,
            child: Opacity(
              opacity: 0.18,
              child: Icon(Icons.mosque_rounded, size: 150, color: AppColors.gold.withValues(alpha: 0.9)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _pill(current == null ? '' : 'الآن: ${current.name.ar}'),
                const Spacer(),
                Text(HijriService.today().formatted,
                    style: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 18),
              Text('الصلاة القادمة · ${next.name.ar}',
                  style: const TextStyle(color: AppColors.textSoft, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (r) => AppColors.goldGradient.createShader(r),
                child: Text(
                  fmtTime(next.time),
                  style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 18, color: AppColors.aqua),
                const SizedBox(width: 6),
                const Text('متبقٍ ', style: TextStyle(color: AppColors.textSoft)),
                Text(fmtDuration(remaining),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.aqua, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Text(t, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _dayCard(DateTime viewDay, HijriDate hijri, DayPrayers day, Set<String> done, String? event) {
    final isToday = _dayOffset == 0;
    final next = PrayerService.next(_now);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Column(
        children: [
          Row(children: [
            IconButton(
              onPressed: () => setState(() => _dayOffset--),
              icon: const Icon(Icons.chevron_right_rounded, color: AppColors.ivory),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _dayOffset = 0),
                child: Column(children: [
                  Text(hijri.formatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(HijriService.gregorianLabel(viewDay),
                      style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5)),
                  if (event != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('✦ $event ✦', style: const TextStyle(color: AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _dayOffset++),
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.ivory),
            ),
          ]),
          const Divider(color: Colors.white12, height: 14),
          ...day.entries.map((e) {
            final isNext = isToday && e.name == next.name && e.time == next.time;
            final checked = done.contains(e.name.name);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isNext
                    ? LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.28), AppColors.gold.withValues(alpha: 0.06)])
                    : null,
                border: isNext ? Border.all(color: AppColors.gold.withValues(alpha: 0.5)) : null,
              ),
              child: Row(children: [
                Icon(prayerIcon(e.name), color: isNext ? AppColors.gold : AppColors.aqua, size: 22),
                const SizedBox(width: 12),
                Text(e.name.ar, style: TextStyle(fontSize: 16.5, fontWeight: isNext ? FontWeight.w800 : FontWeight.w600)),
                const SizedBox(width: 6),
                Icon(
                  (Store.settings.value.prayerAlerts[e.name.name] ?? false)
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  size: 14,
                  color: AppColors.textFaint,
                ),
                const Spacer(),
                Text(fmtTime(e.time),
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: isNext ? AppColors.gold : AppColors.ivory)),
                const SizedBox(width: 12),
                if (e.name.isFard)
                  GestureDetector(
                    onTap: viewDay.isAfter(DateTime.now())
                        ? null
                        : () async {
                            HapticFeedback.lightImpact();
                            await PrayerService.toggleDone(viewDay, e.name);
                            setState(() {});
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: checked ? AppColors.goldGradient : null,
                        border: Border.all(color: checked ? Colors.transparent : Colors.white38, width: 1.5),
                      ),
                      child: checked ? const Icon(Icons.check_rounded, size: 18, color: AppColors.midnight) : null,
                    ),
                  )
                else
                  const SizedBox(width: 26),
              ]),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Row(children: [
              const Icon(Icons.bedtime_outlined, size: 16, color: AppColors.textFaint),
              const SizedBox(width: 6),
              Text('منتصف الليل ${fmtTime(day.middleOfNight)}',
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
              const Spacer(),
              Text('الثلث الأخير ${fmtTime(day.lastThird)}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _featuresGrid() {
    final items = <(IconData, String, Widget)>[
      (Icons.auto_stories_rounded, 'الأذكار', const AzkarScreen()),
      (Icons.radio_button_checked_rounded, 'التسبيح', const TasbihScreen()),
      (Icons.insights_rounded, 'متابعة الصلاة', const TrackerScreen()),
      (Icons.calendar_month_rounded, 'التقويم', const CalendarScreen()),
      (Icons.volunteer_activism_rounded, 'الأدعية', const DuasScreen()),
      (Icons.star_rounded, 'أسماء الله', const NamesScreen()),
      (Icons.front_hand_rounded, 'الشهادة', const ShahadaScreen()),
      (Icons.restaurant_rounded, 'الصيام', const FastingScreen()),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      padding: EdgeInsets.zero,
      children: items
          .map((it) => GlassCard(
                radius: 22,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                onTap: () => Navigator.push(context, glassRoute(it.$3)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.gold.withValues(alpha: 0.35), AppColors.aqua.withValues(alpha: 0.12)],
                        ),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(it.$1, color: AppColors.gold, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(it.$2,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _ayahOfDay() {
    final a = QuranService.ayahOfDay();
    if (a == null) {
      return const GlassCard(child: Center(child: CircularProgressIndicator(color: AppColors.gold)));
    }
    final (s, ayah) = a;
    return GlassCard(
      onTap: () => Navigator.push(context, glassRoute(SurahReaderScreen(surah: s.number, initialAyah: ayah.numberInSurah))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${ayah.text} ﴿${toArabicDigits(ayah.numberInSurah)}﴾',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: AppFonts.quran, fontSize: 23, height: 2.0, color: AppColors.ivory),
          ),
          const SizedBox(height: 10),
          Text(
            ayah.tafsir,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSoft, fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text('${s.shortName} · الآية ${toArabicDigits(ayah.numberInSurah)}',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(DateFormat('d/M').format(DateTime.now()), style: const TextStyle(color: AppColors.textFaint)),
          ]),
        ],
      ),
    );
  }
}

/// Fade + slight scale route for a fluid glass feel.
Route<T> glassRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(c), child: child),
        );
      },
    );

/// Scaffold for inner screens: background + header + content.
class GlassPage extends StatelessWidget {
  const GlassPage({super.key, required this.title, required this.child, this.actions = const [], this.showMosque = false});
  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool showMosque;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.midnight,
        body: AppBackground(
          showMosque: showMosque,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              GlassHeader(title: title, actions: actions),
              Expanded(child: child),
            ]),
          ),
        ),
      );
}
