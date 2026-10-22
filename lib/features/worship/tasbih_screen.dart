import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/storage.dart';
import '../../services/worship_store.dart';
import 'worship_widgets.dart';

/// Premium digital tasbih: presets, custom dhikr, goal, bead ring, daily history.
class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});
  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> with SingleTickerProviderStateMixin {
  static const presets = [
    'سُبْحَانَ اللَّهِ',
    'الْحَمْدُ لِلَّهِ',
    'اللَّهُ أَكْبَرُ',
    'لَا إِلَهَ إِلَّا اللَّهُ',
    'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
    'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
  ];

  int _index = Store.getInt('w_tasbih_sel');
  int _count = Store.getInt('w_tasbih_cur');
  int _rounds = Store.getInt('w_tasbih_rounds');
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));

  List<String> get _all => [...presets, ...WorshipStore.customDhikr];
  int get _goal => Store.settings.value.tasbihGoal <= 0 ? 33 : Store.settings.value.tasbihGoal;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    _pulse.forward(from: 0);
    setState(() => _count++);
    var reached = false;
    if (_count >= _goal) {
      reached = true;
      _rounds++;
      Store.setInt('w_tasbih_rounds', _rounds);
    }
    tick(reached);
    await WorshipStore.addTasbih(1);
    if (reached) {
      if (mounted) showToast(context, 'أتممت $_goal، بارك الله فيك');
      setState(() => _count = 0);
    }
    Store.setInt('w_tasbih_cur', _count);
  }

  void _reset() {
    tick(true);
    setState(() {
      _count = 0;
      _rounds = 0;
    });
    Store.setInt('w_tasbih_cur', 0);
    Store.setInt('w_tasbih_rounds', 0);
  }

  void _select(int i) {
    setState(() {
      _index = i;
      _count = 0;
      _rounds = 0;
    });
    Store.setInt('w_tasbih_sel', i);
    Store.setInt('w_tasbih_cur', 0);
    Store.setInt('w_tasbih_rounds', 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final all = _all;
    if (_index >= all.length) _index = 0;
    final today = WorshipStore.tasbihOn(DateTime.now());
    return NoorPage(
      title: 'المسبحة',
      actions: [
        GlassIconButton(icon: PhosphorIconsRegular.target, onTap: _goalSheet),
        GlassIconButton(icon: PhosphorIconsRegular.arrowCounterClockwise, onTap: _reset),
      ],
      child: Column(children: [
        Pressable(
          onTap: _dhikrSheet,
          child: Glass(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(child: Text(all[_index], textAlign: TextAlign.center, style: NoorText.arabic(context, 22))),
              Icon(PhosphorIconsRegular.caretDown, size: 18, color: p.textFaint),
            ]),
          ),
        ),
        const SizedBox(height: 26),
        Semantics(
          button: true,
          label: 'سبّح',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Transform.scale(scale: 1 - 0.035 * Curves.easeOut.transform(1 - (_pulse.value - 0.5).abs() * 2), child: child),
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [p.accent.withValues(alpha: p.isDark ? 0.22 : 0.16), p.accent.withValues(alpha: 0)]),
                    ),
                  ),
                  Glass(radius: 115, width: 230, height: 230, padding: EdgeInsets.zero, strong: true, child: const SizedBox()),
                  CustomPaint(
                    size: const Size(268, 268),
                    painter: RingPainter(
                      progress: _count / _goal,
                      color: p.accent,
                      track: p.glassStrong,
                      stroke: 8,
                      beads: _goal <= 100 ? _goal.clamp(1, 100) : 100,
                      beadColor: p.gold,
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$_count', style: NoorText.number(context, size: 64, w: FontWeight.w700)),
                    Text('من $_goal', style: NoorText.label(context)),
                    const SizedBox(height: 6),
                    Icon(PhosphorIconsRegular.handTap, size: 20, color: p.textFaint),
                  ]),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('اضغط على الدائرة للتسبيح', style: NoorText.caption(context)),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: _stat(context, '$_rounds', 'الدورات', PhosphorIconsRegular.arrowsClockwise)),
          const SizedBox(width: 10),
          Expanded(child: _stat(context, Fmt.number(today), 'اليوم', PhosphorIconsRegular.sun)),
          const SizedBox(width: 10),
          Expanded(child: _stat(context, Fmt.number(WorshipStore.tasbihLifetime), 'الإجمالي', PhosphorIconsRegular.infinity)),
        ]),
        const SectionHeader('آخر 7 أيام', padding: EdgeInsets.fromLTRB(0, 24, 0, 12)),
        _history(context),
      ]),
    );
  }

  Widget _stat(BuildContext context, String v, String l, IconData i) => Glass(
        radius: 20,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Icon(i, size: 18, color: context.noor.accent),
          const SizedBox(height: 6),
          Text(v, style: NoorText.number(context, size: 18)),
          Text(l, style: NoorText.caption(context)),
        ]),
      );

  Widget _history(BuildContext context) {
    final p = context.noor;
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final vals = days.map(WorshipStore.tasbihOn).toList();
    final maxV = vals.fold<int>(1, (a, b) => b > a ? b : a);
    return Glass(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: SizedBox(
        height: 130,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(vals[i] == 0 ? '' : Fmt.number(vals[i]), style: NoorText.caption(context).copyWith(fontSize: 10)),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 18,
                  height: 6 + 74 * vals[i] / maxV,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: vals[i] == 0 ? [p.glassStrong, p.glassStrong] : [p.accent, Color.lerp(p.accent, Colors.white, 0.35)!],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(Fmt.weekdaysShort[days[i].weekday - 1], style: NoorText.caption(context).copyWith(fontSize: 10.5)),
              ]),
            ),
        ]),
      ),
    );
  }

  void _goalSheet() {
    final custom = TextEditingController();
    showGlassSheet(
      context,
      title: 'الهدف',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final g in const [33, 99, 100, 1000])
              GlassChip(
                label: '$g',
                selected: _goal == g,
                onTap: () {
                  Store.saveSettings(Store.settings.value.copyWith(tasbihGoal: g));
                  Navigator.pop(ctx);
                  setState(() => _count = 0);
                },
              ),
          ]),
          const SizedBox(height: 16),
          Glass(
            radius: 18,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: custom,
              keyboardType: TextInputType.number,
              style: NoorText.body(ctx).copyWith(color: ctx.noor.text),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'هدف مخصص (مثال: 500)'),
            ),
          ),
          const SizedBox(height: 12),
          NoorButton(
            label: 'حفظ',
            expand: true,
            onTap: () {
              final v = int.tryParse(Fmt.western(custom.text.trim()));
              if (v == null || v < 1 || v > 100000) {
                showToast(context, 'أدخل رقمًا بين 1 و 100000');
                return;
              }
              Store.saveSettings(Store.settings.value.copyWith(tasbihGoal: v));
              Navigator.pop(ctx);
              setState(() => _count = 0);
            },
          ),
        ]),
      ),
    );
  }

  void _dhikrSheet() {
    showGlassSheet(
      context,
      title: 'اختر الذكر',
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final all = _all;
        return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 10, 20, 24), children: [
          for (var i = 0; i < all.length; i++)
            GlassTile(
              title: all[i],
              icon: i == _index ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
              trailing: i >= presets.length
                  ? GestureDetector(
                      onTap: () async {
                        final c = WorshipStore.customDhikr..removeAt(i - presets.length);
                        await WorshipStore.setCustomDhikr(c);
                        if (_index >= _all.length) _select(0);
                        set(() {});
                      },
                      child: Icon(PhosphorIconsRegular.trash, size: 18, color: ctx.noor.danger),
                    )
                  : const SizedBox(),
              onTap: () {
                _select(i);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 6),
          NoorButton(label: 'إضافة ذكر مخصص', icon: PhosphorIconsRegular.plus, secondary: true, expand: true, onTap: () => _addCustom(ctx, set)),
        ]);
      }),
    );
  }

  void _addCustom(BuildContext sheetCtx, StateSetter set) {
    final c = TextEditingController();
    showDialog<void>(
      context: sheetCtx,
      builder: (d) => AlertDialog(
        backgroundColor: d.noor.isDark ? const Color(0xFF1E2538) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('ذكر مخصص', style: NoorText.h3(d)),
        content: TextField(controller: c, autofocus: true, maxLength: 120, style: NoorText.arabic(d, 18), decoration: const InputDecoration(hintText: 'اكتب الذكر')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final t = c.text.trim();
              if (t.isEmpty) return;
              await WorshipStore.setCustomDhikr([...WorshipStore.customDhikr, t]);
              if (d.mounted) Navigator.pop(d);
              set(() {});
              if (mounted) setState(() {});
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
