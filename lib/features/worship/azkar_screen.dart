import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/content_service.dart';
import '../../services/worship_store.dart';
import 'worship_widgets.dart';

/// Opens the azkar reader for a category id (e.g. 'morning', 'evening', 'sleep').
void openAzkar(BuildContext context, String categoryId) => push(context, AzkarReaderScreen(categoryId: categoryId));

/// Icon for each azkar category id.
IconData azkarIcon(String id) => switch (id) {
      'morning' => PhosphorIconsRegular.sunHorizon,
      'evening' => PhosphorIconsRegular.moonStars,
      'sleep' => PhosphorIconsRegular.bed,
      'waking' => PhosphorIconsRegular.alarm,
      'prayer' => PhosphorIconsRegular.handsPraying,
      'home' => PhosphorIconsRegular.house,
      'mosque' => PhosphorIconsRegular.mosque,
      'wudu' => PhosphorIconsRegular.drop,
      'toilet' => PhosphorIconsRegular.door,
      'adhan' => PhosphorIconsRegular.speakerHigh,
      'istikhara' => PhosphorIconsRegular.signpost,
      'witr' => PhosphorIconsRegular.moon,
      'travel' => PhosphorIconsRegular.airplane,
      'food' => PhosphorIconsRegular.forkKnife,
      'clothing' => PhosphorIconsRegular.tShirt,
      'distress' => PhosphorIconsRegular.heartbeat,
      'waswas' => PhosphorIconsRegular.shieldCheck,
      'sick' => PhosphorIconsRegular.firstAid,
      'weather' => PhosphorIconsRegular.cloudRain,
      'istighfar' => PhosphorIconsRegular.arrowCounterClockwise,
      'salawat' => PhosphorIconsRegular.flowerLotus,
      'majlis' => PhosphorIconsRegular.users,
      'market' => PhosphorIconsRegular.storefront,
      'anger' => PhosphorIconsRegular.flame,
      'ruqyah' => PhosphorIconsRegular.bookOpenText,
      'friday' => PhosphorIconsRegular.calendarStar,
      'qadr' => PhosphorIconsRegular.star,
      'tasbih' => PhosphorIconsRegular.circlesThree,
      'manners' => PhosphorIconsRegular.handHeart,
      _ => PhosphorIconsRegular.sparkle,
    };

/// Azkar library: featured morning/evening cards, every Hisn al-Muslim category, favourites.
class AzkarHomeScreen extends StatefulWidget {
  const AzkarHomeScreen({super.key});
  @override
  State<AzkarHomeScreen> createState() => _AzkarHomeScreenState();
}

class _AzkarHomeScreenState extends State<AzkarHomeScreen> {
  final _future = ContentService.azkar();
  final _search = TextEditingController();
  String _q = '';
  int _tab = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NoorPage(
      title: 'الأذكار',
      subtitle: 'من حصن المسلم',
      child: Loader<List<ZikrCategory>>(
        future: _future,
        builder: (context, cats) => ValueListenableBuilder<int>(
          valueListenable: WorshipStore.changes,
          builder: (context, _, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _featured(context, cats),
            const SizedBox(height: 16),
            GlassSearchField(controller: _search, hint: 'ابحث في الأذكار', onChanged: (v) => setState(() => _q = v)),
            const SizedBox(height: 14),
            if (_q.trim().isEmpty) ...[
              ChipBar(labels: const ['كل الأقسام', 'المفضلة'], index: _tab, onChanged: (i) => setState(() => _tab = i), padding: EdgeInsets.zero),
              const SizedBox(height: 14),
              if (_tab == 0) _grid(context, cats) else _favourites(context, cats),
            ] else
              _results(context, cats),
          ]),
        ),
      ),
    );
  }

  Widget _featured(BuildContext context, List<ZikrCategory> cats) {
    final morning = DateTime.now().hour < 12;
    Widget card(String id, String image, String title, String sub) {
      final c = cats.firstWhere((e) => e.id == id, orElse: () => cats.first);
      final done = WorshipStore.azkarDone(id);
      final prog = WorshipStore.azkarProgress(id, c.items.length);
      final finished = [for (var i = 0; i < c.items.length; i++) if (prog[i] >= c.items[i].count) i].length;
      return Expanded(
        child: HeroPhotoCard(
          image: image,
          height: 170,
          radius: 24,
          onTap: () => openAzkar(context, id),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(azkarIcon(id), color: Colors.white, size: 22),
              const Spacer(),
              if (done) const Icon(PhosphorIconsFill.sealCheck, color: Color(0xFF7EF0CF), size: 22),
            ]),
            const Spacer(),
            Text(title, style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text(done ? 'أكملتها اليوم' : '$finished من ${c.items.length} · $sub',
                style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(height: 8),
            GlassProgress(c.items.isEmpty ? 0 : finished / c.items.length, height: 4, color: const Color(0xFF7EF0CF)),
          ]),
        ),
      );
    }

    final a = card('morning', 'assets/images/hero_dusk.jpg', 'أذكار الصباح', 'بعد الفجر');
    final b = card('evening', 'assets/images/hero_night.jpg', 'أذكار المساء', 'بعد العصر');
    return Row(children: morning ? [a, const SizedBox(width: 12), b] : [b, const SizedBox(width: 12), a]);
  }

  Widget _grid(BuildContext context, List<ZikrCategory> cats) {
    final rest = cats.where((c) => c.id != 'morning' && c.id != 'evening').toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rest.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 112),
      itemBuilder: (context, i) {
        final c = rest[i];
        final done = WorshipStore.azkarDone(c.id);
        final p = context.noor;
        return Glass(
          radius: 22,
          padding: const EdgeInsets.all(14),
          onTap: () => openAzkar(context, c.id),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(azkarIcon(c.id), size: 38),
              const Spacer(),
              if (done) Icon(PhosphorIconsFill.checkCircle, size: 18, color: p.success),
            ]),
            const Spacer(),
            Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: NoorText.h3(context).copyWith(fontSize: 13.5, height: 1.3)),
            Text('${c.items.length} ذكر', style: NoorText.caption(context)),
          ]),
        );
      },
    );
  }

  Widget _favourites(BuildContext context, List<ZikrCategory> cats) {
    final fav = WorshipStore.favourites('azkar');
    final items = <(ZikrCategory, int)>[
      for (final c in cats)
        for (var i = 0; i < c.items.length; i++)
          if (fav.contains(c.items[i].id)) (c, i),
    ];
    if (items.isEmpty) {
      return const EmptyState(
          icon: PhosphorIconsRegular.heart, title: 'لا توجد أذكار مفضلة', message: 'اضغط على رمز القلب داخل أي ذكر لإضافته هنا.');
    }
    return Column(children: [for (final it in items) _resultTile(context, it.$1, it.$2)]);
  }

  Widget _results(BuildContext context, List<ZikrCategory> cats) {
    final q = ContentService.normalize(_q);
    final hits = <(ZikrCategory, int)>[];
    for (final c in cats) {
      final titleHit = ContentService.normalize(c.title).contains(q);
      for (var i = 0; i < c.items.length; i++) {
        if (titleHit || ContentService.normalize(c.items[i].text).contains(q)) hits.add((c, i));
      }
    }
    if (hits.isEmpty) return const EmptyState(icon: PhosphorIconsRegular.magnifyingGlass, title: 'لا نتائج', message: 'جرّب كلمة أخرى.');
    return Column(children: [for (final h in hits.take(60)) _resultTile(context, h.$1, h.$2)]);
  }

  Widget _resultTile(BuildContext context, ZikrCategory c, int i) {
    final z = c.items[i];
    return Glass(
      margin: const EdgeInsets.only(bottom: 10),
      radius: 20,
      onTap: () => push(context, AzkarReaderScreen(categoryId: c.id, initialIndex: i)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(azkarIcon(c.id), size: 16, color: context.noor.accent),
          const SizedBox(width: 6),
          Expanded(child: Text(c.title, style: NoorText.label(context))),
          if (z.count > 1) InfoPill('${z.count} مرات'),
        ]),
        const SizedBox(height: 8),
        Text(z.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: NoorText.arabic(context, 18)),
      ]),
    );
  }
}

/// Reader: one dhikr per page, tap the big glass counter to count, auto-advance on completion.
class AzkarReaderScreen extends StatefulWidget {
  const AzkarReaderScreen({super.key, required this.categoryId, this.initialIndex = 0});
  final String categoryId;
  final int initialIndex;
  @override
  State<AzkarReaderScreen> createState() => _AzkarReaderScreenState();
}

class _AzkarReaderScreenState extends State<AzkarReaderScreen> {
  ZikrCategory? _cat;
  bool _failed = false;
  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;
  List<int> _counts = [];
  double _font = 24;

  @override
  void initState() {
    super.initState();
    ContentService.azkarCategory(widget.categoryId).then((c) {
      if (!mounted) return;
      setState(() {
        _cat = c;
        _failed = c == null;
        if (c != null) _counts = WorshipStore.azkarProgress(c.id, c.items.length);
      });
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  int get _doneCount => _cat == null ? 0 : [for (var i = 0; i < _cat!.items.length; i++) if (_counts[i] >= _cat!.items[i].count) i].length;
  bool get _allDone => _cat != null && _doneCount == _cat!.items.length;

  Future<void> _tap() async {
    final c = _cat!;
    final z = c.items[_page];
    if (_counts[_page] >= z.count) {
      _next();
      return;
    }
    setState(() => _counts[_page]++);
    final finished = _counts[_page] >= z.count;
    tick(finished);
    await WorshipStore.saveAzkarProgress(c.id, _counts);
    if (finished) {
      if (_allDone) {
        await WorshipStore.markAzkarDone(c.id);
        tick(true);
        if (mounted) setState(() {});
      } else {
        Future.delayed(const Duration(milliseconds: 380), _next);
      }
    }
  }

  void _next() {
    if (!mounted || _cat == null) return;
    if (_page < _cat!.items.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _reset() async {
    await WorshipStore.resetAzkar(_cat!.id);
    setState(() => _counts = List.filled(_cat!.items.length, 0));
    _pc.animateToPage(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final c = _cat;
    final p = context.noor;
    if (c == null) {
      return NoorPage(title: 'الأذكار', child: _failed ? const ErrorState() : const LoadingState());
    }
    return NoorPage(
      title: c.title,
      subtitle: '$_doneCount من ${c.items.length}',
      scroll: false,
      padding: EdgeInsets.zero,
      actions: [
        GlassIconButton(icon: PhosphorIconsRegular.textAa, onTap: _fontSheet),
        GlassIconButton(icon: PhosphorIconsRegular.arrowCounterClockwise, onTap: _reset),
      ],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
          child: GlassProgress(c.items.isEmpty ? 0 : _doneCount / c.items.length),
        ),
        if (_allDone)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Glass(
              tint: p.success,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(PhosphorIconsFill.sealCheck, color: p.success),
                const SizedBox(width: 10),
                Expanded(child: Text('أتممت ${c.title} اليوم، تقبّل الله منك', style: NoorText.h3(context).copyWith(fontSize: 14))),
              ]),
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _pc,
            reverse: false,
            itemCount: c.items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _itemPage(context, c, i),
          ),
        ),
        _counter(context, c),
      ]),
    );
  }

  Widget _itemPage(BuildContext context, ZikrCategory c, int i) {
    final z = c.items[i];
    final p = context.noor;
    final fav = WorshipStore.isFavourite('azkar', z.id);
    final done = _counts[i] >= z.count;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Glass(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        tint: done ? p.success : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            InfoPill('${i + 1} / ${c.items.length}', icon: PhosphorIconsRegular.listNumbers),
            const SizedBox(width: 8),
            if (z.count > 1) InfoPill('${z.count} مرات', icon: PhosphorIconsRegular.repeat, color: p.gold),
            const Spacer(),
            if (done) Icon(PhosphorIconsFill.checkCircle, color: p.success, size: 22),
          ]),
          const SizedBox(height: 14),
          SelectableText(z.text, textAlign: TextAlign.center, style: NoorText.arabic(context, _font)),
          if (z.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(z.note, textAlign: TextAlign.center, style: NoorText.label(context).copyWith(color: p.gold)),
          ],
          if (z.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(z.description, textAlign: TextAlign.center, style: NoorText.body(context).copyWith(fontSize: 13.5)),
          ],
          if (z.reference.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: p.hairline),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(PhosphorIconsRegular.scroll, size: 16, color: p.textFaint),
              const SizedBox(width: 8),
              Expanded(child: Text(z.reference, style: NoorText.caption(context).copyWith(height: 1.6))),
            ]),
          ],
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            MiniAction(
              icon: fav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
              active: fav,
              color: fav ? p.danger : null,
              tooltip: 'المفضلة',
              onTap: () async {
                await WorshipStore.toggleFavourite('azkar', z.id);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(width: 12),
            MiniAction(icon: PhosphorIconsRegular.copy, tooltip: 'نسخ', onTap: () => copyText(context, '${z.text}\n\n${z.reference}')),
            const SizedBox(width: 12),
            MiniAction(icon: PhosphorIconsRegular.shareNetwork, tooltip: 'مشاركة', onTap: () => shareText('${z.text}\n\n${z.reference}')),
          ]),
        ]),
      ),
    );
  }

  Widget _counter(BuildContext context, ZikrCategory c) {
    final p = context.noor;
    final z = c.items[_page];
    final n = _counts[_page];
    final done = n >= z.count;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 6, 20, bottom + 16),
      child: Row(children: [
        GlassIconButton(
          icon: PhosphorIconsRegular.caretRight,
          onTap: () => _pc.previousPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic),
        ),
        const Spacer(),
        Semantics(
          button: true,
          label: 'عدّ',
          child: Pressable(
            onTap: _tap,
            scale: 0.93,
            child: SizedBox(
              width: 118,
              height: 118,
              child: Stack(alignment: Alignment.center, children: [
                Glass(radius: 59, width: 118, height: 118, padding: EdgeInsets.zero, strong: true, tint: done ? p.success : p.accent, child: const SizedBox()),
                CustomPaint(
                  size: const Size(118, 118),
                  painter: RingPainter(progress: z.count == 0 ? 0 : n / z.count, color: done ? p.success : p.accent, track: p.glassStrong, stroke: 6),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  if (done)
                    Icon(PhosphorIconsBold.check, size: 34, color: p.success)
                  else
                    Text('$n', style: NoorText.number(context, size: 34, w: FontWeight.w700)),
                  Text(done ? 'التالي' : 'من ${z.count}', style: NoorText.caption(context)),
                ]),
              ]),
            ),
          ),
        ),
        const Spacer(),
        GlassIconButton(icon: PhosphorIconsRegular.caretLeft, onTap: _next),
      ]),
    );
  }

  void _fontSheet() {
    showGlassSheet(
      context,
      title: 'حجم الخط',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', style: NoorText.arabic(ctx, _font)),
            Slider(
              value: _font,
              min: 18,
              max: 36,
              divisions: 9,
              onChanged: (v) {
                set(() {});
                setState(() => _font = v);
              },
            ),
          ]),
        ),
      ),
    );
  }
}
