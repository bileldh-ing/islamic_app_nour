import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/nav.dart';
import '../../core/open.dart';
import '../../core/theme.dart';
import '../../services/hijri_service.dart';
import '../../services/location_service.dart';
import '../../services/storage.dart';
import '../../services/worship_store.dart';
import '../settings/settings_screen.dart';

class _Service {
  const _Service(this.icon, this.label, {this.route, this.tab});
  final IconData icon;
  final String label;
  final String? route;
  final int? tab;
}

/// "More" tab: greeting, quick appearance toggles and every service grouped by section.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _sections = <(String, List<_Service>)>[
    ('عبادات', [
      _Service(PhosphorIconsRegular.handsPraying, 'الأذكار', route: 'azkar'),
      _Service(PhosphorIconsRegular.sunHorizon, 'أذكار الصباح', route: 'azkar-morning'),
      _Service(PhosphorIconsRegular.moonStars, 'أذكار المساء', route: 'azkar-evening'),
      _Service(PhosphorIconsRegular.circlesThree, 'المسبحة', route: 'tasbih'),
      _Service(PhosphorIconsRegular.handHeart, 'الأدعية', route: 'duas'),
      _Service(PhosphorIconsRegular.moon, 'الصيام', route: 'fasting'),
      _Service(PhosphorIconsRegular.checkSquare, 'متابعة الصلوات', route: 'tracker'),
      _Service(PhosphorIconsRegular.sealCheck, 'الشهادة', route: 'shahada'),
    ]),
    ('القرآن والسنة', [
      _Service(PhosphorIconsRegular.bookOpenText, 'القرآن', tab: 2),
      _Service(PhosphorIconsRegular.target, 'الختمة', route: 'khatma'),
      _Service(PhosphorIconsRegular.bookmarkSimple, 'العلامات', route: 'quran-bookmarks'),
      _Service(PhosphorIconsRegular.quotes, 'الأربعون النووية', route: 'hadith'),
      _Service(PhosphorIconsRegular.sparkle, 'أسماء الله الحسنى', route: 'names'),
      _Service(PhosphorIconsRegular.personSimple, 'صفة الصلاة', route: 'guide-salah'),
      _Service(PhosphorIconsRegular.mountains, 'الحج والعمرة', route: 'guide-hajj'),
    ]),
    ('أدوات', [
      _Service(PhosphorIconsRegular.calendarBlank, 'التقويم الهجري', route: 'calendar'),
      _Service(PhosphorIconsRegular.coins, 'حاسبة الزكاة', route: 'zakat'),
      _Service(PhosphorIconsRegular.compass, 'القبلة', tab: 3),
      _Service(PhosphorIconsRegular.mosque, 'المساجد القريبة', route: 'mosques'),
      _Service(PhosphorIconsRegular.table, 'جدول المواقيت', route: 'timetable'),
    ]),
    ('التطبيق', [
      _Service(PhosphorIconsRegular.bellRinging, 'تنبيهات الأذان', route: 'adhan-settings'),
      _Service(PhosphorIconsRegular.sliders, 'إعدادات الصلاة', route: 'prayer-settings'),
      _Service(PhosphorIconsRegular.gear, 'الإعدادات', route: 'settings'),
    ]),
  ];

  void _open(BuildContext context, _Service s) {
    if (s.tab != null) {
      rootTab.value = s.tab!;
      return;
    }
    if (s.route == 'settings') {
      push(context, const SettingsScreen());
      return;
    }
    if (s.route != null && !openRoute(context, s.route!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذه الخدمة غير متاحة حاليًا')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Scaffold(
      backgroundColor: p.bgBottom,
      body: NoorBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              Row(children: [
                Expanded(child: Text('المزيد', style: NoorText.h1(context))),
                GlassIconButton(icon: PhosphorIconsRegular.gear, onTap: () => push(context, const SettingsScreen())),
              ]),
              const SizedBox(height: 16),
              const _Greeting(),
              const SizedBox(height: 14),
              const _QuickToggles(),
              for (final sec in _sections) ...[
                SectionHeader(sec.$1, padding: const EdgeInsets.fromLTRB(4, 24, 4, 12)),
                Glass(
                  radius: 26,
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                  child: LayoutBuilder(builder: (context, c) {
                    final w = (c.maxWidth / 4).floorToDouble();
                    return Wrap(children: [for (final s in sec.$2) SizedBox(width: w, child: _tile(context, s))]);
                  }),
                ),
              ],
              const SizedBox(height: 22),
              Center(child: Text('نور · صُنع بإتقان لخدمة المسلمين', style: NoorText.caption(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, _Service s) {
    final p = context.noor;
    return Pressable(
      onTap: () => _open(context, s),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: p.isDark ? [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.05)] : [Colors.white, const Color(0xFFF1F4F9)],
              ),
              border: Border.all(color: p.isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white),
              boxShadow: [BoxShadow(color: p.shadow.withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Icon(s.icon, size: 25, color: p.accent),
          ),
          const SizedBox(height: 7),
          Text(s.label, textAlign: TextAlign.center, maxLines: 2, style: NoorText.label(context).copyWith(fontSize: 11.5, color: p.text, height: 1.25)),
        ]),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final h = HijriService.of(now);
    final greet = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    return ValueListenableBuilder<UserLocation?>(
      valueListenable: LocationService.current,
      builder: (context, loc, _) => ValueListenableBuilder<int>(
        valueListenable: WorshipStore.changes,
        builder: (context, _, _) {
          final morningDone = WorshipStore.azkarDone('morning');
          final eveningDone = WorshipStore.azkarDone('evening');
          return Container(
            height: 168,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: context.noor.shadow, blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -8)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(now.hour >= 6 && now.hour < 18 ? 'assets/images/hero_dusk.jpg' : 'assets/images/hero_night.jpg',
                    fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: context.noor.accent)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x26000000), Color(0xCC000000)]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(PhosphorIconsRegular.userCircle, color: Colors.white, size: 26),
                      const SizedBox(width: 8),
                      Text(greet, style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                      const Spacer(),
                      if (loc != null)
                        Row(children: [
                          const Icon(PhosphorIconsRegular.mapPin, color: Colors.white, size: 15),
                          const SizedBox(width: 4),
                          Text(loc.city, style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 12.5, color: Colors.white)),
                        ]),
                    ]),
                    const Spacer(),
                    Text(Fmt.hijri(h.day, h.month, h.year),
                        style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(Fmt.dateLong(now), style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 10),
                    Row(children: [
                      _pill('الصباح', morningDone),
                      const SizedBox(width: 8),
                      _pill('المساء', eveningDone),
                      const SizedBox(width: 8),
                      _pill('تسبيح اليوم ${Fmt.number(WorshipStore.tasbihOn(now))}', null),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(String label, bool? done) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (done != null) ...[
            Icon(done ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle, size: 13, color: done ? const Color(0xFF7EF0CF) : Colors.white),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w500)),
        ]),
      );
}

class _QuickToggles extends StatelessWidget {
  const _QuickToggles();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppSettings>(
        valueListenable: Store.settings,
        builder: (context, s, _) {
          final p = context.noor;
          Widget mode(String id, IconData icon, String label) {
            final sel = s.themeMode == id;
            return Expanded(
              child: Pressable(
                onTap: () => Store.saveSettings(s.copyWith(themeMode: id)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: sel ? p.accent : Colors.transparent,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, size: 16, color: sel ? p.onAccent : p.textSoft),
                    const SizedBox(width: 5),
                    Text(label, style: NoorText.label(context).copyWith(color: sel ? p.onAccent : p.textSoft, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          }

          return Glass(
            radius: 24,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: p.glassStrong.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  mode('light', PhosphorIconsRegular.sun, 'فاتح'),
                  mode('dark', PhosphorIconsRegular.moon, 'داكن'),
                  mode('system', PhosphorIconsRegular.circleHalf, 'تلقائي'),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Text('اللون', style: NoorText.label(context)),
                const SizedBox(width: 12),
                Expanded(child: AccentSwatches(selected: s.accent, onChanged: (id) => Store.saveSettings(s.copyWith(accent: id)))),
              ]),
            ]),
          );
        },
      );
}
