import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/content_service.dart';
import 'names_recitation.dart';
import 'worship_widgets.dart';

/// The 99 Names of Allah in the order of the Tirmidhi narration (no. 3507).
class NamesScreen extends StatefulWidget {
  const NamesScreen({super.key});
  @override
  State<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends State<NamesScreen> {
  final _future = ContentService.names();
  final _search = TextEditingController();
  String _q = '';
  final _player = NamesPlayer();
  final _keys = List.generate(99, (_) => GlobalKey());
  int _lastScrolled = -1;

  @override
  void initState() {
    super.initState();
    _player.init();
    _player.phase.addListener(_follow);
  }

  /// Keeps the name being recited in view while the user is not searching.
  void _follow() {
    final ph = _player.phase.value;
    if (!_player.playing || _q.isNotEmpty || ph < 1 || ph > 99 || ph == _lastScrolled) return;
    _lastScrolled = ph;
    final ctx = _keys[ph - 1].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.55, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _player.phase.removeListener(_follow);
    _player.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NoorPage(
        title: 'أسماء الله الحسنى',
        subtitle: '99 اسمًا',
        child: Loader<List<AllahName>>(
          future: _future,
          builder: (context, names) {
            final q = ContentService.normalize(_q);
            final list = q.isEmpty
                ? names
                : names.where((n) => ContentService.normalize('${n.arabic} ${n.meaning}').contains(q) || '${n.number}' == q).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              HeroPhotoCard(
                image: 'assets/images/hero_night.jpg',
                height: 160,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Text('﴿وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا﴾',
                      style: TextStyle(fontFamily: NoorFonts.arabic, fontSize: 22, color: Colors.white, height: 1.6)),
                  Text('سورة الأعراف: 180', style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ]),
              ),
              const SizedBox(height: 14),
              NamesRecitationCard(player: _player, names: names),
              const SizedBox(height: 14),
              GlassSearchField(controller: _search, hint: 'ابحث عن اسم أو معنى', onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 14),
              if (list.isEmpty)
                const EmptyState(icon: PhosphorIconsRegular.magnifyingGlass, title: 'لا نتائج')
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.92),
                  itemBuilder: (context, i) => ValueListenableBuilder<int>(
                    valueListenable: _player.phase,
                    builder: (context, ph, _) => _tile(context, list[i], names, ph == list[i].number),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'الترتيب وفق رواية الترمذي (3507) عن أبي هريرة رضي الله عنه، وأصل الحديث في الصحيحين: «إن لله تسعة وتسعين اسمًا، مائة إلا واحدًا، من أحصاها دخل الجنة».',
                textAlign: TextAlign.center,
                style: NoorText.caption(context).copyWith(height: 1.7),
              ),
            ]);
          },
        ),
      );

  Widget _tile(BuildContext context, AllahName n, List<AllahName> all, bool live) {
    final p = context.noor;
    return KeyedSubtree(
      key: _keys[n.number - 1],
      child: AnimatedScale(
        scale: live ? 1.07 : 1,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: live ? p.accent : Colors.transparent, width: 1.6),
            boxShadow: live ? [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -2)] : const [],
          ),
          child: Glass(
            radius: 22,
            padding: const EdgeInsets.all(8),
            strong: live,
            onTap: () => _detail(context, n, all),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${n.number}', style: NoorText.caption(context).copyWith(color: p.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(n.arabic,
                    style: NoorText.arabic(context, 22, w: FontWeight.w700).copyWith(height: 1.5, color: live ? p.accent : null)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _detail(BuildContext context, AllahName start, List<AllahName> all) {
    var n = start;
    showGlassSheet(
      context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final p = ctx.noor;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AyahNumber(n.number, size: 46),
            const SizedBox(height: 10),
            Text(n.arabic, style: NoorText.arabic(ctx, 40, w: FontWeight.w700).copyWith(color: p.accent, height: 1.6)),
            if (n.transliteration.isNotEmpty)
              Text(n.transliteration, textDirection: TextDirection.ltr, style: NoorText.caption(ctx)),
            const SizedBox(height: 14),
            Glass(
              radius: 20,
              child: Row(children: [
                Icon(PhosphorIconsRegular.lightbulb, color: p.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(n.meaning, style: NoorText.body(ctx).copyWith(color: p.text, fontSize: 15.5, height: 1.8))),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              GlassIconButton(
                icon: PhosphorIconsRegular.caretRight,
                onTap: () {
                  if (n.number > 1) set(() => n = all[n.number - 2]);
                },
              ),
              const Spacer(),
              MiniAction(
                icon: PhosphorIconsRegular.play,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _player.playName(n.number);
                },
              ),
              const SizedBox(width: 10),
              MiniAction(icon: PhosphorIconsRegular.copy, onTap: () => copyText(ctx, '${n.arabic}\n${n.meaning}')),
              const SizedBox(width: 10),
              MiniAction(icon: PhosphorIconsRegular.shareNetwork, onTap: () => shareText('${n.arabic}\n${n.meaning}')),
              const Spacer(),
              GlassIconButton(
                icon: PhosphorIconsRegular.caretLeft,
                onTap: () {
                  if (n.number < all.length) set(() => n = all[n.number]);
                },
              ),
            ]),
          ]),
        );
      }),
    );
  }
}
