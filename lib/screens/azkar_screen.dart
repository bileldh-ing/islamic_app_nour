import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/content_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';

IconData zikrIcon(String title) => switch (title) {
      'أذكار الصباح' => Icons.wb_sunny_rounded,
      'أذكار المساء' => Icons.nights_stay_rounded,
      'أذكار بعد السلام من الصلاة المفروضة' => Icons.mosque_rounded,
      'تسابيح' => Icons.radio_button_checked_rounded,
      'أذكار النوم' => Icons.bedtime_rounded,
      'أذكار الاستيقاظ' => Icons.wb_twilight_rounded,
      'أدعية قرآنية' => Icons.auto_stories_rounded,
      'أدعية الأنبياء' => Icons.volunteer_activism_rounded,
      _ => Icons.star_rounded,
    };

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});
  @override
  Widget build(BuildContext context) => GlassPage(
        title: 'الأذكار',
        child: FutureBuilder(
          future: ContentService.azkarOnly(),
          builder: (context, snap) => !snap.hasData
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : CategoryList(categories: snap.data!),
        ),
      );
}

class CategoryList extends StatelessWidget {
  const CategoryList({super.key, required this.categories});
  final List<ZikrCategory> categories;
  @override
  Widget build(BuildContext context) => ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final c = categories[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              onTap: () => Navigator.push(context, glassRoute(ZikrReaderScreen(category: c))),
              child: Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.35), AppColors.aqua.withValues(alpha: 0.12)]),
                  ),
                  child: Icon(zikrIcon(c.title), color: AppColors.gold),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                    const SizedBox(height: 3),
                    Text('${toArabicDigits(c.items.length)} ذكر', style: const TextStyle(color: AppColors.textSoft, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textFaint, size: 16),
              ]),
            ),
          );
        },
      );
}

class ZikrReaderScreen extends StatefulWidget {
  const ZikrReaderScreen({super.key, required this.category});
  final ZikrCategory category;
  @override
  State<ZikrReaderScreen> createState() => _ZikrReaderScreenState();
}

class _ZikrReaderScreenState extends State<ZikrReaderScreen> {
  late final List<int> _left = widget.category.items.map((z) => z.count).toList();

  int get _doneCount => _left.where((x) => x == 0).length;

  void _tap(int i) {
    if (_left[i] == 0) return;
    setState(() => _left[i]--);
    if (_left[i] == 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.category.items;
    final progress = items.isEmpty ? 0.0 : _doneCount / items.length;
    return GlassPage(
      title: widget.category.title,
      actions: [
        GlassIconButton(
          icon: Icons.restart_alt_rounded,
          onTap: () => setState(() {
            for (var i = 0; i < items.length; i++) {
              _left[i] = items[i].count;
            }
          }),
        ),
      ],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${toArabicDigits(_doneCount)}/${toArabicDigits(items.length)}',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final z = items[i];
              final done = _left[i] == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: done ? 0.55 : 1,
                  child: GlassCard(
                    onTap: () => _tap(i),
                    borderGold: done,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(z.text,
                          style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 20, height: 1.95, color: AppColors.ivory)),
                      if (z.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(z.description, style: const TextStyle(color: AppColors.aqua, fontSize: 13.5, height: 1.6)),
                      ],
                      if (z.reference.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(z.reference, style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
                      ],
                      const SizedBox(height: 12),
                      Row(children: [
                        IconButton(
                          onPressed: () => SharePlus.instance.share(ShareParams(text: z.text)),
                          icon: const Icon(Icons.ios_share_rounded, color: AppColors.textSoft, size: 20),
                        ),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: z.text));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
                          },
                          icon: const Icon(Icons.copy_rounded, color: AppColors.textSoft, size: 20),
                        ),
                        const Spacer(),
                        Text('التكرار ${toArabicDigits(z.count)}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
                        const SizedBox(width: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: done ? null : AppColors.goldGradient,
                            border: done ? Border.all(color: AppColors.gold) : null,
                          ),
                          child: done
                              ? const Icon(Icons.check_rounded, color: AppColors.gold, size: 20)
                              : Text(toArabicDigits(_left[i]),
                                  style: const TextStyle(color: AppColors.midnight, fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ]),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
