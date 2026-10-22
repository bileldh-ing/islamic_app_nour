import 'package:flutter/widgets.dart';

import '../../services/demo.dart';
import '../../services/quran_service.dart';
import 'ayah_share.dart';
import 'khatma_screen.dart';
import 'mushaf_pages_screen.dart';
import 'quran_bookmarks_screen.dart';
import 'quran_home_screen.dart';
import 'surah_reader_screen.dart';

int? _ayahParam() => int.tryParse(DemoMode.params['ayah'] ?? '');

/// Demo deep-link ids for the Quran suite (`?demo&screen=<id>`).
final Map<String, WidgetBuilder> quranRoutes = {
  'quran': (_) => const QuranHomeScreen(),
  'reader': (_) => SurahReaderScreen(surah: DemoMode.intParam('surah', 1), initialAyah: _ayahParam()),
  'reader-last': (_) {
    final lr = QuranService.lastRead.value;
    return SurahReaderScreen(surah: lr?.$1 ?? 1, initialAyah: lr?.$2);
  },
  'khatma': (_) => const KhatmaScreen(),
  'quran-pages': (_) => const MushafPagesScreen(),
  'quran-bookmarks': (_) => const QuranBookmarksScreen(),
  'ayah-card': (_) => const AyahOfDayScreen(),
};
