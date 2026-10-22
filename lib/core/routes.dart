import 'package:flutter/widgets.dart';

import '../features/prayer/prayer_routes.dart';
import '../features/quran/quran_routes.dart';
import '../features/tools/tools_routes.dart';

/// Every pushable screen registered by id, used by web demo deep links
/// (`?demo&screen=<id>`) and the screenshot pipeline. Each feature folder owns its own map.
Map<String, WidgetBuilder> allDemoRoutes() => {
      ...prayerRoutes,
      ...quranRoutes,
      ...toolsRoutes,
    };
