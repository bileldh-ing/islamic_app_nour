import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/quran_service.dart';
import '../../services/storage.dart';
import 'khatma_screen.dart';
import 'mushaf_pages_screen.dart';
import 'quran_bookmarks_screen.dart';
import 'quran_nav.dart';
import 'quran_widgets.dart';

/// Quran tab root: search, continue reading, khatma, and the surah / juz / bookmark / plan indexes.
class QuranHomeScreen extends StatefulWidget {
  const QuranHomeScreen({super.key});
  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen> {
  late final Future<List<Surah>> _load = QuranService.load();
  final _query = TextEditingController();
  Timer? _debounce;
  int _tab = 0;
  String _q = '';
  List<(Surah, Ayah)>? _ayahResults;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    setState(() => _q = v.trim());
    _debounce?.cancel();
    if (_q.length < 2) {
      setState(() {
        _ayahResults = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      final q = _q;
      final r = await QuranService.search(q);
      if (!mounted || q != _q) return;
      setState(() {
        _ayahResults = r;
        _searching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Scaffold(
      backgroundColor: p.bgBottom,
      body: NoorBackground(
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<List<Surah>>(
            future: _load,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: EmptyState(icon: PhosphorIconsRegular.warningCircle, title: 'تعذّر تحميل المصحف'));
              }
              final ready = snap.hasData;
              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(child: _titleBar()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                        child: GlassSearchField(controller: _query, onChanged: _onQuery, hint: 'ابحث في السور والآيات'),
                      ),
                    ),
                    if (!ready)
                      const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
                    else if (_q.isNotEmpty)
                      ..._searchSlivers()
                    else ...[
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: _continueCard())),
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: _khatmaCard())),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 12),
                          child: ChipBar(labels: const ['السور', 'الأجزاء', 'المحفوظات', 'الخطة'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
                        ),
                      ),
                      ..._tabSlivers(),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _titleBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('القرآن الكريم', style: NoorText.h1(context).copyWith(fontSize: 30)),
              Text('114 سورة · 30 جزءًا · 604 صفحة', style: NoorText.caption(context).copyWith(fontSize: 12.5)),
            ]),
          ),
          GlassIconButton(icon: PhosphorIconsRegular.hash, onTap: () => push(context, const MushafPagesScreen())),
          const SizedBox(width: 8),
          ValueListenableBuilder<List<Bookmark>>(
            valueListenable: QuranService.bookmarks,
            builder: (_, b, _) => GlassIconButton(
              icon: PhosphorIconsRegular.bookmarksSimple,
              badge: b.length,
              onTap: () => push(context, const QuranBookmarksScreen()),
            ),
          ),
        ]),
      );

  // ---------------- cards ----------------
  Widget _continueCard() => ValueListenableBuilder<(int, int)?>(
        valueListenable: QuranService.lastRead,
        builder: (context, lr, _) {
          final p = context.noor;
          final s = lr == null ? null : QuranService.surah(lr.$1);
          final a = lr == null ? null : QuranService.ayah(lr.$1, lr.$2);
          final progress = QuranService.mushafProgress();
          const white = Colors.white; // text sits on a dark photo scrim in both themes
          return Pressable(
            onTap: () => openLastRead(context),
            scale: 0.98,
            child: Container(
              height: 212,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: p.shadow, blurRadius: 26, offset: const Offset(0, 12), spreadRadius: -8)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset('assets/images/hero_quran.jpg', fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: p.accent)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0x26000000), Color(0x8C000000), Color(0xD9000000)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: white.withValues(alpha: 0.28)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIconsRegular.clockCounterClockwise, size: 13, color: p.isDark ? p.accentSoft : const Color(0xFFF5D894)),
                          const SizedBox(width: 5),
                          Text(s == null ? 'ابدأ القراءة' : 'متابعة القراءة',
                              style: TextStyle(
                                  fontFamily: NoorFonts.ui, color: p.isDark ? p.accentSoft : const Color(0xFFF5D894), fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const Spacer(),
                      Text(s?.shortName ?? 'سورة الفاتحة',
                          style: const TextStyle(fontFamily: NoorFonts.quran, color: white, fontSize: 30, height: 1.5)),
                      Text(
                        a == null ? 'ابدأ رحلتك مع كتاب الله' : 'الآية ${a.numberInSurah} · صفحة ${a.page} · الجزء ${a.juz}',
                        style: TextStyle(fontFamily: NoorFonts.ui, color: white.withValues(alpha: 0.85), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                color: p.accentSoft,
                                backgroundColor: white.withValues(alpha: 0.2),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('${Fmt.percent(progress)} من المصحف',
                                style: TextStyle(fontFamily: NoorFonts.ui, color: white.withValues(alpha: 0.75), fontSize: 11.5)),
                          ]),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: p.accent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.4), blurRadius: 16)],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(PhosphorIconsFill.bookOpen, size: 17, color: p.onAccent),
                            const SizedBox(width: 6),
                            Text(s == null ? 'ابدأ' : 'تابع',
                                style: TextStyle(fontFamily: NoorFonts.ui, fontWeight: FontWeight.w600, fontSize: 14, color: p.onAccent)),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        },
      );

  Widget _khatmaCard() => ValueListenableBuilder<KhatmaPlan?>(
        valueListenable: QuranService.khatma,
        builder: (context, k, _) {
          final p = context.noor;
          if (k == null) {
            return GlassTile(
              margin: EdgeInsets.zero,
              icon: PhosphorIconsRegular.flag,
              iconColor: p.gold,
              title: 'ابدأ ختمة جديدة',
              subtitle: 'خطة يومية مقسّمة على 604 صفحة',
              onTap: () => push(context, const KhatmaScreen()),
            );
          }
          final (st, en) = k.nextPortion;
          return Glass(
            radius: 24,
            onTap: () => push(context, const KhatmaScreen()),
            child: Row(children: [
              ProgressRing(
                value: k.progress,
                size: 58,
                child: Text(Fmt.percent(k.progress), style: NoorText.number(context, size: 13, w: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k.finished ? 'أتممت الختمة' : 'ختمة ${k.days} يومًا', style: NoorText.h3(context)),
                  const SizedBox(height: 2),
                  Text(k.finished ? 'تقبّل الله منك' : (k.doneToday ? 'أنجزت ورد اليوم' : 'ورد اليوم: صفحة $st – $en'),
                      style: NoorText.caption(context).copyWith(fontSize: 12.5)),
                ]),
              ),
              if (k.streak > 0) MetaPill(label: '${k.streak} يوم', icon: PhosphorIconsFill.fire, color: p.gold),
              const SizedBox(width: 4),
              Icon(PhosphorIconsRegular.caretLeft, size: 18, color: p.textFaint),
            ]),
          );
        },
      );

  // ---------------- tabs ----------------
  List<Widget> _tabSlivers() {
    const pad = EdgeInsets.symmetric(horizontal: 20);
    switch (_tab) {
      case 0:
        final list = QuranService.surahs;
        return [
          SliverPadding(
            padding: pad,
            sliver: ValueListenableBuilder<(int, int)?>(
              valueListenable: QuranService.lastRead,
              builder: (_, lr, _) => SliverList.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => SurahRow(surah: list[i], highlight: lr?.$1 == list[i].number, onTap: () => openSurah(context, list[i].number)),
              ),
            ),
          ),
        ];
      case 1:
        final js = QuranService.juzs;
        return [
          SliverPadding(
            padding: pad,
            sliver: SliverList.builder(
              itemCount: js.length,
              itemBuilder: (_, i) => JuzRow(juz: js[i], onTap: () => openSurah(context, js[i].surah, ayah: js[i].ayah)),
            ),
          ),
        ];
      case 2:
        return [
          SliverPadding(
            padding: pad,
            sliver: ValueListenableBuilder<List<Bookmark>>(
              valueListenable: QuranService.bookmarks,
              builder: (_, b, _) => b.isEmpty
                  ? const SliverToBoxAdapter(
                      child: EmptyState(
                        icon: PhosphorIconsRegular.bookmarkSimple,
                        title: 'لا توجد آيات محفوظة',
                        message: 'اضغط على رمز الحفظ بجانب أي آية لتجدها هنا.',
                      ),
                    )
                  : SliverList.builder(
                      itemCount: b.length,
                      itemBuilder: (_, i) => BookmarkRow(
                        bookmark: b[i],
                        onTap: () => openSurah(context, b[i].surah, ayah: b[i].ayah),
                        onDelete: () => QuranService.toggleBookmark(b[i].surah, b[i].ayah),
                      ),
                    ),
            ),
          ),
        ];
      default:
        return [SliverPadding(padding: pad, sliver: SliverToBoxAdapter(child: _planTab()))];
    }
  }

  Widget _planTab() {
    final p = context.noor;
    return ValueListenableBuilder<AppSettings>(
      valueListenable: Store.settings,
      builder: (context, s, _) => ValueListenableBuilder<int>(
        valueListenable: QuranService.pagesReadToday,
        builder: (context, n, _) {
          final goal = s.dailyGoalPages;
          final done = n >= goal;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Glass(
              radius: 24,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  ProgressRing(
                    value: goal == 0 ? 0 : n / goal,
                    size: 64,
                    color: done ? p.success : null,
                    child: Text('$n', style: NoorText.number(context, size: 18, w: FontWeight.w700)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('الورد اليومي', style: NoorText.h3(context)),
                      Text(done ? 'أحسنت، أتممت هدف اليوم' : 'قرأت $n من $goal صفحات اليوم', style: NoorText.caption(context).copyWith(fontSize: 12.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Text('الهدف اليومي', style: NoorText.label(context)),
                  const Spacer(),
                  _stepper(PhosphorIconsRegular.minus, goal > 1 ? () => Store.saveSettings(s.copyWith(dailyGoalPages: goal - 1)) : null),
                  SizedBox(width: 64, child: Text('$goal صفحة', textAlign: TextAlign.center, style: NoorText.number(context, size: 14))),
                  _stepper(PhosphorIconsRegular.plus, goal < 40 ? () => Store.saveSettings(s.copyWith(dailyGoalPages: goal + 1)) : null),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            GlassTile(
              icon: PhosphorIconsRegular.calendarCheck,
              title: 'مخطط الختمة',
              subtitle: QuranService.khatma.value == null ? 'اختر مدة الختمة واحصل على ورد يومي' : 'تابع خطتك وسجّل ورد اليوم',
              onTap: () => push(context, const KhatmaScreen()),
            ),
            GlassTile(
              icon: PhosphorIconsRegular.hash,
              iconColor: p.gold,
              title: 'فهرس صفحات المصحف',
              subtitle: 'انتقل مباشرة إلى أي صفحة من 1 إلى 604',
              onTap: () => push(context, const MushafPagesScreen()),
            ),
            GlassTile(
              icon: PhosphorIconsRegular.bookmarksSimple,
              title: 'المحفوظات',
              subtitle: '${QuranService.bookmarks.value.length} آية محفوظة',
              onTap: () => push(context, const QuranBookmarksScreen()),
            ),
          ]);
        },
      ),
    );
  }

  Widget _stepper(IconData icon, VoidCallback? onTap) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: GlassIconButton(icon: icon, size: 36, onTap: onTap ?? () {}),
      );

  // ---------------- search ----------------
  List<Widget> _searchSlivers() {
    final surahs = QuranService.searchSurahs(_q);
    final ayahs = _ayahResults;
    return [
      if (surahs.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader('السور')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: surahs.length.clamp(0, 12),
            itemBuilder: (_, i) => SurahRow(surah: surahs[i], onTap: () => openSurah(context, surahs[i].number)),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: SectionHeader(ayahs == null || _searching ? 'الآيات' : 'الآيات (${ayahs.length >= 150 ? '150+' : ayahs.length})'),
      ),
      if (_q.length < 2)
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('اكتب حرفين على الأقل', style: NoorText.caption(context))))
      else if (_searching || ayahs == null)
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())))
      else if (ayahs.isEmpty && surahs.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(icon: PhosphorIconsRegular.magnifyingGlass, title: 'لا نتائج', message: 'جرّب كلمة أخرى، البحث لا يتأثر بالتشكيل.'),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: ayahs.length,
            itemBuilder: (_, i) {
              final (s, a) = ayahs[i];
              return Glass(
                margin: const EdgeInsets.only(bottom: 10),
                radius: 22,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                onTap: () => openSurah(context, s.number, ayah: a.numberInSurah),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    AyahNumber(a.numberInSurah, size: 30),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.shortName, style: NoorText.h3(context).copyWith(fontSize: 14.5))),
                    MetaPill(label: 'ص ${a.page}'),
                  ]),
                  const SizedBox(height: 6),
                  Text(a.text, style: NoorText.quran(context, 19).copyWith(height: 1.9), maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl),
                ]),
              );
            },
          ),
        ),
    ];
  }
}
