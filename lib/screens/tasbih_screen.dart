import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});
  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> with SingleTickerProviderStateMixin {
  static const presets = [
    ('سُبْحَانَ اللَّهِ', 33),
    ('الْحَمْدُ لِلَّهِ', 33),
    ('اللَّهُ أَكْبَرُ', 34),
    ('لَا إِلَٰهَ إِلَّا اللَّهُ', 100),
    ('أَسْتَغْفِرُ اللَّهَ', 100),
    ('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 100),
    ('اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 100),
    ('لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', 100),
  ];

  int _preset = 0;
  int _count = 0;
  int _rounds = 0;
  late int _total = Store.getInt('tasbih_total');
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));

  int get _target => presets[_preset].$2;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap() {
    _pulse.forward(from: 0);
    setState(() {
      _count++;
      _total++;
      if (_count >= _target) {
        _count = 0;
        _rounds++;
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
    Store.setInt('tasbih_total', _total);
    final k = 'tasbih_${Store.dayKey(DateTime.now())}';
    Store.setInt(k, Store.getInt(k) + 1);
  }

  @override
  Widget build(BuildContext context) {
    final today = Store.getInt('tasbih_${Store.dayKey(DateTime.now())}');
    return GlassPage(
      title: 'التسبيح',
      showMosque: true,
      actions: [
        GlassIconButton(
            icon: Icons.restart_alt_rounded,
            onTap: () => setState(() {
                  _count = 0;
                  _rounds = 0;
                })),
      ],
      child: Column(children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final sel = i == _preset;
              return GestureDetector(
                onTap: () => setState(() {
                  _preset = i;
                  _count = 0;
                  _rounds = 0;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: sel ? AppColors.goldGradient : null,
                    color: sel ? null : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: sel ? Colors.transparent : Colors.white24),
                  ),
                  child: Text(presets[i].$1,
                      style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: sel ? AppColors.midnight : AppColors.ivory)),
                ),
              );
            },
          ),
        ),
        const Spacer(),
        Text(presets[_preset].$1,
            style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 34, color: AppColors.gold, fontWeight: FontWeight.w700)),
        const SizedBox(height: 26),
        GestureDetector(
          onTap: _tap,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(scale: 1 - 0.04 * math.sin(_pulse.value * math.pi), child: child),
            child: SizedBox(
              width: 270,
              height: 270,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 270,
                  height: 270,
                  child: CustomPaint(painter: _BeadsPainter(progress: _count / _target, beads: 33)),
                ),
                GlassCard(
                  radius: 100,
                  glow: true,
                  borderGold: true,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ShaderMask(
                        shaderCallback: (r) => AppColors.goldGradient.createShader(r),
                        child: Text(toArabicDigits(_count),
                            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                      Text('من ${toArabicDigits(_target)}', style: const TextStyle(color: AppColors.textSoft)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text('اضغط في أي مكان على الدائرة للتسبيح', style: TextStyle(color: AppColors.textFaint)),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
          child: GlassCard(
            child: Row(children: [
              _stat(toArabicDigits(_rounds), 'الدورات'),
              _stat(toArabicDigits(today), 'اليوم'),
              _stat(toArabicDigits(_total), 'الإجمالي'),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(l, style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5)),
        ]),
      );
}

class _BeadsPainter extends CustomPainter {
  _BeadsPainter({required this.progress, required this.beads});
  final double progress;
  final int beads;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 10;
    final lit = (progress * beads).floor();
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white10
          ..strokeWidth = 1.5);
    for (var i = 0; i < beads; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / beads;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      final on = i < lit;
      if (on) {
        canvas.drawCircle(p, 9, Paint()..color = AppColors.gold.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      canvas.drawCircle(
        p,
        6.5,
        Paint()
          ..shader = RadialGradient(
            colors: on ? [const Color(0xFFFFF0C8), AppColors.gold] : [Colors.white38, Colors.white10],
          ).createShader(Rect.fromCircle(center: p, radius: 6.5)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BeadsPainter old) => old.progress != progress;
}
