import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/storage.dart';
import 'theme.dart';

/// Haptic tick that respects the user's setting.
void tick([bool heavy = false]) {
  if (!Store.settings.value.hapticsOn) return;
  heavy ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
}

/// Frosted liquid-glass surface. Adapts to light / dark automatically.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 24,
    this.blur = 24,
    this.onTap,
    this.strong = false,
    this.tint,
    this.border = true,
    this.shadow = true,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blur;
  final VoidCallback? onTap;
  final bool strong;
  final Color? tint;
  final bool border;
  final bool shadow;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final r = BorderRadius.circular(radius);
    final fill = strong ? p.glassStrong : p.glass;
    Widget body = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: CustomPaint(
          foregroundPainter: border ? _RimPainter(radius: radius, p: p, tint: tint) : null,
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: tint == null
                    ? [fill, Color.lerp(fill, Colors.transparent, p.isDark ? 0.45 : 0.15)!]
                    : [tint!.withValues(alpha: p.isDark ? 0.30 : 0.18), tint!.withValues(alpha: p.isDark ? 0.10 : 0.07)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
    if (onTap != null) body = Pressable(onTap: onTap!, child: body);
    return Container(
      margin: margin,
      decoration: shadow
          ? BoxDecoration(borderRadius: r, boxShadow: [
              BoxShadow(color: p.shadow, blurRadius: p.isDark ? 28 : 24, offset: const Offset(0, 10), spreadRadius: -8),
            ])
          : null,
      child: body,
    );
  }
}

/// Specular rim: bright top edge fading to a faint bottom edge, like real glass.
class _RimPainter extends CustomPainter {
  _RimPainter({required this.radius, required this.p, this.tint});
  final double radius;
  final NoorPalette p;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius));
    final top = tint?.withValues(alpha: 0.7) ?? (p.isDark ? Colors.white.withValues(alpha: 0.30) : Colors.white);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, p.glassBorder.withValues(alpha: p.isDark ? 0.06 : 0.5), (tint ?? p.glassBorder).withValues(alpha: p.isDark ? 0.14 : 0.6)],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(rr, paint);
  }

  @override
  bool shouldRepaint(covariant _RimPainter old) => old.p != p || old.tint != tint || old.radius != radius;
}

/// Scale-down press feedback.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.onLongPress, this.scale = 0.965});
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          tick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Islamic 8-point star lattice (khatam) used as a subtle texture.
class GeometricPatternPainter extends CustomPainter {
  GeometricPatternPainter(this.color, {this.cell = 46});
  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final r = cell * 0.42;
    for (double y = 0; y < size.height + cell; y += cell) {
      for (double x = 0; x < size.width + cell; x += cell) {
        final c = Offset(x, y);
        // Two overlapping squares = 8-point star.
        for (final rot in [0.0, math.pi / 4]) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = rot + i * math.pi / 2 + math.pi / 4;
            final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
            i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          path.close();
          canvas.drawPath(path, paint);
        }
        canvas.drawCircle(c, r * 0.32, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GeometricPatternPainter old) => old.color != color;
}

/// App background: deep slate (dark) or porcelain (light) with soft colour
/// blooms and a geometric pattern fading out from the top.
class NoorBackground extends StatelessWidget {
  const NoorBackground({super.key, required this.child, this.pattern = true, this.bloom});
  final Widget child;
  final bool pattern;
  final Color? bloom;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final b = bloom ?? p.accent;
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.bgTop, p.bgBottom]),
        ),
      ),
      Positioned(
        top: -160,
        right: -120,
        child: _bloom(b.withValues(alpha: p.isDark ? 0.22 : 0.20), 420),
      ),
      Positioned(
        top: 220,
        left: -160,
        child: _bloom(p.gold.withValues(alpha: p.isDark ? 0.10 : 0.12), 380),
      ),
      if (pattern)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 340,
          child: IgnorePointer(
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.transparent],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: CustomPaint(painter: GeometricPatternPainter(p.pattern)),
            ),
          ),
        ),
      child,
    ]);
  }

  Widget _bloom(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
        ),
      );
}

/// Round glass icon button (header actions, back).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.size = 44, this.badge, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final int? badge;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Pressable(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Glass(
          radius: size / 2,
          padding: EdgeInsets.zero,
          width: size,
          height: size,
          shadow: false,
          strong: active,
          tint: active ? p.accent : null,
          child: Center(child: Icon(icon, size: size * 0.48, color: active ? p.accent : p.text)),
        ),
        if (badge != null && badge! > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFFF6B3D), borderRadius: BorderRadius.circular(10)),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

/// Pill chip used for filters and segmented choices.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.selected = false, this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: selected ? p.accent : p.glass,
        border: Border.all(color: selected ? p.accent : p.glassBorder.withValues(alpha: p.isDark ? 0.5 : 1)),
        boxShadow: selected ? [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16, color: selected ? p.onAccent : p.textSoft), const SizedBox(width: 6)],
        Text(label,
            style: TextStyle(
                fontFamily: NoorFonts.ui,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? p.onAccent : p.textSoft)),
      ]),
    );
    return onTap == null ? child : Pressable(onTap: onTap!, child: child);
  }
}

/// Horizontal row of [GlassChip]s.
class ChipBar extends StatelessWidget {
  const ChipBar({super.key, required this.labels, required this.index, required this.onChanged, this.padding = const EdgeInsets.symmetric(horizontal: 20)});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: labels.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GlassChip(label: labels[i], selected: i == index, onTap: () => onChanged(i)),
        ),
      );
}

/// Section title with an optional "View all" glass pill.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 26, 20, 12)});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(title, style: NoorText.h2(context))),
        if (onAction != null)
          Pressable(
            onTap: onAction!,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: p.glassBorder.withValues(alpha: p.isDark ? 0.5 : 1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(PhosphorIconsRegular.dotsNine, size: 14, color: p.textSoft),
                const SizedBox(width: 5),
                Text(action ?? 'عرض الكل', style: NoorText.label(context).copyWith(fontSize: 12)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Inner page scaffold: background, glass header with back button and title, scrollable body.
class NoorPage extends StatelessWidget {
  const NoorPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions = const [],
    this.scroll = true,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 40),
    this.bloom,
    this.showBack = true,
    this.floating,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool scroll;
  final EdgeInsets padding;
  final Color? bloom;
  final bool showBack;
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(children: [
        if (showBack && Navigator.of(context).canPop())
          GlassIconButton(icon: PhosphorIconsRegular.caretRight, onTap: () => Navigator.of(context).maybePop())
        else
          const SizedBox(width: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(children: [
            Text(title, style: NoorText.h3(context).copyWith(fontSize: 18), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null) Text(subtitle!, style: NoorText.caption(context), textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(width: 10),
        if (actions.isEmpty) const SizedBox(width: 44) else Row(mainAxisSize: MainAxisSize.min, children: _spaced(actions)),
      ]),
    );
    return Scaffold(
      backgroundColor: p.bgBottom,
      body: NoorBackground(
        bloom: bloom,
        child: SafeArea(
          bottom: false,
          child: Stack(children: [
            Column(children: [
              header,
              Expanded(
                child: scroll
                    ? SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: padding, child: child)
                    : Padding(padding: EdgeInsets.only(left: padding.left, right: padding.right), child: child),
              ),
            ]),
            if (floating != null) Positioned(left: 0, right: 0, bottom: 0, child: floating!),
          ]),
        ),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> w) => [for (var i = 0; i < w.length; i++) ...[if (i > 0) const SizedBox(width: 8), w[i]]];
}

/// Accent-filled primary button.
class NoorButton extends StatelessWidget {
  const NoorButton({super.key, required this.label, required this.onTap, this.icon, this.expand = false, this.secondary = false});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expand;
  final bool secondary;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final fg = secondary ? p.text : p.onAccent;
    final content = Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: 8)],
      Text(label, style: TextStyle(fontFamily: NoorFonts.ui, fontWeight: FontWeight.w600, fontSize: 15, color: fg)),
    ]);
    return Pressable(
      onTap: onTap,
      child: secondary
          ? Glass(radius: 18, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), shadow: false, child: content)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: [Color.lerp(p.accent, Colors.white, 0.18)!, p.accent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: content,
            ),
    );
  }
}

/// Icon inside a soft accent-tinted rounded square.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 42, this.iconSize});
  final IconData icon;
  final Color? color;
  final double size;
  final double? iconSize;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final c = color ?? p.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        color: c.withValues(alpha: p.isDark ? 0.16 : 0.12),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: c),
    );
  }
}

/// Glass list row: icon badge, title/subtitle, trailing.
class GlassTile extends StatelessWidget {
  const GlassTile({super.key, required this.title, this.subtitle, this.icon, this.iconColor, this.trailing, this.onTap, this.margin = const EdgeInsets.only(bottom: 10)});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Glass(
      margin: margin,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(children: [
        if (icon != null) ...[IconBadge(icon!, color: iconColor), const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: NoorText.h3(context).copyWith(fontSize: 15)),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: NoorText.caption(context).copyWith(fontSize: 12.5))],
          ]),
        ),
        trailing ?? (onTap != null ? Icon(PhosphorIconsRegular.caretLeft, size: 18, color: p.textFaint) : const SizedBox()),
      ]),
    );
  }
}

/// Bottom sheet with a glass body.
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder, String? title}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      final p = ctx.noor;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
              decoration: BoxDecoration(
                color: p.isDark ? const Color(0xE61A2032) : const Color(0xF2F7F9FC),
                border: Border(top: BorderSide(color: p.glassBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: p.textFaint, borderRadius: BorderRadius.circular(4))),
                  if (title != null) Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), child: Text(title, style: NoorText.h2(ctx))),
                  Flexible(child: builder(ctx)),
                ]),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Fade + slight slide page route.
Route<T> noorRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(position: Tween(begin: const Offset(-0.06, 0), end: Offset.zero).animate(c), child: child),
        );
      },
    );

void push(BuildContext context, Widget page) => Navigator.of(context).push(noorRoute(page));

/// Thin progress bar.
class GlassProgress extends StatelessWidget {
  const GlassProgress(this.value, {super.key, this.height = 6, this.color});
  final double value;
  final double height;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(children: [
        Container(height: height, color: p.glassStrong),
        FractionallySizedBox(
          widthFactor: value.clamp(0, 1).toDouble(),
          child: Container(
            height: height,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color ?? p.accent, Color.lerp(color ?? p.accent, Colors.white, 0.3)!])),
          ),
        ),
      ]),
    );
  }
}

/// Empty / info state.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});
  final IconData icon;
  final String title;
  final String? message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          IconBadge(icon, size: 64),
          const SizedBox(height: 14),
          Text(title, style: NoorText.h3(context), textAlign: TextAlign.center),
          if (message != null) ...[const SizedBox(height: 6), Text(message!, style: NoorText.body(context), textAlign: TextAlign.center)],
        ]),
      );
}

/// Ornamental ayah-number medallion (8-point star) with Western digits.
class AyahNumber extends StatelessWidget {
  const AyahNumber(this.n, {super.key, this.size = 34});
  final int n;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(p.gold),
        child: Center(child: Text('$n', style: TextStyle(fontFamily: NoorFonts.ui, fontSize: size * 0.33, fontWeight: FontWeight.w700, color: p.gold))),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final ctr = s.center(Offset.zero);
    final r = s.width / 2 - 1;
    for (final rot in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = rot + i * math.pi / 2;
        final pt = ctr + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(ctr, r * 0.62, paint..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.c != c;
}
