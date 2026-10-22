import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/quran_service.dart';
import 'quran_widgets.dart';

/// A self-contained decorative ayah card (used for "آية اليوم" and sharing as image).
class AyahShareCard extends StatelessWidget {
  const AyahShareCard({super.key, required this.surah, required this.ayah, this.title = 'آية اليوم', this.showTafsir = false});
  final Surah surah;
  final Ayah ayah;
  final String title;
  final bool showTafsir;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [p.bgTop, p.bgBottom]),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(painter: GeometricPatternPainter(p.pattern.withValues(alpha: p.isDark ? 0.10 : 0.07), cell: 40)),
          ),
          Positioned(
            top: -90,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [p.accent.withValues(alpha: 0.28), p.accent.withValues(alpha: 0)]),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.gold.withValues(alpha: 0.45)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(PhosphorIconsFill.sparkle, size: 14, color: p.gold),
                const SizedBox(width: 6),
                Text(title, style: NoorText.label(context).copyWith(color: p.gold, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              const OrnamentDivider(width: 150),
              const SizedBox(height: 14),
              Text('﴿${ayah.text}﴾',
                  textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: NoorText.quran(context, 23).copyWith(height: 2.0)),
              if (showTafsir) ...[
                const SizedBox(height: 10),
                Text(ayah.tafsir, textAlign: TextAlign.center, style: NoorText.body(context).copyWith(fontSize: 13)),
              ],
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                MetaPill(label: '${surah.shortName} · ${ayah.numberInSurah}', icon: PhosphorIconsRegular.bookOpenText, color: p.accent),
              ]),
              const SizedBox(height: 12),
              Text('نور', style: NoorText.caption(context).copyWith(letterSpacing: 2)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Shares [ayah] as text (with optional tafsir) through the system sheet.
Future<void> shareAyahText(Surah s, Ayah a, {bool tafsir = false}) =>
    SharePlus.instance.share(ShareParams(text: '${QuranService.shareText(s, a, tafsir: tafsir)}\n\n— نور'));

/// Preview sheet with the decorative card and share / copy actions.
Future<void> showAyahShareSheet(BuildContext context, Surah s, Ayah a, {String title = 'آية اليوم'}) {
  final key = GlobalKey();
  return showGlassSheet(
    context,
    title: 'مشاركة الآية',
    builder: (ctx) {
      var withTafsir = false;
      return StatefulBuilder(builder: (ctx, setState) {
        final p = ctx.noor;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RepaintBoundary(key: key, child: AyahShareCard(surah: s, ayah: a, title: title, showTafsir: withTafsir)),
            const SizedBox(height: 14),
            Glass(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              shadow: false,
              child: Row(children: [
                Icon(PhosphorIconsRegular.bookOpenText, size: 18, color: p.textSoft),
                const SizedBox(width: 10),
                Expanded(child: Text('إرفاق التفسير الميسر', style: NoorText.h3(ctx).copyWith(fontSize: 14.5))),
                Switch(value: withTafsir, onChanged: (v) => setState(() => withTafsir = v)),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: NoorButton(
                  label: 'مشاركة كصورة',
                  icon: PhosphorIconsRegular.image,
                  expand: true,
                  onTap: () async {
                    final ok = await _shareImage(key, s, a, withTafsir);
                    if (!ok) await shareAyahText(s, a, tafsir: withTafsir);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NoorButton(
                  label: 'مشاركة كنص',
                  icon: PhosphorIconsRegular.shareNetwork,
                  secondary: true,
                  expand: true,
                  onTap: () => shareAyahText(s, a, tafsir: withTafsir),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            NoorButton(
              label: 'نسخ النص',
              icon: PhosphorIconsRegular.copy,
              secondary: true,
              expand: true,
              onTap: () {
                Clipboard.setData(ClipboardData(text: QuranService.shareText(s, a, tafsir: withTafsir)));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('تم نسخ الآية')));
              },
            ),
          ]),
        );
      });
    },
  );
}

Future<bool> _shareImage(GlobalKey key, Surah s, Ayah a, bool tafsir) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return false;
    final img = await boundary.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return false;
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'noor_ayah_${s.number}_${a.numberInSurah}.png')],
      text: QuranService.shareText(s, a, tafsir: tafsir),
    ));
    return true;
  } catch (_) {
    return false;
  }
}

/// "آية اليوم" screen: the deterministic ayah of the day as a shareable card.
class AyahOfDayScreen extends StatefulWidget {
  const AyahOfDayScreen({super.key});
  @override
  State<AyahOfDayScreen> createState() => _AyahOfDayScreenState();
}

class _AyahOfDayScreenState extends State<AyahOfDayScreen> {
  late final Future<List<Surah>> _load = QuranService.load();

  @override
  Widget build(BuildContext context) => NoorPage(
        title: 'آية اليوم',
        child: FutureBuilder<List<Surah>>(
          future: _load,
          builder: (context, snap) {
            final d = snap.hasData ? QuranService.ayahOfDay() : null;
            if (d == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            final (s, a) = d;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              AyahShareCard(surah: s, ayah: a, showTafsir: true),
              const SizedBox(height: 18),
              NoorButton(label: 'مشاركة', icon: PhosphorIconsRegular.shareNetwork, expand: true, onTap: () => showAyahShareSheet(context, s, a)),
            ]);
          },
        ),
      );
}
