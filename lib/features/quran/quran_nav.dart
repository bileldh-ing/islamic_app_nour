import 'package:flutter/widgets.dart';

import '../../core/glass.dart';
import '../../services/quran_service.dart';
import 'surah_reader_screen.dart';

/// Opens the reader at [surah] (1-114), optionally scrolled to [ayah].
void openSurah(BuildContext context, int surah, {int? ayah}) =>
    push(context, SurahReaderScreen(surah: surah.clamp(1, 114), initialAyah: ayah));

/// Opens the reader at the first ayah of mushaf [page] (1-604).
Future<void> openPage(BuildContext context, int page) async {
  await QuranService.load();
  if (!context.mounted) return;
  final (s, a) = QuranService.pageStart(page);
  openSurah(context, s, ayah: a);
}

/// Opens the reader at the last-read position (or Al-Fatiha).
void openLastRead(BuildContext context) {
  final lr = QuranService.lastRead.value;
  openSurah(context, lr?.$1 ?? 1, ayah: lr?.$2);
}
