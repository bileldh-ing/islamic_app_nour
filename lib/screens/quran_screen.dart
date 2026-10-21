import 'dart:async';

import 'package:flutter/material.dart';

import '../services/quran_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';
import 'surah_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});
  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  int _tab = 0;
  final _search = TextEditingController();
  Timer? _debounce;
  List<(Surah, Ayah)>? _results;

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (q.trim().length < 2) {
        setState(() => _results = null);
        return;
      }
      final r = await QuranService.search(q);
      if (mounted) setState(() => _results = r);
    });
  }

  void _open(int surah, [int? ayah]) =>
      Navigator.push(context, glassRoute(SurahReaderScreen(surah: surah, initialAyah: ayah)));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder(
        future: QuranService.load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          final surahs = snap.data!;
          return Column(children: [
            const GlassHeader(title: 'القرآن الكريم', showBack: false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GlassCard(
                radius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  style: const TextStyle(color: AppColors.ivory, fontSize: 16),
                  cursorColor: AppColors.gold,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: const Icon(Icons.search_rounded, color: AppColors.gold),
                    hintText: 'ابحث في آيات القرآن…',
                    hintStyle: const TextStyle(color: AppColors.textFaint),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textSoft),
                            onPressed: () {
                              _search.clear();
                              setState(() => _results = null);
                            },
                          ),
                  ),
                ),
              ),
            ),
            if (_results != null)
              Expanded(child: _searchResults())
            else ...[
              const SizedBox(height: 12),
              _lastRead(surahs),
              _tabs(),
              Expanded(
                child: switch (_tab) {
                  0 => _surahList(surahs),
                  1 => _juzList(surahs),
                  _ => _bookmarks(surahs),
                },
              ),
            ],
          ]);
        },
      ),
    );
  }

  Widget _lastRead(List<Surah> surahs) => ValueListenableBuilder(
        valueListenable: QuranService.lastRead,
        builder: (context, lr, _) {
          if (lr == null) return const SizedBox.shrink();
          final s = surahs[lr.$1 - 1];
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: GlassCard(
              borderGold: true,
              glow: true,
              onTap: () => _open(lr.$1, lr.$2),
              child: Row(children: [
                const Icon(Icons.bookmark_rounded, color: AppColors.gold, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('متابعة القراءة', style: TextStyle(color: AppColors.textSoft, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('${s.shortName} · الآية ${toArabicDigits(lr.$2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ]),
                ),
                const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 18),
              ]),
            ),
          );
        },
      );

  Widget _tabs() {
    const labels = ['السور', 'الأجزاء', 'المحفوظات'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(5),
        child: Row(
          children: List.generate(3, (i) {
            final sel = _tab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: sel ? AppColors.goldGradient : null,
                  ),
                  child: Text(labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: sel ? AppColors.midnight : AppColors.textSoft)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _surahList(List<Surah> surahs) => ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 140),
        itemCount: surahs.length,
        itemBuilder: (context, i) {
          final s = surahs[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => _open(s.number),
              child: Row(children: [
                AyahMedallion(number: s.number, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.shortName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                    const SizedBox(height: 3),
                    Text('${s.revelation} · ${toArabicDigits(s.ayahs.length)} آية',
                        style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5)),
                  ]),
                ),
                Text(s.name,
                    style: const TextStyle(fontFamily: AppFonts.quran, fontSize: 20, color: AppColors.gold)),
              ]),
            ),
          );
        },
      );

  Widget _juzList(List<Surah> surahs) {
    final starts = <int, (Surah, Ayah)>{};
    for (final s in surahs) {
      for (final a in s.ayahs) {
        starts.putIfAbsent(a.juz, () => (s, a));
      }
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 140),
      itemCount: 30,
      itemBuilder: (context, i) {
        final (s, a) = starts[i + 1]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => _open(s.number, a.numberInSurah),
            child: Row(children: [
              AyahMedallion(number: i + 1, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الجزء ${toArabicDigits(i + 1)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                  const SizedBox(height: 3),
                  Text('يبدأ من ${s.shortName} · آية ${toArabicDigits(a.numberInSurah)}',
                      style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5)),
                ]),
              ),
              Flexible(
                child: Text(
                  a.text.split(' ').take(3).join(' '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AppFonts.quran, fontSize: 16, color: AppColors.gold),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _bookmarks(List<Surah> surahs) => ValueListenableBuilder(
        valueListenable: QuranService.bookmarks,
        builder: (context, list, _) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('لا توجد آيات محفوظة بعد.\nاضغط مطولًا على أي آية لحفظها.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSoft, height: 1.8)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 140),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final b = list[i];
              final s = surahs[b.surah - 1];
              final a = s.ayahs[b.ayah - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => _open(b.surah, b.ayah),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(a.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: AppFonts.quran, fontSize: 19, height: 1.9)),
                    const SizedBox(height: 6),
                    Text('${s.shortName} · ${toArabicDigits(b.ayah)}',
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                  ]),
                ),
              );
            },
          );
        },
      );

  Widget _searchResults() {
    final r = _results!;
    if (r.isEmpty) {
      return const Center(child: Text('لا توجد نتائج', style: TextStyle(color: AppColors.textSoft)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 140),
      itemCount: r.length,
      itemBuilder: (context, i) {
        final (s, a) = r[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            onTap: () => _open(s.number, a.numberInSurah),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(a.text, style: const TextStyle(fontFamily: AppFonts.quran, fontSize: 19, height: 1.9)),
              const SizedBox(height: 6),
              Text('${s.shortName} · ${toArabicDigits(a.numberInSurah)}',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    );
  }
}
