import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/quran_service.dart';

/// Small rounded pill with an icon and a label (meta information).
class MetaPill extends StatelessWidget {
  const MetaPill({super.key, required this.label, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final c = color ?? p.textSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? p.text).withValues(alpha: p.isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (color ?? p.glassBorder).withValues(alpha: color == null ? (p.isDark ? 0.4 : 1) : 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
        Text(label, style: NoorText.caption(context).copyWith(color: c, fontWeight: FontWeight.w500, fontSize: 11)),
      ]),
    );
  }
}

/// One surah in the index list.
class SurahRow extends StatelessWidget {
  const SurahRow({super.key, required this.surah, required this.onTap, this.highlight = false});
  final Surah surah;
  final VoidCallback onTap;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final s = surah;
    final meccan = s.revelation.contains('مك');
    return Glass(
      margin: const EdgeInsets.only(bottom: 10),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      onTap: onTap,
      tint: highlight ? p.accent : null,
      child: Row(children: [
        AyahNumber(s.number, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.shortName, style: NoorText.h3(context).copyWith(fontSize: 16)),
            const SizedBox(height: 3),
            Text('${meccan ? 'مكية' : 'مدنية'} · ${s.ayahs.length} آية', style: NoorText.caption(context).copyWith(fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(s.englishName, style: NoorText.label(context).copyWith(fontSize: 12.5, color: p.textSoft), textDirection: TextDirection.ltr),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIconsRegular.bookOpen, size: 12, color: p.textFaint),
            const SizedBox(width: 4),
            Text('ص ${s.ayahs.first.page}', style: NoorText.caption(context)),
          ]),
        ]),
      ]),
    );
  }
}

/// One juz in the index list.
class JuzRow extends StatelessWidget {
  const JuzRow({super.key, required this.juz, required this.onTap});
  final JuzInfo juz;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final s = QuranService.surah(juz.surah);
    final a = QuranService.ayah(juz.surah, juz.ayah);
    final firstWords = a == null ? '' : a.text.split(' ').take(5).join(' ');
    return Glass(
      margin: const EdgeInsets.only(bottom: 10),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.accent.withValues(alpha: p.isDark ? 0.28 : 0.18), p.accent.withValues(alpha: p.isDark ? 0.10 : 0.06)],
            ),
            border: Border.all(color: p.accent.withValues(alpha: 0.3)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${juz.number}', style: NoorText.number(context, size: 17, w: FontWeight.w700).copyWith(color: p.accent, height: 1)),
            Text('جزء', style: NoorText.caption(context).copyWith(fontSize: 9.5, color: p.accent)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الجزء ${juz.number}', style: NoorText.h3(context).copyWith(fontSize: 15.5)),
            const SizedBox(height: 2),
            Text(firstWords, style: NoorText.quran(context, 15).copyWith(height: 1.6, color: p.textSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${s?.shortName ?? ''} ${juz.surah}:${juz.ayah}', style: NoorText.caption(context)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          MetaPill(label: 'ص ${juz.page}–${juz.endPage}', icon: PhosphorIconsRegular.bookOpen),
        ]),
      ]),
    );
  }
}

/// A saved ayah with swipe-free delete.
class BookmarkRow extends StatelessWidget {
  const BookmarkRow({super.key, required this.bookmark, required this.onTap, required this.onDelete});
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final s = QuranService.surah(bookmark.surah);
    final a = QuranService.ayah(bookmark.surah, bookmark.ayah);
    if (s == null || a == null) return const SizedBox.shrink();
    return Glass(
      margin: const EdgeInsets.only(bottom: 10),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(PhosphorIconsFill.bookmarkSimple, size: 18, color: p.gold),
          const SizedBox(width: 8),
          Expanded(child: Text('${s.shortName} · الآية ${a.numberInSurah}', style: NoorText.h3(context).copyWith(fontSize: 15))),
          MetaPill(label: 'ص ${a.page}'),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'حذف',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              tick();
              onDelete();
            },
            icon: Icon(PhosphorIconsRegular.trash, size: 19, color: p.danger),
          ),
        ]),
        const SizedBox(height: 6),
        Text(a.text,
            style: NoorText.quran(context, 19).copyWith(height: 1.9),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl),
        const SizedBox(height: 4),
        Text('حُفظت ${Fmt.dateShort(bookmark.time)}', style: NoorText.caption(context)),
      ]),
    );
  }
}

/// Glass search field.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({super.key, required this.controller, required this.onChanged, this.hint = 'ابحث عن سورة أو آية', this.onClear});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shadow: false,
      child: Row(children: [
        Icon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: p.textFaint),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: NoorText.body(context).copyWith(color: p.text, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: NoorText.body(context).copyWith(color: p.textFaint, fontSize: 14.5),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, _) => v.text.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                    onClear?.call();
                  },
                  child: Icon(PhosphorIconsFill.xCircle, size: 20, color: p.textFaint),
                ),
        ),
      ]),
    );
  }
}

/// Circular progress ring with a centred label.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 64, this.stroke = 6, this.child, this.color});
  final double value;
  final double size;
  final double stroke;
  final Widget? child;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            strokeWidth: stroke,
            strokeCap: StrokeCap.round,
            color: color ?? p.accent,
            backgroundColor: p.glassStrong,
          ),
        ),
        ?child,
      ]),
    );
  }
}

/// Decorative double-rule divider with a central star (used in surah headers).
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key, this.width = 180});
  final double width;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    Widget line(bool rtl) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: rtl ? [p.gold.withValues(alpha: 0), p.gold.withValues(alpha: 0.7)] : [p.gold.withValues(alpha: 0.7), p.gold.withValues(alpha: 0)]),
            ),
          ),
        );
    return SizedBox(
      width: width,
      child: Row(children: [
        line(true),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(PhosphorIconsFill.star, size: 10, color: p.gold)),
        line(false),
      ]),
    );
  }
}
