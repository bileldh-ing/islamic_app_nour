import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/content_service.dart';

/// Timing map for the bundled recitation of the 99 Names
/// (`assets/data/names_timings.json`, built by `scripts/audio/align_names.py`).
class NamesTimings {
  NamesTimings({required this.audio, required this.reciter, required this.title, required this.starts, required this.closingStart});
  final String audio;
  final String reciter;
  final String title;

  /// Start second of each name, index 0 = name 1 (الله).
  final List<double> starts;

  /// Second where the closing praise begins (after the 99th name).
  final double closingStart;

  static Future<NamesTimings> load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/data/names_timings.json')) as Map<String, dynamic>;
    return NamesTimings(
      audio: j['audio'] as String,
      reciter: j['reciter'] as String,
      title: j['title'] as String,
      starts: (j['starts'] as List).map((e) => (e as num).toDouble()).toList(),
      closingStart: (j['closing_start'] as num).toDouble(),
    );
  }

  /// 0 = opening verse, 1..99 = name being recited, 100 = closing praise.
  int phaseAt(double sec) {
    if (sec < starts.first) return 0;
    if (sec >= closingStart) return 100;
    var lo = 0, hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= sec) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }
}

/// Owns the player. Playback speed and pitch are locked at 1.0: there is no
/// speed control anywhere, and any external rate change is reset immediately.
class NamesPlayer extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  NamesTimings? timings;
  final ValueNotifier<int> phase = ValueNotifier(-1); // -1 = idle
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  bool ready = false;
  bool failed = false;
  final _subs = <StreamSubscription>[];

  Future<void> init() async {
    try {
      timings = await NamesTimings.load();
      final d = await _player.setAsset(timings!.audio);
      duration = d ?? Duration.zero;
      await _player.setSpeed(1.0);
      try {
        await _player.setPitch(1.0);
      } catch (_) {} // not supported on every platform
      _subs.add(_player.speedStream.listen((s) {
        if (s != 1.0) _player.setSpeed(1.0);
      }));
      _subs.add(_player.positionStream.listen((p) {
        position = p;
        if (playing || p > Duration.zero) phase.value = timings!.phaseAt(p.inMilliseconds / 1000);
        notifyListeners();
      }));
      _subs.add(_player.durationStream.listen((d) {
        if (d != null) duration = d;
        notifyListeners();
      }));
      _subs.add(_player.playerStateStream.listen((s) {
        playing = s.playing && s.processingState != ProcessingState.completed;
        if (s.processingState == ProcessingState.completed) {
          _player.pause();
          _player.seek(Duration.zero);
          phase.value = -1;
        }
        notifyListeners();
      }));
      ready = true;
    } catch (_) {
      failed = true;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (!ready) return;
    tick();
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.setSpeed(1.0);
      await _player.play();
    }
  }

  Future<void> seekSec(double s) => _player.seek(Duration(milliseconds: (s * 1000).round()));

  /// Jump to a given name (1..99) and play from it.
  Future<void> playName(int n) async {
    final t = timings;
    if (!ready || t == null) return;
    await seekSec(math.max(0, t.starts[n - 1] - 0.15));
    phase.value = n;
    if (!_player.playing) {
      await _player.setSpeed(1.0);
      await _player.play();
    }
  }

  Future<void> stop() async {
    await _player.pause();
    await _player.seek(Duration.zero);
    phase.value = -1;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    phase.dispose();
    super.dispose();
  }
}

String _mmss(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The "listen" card: a luminous stage showing the name being recited, a
/// breathing halo while playing, and a seekable progress rail.
class NamesRecitationCard extends StatefulWidget {
  const NamesRecitationCard({super.key, required this.player, required this.names});
  final NamesPlayer player;
  final List<AllahName> names;
  @override
  State<NamesRecitationCard> createState() => _NamesRecitationCardState();
}

class _NamesRecitationCardState extends State<NamesRecitationCard> with SingleTickerProviderStateMixin {
  late final AnimationController _halo = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  double? _drag;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_sync);
  }

  void _sync() {
    if (widget.player.playing && !_halo.isAnimating) {
      _halo.repeat();
    } else if (!widget.player.playing && _halo.isAnimating) {
      _halo.stop();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.player.removeListener(_sync);
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final pl = widget.player;
    if (pl.failed) return const SizedBox.shrink();
    final total = pl.duration.inMilliseconds / 1000;
    final pos = _drag ?? pl.position.inMilliseconds / 1000;
    final frac = total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);

    return Glass(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(PhosphorIconsRegular.waveform, color: p.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('استمع إلى الأسماء', style: NoorText.h3(context)),
              Text(pl.timings == null ? '' : 'بصوت ${pl.timings!.reciter}', style: NoorText.caption(context)),
            ]),
          ),
          if (pl.phase.value >= 0)
            GlassIconButton(icon: PhosphorIconsRegular.stop, size: 40, onTap: pl.stop),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(
              animation: _halo,
              builder: (context, _) => CustomPaint(
                size: const Size(double.infinity, 150),
                painter: _HaloPainter(t: _halo.value, active: pl.playing, accent: p.accent, gold: p.gold),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: pl.phase,
              builder: (context, ph, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.86, end: 1.0).animate(a),
                    child: SlideTransition(position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(a), child: c),
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(ph), child: _stage(context, ph)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        // Progress rail (seekable). No speed control by design.
        LayoutBuilder(builder: (context, c) {
          void seekTo(double dx) {
            final rtl = Directionality.of(context) == TextDirection.rtl;
            var f = (dx / c.maxWidth).clamp(0.0, 1.0);
            if (rtl) f = 1 - f;
            setState(() => _drag = f * total);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) => seekTo(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
            onHorizontalDragEnd: (_) {
              if (_drag != null) pl.seekSec(_drag!);
              setState(() => _drag = null);
            },
            onTapUp: (d) {
              seekTo(d.localPosition.dx);
              pl.seekSec(_drag!);
              setState(() => _drag = null);
            },
            child: SizedBox(
              height: 22,
              child: Stack(alignment: AlignmentDirectional.centerStart, children: [
                Container(height: 5, decoration: BoxDecoration(color: p.hairline, borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(colors: [p.accent, p.gold]),
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(frac * 2 - 1, 0),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: p.accent, width: 3),
                      boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.4), blurRadius: 8)],
                    ),
                  ),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: 6),
        Row(children: [
          Text(_mmss(Duration(milliseconds: (pos * 1000).round())), style: NoorText.number(context, size: 12, w: FontWeight.w500).copyWith(color: p.textSoft)),
          const Spacer(),
          _PlayButton(playing: pl.playing, enabled: pl.ready, onTap: pl.toggle),
          const Spacer(),
          Text(_mmss(pl.duration), style: NoorText.number(context, size: 12, w: FontWeight.w500).copyWith(color: p.textSoft)),
        ]),
      ]),
    );
  }

  Widget _stage(BuildContext context, int ph) {
    final p = context.noor;
    if (ph <= 0 || ph == 100) {
      final text = ph == 100 ? 'جلّ جلاله وتقدّست أسماؤه' : '﴿وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا﴾';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, textAlign: TextAlign.center, style: NoorText.arabic(context, 22, w: FontWeight.w600).copyWith(color: p.text, height: 1.7)),
      );
    }
    final n = widget.names[ph - 1];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$ph / 99', style: NoorText.number(context, size: 12, w: FontWeight.w600).copyWith(color: p.gold, letterSpacing: 1)),
      const SizedBox(height: 2),
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(colors: [p.accent, p.gold], begin: Alignment.topRight, end: Alignment.bottomLeft).createShader(r),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(n.arabic, style: NoorText.arabic(context, 48, w: FontWeight.w700).copyWith(height: 1.45)),
        ),
      ),
      if (n.transliteration.isNotEmpty)
        Text(n.transliteration, textDirection: TextDirection.ltr, style: NoorText.caption(context).copyWith(letterSpacing: 0.4)),
    ]);
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.enabled, required this.onTap});
  final bool playing;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Pressable(
      onTap: enabled ? onTap : () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [p.accent, Color.lerp(p.accent, p.gold, 0.45)!], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          boxShadow: [BoxShadow(color: p.accent.withValues(alpha: playing ? 0.55 : 0.3), blurRadius: playing ? 22 : 12, offset: const Offset(0, 6))],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play,
            key: ValueKey(playing),
            color: p.onAccent,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// Concentric rings that slowly breathe outward while the recitation plays,
/// with a faint eight-point star behind the name.
class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.t, required this.active, required this.accent, required this.gold});
  final double t;
  final bool active;
  final Color accent;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.height * 0.36;
    final glow = Paint()
      ..shader = RadialGradient(colors: [accent.withValues(alpha: active ? 0.20 : 0.10), accent.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: base * 2));
    canvas.drawCircle(c, base * 2, glow);

    // Eight-point star (two overlapping squares).
    final star = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gold.withValues(alpha: 0.22);
    final rot = active ? t * math.pi / 4 : 0.0;
    for (final a in [0.0, math.pi / 4]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a + rot);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: base * 1.9, height: base * 1.9), star);
      canvas.restore();
    }

    if (!active) return;
    for (var i = 0; i < 3; i++) {
      final f = (t + i / 3) % 1.0;
      final r = base * (0.9 + f * 1.3);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: (1 - f) * 0.35);
      canvas.drawCircle(c, r, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => old.t != t || old.active != active || old.accent != accent;
}
