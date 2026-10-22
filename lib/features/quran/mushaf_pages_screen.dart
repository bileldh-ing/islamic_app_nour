import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/quran_service.dart';
import 'quran_nav.dart';

/// Mushaf page index: jump to any page 1-604, grouped by juz.
class MushafPagesScreen extends StatefulWidget {
  const MushafPagesScreen({super.key});
  @override
  State<MushafPagesScreen> createState() => _MushafPagesScreenState();
}

class _MushafPagesScreenState extends State<MushafPagesScreen> {
  late final Future<List<Surah>> _load = QuranService.load();
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _go() {
    final n = int.tryParse(Fmt.western(_field.text.trim()));
    if (n == null || n < 1 || n > QuranService.totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رقم صفحة بين 1 و 604')));
      return;
    }
    FocusScope.of(context).unfocus();
    openPage(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return NoorPage(
      title: 'صفحات المصحف',
      subtitle: '604 صفحة · مصحف المدينة',
      scroll: false,
      padding: EdgeInsets.zero,
      child: FutureBuilder<List<Surah>>(
        future: _load,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final lr = QuranService.lastRead.value;
          final lastPage = lr == null ? null : QuranService.ayah(lr.$1, lr.$2)?.page;
          // Each page is listed once, under the juz of its first ayah.
          final byJuz = <int, List<int>>{};
          for (var pg = 1; pg <= QuranService.totalPages; pg++) {
            final (s, a) = QuranService.pageStart(pg);
            byJuz.putIfAbsent(QuranService.ayah(s, a)!.juz, () => []).add(pg);
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: Glass(
                    radius: 20,
                    padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                    child: Row(children: [
                      Icon(PhosphorIconsRegular.hash, size: 20, color: p.textFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _field,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _go(),
                          style: NoorText.number(context, size: 16),
                          decoration: InputDecoration(
                            hintText: 'رقم الصفحة (1 – 604)',
                            hintStyle: NoorText.body(context).copyWith(color: p.textFaint),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      NoorButton(label: 'انتقال', icon: PhosphorIconsRegular.arrowLeft, onTap: _go),
                    ]),
                  ),
                ),
              ),
              for (final j in QuranService.juzs) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Row(children: [
                      Text('الجزء ${j.number}', style: NoorText.h3(context)),
                      const SizedBox(width: 8),
                      Text('${QuranService.surah(j.surah)?.shortName ?? ''} ${j.surah}:${j.ayah}', style: NoorText.caption(context)),
                      const Spacer(),
                      Text('ص ${j.page}–${j.endPage}', style: NoorText.caption(context)),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 74, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.86),
                    itemCount: byJuz[j.number]?.length ?? 0,
                    itemBuilder: (context, i) {
                      final pg = byJuz[j.number]![i];
                      return _PageCell(page: pg, current: pg == lastPage);
                    },
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}

class _PageCell extends StatelessWidget {
  const _PageCell({required this.page, required this.current});
  final int page;
  final bool current;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final (s, a) = QuranService.pageStart(page);
    final surah = QuranService.surah(s);
    final opensSurah = a == 1;
    return Glass(
      radius: 16,
      shadow: false,
      tint: current ? p.accent : (opensSurah ? p.gold : null),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      onTap: () => openSurah(context, s, ayah: a),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$page', style: NoorText.number(context, size: 17, w: FontWeight.w700).copyWith(color: current ? p.accent : null)),
        const SizedBox(height: 2),
        Text(surah?.shortName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: NoorText.caption(context).copyWith(fontSize: 9.5)),
      ]),
    );
  }
}
