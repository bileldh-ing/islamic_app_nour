import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import 'guide_data.dart';
import 'worship_widgets.dart';

/// Step-by-step guide (Wudu & Salah, Hajj & Umrah).
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.guide});
  final Guide guide;
  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final s = g.sections[_section];
    final p = context.noor;
    return NoorPage(
      title: g.title,
      subtitle: g.subtitle,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: HeroPhotoCard(
            image: g.image,
            height: 150,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(s.title, style: const TextStyle(fontFamily: NoorFonts.ui, fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('${s.steps.length} خطوات', style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        ChipBar(labels: [for (final x in g.sections) x.title], index: _section, onChanged: (i) => setState(() => _section = i)),
        const SizedBox(height: 14),
        if (s.intro != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Glass(
              radius: 18,
              tint: p.gold,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(PhosphorIconsRegular.info, color: p.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(s.intro!, style: NoorText.label(context).copyWith(color: p.text))),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [for (var i = 0; i < s.steps.length; i++) _step(context, i, s.steps[i], i == s.steps.length - 1)]),
        ),
        if (g.note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
            child: Text(g.note!, textAlign: TextAlign.center, style: NoorText.caption(context).copyWith(height: 1.7)),
          ),
      ]),
    );
  }

  Widget _step(BuildContext context, int i, GuideStep st, bool last) {
    final p = context.noor;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Column(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color.lerp(p.accent, Colors.white, 0.2)!, p.accent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Text('${i + 1}', style: TextStyle(fontFamily: NoorFonts.ui, fontWeight: FontWeight.w700, color: p.onAccent, fontSize: 13)),
            ),
            if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: p.accent.withValues(alpha: 0.25))),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Glass(
            margin: const EdgeInsets.only(bottom: 12),
            radius: 22,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconBadge(st.icon, size: 34),
                const SizedBox(width: 10),
                Expanded(child: Text(st.title, style: NoorText.h3(context).copyWith(fontSize: 15))),
              ]),
              const SizedBox(height: 8),
              Text(st.body, style: NoorText.body(context).copyWith(fontSize: 14)),
              if (st.dhikr != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onLongPress: () => copyText(context, st.dhikr!),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: p.isDark ? 0.10 : 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.accent.withValues(alpha: 0.2)),
                    ),
                    child: Text(st.dhikr!, textAlign: TextAlign.center, style: NoorText.arabic(context, 18)),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
