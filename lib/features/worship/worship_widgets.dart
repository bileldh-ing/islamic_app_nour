import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';

/// Copies [text] and confirms with a floating snackbar.
Future<void> copyText(BuildContext context, String text, {String message = 'تم النسخ'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  tick();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1400)));
}

Future<void> shareText(String text) => SharePlus.instance.share(ShareParams(text: '$text\n\n— تطبيق نور'));

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1600)));
}

/// Wide card with a photo background, dark gradient overlay and content on top.
class HeroPhotoCard extends StatelessWidget {
  const HeroPhotoCard({super.key, required this.image, required this.child, this.height = 190, this.onTap, this.radius = 28});
  final String image;
  final Widget child;
  final double height;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final body = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: p.shadow, blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: p.accent.withValues(alpha: 0.3))),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x1A000000), Color(0x66000000), Color(0xD9000000)],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ]),
      ),
    );
    return onTap == null ? body : Pressable(onTap: onTap!, child: body);
  }
}

/// Small round action used under Arabic text cards (copy / share / favourite).
class MiniAction extends StatelessWidget {
  const MiniAction({super.key, required this.icon, required this.onTap, this.active = false, this.color, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? color;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final c = color ?? (active ? p.accent : p.textSoft);
    final w = Pressable(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? p.accent.withValues(alpha: p.isDark ? 0.18 : 0.12) : p.glass,
          border: Border.all(color: active ? p.accent.withValues(alpha: 0.4) : p.glassBorder.withValues(alpha: p.isDark ? 0.5 : 1)),
        ),
        child: Icon(icon, size: 18, color: c),
      ),
    );
    return tooltip == null ? w : Semantics(label: tooltip, button: true, child: w);
  }
}

/// Pill showing a small label, e.g. "3 مرات" or a reference.
class InfoPill extends StatelessWidget {
  const InfoPill(this.label, {super.key, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final c = color ?? p.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: p.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 5)],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
        ),
      ]),
    );
  }
}

/// Glass search field.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({super.key, required this.controller, required this.onChanged, this.hint = 'ابحث'});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Glass(
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        Icon(PhosphorIconsRegular.magnifyingGlass, size: 19, color: p.textFaint),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: NoorText.body(context).copyWith(color: p.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: NoorText.body(context).copyWith(color: p.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: () {
              controller.clear();
              onChanged('');
            },
            child: Icon(PhosphorIconsRegular.x, size: 18, color: p.textFaint),
          ),
      ]),
    );
  }
}

/// Loading placeholder used while bundled data is parsed.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message = 'تعذّر تحميل البيانات. أعد فتح الصفحة.'});
  final String message;
  @override
  Widget build(BuildContext context) => EmptyState(icon: PhosphorIconsRegular.warningCircle, title: 'حدث خطأ', message: message);
}

/// Standard FutureBuilder wrapper with loading / error states.
class Loader<T> extends StatelessWidget {
  const Loader({super.key, required this.future, required this.builder});
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) return const ErrorState();
          if (!snap.hasData) return const LoadingState();
          return builder(context, snap.data as T);
        },
      );
}

/// Large ring progress painter (used by tasbih and azkar counters).
class RingPainter extends CustomPainter {
  RingPainter({required this.progress, required this.color, required this.track, this.stroke = 10, this.beads = 0, this.beadColor});
  final double progress;
  final Color color;
  final Color track;
  final double stroke;
  final int beads;
  final Color? beadColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, base);
    final rect = Rect.fromCircle(center: c, radius: r);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: [Color.lerp(color, Colors.white, 0.35)!, color],
      ).createShader(rect);
    final p = progress.clamp(0.0, 1.0);
    if (p > 0) canvas.drawArc(rect, -1.5708, 6.2832 * p, false, fg);
    if (beads > 0) {
      final lit = (beads * p).floor();
      for (var i = 0; i < beads; i++) {
        final a = -1.5708 + 6.2832 * i / beads;
        final pos = c + Offset(r * 0.80 * math.cos(a), r * 0.80 * math.sin(a));
        final on = i < lit;
        canvas.drawCircle(pos, on ? 3.6 : 2.6, Paint()..color = on ? (beadColor ?? color) : track);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.progress != progress || old.color != color || old.track != track || old.beads != beads;
}
