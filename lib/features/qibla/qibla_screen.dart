import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/demo.dart';
import '../../services/geomag.dart';
import '../../services/location_service.dart';
import '../../services/prayer_calc.dart';
import '../../services/prayer_service.dart';
import '../prayer/location_sheet.dart';
import '../prayer/prayer_widgets.dart';
import 'compass_dial.dart';
import 'map_tiles.dart';

/// Qibla tab root: filtered, declination-corrected compass with Kaaba marker, or a map with the great-circle path.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _sub;
  Timer? _demoTimer;
  double? _heading; // true heading, filtered
  double? _accuracy;
  bool _noSensor = false;
  bool _aligned = false;
  bool _map = false;

  static const _alpha = 0.16; // low-pass factor
  static const _alignTolerance = 3.0;

  /// flutter_compass returns a *true* heading on iOS (CLHeading.trueHeading) but a
  /// *magnetic* one on Android, so the WMM2025 declination is added on Android only.
  bool get _needsDeclination => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (DemoMode.on) {
      _startDemoSweep();
      return;
    }
    final events = kIsWeb ? null : FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
      return;
    }
    _sub = events.listen((e) {
      final h = e.heading;
      if (h == null) {
        if (mounted) setState(() => _noSensor = true);
        return;
      }
      final l = LocationService.current.value ?? UserLocation.makkah;
      final decl = _needsDeclination ? MagneticModel.declination(l.lat, l.lng) : 0.0;
      final target = (h + decl + 720) % 360;
      final prev = _heading;
      double next;
      if (prev == null) {
        next = target;
      } else {
        var diff = target - prev;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        next = (prev + diff * _alpha + 360) % 360;
      }
      if (!mounted) return;
      setState(() {
        _heading = next;
        _accuracy = e.accuracy;
        _noSensor = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _noSensor = true);
    });
  }

  /// Web demo: a phone being turned until it locks onto the Qibla (damped oscillation).
  void _startDemoSweep() {
    final start = DateTime.now();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      final l = LocationService.current.value ?? const UserLocation(lat: 36.8065, lng: 10.1815, city: 'تونس');
      final target = PrayerService.qibla(l);
      final t = DateTime.now().difference(start).inMilliseconds / 1000.0;
      final h = (target + 80 * math.cos(t * 1.5) * math.exp(-t / 2.0) + 360) % 360;
      setState(() {
        _heading = h;
        _accuracy = 5;
      });
      if (t > 9) _demoTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Scaffold(
      backgroundColor: p.bgBottom,
      body: NoorBackground(
        bloom: _aligned ? p.gold : null,
        child: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<UserLocation?>(
            valueListenable: LocationService.current,
            builder: (context, loc, _) {
              final l = loc ?? UserLocation.makkah;
              final qibla = PrayerService.qibla(l);
              final dist = PrayerService.distanceToKaaba(l);
              final heading = _heading;
              final delta = heading == null ? 0.0 : (qibla - heading + 540) % 360 - 180;
              final aligned = heading != null && delta.abs() <= _alignTolerance;
              if (aligned && !_aligned) tick(true);
              _aligned = aligned;
              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('اتجاه القبلة', style: NoorText.h1(context)),
                        const SizedBox(height: 8),
                        Align(alignment: AlignmentDirectional.centerStart, child: LocationPill(onTap: () => showLocationSheet(context))),
                      ]),
                    ),
                    GlassIconButton(
                      icon: _map ? PhosphorIconsRegular.compass : PhosphorIconsRegular.mapTrifold,
                      active: _map,
                      onTap: () => setState(() => _map = !_map),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _status(context, heading, delta, aligned, qibla),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    child: _map
                        ? _QiblaMap(key: const ValueKey('map'), loc: l)
                        : _Compass(key: const ValueKey('compass'), heading: heading ?? 0, qibla: qibla, aligned: aligned, live: heading != null),
                  ),
                  const SizedBox(height: 18),
                  Glass(
                    radius: 24,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(children: [
                      Expanded(child: StatBlock(value: '${qibla.toStringAsFixed(1)}°', label: 'زاوية القبلة من الشمال', icon: PhosphorIconsRegular.navigationArrow)),
                      Container(width: 1, height: 44, color: p.hairline),
                      Expanded(child: StatBlock(value: Fmt.distanceKm(dist), label: 'المسافة إلى الكعبة', icon: PhosphorIconsRegular.path, color: p.gold)),
                      Container(width: 1, height: 44, color: p.hairline),
                      Expanded(
                        child: StatBlock(
                          value: heading == null ? '--' : '${heading.round() % 360}°',
                          label: 'اتجاه جهازك',
                          icon: PhosphorIconsRegular.compass,
                          color: aligned ? p.gold : p.textSoft,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _hint(context, l),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context, double? heading, double delta, bool aligned, double qibla) {
    final p = context.noor;
    final String text;
    final IconData icon;
    if (_noSensor && heading == null) {
      text = 'لا يتوفر مستشعر بوصلة. القبلة على ${qibla.round()}° من الشمال الجغرافي.';
      icon = PhosphorIconsRegular.info;
    } else if (heading == null) {
      text = 'جارٍ قراءة البوصلة…';
      icon = PhosphorIconsRegular.compass;
    } else if (aligned) {
      text = 'أنت تواجه القبلة الآن';
      icon = PhosphorIconsFill.checkCircle;
    } else {
      text = delta > 0 ? 'استدر يمينًا ${delta.abs().round()}°' : 'استدر يسارًا ${delta.abs().round()}°';
      icon = delta > 0 ? PhosphorIconsRegular.arrowClockwise : PhosphorIconsRegular.arrowCounterClockwise;
    }
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: aligned ? p.gold.withValues(alpha: p.isDark ? 0.22 : 0.18) : p.glass,
          border: Border.all(color: aligned ? p.gold : p.glassBorder.withValues(alpha: 0.6)),
          boxShadow: aligned ? [BoxShadow(color: p.gold.withValues(alpha: 0.35), blurRadius: 20)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 19, color: aligned ? p.gold : p.text),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center, style: NoorText.h3(context).copyWith(fontSize: 15, color: aligned ? p.gold : p.text)),
          ),
        ]),
      ),
    );
  }

  Widget _hint(BuildContext context, UserLocation l) {
    final p = context.noor;
    final decl = MagneticModel.declination(l.lat, l.lng);
    final poor = !DemoMode.on && (_accuracy == null || _accuracy! >= 30);
    final lines = <String>[
      if (poor && !_noSensor) 'لتحسين الدقة: حرّك الهاتف في الهواء على شكل الرقم 8 عدة مرات.',
      'ضع الهاتف أفقيًا وابتعد عن المعادن والأجهزة الكهربائية والمغناطيس.',
      'الانحراف المغناطيسي هنا ${decl.abs().toStringAsFixed(1)}° ${decl >= 0 ? 'شرقًا' : 'غربًا'} (نموذج WMM2025)${_needsDeclination ? '، ويُصحَّح تلقائيًا' : ''}.',
    ];
    return Glass(
      radius: 22,
      shadow: false,
      tint: poor && !_noSensor ? p.gold : null,
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(poor && !_noSensor ? PhosphorIconsRegular.warningCircle : PhosphorIconsRegular.info, size: 20, color: poor && !_noSensor ? p.gold : p.textSoft),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final s in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(s, style: NoorText.caption(context).copyWith(color: p.textSoft, fontSize: 12))),
          ]),
        ),
      ]),
    );
  }
}

class _Compass extends StatelessWidget {
  const _Compass({super.key, required this.heading, required this.qibla, required this.aligned, required this.live});
  final double heading;
  final double qibla;
  final bool aligned;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    double rad(double d) => d * math.pi / 180;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, c) {
        final size = c.maxWidth;
        final marker = size * 0.15;
        return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            width: size * 0.96,
            height: size * 0.96,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(
                color: (aligned ? p.gold : p.accent).withValues(alpha: aligned ? (p.isDark ? 0.55 : 0.45) : (p.isDark ? 0.18 : 0.14)),
                blurRadius: aligned ? 70 : 50,
                spreadRadius: aligned ? 4 : -6,
              ),
            ]),
          ),
          Glass(
            radius: size / 2,
            strong: true,
            padding: EdgeInsets.zero,
            width: size * 0.96,
            height: size * 0.96,
            tint: aligned ? p.gold : null,
            child: const SizedBox(),
          ),
          // Rotating rose + Kaaba marker riding the rim at the qibla bearing.
          Transform.rotate(
            angle: -rad(heading),
            child: SizedBox(
              width: size * 0.96,
              height: size * 0.96,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: CustomPaint(painter: CompassDialPainter(p: p, qibla: qibla, aligned: aligned))),
                Positioned.fill(
                  child: Transform.rotate(
                    angle: rad(qibla),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Transform.translate(
                        offset: Offset(0, -marker * 0.15),
                        child: Transform.rotate(
                          angle: -rad(qibla) + rad(heading),
                          child: Container(
                            width: marker,
                            height: marker,
                            padding: EdgeInsets.all(marker * 0.14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.isDark ? const Color(0xE61A2032) : Colors.white,
                              border: Border.all(color: p.gold, width: 2),
                              boxShadow: [BoxShadow(color: p.gold.withValues(alpha: aligned ? 0.7 : 0.35), blurRadius: aligned ? 22 : 12)],
                            ),
                            child: Image.asset('assets/images/kaaba.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          // Qibla needle.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: live ? 1 : 0.35,
            child: Transform.rotate(
              angle: rad(qibla - heading),
              child: SizedBox(
                width: size * 0.96,
                height: size * 0.96,
                child: CustomPaint(painter: NeedlePainter(color: aligned ? p.gold : p.accent, tail: p.textFaint.withValues(alpha: 0.5))),
              ),
            ),
          ),
          // Hub.
          Container(
            width: size * 0.16,
            height: size * 0.16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.isDark ? const Color(0xFF1B2133) : Colors.white,
              border: Border.all(color: aligned ? p.gold : p.glassBorder, width: 1.5),
              boxShadow: [BoxShadow(color: p.shadow, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: Icon(PhosphorIconsFill.starAndCrescent, size: size * 0.065, color: aligned ? p.gold : p.accent)),
          ),
          // Fixed lubber line: the direction the phone's top points to.
          Positioned(top: size * 0.005, child: SizedBox(width: 40, height: 18, child: CustomPaint(painter: LubberPainter(aligned ? p.gold : p.text)))),
        ]);
      }),
    );
  }
}

class _QiblaMap extends StatelessWidget {
  const _QiblaMap({super.key, required this.loc});
  final UserLocation loc;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final user = LatLng(loc.lat, loc.lng);
    const kaaba = LatLng(PrayerCalc.kaabaLat, PrayerCalc.kaabaLng);
    // Unwrap longitudes so the path never jumps across the antimeridian.
    final pts = <LatLng>[];
    double? prev;
    for (final (la, lo) in PrayerCalc.greatCircle(loc.lat, loc.lng)) {
      var x = lo;
      if (prev != null) {
        while (x - prev > 180) {
          x -= 360;
        }
        while (x - prev < -180) {
          x += 360;
        }
      }
      prev = x;
      pts.add(LatLng(la, x));
    }
    final near = PrayerCalc.distanceToKaabaKm(loc.lat, loc.lng) < 1;
    return AspectRatio(
      aspectRatio: 0.92,
      child: Glass(
        radius: 30,
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: user,
                initialZoom: near ? 15 : 3,
                initialCameraFit: near ? null : CameraFit.coordinates(coordinates: [user, pts.last], padding: const EdgeInsets.all(48), maxZoom: 12),
                backgroundColor: p.bgBottom,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                noorTileLayer(context),
                PolylineLayer(polylines: [
                  Polyline(points: pts, strokeWidth: 7, color: p.gold.withValues(alpha: 0.25)),
                  Polyline(points: pts, strokeWidth: 3, color: p.gold, pattern: const StrokePattern.dotted(spacingFactor: 2)),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: user,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.accent,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.6), blurRadius: 14)],
                      ),
                    ),
                  ),
                  Marker(
                    point: near ? kaaba : pts.last,
                    width: 46,
                    height: 46,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.isDark ? const Color(0xE61A2032) : Colors.white,
                        border: Border.all(color: p.gold, width: 2),
                        boxShadow: [BoxShadow(color: p.gold.withValues(alpha: 0.5), blurRadius: 16)],
                      ),
                      child: Image.asset('assets/images/kaaba.png'),
                    ),
                  ),
                ]),
              ],
            ),
            noorMapAttribution(context),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Glass(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text('أقصر مسار إلى الكعبة (دائرة عظمى)', style: NoorText.caption(context).copyWith(color: p.text)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
