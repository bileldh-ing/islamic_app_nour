import 'package:flutter/widgets.dart';

import '../../services/demo.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/settings_screen.dart';
import '../worship/azkar_screen.dart';
import '../worship/calendar_screen.dart';
import '../worship/duas_screen.dart';
import '../worship/fasting_screen.dart';
import '../worship/guide_data.dart';
import '../worship/guide_screen.dart';
import '../worship/hadith_screen.dart';
import '../worship/names_screen.dart';
import '../worship/shahada_screen.dart';
import '../worship/tasbih_screen.dart';
import 'more_screen.dart';
import 'zakat_screen.dart';

/// Demo deep-link ids for the Worship & Tools suite (`?demo&screen=<id>`).
/// `azkar-reader&cat=sleep` opens any azkar category.
final Map<String, WidgetBuilder> toolsRoutes = {
  'more': (_) => const MoreScreen(),
  'azkar': (_) => const AzkarHomeScreen(),
  'azkar-morning': (_) => const AzkarReaderScreen(categoryId: 'morning'),
  'azkar-evening': (_) => const AzkarReaderScreen(categoryId: 'evening'),
  'azkar-sleep': (_) => const AzkarReaderScreen(categoryId: 'sleep'),
  'azkar-prayer': (_) => const AzkarReaderScreen(categoryId: 'prayer'),
  'azkar-reader': (_) => AzkarReaderScreen(categoryId: DemoMode.params['cat'] ?? 'morning'),
  'duas': (_) => const DuasScreen(),
  'tasbih': (_) => const TasbihScreen(),
  'hadith': (_) => const HadithListScreen(),
  'names': (_) => const NamesScreen(),
  'calendar': (_) => const CalendarScreen(),
  'fasting': (_) => const FastingScreen(),
  'zakat': (_) => const ZakatScreen(),
  'guide-salah': (_) => const GuideScreen(guide: Guides.salah),
  'guide-hajj': (_) => const GuideScreen(guide: Guides.hajj),
  'shahada': (_) => const ShahadaScreen(),
  'settings': (_) => const SettingsScreen(),
  'sources': (_) => const SourcesScreen(),
  'onboarding-flow': (_) => const OnboardingScreen(),
};
