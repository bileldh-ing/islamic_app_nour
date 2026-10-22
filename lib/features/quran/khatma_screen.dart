import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/quran_service.dart';
import '../../services/storage.dart';
import 'quran_nav.dart';
import 'quran_widgets.dart';

/// Khatma planner: choose a duration, get a daily portion of the 604 pages, track streak.
class KhatmaScreen extends StatefulWidget {
  const KhatmaScreen({super.key});
  @override
  State<KhatmaScreen> createState() => _KhatmaScreenState();
}

class _KhatmaScreenState extends State<KhatmaScreen> {
  late final Future<List<Surah>> _load = QuranService.load();
  static const _options = [7, 10, 15, 30, 60, 90];
  int _days = 30;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Surah>>(
        future: _load,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const NoorPage(title: 'مخطط الختمة', scroll: false, child: Center(child: CircularProgressIndicator()));
          }
          return ValueListenableBuilder<KhatmaPlan?>(
            valueListenable: QuranService.khatma,
            builder: (context, k, _) => NoorPage(
              title: 'مخطط الختمة',
              subtitle: k == null ? 'خطة يومية لختم القرآن' : 'ختمة ${k.days} يومًا',
              bloom: context.noor.gold,
              actions: [
                if (k != null) GlassIconButton(icon: PhosphorIconsRegular.arrowCounterClockwise, onTap: () => _confirmReset(context)),
              ],
              child: k == null ? _setup() : _plan(k),
            ),
          );
        },
      );

  // ---------------- setup ----------------
  Widget _setup() {
    final p = context.noor;
    final perDay = (QuranService.totalPages / _days).ceil();
    final end = DateTime.now().add(Duration(days: _days - 1));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      Glass(
        radius: 28,
        strong: true,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(children: [
          IconBadge(PhosphorIconsRegular.flag, size: 60, color: p.gold),
          const SizedBox(height: 14),
          Text('ابدأ ختمة جديدة', style: NoorText.h2(context)),
          const SizedBox(height: 6),
          Text('اختر المدة التي تريد أن تختم فيها القرآن، وسنقسّم لك 604 صفحة إلى ورد يومي ثابت.',
              textAlign: TextAlign.center, style: NoorText.body(context)),
        ]),
      ),
      const SizedBox(height: 22),
      Text('مدة الختمة', style: NoorText.h3(context)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in _options) GlassChip(label: '$d يومًا', selected: d == _days, onTap: () => setState(() => _days = d)),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: _stat(PhosphorIconsRegular.bookOpen, '$perDay', 'صفحة يوميًا')),
        const SizedBox(width: 10),
        Expanded(child: _stat(PhosphorIconsRegular.clock, '${(perDay * 2.5).round()}', 'دقيقة تقريبًا')),
        const SizedBox(width: 10),
        Expanded(child: _stat(PhosphorIconsRegular.calendarCheck, Fmt.dateShort(end), 'موعد الختم')),
      ]),
      const SizedBox(height: 26),
      NoorButton(label: 'ابدأ الختمة', icon: PhosphorIconsRegular.play, expand: true, onTap: () => QuranService.startKhatma(_days)),
      const SizedBox(height: 10),
      Text('تقدير الوقت بمعدل دقيقتين ونصف للصفحة تقريبًا.', textAlign: TextAlign.center, style: NoorText.caption(context)),
    ]);
  }

  Widget _stat(IconData icon, String value, String label) {
    final p = context.noor;
    return Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(children: [
        Icon(icon, size: 20, color: p.accent),
        const SizedBox(height: 6),
        Text(value, style: NoorText.number(context, size: 18, w: FontWeight.w700), maxLines: 1),
        Text(label, style: NoorText.caption(context), textAlign: TextAlign.center),
      ]),
    );
  }

  // ---------------- active plan ----------------
  Widget _plan(KhatmaPlan k) {
    final p = context.noor;
    final (st, en) = k.nextPortion;
    final diff = k.donePortions - k.expectedPortions;
    final status = k.finished
        ? 'أتممت الختمة، تقبّل الله منك'
        : diff >= 0
            ? (diff == 0 ? 'أنت على الموعد' : 'متقدّم بـ $diff ${diff == 1 ? 'ورد' : 'أوراد'}')
            : 'متأخر بـ ${-diff} ${diff == -1 ? 'ورد' : 'أوراد'}';
    final statusColor = k.finished || diff >= 0 ? p.success : p.danger;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      Glass(
        radius: 28,
        strong: true,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(children: [
          ProgressRing(
            value: k.progress,
            size: 132,
            stroke: 10,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(Fmt.percent(k.progress), style: NoorText.number(context, size: 30, w: FontWeight.w700)),
              Text('${k.pagesDone}/604 صفحة', style: NoorText.caption(context)),
            ]),
          ),
          const SizedBox(height: 14),
          MetaPill(label: status, icon: k.finished || diff >= 0 ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.warning, color: statusColor),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _mini('${k.dayNumber.clamp(1, 9999)}/${k.days}', 'اليوم')),
            Expanded(child: _mini('${k.streak}', 'أيام متتالية', icon: PhosphorIconsFill.fire, color: p.gold)),
            Expanded(child: _mini('${k.pagesPerDay}', 'صفحة يوميًا')),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      _weekStrip(k),
      if (!k.finished) ...[
        const SectionHeader('ورد اليوم', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
        _portionCard(k, st, en),
      ] else ...[
        const SizedBox(height: 18),
        NoorButton(label: 'ابدأ ختمة جديدة', icon: PhosphorIconsRegular.arrowCounterClockwise, expand: true, onTap: QuranService.resetKhatma),
      ],
      const SizedBox(height: 14),
      Text('بدأت في ${Fmt.dateMedium(k.start)} · الموعد المستهدف ${Fmt.dateMedium(k.targetEnd)}', textAlign: TextAlign.center, style: NoorText.caption(context)),
    ]);
  }

  Widget _mini(String v, String label, {IconData? icon, Color? color}) => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 4)],
          Text(v, style: NoorText.number(context, size: 18, w: FontWeight.w700)),
        ]),
        Text(label, style: NoorText.caption(context)),
      ]);

  Widget _weekStrip(KhatmaPlan k) {
    final p = context.noor;
    final today = DateTime.now();
    final done = k.doneDays.toSet();
    return Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(children: [
        for (var i = 6; i >= 0; i--)
          Expanded(
            child: Builder(builder: (context) {
              final d = today.subtract(Duration(days: i));
              final ok = done.contains(Store.dayKey(d));
              final isToday = i == 0;
              return Column(children: [
                Text(Fmt.weekdaysShort[d.weekday - 1], style: NoorText.caption(context).copyWith(fontSize: 10.5, color: isToday ? p.accent : null)),
                const SizedBox(height: 6),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ok ? p.accent : p.glassStrong,
                    border: Border.all(color: isToday ? p.accent : p.glassBorder.withValues(alpha: 0.5), width: isToday ? 1.6 : 1),
                  ),
                  child: Center(
                    child: ok
                        ? Icon(PhosphorIconsBold.check, size: 14, color: p.onAccent)
                        : Text('${d.day}', style: NoorText.number(context, size: 11.5, w: FontWeight.w500).copyWith(color: p.textSoft)),
                  ),
                ),
              ]);
            }),
          ),
      ]),
    );
  }

  Widget _portionCard(KhatmaPlan k, int st, int en) {
    final p = context.noor;
    final (s1, a1) = QuranService.pageStart(st);
    final (s2, a2) = _pageEnd(en);
    final from = QuranService.surah(s1)!;
    final to = QuranService.surah(s2)!;
    return Glass(
      radius: 26,
      tint: k.doneToday ? p.success : p.accent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBadge(k.doneToday ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.bookOpenText, color: k.doneToday ? p.success : p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.doneToday ? 'أنجزت ورد اليوم، هذا الورد التالي' : 'الورد ${k.donePortions + 1} من ${k.totalPortions}',
                  style: NoorText.h3(context).copyWith(fontSize: 15)),
              Text('صفحة $st – $en · ${en - st + 1} صفحات', style: NoorText.caption(context).copyWith(fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _endpoint('من', from.shortName, a1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(PhosphorIconsRegular.arrowLeft, size: 18, color: p.textFaint)),
          Expanded(child: _endpoint('إلى', to.shortName, a2)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: NoorButton(label: 'اقرأ الآن', icon: PhosphorIconsRegular.bookOpen, expand: true, onTap: () => openPage(context, st))),
          const SizedBox(width: 10),
          Expanded(
            child: NoorButton(
              label: 'تم الورد',
              icon: PhosphorIconsRegular.check,
              secondary: true,
              expand: true,
              onTap: () async {
                tick(true);
                final m = ScaffoldMessenger.of(context);
                await QuranService.completeKhatmaPortion();
                m.hideCurrentSnackBar();
                m.showSnackBar(SnackBar(
                  content: const Text('بارك الله فيك، سُجّل الورد'),
                  action: SnackBarAction(label: 'تراجع', onPressed: QuranService.undoKhatmaPortion),
                ));
              },
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _endpoint(String label, String surah, int ayah) => Glass(
        radius: 18,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(children: [
          Text(label, style: NoorText.caption(context)),
          Text(surah, style: NoorText.h3(context).copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('الآية $ayah', style: NoorText.caption(context)),
        ]),
      );

  /// Last (surah, ayah) on [page].
  (int, int) _pageEnd(int page) {
    if (page >= QuranService.totalPages) return (114, 6);
    final (s, a) = QuranService.pageStart(page + 1);
    if (a > 1) return (s, a - 1);
    final prev = QuranService.surah(s - 1)!;
    return (prev.number, prev.ayahs.length);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showGlassSheet<bool>(
      context,
      title: 'إعادة ضبط الختمة',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('سيُحذف تقدّمك في الختمة الحالية وتبدأ من جديد.', style: NoorText.body(ctx)),
          const SizedBox(height: 18),
          NoorButton(label: 'إعادة الضبط', icon: PhosphorIconsRegular.trash, expand: true, onTap: () => Navigator.of(ctx).pop(true)),
          const SizedBox(height: 10),
          NoorButton(label: 'إلغاء', secondary: true, expand: true, onTap: () => Navigator.of(ctx).pop(false)),
        ]),
      ),
    );
    if (ok == true) await QuranService.resetKhatma();
  }
}
