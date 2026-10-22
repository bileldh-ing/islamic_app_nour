import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'routes.dart';

/// Opens a registered screen by id (see core/routes.dart). Returns false when unknown.
bool openRoute(BuildContext context, String id) {
  final b = allDemoRoutes()[id];
  if (b == null) return false;
  push(context, Builder(builder: b));
  return true;
}
