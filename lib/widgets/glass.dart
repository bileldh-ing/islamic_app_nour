import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Liquid-glass surface: blurred backdrop, tinted translucent fill,
/// a specular top highlight and a luminous gradient hairline border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 26,
    this.blur = 22,
    this.tint,
    this.onTap,
    this.glow = false,
    this.borderGold = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;
  final bool glow;
  final bool borderGold;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget body = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: CustomPaint(
          painter: _GlassBorderPainter(radius: radius, gold: borderGold),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (tint ?? Colors.white).withValues(alpha: 0.16),
                  (tint ?? Colors.white).withValues(alpha: 0.05),
                  (tint ?? AppColors.aqua).withValues(alpha: 0.07),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
            child: Stack(
              children: [
                // Specular sheen across the top edge.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 40,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      body = _Pressable(onTap: onTap!, child: body);
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 30, offset: const Offset(0, 14)),
          if (glow) BoxShadow(color: AppColors.gold.withValues(alpha: 0.22), blurRadius: 40, spreadRadius: -6),
        ],
      ),
      child: body,
    );
  }
}

class _GlassBorderPainter extends CustomPainter {
  _GlassBorderPainter({required this.radius, required this.gold});
  final double radius;
  final bool gold;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.6), Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gold
            ? [const Color(0xFFFFE6A8), AppColors.gold.withValues(alpha: 0.25), AppColors.gold.withValues(alpha: 0.7)]
            : [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.06), AppColors.aqua.withValues(alpha: 0.35)],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter old) => old.gold != gold || old.radius != radius;
}

/// Subtle squish on press — the "liquid" feel.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.965 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Full-screen night background with drifting aurora orbs.
class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.child, this.showMosque = true});
  final Widget child;
  final bool showMosque;
  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF020F11), Color(0xFF052326), Color(0xFF07322F)],
            ),
          ),
        ),
        if (widget.showMosque)
          Opacity(
            opacity: 0.9,
            child: Image.asset('assets/images/bg_night.jpg', fit: BoxFit.cover, alignment: Alignment.bottomCenter),
          ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * 2 * math.pi;
            return Stack(children: [
              _orb(Alignment(-0.9 + 0.25 * math.sin(t), -0.7 + 0.12 * math.cos(t)), 260, AppColors.aqua.withValues(alpha: 0.16)),
              _orb(Alignment(0.95 + 0.15 * math.cos(t), 0.1 + 0.2 * math.sin(t)), 300, AppColors.gold.withValues(alpha: 0.10)),
              _orb(Alignment(-0.4 + 0.2 * math.cos(t * 0.7), 0.95), 240, AppColors.emerald.withValues(alpha: 0.25)),
            ]);
          },
        ),
        // Darken for legibility.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.45)],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }

  Widget _orb(Alignment a, double size, Color c) => Align(
        alignment: a,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
            ),
          ),
        ),
      );
}

/// Glass app bar row used at the top of every inner screen.
class GlassHeader extends StatelessWidget {
  const GlassHeader({super.key, required this.title, this.actions = const [], this.showBack = true});
  final String title;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          if (showBack && Navigator.of(context).canPop())
            GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).pop())
          else
            const SizedBox(width: 44),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.ivory),
            ),
          ),
          if (actions.isEmpty) const SizedBox(width: 44) else ...actions,
        ],
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.active = false, this.size = 44});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GlassCard(
        radius: size / 2,
        padding: EdgeInsets.zero,
        borderGold: active,
        onTap: onTap,
        child: Center(child: Icon(icon, size: size * 0.45, color: active ? AppColors.gold : AppColors.ivory)),
      ),
    );
  }
}

/// Gold pill button.
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, color: AppColors.midnight, size: 20), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(color: AppColors.midnight, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// Octagram (Rub el Hizb) ayah-number medallion.
class AyahMedallion extends StatelessWidget {
  const AyahMedallion({super.key, required this.number, this.size = 34});
  final int number;
  final double size;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(),
        child: Center(
          child: Text(
            toArabicDigits(number),
            style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: AppColors.gold),
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 * 0.92;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AppColors.gold;
    for (final rot in [0.0, math.pi / 4]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rot);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.42, height: r * 1.42), p);
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.58, p..color = AppColors.gold.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String toArabicDigits(Object n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((ch) {
    final i = int.tryParse(ch);
    return i == null ? ch : d[i];
  }).join();
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ?trailing,
        ]),
      );
}
