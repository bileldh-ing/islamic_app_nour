import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';

class NamesScreen extends StatelessWidget {
  const NamesScreen({super.key});
  @override
  Widget build(BuildContext context) => GlassPage(
        title: 'أسماء الله الحسنى',
        child: FutureBuilder(
          future: ContentService.names(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            final names = snap.data!;
            return GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: names.length,
              itemBuilder: (context, i) {
                final n = names[i];
                return GlassCard(
                  radius: 22,
                  padding: const EdgeInsets.all(8),
                  onTap: () => _detail(context, n),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(toArabicDigits(n.number), style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(n.arabic,
                          style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 24, color: AppColors.gold, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text(n.transliteration,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppColors.textSoft, fontSize: 11)),
                  ]),
                );
              },
            );
          },
        ),
      );

  void _detail(BuildContext context, AllahName n) => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            blur: 30,
            borderGold: true,
            tint: AppColors.deepTeal,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(n.arabic, style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 48, color: AppColors.gold)),
              const SizedBox(height: 6),
              Text(n.transliteration, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(n.meaningEn, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.textSoft)),
              const SizedBox(height: 12),
              Text('الاسم رقم ${toArabicDigits(n.number)} من ٩٩', style: const TextStyle(color: AppColors.textFaint)),
            ]),
          ),
        ),
      );
}
