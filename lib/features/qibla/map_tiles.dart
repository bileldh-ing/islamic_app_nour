import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/theme.dart';

/// Esri Canvas basemaps: World Dark Gray in dark mode, World Light Gray in light mode.
/// Attribution required: "Tiles © Esri".
TileLayer noorTileLayer(BuildContext context) {
  final dark = context.noor.isDark;
  final style = dark ? 'World_Dark_Gray_Base' : 'World_Light_Gray_Base';
  return TileLayer(
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/$style/MapServer/tile/{z}/{y}/{x}',
    userAgentPackageName: 'app.noor.islamic',
    maxNativeZoom: 16,
  );
}

/// Small glass attribution chip for map corners.
Widget noorMapAttribution(BuildContext context) {
  final p = context.noor;
  return Align(
    alignment: AlignmentDirectional.bottomStart,
    child: Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: p.bgBottom.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
      child: Text('Tiles © Esri', style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 10, color: p.textSoft)),
    ),
  );
}
