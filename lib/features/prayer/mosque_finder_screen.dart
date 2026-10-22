import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/location_service.dart';
import '../../services/mosque_service.dart';
import '../qibla/map_tiles.dart';
import 'location_sheet.dart';

/// Nearby mosques (OpenStreetMap / Overpass) within 5 km: list and map.
class MosqueFinderScreen extends StatefulWidget {
  const MosqueFinderScreen({super.key});
  @override
  State<MosqueFinderScreen> createState() => _MosqueFinderScreenState();
}

class _MosqueFinderScreenState extends State<MosqueFinderScreen> {
  List<Mosque>? _items;
  bool _loading = false;
  bool _error = false;
  bool _fromCache = false;
  int _view = 0; // 0 list, 1 map
  UserLocation? _loc;
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    LocationService.current.addListener(_onLoc);
    _load();
  }

  @override
  void dispose() {
    LocationService.current.removeListener(_onLoc);
    super.dispose();
  }

  void _onLoc() => _load();

  Future<void> _load() async {
    final l = LocationService.current.value ?? UserLocation.makkah;
    final cached = MosqueService.cached(l.lat, l.lng);
    setState(() {
      _loc = l;
      _loading = true;
      _error = false;
      if (cached != null) {
        _items = cached;
        _fromCache = true;
      }
    });
    try {
      final r = await MosqueService.nearby(l.lat, l.lng);
      if (!mounted) return;
      setState(() {
        _items = r;
        _fromCache = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Mosque m) async {
    final native = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final uri = native ? MosqueService.geoUri(m) : MosqueService.directionsUri(m);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && native) ok = await launchUrl(MosqueService.directionsUri(m), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح تطبيق الخرائط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final items = _items;
    Widget body;
    if (items == null && _loading) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: p.accent, strokeWidth: 2.4),
          const SizedBox(height: 14),
          Text('جارٍ البحث عن المساجد القريبة…', style: NoorText.body(context)),
        ]),
      );
    } else if (items == null && _error) {
      body = _Message(
        icon: PhosphorIconsRegular.wifiSlash,
        title: 'تعذّر تحميل المساجد',
        message: 'تحقّق من اتصالك بالإنترنت ثم أعد المحاولة.',
        action: NoorButton(label: 'إعادة المحاولة', icon: PhosphorIconsRegular.arrowClockwise, onTap: _load),
      );
    } else if (items != null && items.isEmpty) {
      body = _Message(
        icon: PhosphorIconsRegular.mosque,
        title: 'لا توجد مساجد مسجّلة قريبة',
        message: 'لم نجد مساجد ضمن 5 كم في بيانات OpenStreetMap. جرّب تحديث موقعك.',
        action: NoorButton(label: 'تغيير الموقع', icon: PhosphorIconsRegular.mapPin, secondary: true, onTap: () => showLocationSheet(context)),
      );
    } else {
      body = _view == 0 ? _list(items!) : _mapView(items!);
    }

    return NoorPage(
      title: 'المساجد القريبة',
      subtitle: _loc?.city,
      scroll: false,
      actions: [GlassIconButton(icon: PhosphorIconsRegular.arrowClockwise, onTap: _loading ? () {} : _load)],
      child: Column(children: [
        Row(children: [
          Expanded(
            child: ChipBar(
              labels: const ['القائمة', 'الخريطة'],
              index: _view,
              padding: EdgeInsets.zero,
              onChanged: (i) => setState(() => _view = i),
            ),
          ),
          if (_loading && items != null) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)),
        ]),
        if (items != null && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(children: [
              Text('${_count(items.length)} ضمن 5 كم', style: NoorText.caption(context)),
              const Spacer(),
              if (_fromCache || _error) Text(_error ? 'آخر نتائج محفوظة' : 'نتائج محفوظة', style: NoorText.caption(context).copyWith(color: p.gold)),
            ]),
          ),
        const SizedBox(height: 6),
        Expanded(child: body),
      ]),
    );
  }

  static String _count(int n) => switch (n) {
        1 => 'مسجد واحد',
        2 => 'مسجدان',
        <= 10 => '$n مساجد',
        _ => '$n مسجدًا',
      };

  Widget _list(List<Mosque> items) {
    final p = context.noor;
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('بيانات المساجد © مساهمو OpenStreetMap', style: NoorText.caption(context), textAlign: TextAlign.center),
          );
        }
        final m = items[i];
        return GlassTile(
          icon: PhosphorIconsRegular.mosque,
          iconColor: i == 0 ? p.gold : p.accent,
          title: m.name,
          subtitle: [Fmt.distanceKm(m.distanceKm), if (m.address.isNotEmpty) m.address].join(' · '),
          onTap: () => _open(m),
          trailing: Icon(PhosphorIconsRegular.navigationArrow, size: 20, color: p.accent),
        );
      },
    );
  }

  Widget _mapView(List<Mosque> items) {
    final p = context.noor;
    final l = _loc ?? UserLocation.makkah;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: LatLng(l.lat, l.lng),
            initialZoom: 13.5,
            backgroundColor: p.bgBottom,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            noorTileLayer(context),
            MarkerLayer(markers: [
              Marker(
                point: LatLng(l.lat, l.lng),
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.accent,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.5), blurRadius: 12)],
                  ),
                ),
              ),
              for (final m in items)
                Marker(
                  point: LatLng(m.lat, m.lng),
                  width: 38,
                  height: 38,
                  child: Tooltip(
                    message: '${m.name} · ${Fmt.distanceKm(m.distanceKm)}',
                    child: Pressable(
                      onTap: () => _open(m),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.isDark ? const Color(0xE61A2032) : Colors.white,
                          border: Border.all(color: p.gold, width: 1.6),
                          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Icon(PhosphorIconsFill.mosque, size: 19, color: p.gold),
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        ),
        noorMapAttribution(context),
        PositionedDirectional(
          top: 10,
          end: 10,
          child: GlassIconButton(icon: PhosphorIconsRegular.crosshairSimple, onTap: () => _map.move(LatLng(l.lat, l.lng), 14)),
        ),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message, required this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget action;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(children: [
          EmptyState(icon: icon, title: title, message: message),
          action,
        ]),
      );
}
