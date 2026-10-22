import 'package:flutter/foundation.dart' show kIsWeb;

/// Web-only demo mode used by the screenshot/demo pipeline and the live web demo.
/// `?demo&screen=tasbih&theme=light` opens a screen directly; never active on mobile.
class DemoMode {
  DemoMode._();
  static Map<String, String> get params => kIsWeb ? Uri.base.queryParameters : const {};
  static bool get on => params.containsKey('demo');
  static String? get screen => params['screen'];
  static String? get theme => params['theme']; // light | dark
  static int intParam(String k, int def) => int.tryParse(params[k] ?? '') ?? def;
}
