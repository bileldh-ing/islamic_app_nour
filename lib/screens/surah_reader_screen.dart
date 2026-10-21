import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';

import '../services/quran_service.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';

class SurahReaderScreen extends StatefulWidget {
  const SurahReaderScreen({super.key, required this.surah, this.initialAyah});
  final int surah;
  final int? initialAyah;
  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  final _items = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  late int _surahNo = widget.surah;
  int? _playing; // ayah numberInSurah
  bool _loadingAudio = false;
  List<String>? _translation;

  Surah get _surah => QuranService.surahs[_surahNo - 1];

  @override
  void initState() {
    super.initState();
    _loadTranslation();
    _playerSub = _player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && _playing != null) {
        final next = _playing! + 1;
        if (next <= _surah.ayahs.length) {
          _play(next);
        } else {
          setState(() => _playing = null);
        }
      }
    });
    _positions.itemPositions.addListener(_trackProgress);
    if (widget.initialAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_items.isAttached) _items.jumpTo(index: widget.initialAyah!);
      });
    }
  }

  void _trackProgress() {
    final pos = _positions.itemPositions.value;
    if (pos.isEmpty) return;
    final first = pos.where((p) => p.itemTrailingEdge > 0.15).map((p) => p.index).fold<int>(9999, (a, b) => a < b ? a : b);
    if (first >= 1 && first <= _surah.ayahs.length) {
      QuranService.setLastRead(_surahNo, first);
    }
  }

  Future<void> _loadTranslation() async {
    final ed = Store.settings.value.translation;
    setState(() => _translation = null);
    if (ed == 'none') return;
    final t = await QuranService.translation(_surahNo, ed);
    if (mounted) setState(() => _translation = t);
  }

  Future<void> _play(int ayah) async {
    final a = _surah.ayahs[ayah - 1];
    setState(() {
      _playing = ayah;
      _loadingAudio = true;
    });
    if (_items.isAttached) {
      _items.scrollTo(index: ayah, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic, alignment: 0.15);
    }
    try {
      await _player.setUrl(QuranService.audioUrl(a.globalNumber, Store.settings.value.reciter));
      setState(() => _loadingAudio = false);
      await _player.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingAudio = false;
          _playing = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تشغيل التلاوة. تحقق من الاتصال بالإنترنت.')));
      }
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() => _playing = null);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_trackProgress);
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Store.settings,
      builder: (context, s, _) => GlassPage(
        title: _surah.shortName,
        actions: [
          GlassIconButton(icon: Icons.tune_rounded, onTap: _openSettings),
        ],
        child: Stack(children: [
          ScrollablePositionedList.builder(
            itemScrollController: _items,
            itemPositionsListener: _positions,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 150),
            itemCount: _surah.ayahs.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) return _header();
              if (i == _surah.ayahs.length + 1) return _footer();
              return _ayahTile(_surah.ayahs[i - 1], s);
            },
          ),
          Positioned(left: 16, right: 16, bottom: 24, child: _playerBar()),
        ]),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GlassCard(
          borderGold: true,
          glow: true,
          child: Column(children: [
            Text(_surah.name, style: const TextStyle(fontFamily: AppFonts.quran, fontSize: 32, color: AppColors.gold)),
            const SizedBox(height: 4),
            Text('${_surah.revelation} · ${toArabicDigits(_surah.ayahs.length)} آية · الجزء ${toArabicDigits(_surah.ayahs.first.juz)}',
                style: const TextStyle(color: AppColors.textSoft)),
            if (_surah.hasBasmala) ...[
              const SizedBox(height: 14),
              const Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  style: TextStyle(fontFamily: AppFonts.quran, fontSize: 26, color: AppColors.ivory)),
            ],
          ]),
        ),
      );

  Widget _footer() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          if (_surahNo > 1)
            Expanded(
              child: GlassCard(
                radius: 20,
                padding: const EdgeInsets.all(14),
                onTap: () => _goTo(_surahNo - 1),
                child: Text('→ ${QuranService.surahs[_surahNo - 2].shortName}', textAlign: TextAlign.center),
              ),
            ),
          if (_surahNo > 1 && _surahNo < 114) const SizedBox(width: 10),
          if (_surahNo < 114)
            Expanded(
              child: GlassCard(
                radius: 20,
                padding: const EdgeInsets.all(14),
                onTap: () => _goTo(_surahNo + 1),
                child: Text('${QuranService.surahs[_surahNo].shortName} ←', textAlign: TextAlign.center),
              ),
            ),
        ]),
      );

  void _goTo(int n) {
    _stop();
    setState(() => _surahNo = n);
    _loadTranslation();
    _items.jumpTo(index: 0);
  }

  Widget _ayahTile(Ayah a, AppSettings s) {
    final active = _playing == a.numberInSurah;
    final marked = QuranService.isBookmarked(_surahNo, a.numberInSurah);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: () => _ayahActions(a),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: active ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 30)] : null,
          ),
          child: GlassCard(
            borderGold: active,
            tint: active ? AppColors.gold : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                AyahMedallion(number: a.numberInSurah),
                const SizedBox(width: 8),
                Text('صفحة ${toArabicDigits(a.page)}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                if (a.sajda) ...[
                  const SizedBox(width: 8),
                  const Text('۩ سجدة', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
                const Spacer(),
                _miniBtn(active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    () => active ? _stop() : _play(a.numberInSurah)),
                _miniBtn(marked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, () async {
                  await QuranService.toggleBookmark(_surahNo, a.numberInSurah);
                  setState(() {});
                }, color: marked ? AppColors.gold : null),
                _miniBtn(Icons.more_horiz_rounded, () => _ayahActions(a)),
              ]),
              const SizedBox(height: 10),
              Text(
                a.text,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: AppFonts.quran, fontSize: s.quranFontSize, height: 2.15, color: AppColors.ivory),
              ),
              if (s.showTafsir) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border(right: BorderSide(color: AppColors.aqua.withValues(alpha: 0.7), width: 3)),
                  ),
                  child: Text(
                    a.tafsir,
                    style: TextStyle(fontSize: s.quranFontSize * 0.52, height: 1.75, color: AppColors.textSoft),
                  ),
                ),
              ],
              if (_translation != null && _translation!.length >= a.numberInSurah) ...[
                const SizedBox(height: 10),
                Text(
                  _translation![a.numberInSurah - 1],
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: s.quranFontSize * 0.52, height: 1.6, color: AppColors.aqua.withValues(alpha: 0.9)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(IconData i, VoidCallback onTap, {Color? color}) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(i, size: 22, color: color ?? AppColors.textSoft),
      );

  Widget _playerBar() {
    if (_playing == null) return const SizedBox.shrink();
    return GlassCard(
      radius: 30,
      borderGold: true,
      blur: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        _loadingAudio
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
            : const Icon(Icons.graphic_eq_rounded, color: AppColors.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${_surah.shortName} · الآية ${toArabicDigits(_playing!)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(QuranService.reciters[Store.settings.value.reciter] ?? '',
                style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
          ]),
        ),
        IconButton(
          onPressed: _playing! > 1 ? () => _play(_playing! - 1) : null,
          icon: const Icon(Icons.skip_next_rounded, color: AppColors.ivory),
        ),
        StreamBuilder<bool>(
          stream: _player.playingStream,
          builder: (context, snap) {
            final playing = snap.data ?? false;
            return IconButton(
              onPressed: () => playing ? _player.pause() : _player.play(),
              icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: AppColors.gold, size: 38),
            );
          },
        ),
        IconButton(
          onPressed: _playing! < _surah.ayahs.length ? () => _play(_playing! + 1) : null,
          icon: const Icon(Icons.skip_previous_rounded, color: AppColors.ivory),
        ),
        IconButton(onPressed: _stop, icon: const Icon(Icons.close_rounded, color: AppColors.textSoft)),
      ]),
    );
  }

  void _ayahActions(Ayah a) {
    final ref = '﴿${a.text}﴾ [${_surah.shortName}: ${toArabicDigits(a.numberInSurah)}]';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          blur: 30,
          tint: AppColors.deepTeal,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetItem(Icons.play_circle_outline_rounded, 'استمع من هنا', () => _play(a.numberInSurah)),
            _sheetItem(Icons.bookmark_add_outlined, 'حفظ / إزالة من المحفوظات', () async {
              await QuranService.toggleBookmark(_surahNo, a.numberInSurah);
              setState(() {});
            }),
            _sheetItem(Icons.copy_rounded, 'نسخ الآية', () {
              Clipboard.setData(ClipboardData(text: ref));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الآية')));
            }),
            _sheetItem(Icons.ios_share_rounded, 'مشاركة الآية مع التفسير', () {
              SharePlus.instance.share(ShareParams(text: '$ref\n\nالتفسير الميسر: ${a.tafsir}'));
            }),
          ]),
        ),
      ),
    );
  }

  Widget _sheetItem(IconData i, String t, VoidCallback onTap) => ListTile(
        leading: Icon(i, color: AppColors.gold),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ValueListenableBuilder(
        valueListenable: Store.settings,
        builder: (context, s, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            blur: 30,
            tint: AppColors.deepTeal,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إعدادات القراءة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('حجم الخط: ${toArabicDigits(s.quranFontSize.round())}'),
              Slider(
                value: s.quranFontSize,
                min: 20,
                max: 44,
                onChanged: (v) => Store.saveSettings(s.copyWith(quranFontSize: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار التفسير الميسر تحت كل آية'),
                value: s.showTafsir,
                onChanged: (v) => Store.saveSettings(s.copyWith(showTafsir: v)),
              ),
              const SizedBox(height: 6),
              const Text('ترجمة إضافية', style: TextStyle(color: AppColors.textSoft)),
              Wrap(
                spacing: 8,
                children: QuranService.translations.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: s.translation == e.key,
                          selectedColor: AppColors.gold,
                          labelStyle: TextStyle(color: s.translation == e.key ? AppColors.midnight : AppColors.ivory),
                          onSelected: (_) async {
                            await Store.saveSettings(s.copyWith(translation: e.key));
                            _loadTranslation();
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              const Text('القارئ', style: TextStyle(color: AppColors.textSoft)),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: QuranService.reciters.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: s.reciter == e.key,
                          selectedColor: AppColors.gold,
                          labelStyle: TextStyle(color: s.reciter == e.key ? AppColors.midnight : AppColors.ivory),
                          onSelected: (_) => Store.saveSettings(s.copyWith(reciter: e.key)),
                        ))
                    .toList(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
