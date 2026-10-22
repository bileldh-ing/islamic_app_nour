import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/quran_service.dart';
import 'quran_nav.dart';
import 'quran_widgets.dart';

/// Saved ayahs with open and delete.
class QuranBookmarksScreen extends StatefulWidget {
  const QuranBookmarksScreen({super.key});
  @override
  State<QuranBookmarksScreen> createState() => _QuranBookmarksScreenState();
}

class _QuranBookmarksScreenState extends State<QuranBookmarksScreen> {
  late final Future<List<Surah>> _load = QuranService.load();

  Future<void> _delete(Bookmark b) async {
    await QuranService.toggleBookmark(b.surah, b.ayah);
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: const Text('أُزيلت من المحفوظات'),
      action: SnackBarAction(label: 'تراجع', onPressed: () => QuranService.toggleBookmark(b.surah, b.ayah)),
    ));
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Bookmark>>(
        valueListenable: QuranService.bookmarks,
        builder: (context, list, _) => NoorPage(
          title: 'المحفوظات',
          subtitle: '${list.length} آية محفوظة',
          child: FutureBuilder<List<Surah>>(
            future: _load,
            builder: (context, snap) {
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
              if (list.isEmpty) {
                return const EmptyState(
                  icon: PhosphorIconsRegular.bookmarkSimple,
                  title: 'لا توجد آيات محفوظة',
                  message: 'اضغط على رمز الحفظ بجانب أي آية أثناء القراءة لتجدها هنا.',
                );
              }
              return Column(children: [
                for (final b in list)
                  BookmarkRow(
                    key: ValueKey(b.key),
                    bookmark: b,
                    onTap: () => openSurah(context, b.surah, ayah: b.ayah),
                    onDelete: () => _delete(b),
                  ),
                const SizedBox(height: 8),
                Text('اضغط على الآية لفتحها في موضعها', style: NoorText.caption(context)),
              ]);
            },
          ),
        ),
      );
}
