import 'package:flutter/widgets.dart';

import 'adhan_settings_screen.dart';
import 'mosque_finder_screen.dart';
import 'prayer_settings_screen.dart';
import 'timetable_screen.dart';
import 'tracker_screen.dart';

/// Demo deep-link ids for the prayer & qibla suite (`?demo&screen=<id>`).
/// The tab roots are opened as tabs: 'prayer' and 'qibla'.
final Map<String, WidgetBuilder> prayerRoutes = {
  'timetable': (_) => const TimetableScreen(),
  'tracker': (_) => const TrackerScreen(),
  'mosques': (_) => const MosqueFinderScreen(),
  'adhan-settings': (_) => const AdhanSettingsScreen(),
  'prayer-settings': (_) => const PrayerSettingsScreen(),
};
