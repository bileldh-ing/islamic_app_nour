import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/quran_service.dart';
import '../../services/storage.dart';
import 'ayah_share.dart';
import 'quran_widgets.dart';

/// Verse-by-verse reader with tafsir, translation, audio and memorisation mode.
/// Open with `openSurah(context, n, ayah: a)` from `quran_nav.dart`.
class SurahReaderScreen extends StatefulWidget {
  const SurahReaderScreen({super.key, required this.surah, this.initialAyah});
  final int surah;
  final int? initialAyah;
  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

enum _Repeat { off, ayah, surah }

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  late final Future<List<Surah>> _load = QuranService.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Surah>>(
        future: _load,
        builder: (context, snap) {
          if (snap.hasError) {
            return const NoorPage(
              title: 'القرآن الكريم',
              child: EmptyState(icon: PhosphorIconsRegular.warningCircle, title: 'تعذّر تحميل المصحف', message: 'أعد فتح الصفحة.'),
            );
          }
          if (!snap.hasData) {
            return const NoorPage(title: 'القرآن الكريم', scroll: false, child: Center(child: CircularProgressIndicator()));
          }
          return _Reader(surah: widget.surah.clamp(1, 114), initialAyah: widget.initialAyah);
        },
      );
}

class _Reader extends StatefulWidget {
  const _Reader({required this.surah, this.initialAyah});
  final int surah;
  final int? initialAyah;
  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> {
  ItemScrollController _items = ItemScrollController();
  ItemPositionsListener _positions = ItemPositionsListener.create();
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  late int _surahNo = widget.surah;
  late int _initialIndex = (widget.initialAyah ?? 0).clamp(0, QuranService.surahs[widget.surah - 1].ayahs.length);
  int? _playing; // numberInSurah being recited
  bool _loadingAudio = false;
  _Repeat _repeat = _Repeat.off;
  List<String>? _translation;
  bool _translationFailed = false;
  bool _translationLoading = false;
  final Set<int> _revealed = {};
  final ValueNotifier<(int, int)> _visible = ValueNotifier((1, 1)); // (page, juz)
  Timer? _progressDebounce;

  Surah get _surah => QuranService.surahs[_surahNo - 1];

  @override
  void initState() {
    super.initState();
    final first = _surah.ayahs[(_initialIndex - 1).clamp(0, _surah.ayahs.length - 1)];
    _visible.value = (first.page, first.juz);
    _loadTranslation();
    _playerSub = _player.playerStateStream.listen(_onPlayerState);
    _positions.itemPositions.addListener(_trackProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) => QuranService.markPageRead(first.page));
  }

  @override
  void dispose() {
    _progressDebounce?.cancel();
    _positions.itemPositions.removeListener(_trackProgress);
    _playerSub?.cancel();
    _player.dispose();
    _visible.dispose();
    _setWakelock(false);
    super.dispose();
  }

  void _setWakelock(bool on) {
    try {
      on ? WakelockPlus.enable() : WakelockPlus.disable();
    } catch (_) {}
  }

  // ---------------- progress ----------------
  void _trackProgress() {
    final pos = _positions.itemPositions.value;
    if (pos.isEmpty) return;
    var first = 1 << 30;
    for (final p in pos) {
      if (p.itemTrailingEdge > 0.18 && p.index < first) first = p.index;
    }
    if (first < 1 || first > _surah.ayahs.length) return;
    final a = _surah.ayahs[first - 1];
    if (_visible.value != (a.page, a.juz)) _visible.value = (a.page, a.juz);
    _progressDebounce?.cancel();
    final no = _surahNo;
    _progressDebounce = Timer(const Duration(milliseconds: 700), () {
      QuranService.setLastRead(no, a.numberInSurah);
      QuranService.markPageRead(a.page);
    });
  }

  // ---------------- translation ----------------
  Future<void> _loadTranslation() async {
    final ed = Store.settings.value.translation;
    setState(() {
      _translation = null;
      _translationFailed = false;
      _translationLoading = ed != 'none';
    });
    if (ed == 'none') return;
    final no = _surahNo;
    final t = await QuranService.translation(no, ed);
    if (!mounted || no != _surahNo) return;
    setState(() {
      _translation = t;
      _translationFailed = t == null;
      _translationLoading = false;
    });
  }

  // ---------------- audio ----------------
  void _onPlayerState(PlayerState st) {
    if (st.processingState != ProcessingState.completed || _playing == null) return;
    if (_repeat == _Repeat.ayah) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    final next = _playing! + 1;
    if (next <= _surah.ayahs.length) {
      _play(next);
    } else if (_repeat == _Repeat.surah) {
      _play(1);
    } else if (_surahNo < 114) {
      _goTo(_surahNo + 1, autoplay: true);
    } else {
      _stop();
    }
  }

  Future<void> _play(int ayah) async {
    final a = _surah.ayahs[ayah - 1];
    final reciter = Store.settings.value.reciter;
    setState(() {
      _playing = ayah;
      _loadingAudio = true;
    });
    _setWakelock(true);
    if (_items.isAttached) {
      _items.scrollTo(index: ayah, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic, alignment: 0.12);
    }
    final no = _surahNo;
    for (final url in [QuranService.audioUrl(a.globalNumber, reciter), QuranService.audioFallbackUrl(no, ayah, reciter)]) {
      try {
        await _player.setUrl(url);
        if (!mounted || _playing != ayah || _surahNo != no) return;
        setState(() => _loadingAudio = false);
        unawaited(_player.play());
        return;
      } catch (_) {
        // try the next source
      }
    }
    if (!mounted) return;
    setState(() {
      _loadingAudio = false;
      _playing = null;
    });
    _setWakelock(false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تشغيل التلاوة. تحقّق من الاتصال بالإنترنت.')));
  }

  Future<void> _stop() async {
    await _player.stop();
    _setWakelock(false);
    if (mounted) setState(() => _playing = null);
  }

  void _goTo(int n, {bool autoplay = false}) {
    _player.stop();
    setState(() {
      _surahNo = n;
      _playing = null;
      _revealed.clear();
      _initialIndex = 0;
      // Fresh controllers so the list restarts at the top of the new surah.
      _positions.itemPositions.removeListener(_trackProgress);
      _items = ItemScrollController();
      _positions = ItemPositionsListener.create()..itemPositions.addListener(_trackProgress);
    });
    final a = _surah.ayahs.first;
    _visible.value = (a.page, a.juz);
    QuranService.setLastRead(n, 1);
    QuranService.markPageRead(a.page);
    _loadTranslation();
    if (autoplay) WidgetsBinding.instance.addPostFrameCallback((_) => _play(1));
  }

  void _snack(String msg, {int seconds = 2}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(msg), duration: Duration(seconds: seconds)));
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: Store.settings,
      builder: (context, s, _) => ValueListenableBuilder<bool>(
        valueListenable: QuranService.hifzMode,
        builder: (context, hifz, _) => ValueListenableBuilder<(int, int)>(
          valueListenable: _visible,
          builder: (context, vis, list) => NoorPage(
            title: _surah.shortName,
            subtitle: 'الجزء ${vis.$2} · صفحة ${vis.$1}',
            scroll: false,
            padding: EdgeInsets.zero,
            actions: [
              GlassIconButton(
                icon: hifz ? PhosphorIconsFill.brain : PhosphorIconsRegular.brain,
                active: hifz,
                onTap: () {
                  _revealed.clear();
                  QuranService.setHifz(!hifz);
                  _snack(!hifz ? 'وضع الحفظ: اضغط على الآية لإظهارها' : 'تم إيقاف وضع الحفظ');
                },
              ),
              GlassIconButton(icon: PhosphorIconsRegular.slidersHorizontal, onTap: _openSettings),
            ],
            floating: _miniPlayer(),
            child: list!,
          ),
          child: _list(s, hifz),
        ),
      ),
    );
  }

  Widget _list(AppSettings s, bool hifz) => ScrollablePositionedList.builder(
        key: ValueKey('surah$_surahNo'),
        itemScrollController: _items,
        itemPositionsListener: _positions,
        initialScrollIndex: _initialIndex,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 4, 20, _playing != null ? 150 : 60),
        itemCount: _surah.ayahs.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _header();
          if (i == _surah.ayahs.length + 1) return _footer();
          return _ayahItem(_surah.ayahs[i - 1], s, hifz);
        },
      );

  Widget _header() {
    final p = context.noor;
    final s = _surah;
    final meccan = s.revelation.contains('مك');
    final daily = Store.settings.value.dailyGoalPages;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 6),
      child: Column(children: [
        Glass(
          strong: true,
          radius: 28,
          padding: EdgeInsets.zero,
          tint: p.gold,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: GeometricPatternPainter(p.gold.withValues(alpha: p.isDark ? 0.10 : 0.12), cell: 34))),
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: p.gold.withValues(alpha: 0.35))),
              child: Column(children: [
                Text('سورة', style: NoorText.label(context).copyWith(color: p.gold, letterSpacing: 1)),
                Text(s.shortName, textAlign: TextAlign.center, style: NoorText.quran(context, 38).copyWith(height: 1.7, color: p.text)),
                Text(s.englishName, style: NoorText.caption(context), textDirection: TextDirection.ltr),
                const SizedBox(height: 10),
                const OrnamentDivider(),
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                  MetaPill(label: meccan ? 'مكية' : 'مدنية', icon: PhosphorIconsRegular.mapPin),
                  MetaPill(label: '${s.ayahs.length} آية', icon: PhosphorIconsRegular.listNumbers),
                  MetaPill(label: 'الجزء ${s.ayahs.first.juz}', icon: PhosphorIconsRegular.stack),
                  MetaPill(label: 'ص ${s.ayahs.first.page}–${s.ayahs.last.page}', icon: PhosphorIconsRegular.bookOpen),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<int>(
          valueListenable: QuranService.pagesReadToday,
          builder: (context, n, _) => Glass(
            radius: 18,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(n >= daily ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.target, size: 18, color: n >= daily ? p.success : p.accent),
              const SizedBox(width: 8),
              Text('ورد اليوم', style: NoorText.label(context)),
              const SizedBox(width: 10),
              Expanded(child: GlassProgress(daily == 0 ? 0 : n / daily, color: n >= daily ? p.success : null)),
              const SizedBox(width: 10),
              Text('$n/$daily صفحة', style: NoorText.number(context, size: 12.5)),
            ]),
          ),
        ),
        if (s.hasBasmala) ...[
          const SizedBox(height: 18),
          Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', textAlign: TextAlign.center, style: NoorText.quran(context, 27).copyWith(color: p.text, height: 1.8)),
        ],
      ]),
    );
  }

  Widget _marker(String label, IconData icon) {
    final p = context.noor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(children: [
        Expanded(child: Divider(color: p.hairline, height: 1)),
        const SizedBox(width: 10),
        MetaPill(label: label, icon: icon, color: p.accent),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: p.hairline, height: 1)),
      ]),
    );
  }

  Widget _ayahItem(Ayah a, AppSettings s, bool hifz) {
    final p = context.noor;
    final i = a.numberInSurah;
    final prev = i > 1 ? _surah.ayahs[i - 2] : null;
    final newPage = prev != null && prev.page != a.page;
    final newJuz = prev != null && prev.juz != a.juz;
    final active = _playing == i;
    final marked = QuranService.isBookmarked(_surahNo, i);
    final hidden = hifz && !_revealed.contains(i);
    final tr = _translation;
    final small = (s.quranFontSize * 0.5).clamp(13, 20).toDouble();

    Widget text = Text(a.text,
        textAlign: TextAlign.justify, textDirection: TextDirection.rtl, style: NoorText.quran(context, s.quranFontSize).copyWith(height: 2.1));
    if (hidden) {
      text = Stack(alignment: Alignment.center, children: [
        ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7), child: text),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: p.glassStrong, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.glassBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIconsRegular.eye, size: 15, color: p.textSoft),
            const SizedBox(width: 6),
            Text('اضغط للإظهار', style: NoorText.caption(context).copyWith(color: p.textSoft)),
          ]),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (newJuz) _marker('بداية الجزء ${a.juz}', PhosphorIconsRegular.stack) else if (newPage) _marker('صفحة ${a.page}', PhosphorIconsRegular.bookOpen),
      AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: active ? [BoxShadow(color: p.accent.withValues(alpha: 0.28), blurRadius: 28, spreadRadius: -4)] : null,
        ),
        child: Pressable(
          scale: 0.99,
          onTap: () => hidden ? setState(() => _revealed.add(i)) : _ayahActions(a),
          onLongPress: () => _ayahActions(a),
          child: Glass(
            radius: 24,
            shadow: false,
            tint: active ? p.accent : null,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                AyahNumber(i, size: 36),
                if (a.sajda) ...[
                  const SizedBox(width: 8),
                  MetaPill(label: 'سجدة تلاوة', icon: PhosphorIconsRegular.arrowFatLineDown, color: p.gold),
                ],
                const Spacer(),
                _mini(active ? PhosphorIconsFill.pauseCircle : PhosphorIconsRegular.playCircle, active ? p.accent : null, () {
                  if (active) {
                    _player.playing ? _player.pause() : _player.play();
                  } else {
                    _play(i);
                  }
                }),
                _mini(marked ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple, marked ? p.gold : null, () => _toggleBookmark(i)),
                _mini(PhosphorIconsRegular.dotsThreeOutline, null, () => _ayahActions(a)),
              ]),
              const SizedBox(height: 8),
              text,
              if (s.showTafsir && !hidden) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: p.text.withValues(alpha: p.isDark ? 0.05 : 0.035),
                    borderRadius: BorderRadius.circular(16),
                    border: BorderDirectional(start: BorderSide(color: p.accent.withValues(alpha: 0.7), width: 3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('التفسير الميسر', style: NoorText.caption(context).copyWith(color: p.accent, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(a.tafsir, style: NoorText.body(context).copyWith(fontSize: small, height: 1.75)),
                  ]),
                ),
              ],
              if (!hidden && s.translation != 'none') ...[
                const SizedBox(height: 10),
                if (tr != null && tr.length >= i)
                  Text(tr[i - 1],
                      textDirection: TextDirection.ltr, textAlign: TextAlign.left, style: NoorText.body(context).copyWith(fontSize: small, color: p.textSoft))
                else if (i == 1 && _translationLoading)
                  Row(children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.textFaint)),
                    const SizedBox(width: 8),
                    Text('جارٍ تحميل الترجمة', style: NoorText.caption(context)),
                  ])
                else if (i == 1 && _translationFailed)
                  GestureDetector(
                    onTap: _loadTranslation,
                    child: Row(children: [
                      Icon(PhosphorIconsRegular.wifiSlash, size: 15, color: p.danger),
                      const SizedBox(width: 6),
                      Expanded(child: Text('تعذّر تحميل الترجمة. اضغط لإعادة المحاولة.', style: NoorText.caption(context).copyWith(color: p.danger))),
                    ]),
                  ),
              ],
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _mini(IconData i, Color? c, VoidCallback onTap) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () {
          tick();
          onTap();
        },
        icon: Icon(i, size: 22, color: c ?? context.noor.textSoft),
      );

  Future<void> _toggleBookmark(int ayah) async {
    final was = QuranService.isBookmarked(_surahNo, ayah);
    await QuranService.toggleBookmark(_surahNo, ayah);
    if (!mounted) return;
    setState(() {});
    _snack(was ? 'أُزيلت من المحفوظات' : 'حُفظت في المحفوظات');
  }

  Widget _footer() {
    Widget nav(int n, bool next) {
      final s = QuranService.surahs[n - 1];
      return Expanded(
        child: Glass(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          onTap: () => _goTo(n),
          child: Row(children: [
            if (!next) Icon(PhosphorIconsRegular.caretRight, size: 18, color: context.noor.textSoft),
            Expanded(
              child: Column(children: [
                Text(next ? 'السورة التالية' : 'السورة السابقة', style: NoorText.caption(context)),
                Text(s.shortName, style: NoorText.h3(context).copyWith(fontSize: 15)),
              ]),
            ),
            if (next) Icon(PhosphorIconsRegular.caretLeft, size: 18, color: context.noor.textSoft),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(children: [
        if (_surahNo > 1) nav(_surahNo - 1, false),
        if (_surahNo > 1 && _surahNo < 114) const SizedBox(width: 10),
        if (_surahNo < 114) nav(_surahNo + 1, true),
      ]),
    );
  }

  // ---------------- mini player ----------------
  Widget? _miniPlayer() {
    if (_playing == null) return null;
    final p = context.noor;
    final reciter = QuranService.reciterById(Store.settings.value.reciter);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Glass(
        strong: true,
        radius: 28,
        blur: 30,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(children: [
          SizedBox(
            width: 40,
            height: 40,
            child: _loadingAudio
                ? Padding(padding: const EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2.2, color: p.accent))
                : const IconBadge(PhosphorIconsRegular.waveform, size: 40),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${_surah.shortName} · الآية $_playing', style: NoorText.h3(context).copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(reciter.name, style: NoorText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          _mini(
            switch (_repeat) {
              _Repeat.off => PhosphorIconsRegular.repeat,
              _Repeat.ayah => PhosphorIconsBold.repeatOnce,
              _Repeat.surah => PhosphorIconsBold.repeat,
            },
            _repeat == _Repeat.off ? null : p.accent,
            () {
              final n = _Repeat.values[(_repeat.index + 1) % 3];
              setState(() => _repeat = n);
              _snack(switch (n) { _Repeat.off => 'بدون تكرار', _Repeat.ayah => 'تكرار الآية', _Repeat.surah => 'تكرار السورة' }, seconds: 1);
            },
          ),
          // RTL: previous ayah on the right, next ayah on the left.
          _mini(PhosphorIconsFill.skipForward, null, () {
            if (_playing! > 1) _play(_playing! - 1);
          }),
          StreamBuilder<bool>(
            stream: _player.playingStream,
            builder: (context, snap) {
              final playing = snap.data ?? false;
              return Pressable(
                onTap: () => playing ? _player.pause() : _player.play(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent, boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.4), blurRadius: 14)]),
                  child: Icon(playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play, color: p.onAccent, size: 20),
                ),
              );
            },
          ),
          _mini(PhosphorIconsFill.skipBack, null, () {
            if (_playing! < _surah.ayahs.length) _play(_playing! + 1);
          }),
          _mini(PhosphorIconsRegular.x, null, _stop),
        ]),
      ),
    );
  }

  // ---------------- sheets ----------------
  void _ayahActions(Ayah a) {
    final s = _surah;
    final i = a.numberInSurah;
    showGlassSheet(
      context,
      title: '${s.shortName} · الآية $i',
      builder: (ctx) {
        final p = ctx.noor;
        final marked = QuranService.isBookmarked(_surahNo, i);
        Widget item(IconData icon, String label, VoidCallback onTap, {Color? color}) => GlassTile(
              title: label,
              icon: icon,
              iconColor: color,
              trailing: const SizedBox.shrink(),
              onTap: () {
                Navigator.of(ctx).pop();
                onTap();
              },
            );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(children: [
            item(PhosphorIconsRegular.playCircle, 'الاستماع من هذه الآية', () => _play(i)),
            item(marked ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple, marked ? 'إزالة من المحفوظات' : 'حفظ في المحفوظات',
                () => _toggleBookmark(i),
                color: p.gold),
            item(PhosphorIconsRegular.bookOpenText, 'التفسير الميسر', () => _tafsirSheet(a)),
            item(PhosphorIconsRegular.copy, 'نسخ الآية', () {
              Clipboard.setData(ClipboardData(text: QuranService.shareText(s, a)));
              _snack('تم نسخ الآية');
            }),
            item(PhosphorIconsRegular.shareNetwork, 'مشاركة الآية', () => showAyahShareSheet(context, s, a, title: 'من القرآن الكريم')),
            item(PhosphorIconsRegular.pushPin, 'تعيين كآخر قراءة', () {
              QuranService.setLastRead(_surahNo, i);
              _snack('تم حفظ موضع القراءة');
            }, color: p.success),
          ]),
        );
      },
    );
  }

  void _tafsirSheet(Ayah a) {
    showGlassSheet(
      context,
      title: 'التفسير الميسر',
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Glass(
            radius: 22,
            shadow: false,
            child: Text(a.text, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: NoorText.quran(ctx, 24)),
          ),
          const SizedBox(height: 14),
          Text(a.tafsir, style: NoorText.body(ctx).copyWith(fontSize: 16, height: 1.9, color: ctx.noor.text)),
          const SizedBox(height: 10),
          Text('${_surah.shortName} · الآية ${a.numberInSurah} · صفحة ${a.page}', style: NoorText.caption(ctx)),
        ]),
      ),
    );
  }

  void _openSettings() {
    showGlassSheet(
      context,
      title: 'إعدادات القراءة',
      builder: (ctx) => ValueListenableBuilder<AppSettings>(
        valueListenable: Store.settings,
        builder: (ctx, s, _) => ValueListenableBuilder<bool>(
          valueListenable: QuranService.hifzMode,
          builder: (ctx, hifz, _) {
            final p = ctx.noor;
            Widget toggle(IconData icon, String title, String sub, bool v, ValueChanged<bool> on) => Glass(
                  radius: 20,
                  shadow: false,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  child: Row(children: [
                    IconBadge(icon, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: NoorText.h3(ctx).copyWith(fontSize: 14.5)),
                        Text(sub, style: NoorText.caption(ctx)),
                      ]),
                    ),
                    Switch(value: v, onChanged: on),
                  ]),
                );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Glass(
                  radius: 20,
                  shadow: false,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Icon(PhosphorIconsRegular.textAa, size: 20, color: p.textSoft),
                      const SizedBox(width: 8),
                      Expanded(child: Text('حجم خط المصحف', style: NoorText.h3(ctx).copyWith(fontSize: 14.5))),
                      Text('${s.quranFontSize.round()}', style: NoorText.number(ctx, size: 14)),
                    ]),
                    Slider(
                      value: s.quranFontSize.clamp(20, 44).toDouble(),
                      min: 20,
                      max: 44,
                      divisions: 12,
                      onChanged: (v) => Store.saveSettings(s.copyWith(quranFontSize: v)),
                    ),
                    Text('بِسْمِ ٱللَّهِ', textAlign: TextAlign.center, style: NoorText.quran(ctx, s.quranFontSize).copyWith(height: 1.6)),
                  ]),
                ),
                toggle(PhosphorIconsRegular.bookOpenText, 'التفسير الميسر', 'إظهار التفسير تحت كل آية', s.showTafsir,
                    (v) => Store.saveSettings(s.copyWith(showTafsir: v))),
                toggle(PhosphorIconsRegular.brain, 'وضع الحفظ', 'إخفاء نص الآيات حتى تضغط عليها', hifz, (v) {
                  _revealed.clear();
                  QuranService.setHifz(v);
                }),
                const SizedBox(height: 6),
                Text('الترجمة', style: NoorText.label(ctx)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in QuranService.translations.entries)
                    GlassChip(
                      label: e.value,
                      icon: e.key == 'none' ? null : PhosphorIconsRegular.translate,
                      selected: s.translation == e.key,
                      onTap: () async {
                        await Store.saveSettings(s.copyWith(translation: e.key));
                        _loadTranslation();
                      },
                    ),
                ]),
                const SizedBox(height: 16),
                Text('القارئ', style: NoorText.label(ctx)),
                const SizedBox(height: 8),
                for (final r in QuranService.reciterList)
                  GlassTile(
                    title: r.name,
                    subtitle: r.style,
                    icon: PhosphorIconsRegular.microphone,
                    iconColor: s.reciter == r.id ? p.accent : p.textFaint,
                    trailing: s.reciter == r.id ? Icon(PhosphorIconsFill.checkCircle, color: p.accent, size: 22) : const SizedBox.shrink(),
                    onTap: () async {
                      await Store.saveSettings(s.copyWith(reciter: r.id));
                      if (_playing != null) _play(_playing!);
                    },
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
