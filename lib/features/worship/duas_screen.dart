import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/content_service.dart';
import '../../services/worship_store.dart';
import 'worship_widgets.dart';

IconData _groupIcon(String id) => switch (id) {
      'quran' => PhosphorIconsRegular.bookOpenText,
      'prophets' => PhosphorIconsRegular.star,
      'salah' => PhosphorIconsRegular.handsPraying,
      'distress' => PhosphorIconsRegular.heartbeat,
      'family' => PhosphorIconsRegular.users,
      'social' => PhosphorIconsRegular.handHeart,
      'sick' => PhosphorIconsRegular.firstAid,
      'travel' => PhosphorIconsRegular.airplane,
      'food' => PhosphorIconsRegular.forkKnife,
      'nature' => PhosphorIconsRegular.cloudRain,
      'hajj' => PhosphorIconsRegular.mosque,
      _ => PhosphorIconsRegular.sparkle,
    };

/// Duas: Quranic, prophets' duas from the Quran and Hisn al-Muslim situational duas.
class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});
  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  final _future = Future.wait([ContentService.duas(), ContentService.duaGroups()]);
  final _search = TextEditingController();
  String _q = '';
  int _group = 0; // 0 = all, last = favourites

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NoorPage(
      title: 'الأدعية',
      subtitle: 'من القرآن الكريم والسنة',
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 40),
      child: Loader<List<Object>>(
        future: _future,
        builder: (context, data) {
          final cats = data[0] as List<ZikrCategory>;
          final groups = data[1] as List<DuaGroup>;
          final labels = ['الكل', ...groups.map((g) => g.title), 'المفضلة'];
          return ValueListenableBuilder<int>(
            valueListenable: WorshipStore.changes,
            builder: (context, _, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HeroPhotoCard(
                  image: 'assets/images/hero_quran.jpg',
                  height: 150,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                    const Text('﴿ادْعُونِي أَسْتَجِبْ لَكُمْ﴾',
                        style: TextStyle(fontFamily: NoorFonts.arabic, fontSize: 24, color: Colors.white, height: 1.6)),
                    Text('سورة غافر: 60 · ${cats.fold<int>(0, (a, c) => a + c.items.length)} دعاء',
                        style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassSearchField(controller: _search, hint: 'ابحث في الأدعية', onChanged: (v) => setState(() => _q = v)),
              ),
              const SizedBox(height: 12),
              if (_q.trim().isEmpty) ...[
                ChipBar(labels: labels, index: _group, onChanged: (i) => setState(() => _group = i)),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _group == labels.length - 1
                      ? _favourites(context, cats)
                      : _list(context, _group == 0 ? cats : cats.where((c) => c.group == groups[_group - 1].id).toList()),
                ),
              ] else
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _results(context, cats)),
            ]),
          );
        },
      ),
    );
  }

  Widget _list(BuildContext context, List<ZikrCategory> cats) => Column(children: [
        for (final c in cats)
          GlassTile(
            title: c.title,
            subtitle: '${c.items.length} ${c.items.length == 1 ? 'دعاء' : 'أدعية'}',
            icon: _groupIcon(c.group),
            onTap: () => push(context, DuaCategoryScreen(category: c)),
          ),
      ]);

  Widget _favourites(BuildContext context, List<ZikrCategory> cats) {
    final fav = WorshipStore.favourites('duas');
    final items = [for (final c in cats) for (final z in c.items) if (fav.contains(z.id)) z];
    if (items.isEmpty) {
      return const EmptyState(icon: PhosphorIconsRegular.heart, title: 'لا توجد أدعية مفضلة', message: 'أضف الأدعية التي تحبها لتجدها هنا بسرعة.');
    }
    return Column(children: [for (final z in items) DuaCard(zikr: z)]);
  }

  Widget _results(BuildContext context, List<ZikrCategory> cats) {
    final q = ContentService.normalize(_q);
    final hits = <Zikr>[];
    for (final c in cats) {
      final t = ContentService.normalize(c.title).contains(q);
      for (final z in c.items) {
        if (t || ContentService.normalize(z.text).contains(q) || ContentService.normalize(z.description).contains(q)) hits.add(z);
      }
    }
    if (hits.isEmpty) return const EmptyState(icon: PhosphorIconsRegular.magnifyingGlass, title: 'لا نتائج', message: 'جرّب كلمة أخرى.');
    return Column(children: [for (final z in hits.take(60)) DuaCard(zikr: z)]);
  }
}

class DuaCategoryScreen extends StatelessWidget {
  const DuaCategoryScreen({super.key, required this.category});
  final ZikrCategory category;
  @override
  Widget build(BuildContext context) => NoorPage(
        title: category.title,
        subtitle: '${category.items.length} ${category.items.length == 1 ? 'دعاء' : 'أدعية'}',
        child: ValueListenableBuilder<int>(
          valueListenable: WorshipStore.changes,
          builder: (context, _, _) => Column(children: [for (final z in category.items) DuaCard(zikr: z)]),
        ),
      );
}

/// Arabic dua card with reference, copy, share and favourite.
class DuaCard extends StatelessWidget {
  const DuaCard({super.key, required this.zikr, this.kind = 'duas'});
  final Zikr zikr;
  final String kind;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final fav = WorshipStore.isFavourite(kind, zikr.id);
    final share = [zikr.text, if (zikr.reference.isNotEmpty) zikr.reference].join('\n\n');
    return Glass(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (zikr.description.isNotEmpty && zikr.reference.startsWith('سورة'))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Align(alignment: AlignmentDirectional.centerStart, child: InfoPill(zikr.description, color: p.gold))),
        SelectableText(zikr.text, textAlign: TextAlign.center, style: NoorText.arabic(context, 21)),
        if (zikr.count > 1) ...[const SizedBox(height: 6), Center(child: InfoPill('${zikr.count} مرات'))],
        if (zikr.reference.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(height: 1, color: p.hairline),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(PhosphorIconsRegular.scroll, size: 15, color: p.textFaint),
            const SizedBox(width: 8),
            Expanded(child: Text(zikr.reference, style: NoorText.caption(context).copyWith(height: 1.6))),
          ]),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          MiniAction(
            icon: fav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
            active: fav,
            color: fav ? p.danger : null,
            tooltip: 'المفضلة',
            onTap: () => WorshipStore.toggleFavourite(kind, zikr.id),
          ),
          const SizedBox(width: 10),
          MiniAction(icon: PhosphorIconsRegular.copy, tooltip: 'نسخ', onTap: () => copyText(context, share)),
          const SizedBox(width: 10),
          MiniAction(icon: PhosphorIconsRegular.shareNetwork, tooltip: 'مشاركة', onTap: () => shareText(share)),
        ]),
      ]),
    );
  }
}
