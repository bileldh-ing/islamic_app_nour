import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/content_service.dart';
import '../../services/hadith_service.dart';
import '../../services/worship_store.dart';
import 'worship_widgets.dart';

/// Home-embeddable card showing today's hadith from an-Nawawi's Forty.
class DailyHadithCard extends StatelessWidget {
  const DailyHadithCard({super.key, this.margin = EdgeInsets.zero});
  final EdgeInsetsGeometry margin;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return FutureBuilder<Hadith>(
      future: HadithService.daily(),
      builder: (context, snap) {
        final h = snap.data;
        return Glass(
          margin: margin,
          radius: 26,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          onTap: h == null ? null : () => push(context, HadithDetailScreen(hadith: h)),
          child: h == null
              ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    IconBadge(PhosphorIconsRegular.quotes, size: 36, color: p.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('حديث اليوم', style: NoorText.caption(context)),
                        Text(h.title, style: NoorText.h3(context).copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    InfoPill('${h.number} / 42', color: p.gold),
                  ]),
                  const SizedBox(height: 12),
                  Text(h.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: NoorText.arabic(context, 18)),
                  const SizedBox(height: 8),
                  Text(h.source, maxLines: 1, overflow: TextOverflow.ellipsis, style: NoorText.caption(context)),
                ]),
        );
      },
    );
  }
}

/// An-Nawawi's Forty Hadith (42 as compiled by the Imam).
class HadithListScreen extends StatefulWidget {
  const HadithListScreen({super.key});
  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  final _future = HadithService.all();
  final _search = TextEditingController();
  String _q = '';
  int _tab = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NoorPage(
        title: 'الأربعون النووية',
        subtitle: 'للإمام يحيى بن شرف النووي',
        child: Loader<List<Hadith>>(
          future: _future,
          builder: (context, all) => ValueListenableBuilder<int>(
            valueListenable: WorshipStore.changes,
            builder: (context, _, _) {
              final fav = WorshipStore.favourites('hadith');
              final q = ContentService.normalize(_q);
              var list = _tab == 1 ? all.where((h) => fav.contains('${h.number}')).toList() : all;
              if (q.isNotEmpty) {
                list = list
                    .where((h) => ContentService.normalize('${h.title} ${h.text}').contains(q) || '${h.number}' == q)
                    .toList();
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const DailyHadithCard(),
                const SizedBox(height: 16),
                GlassSearchField(controller: _search, hint: 'ابحث في الأحاديث أو برقم الحديث', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 12),
                ChipBar(labels: const ['كل الأحاديث', 'المفضلة'], index: _tab, onChanged: (i) => setState(() => _tab = i), padding: EdgeInsets.zero),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  EmptyState(
                    icon: _tab == 1 ? PhosphorIconsRegular.heart : PhosphorIconsRegular.magnifyingGlass,
                    title: _tab == 1 ? 'لا توجد أحاديث مفضلة' : 'لا نتائج',
                  )
                else
                  for (final h in list)
                    Glass(
                      margin: const EdgeInsets.only(bottom: 10),
                      radius: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => push(context, HadithDetailScreen(hadith: h, all: all)),
                      child: Row(children: [
                        AyahNumber(h.number, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(h.title, style: NoorText.h3(context).copyWith(fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(h.source, maxLines: 1, overflow: TextOverflow.ellipsis, style: NoorText.caption(context)),
                          ]),
                        ),
                        if (fav.contains('${h.number}')) Icon(PhosphorIconsFill.heart, size: 16, color: context.noor.danger),
                        const SizedBox(width: 6),
                        Icon(PhosphorIconsRegular.caretLeft, size: 18, color: context.noor.textFaint),
                      ]),
                    ),
              ]);
            },
          ),
        ),
      );
}

class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({super.key, required this.hadith, this.all});
  final Hadith hadith;
  final List<Hadith>? all;
  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  late Hadith _h = widget.hadith;
  double _font = 22;

  void _go(int delta) {
    final all = widget.all;
    if (all == null) return;
    final i = _h.number - 1 + delta;
    if (i < 0 || i >= all.length) return;
    setState(() => _h = all[i]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final fav = WorshipStore.isFavourite('hadith', '${_h.number}');
    return NoorPage(
      title: 'الحديث ${_h.number}',
      subtitle: _h.title,
      actions: [
        GlassIconButton(
          icon: fav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
          active: fav,
          onTap: () async {
            await WorshipStore.toggleFavourite('hadith', '${_h.number}');
            setState(() {});
          },
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Glass(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: AyahNumber(_h.number, size: 46)),
            const SizedBox(height: 10),
            Text(_h.title, textAlign: TextAlign.center, style: NoorText.h2(context)),
            if (_h.narrator.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(_h.narrator, textAlign: TextAlign.center, style: NoorText.label(context).copyWith(color: p.gold)),
            ],
            const SizedBox(height: 16),
            SelectableText(_h.text, textAlign: TextAlign.justify, style: NoorText.arabic(context, _font)),
            const SizedBox(height: 14),
            Container(height: 1, color: p.hairline),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(PhosphorIconsRegular.scroll, size: 16, color: p.textFaint),
              const SizedBox(width: 8),
              Expanded(child: Text(_h.source, style: NoorText.caption(context).copyWith(height: 1.6, fontSize: 12.5))),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: NoorButton(label: 'نسخ', icon: PhosphorIconsRegular.copy, secondary: true, onTap: () => copyText(context, _h.shareText))),
          const SizedBox(width: 10),
          Expanded(child: NoorButton(label: 'مشاركة', icon: PhosphorIconsRegular.shareNetwork, onTap: () => shareText(_h.shareText))),
        ]),
        const SizedBox(height: 14),
        Glass(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Icon(PhosphorIconsRegular.textAa, size: 18, color: p.textSoft),
            Expanded(child: Slider(value: _font, min: 16, max: 32, divisions: 8, onChanged: (v) => setState(() => _font = v))),
          ]),
        ),
        if (widget.all != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            if (_h.number > 1)
              Expanded(child: NoorButton(label: 'السابق', icon: PhosphorIconsRegular.caretRight, secondary: true, onTap: () => _go(-1)))
            else
              const Spacer(),
            const SizedBox(width: 10),
            if (_h.number < widget.all!.length)
              Expanded(child: NoorButton(label: 'التالي', icon: PhosphorIconsRegular.caretLeft, secondary: true, onTap: () => _go(1)))
            else
              const Spacer(),
          ]),
        ],
      ]),
    );
  }
}
