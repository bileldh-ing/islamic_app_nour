import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;

import '../services/location_service.dart';
import '../services/prayer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  double _smooth = 0;
  bool _aligned = false;
  bool _noSensor = false;

  static const kaaba = LatLng(21.4225241, 39.8261818);

  @override
  void initState() {
    super.initState();
    final events = FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
    } else {
      _sub = events.listen((e) {
        final h = e.heading;
        if (h == null) {
          setState(() => _noSensor = true);
          return;
        }
        // Low-pass filter on the shortest angular path to remove jitter.
        final target = (h + 360) % 360;
        var diff = target - _smooth;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        _smooth = (_smooth + diff * 0.18 + 360) % 360;
        setState(() => _heading = _smooth);
      }, onError: (_) {
        if (mounted) setState(() => _noSensor = true);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LocationService.current,
      builder: (context, loc, _) {
        final l = loc ?? UserLocation.makkah;
        final qibla = PrayerService.qibla(l);
        final distKm = const Distance().as(LengthUnit.Kilometer, LatLng(l.lat, l.lng), kaaba);
        final heading = _heading ?? 0;
        var delta = (qibla - heading + 540) % 360 - 180;
        final aligned = _heading != null && delta.abs() < 3;
        if (aligned && !_aligned) HapticFeedback.heavyImpact();
        _aligned = aligned;

        return SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
            children: [
              const GlassHeader(title: 'القبلة', showBack: false),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    child: SizedBox(height: 170, child: _map(LatLng(l.lat, l.lng))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      _stat('${toArabicDigits(distKm.round())} كم', 'المسافة إلى مكة'),
                      Container(width: 1, height: 34, color: Colors.white12),
                      _stat('${toArabicDigits(qibla.toStringAsFixed(1))}°', 'زاوية القبلة'),
                      Container(width: 1, height: 34, color: Colors.white12),
                      _stat(_heading == null ? '—' : '${toArabicDigits(heading.round())}°', 'اتجاه جهازك'),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: aligned ? AppColors.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: aligned ? AppColors.gold : Colors.white24),
                ),
                child: Text(
                  _noSensor
                      ? 'لا يوجد مستشعر بوصلة في هذا الجهاز. اتجاه القبلة ${toArabicDigits(qibla.round())}° من الشمال.'
                      : aligned
                          ? 'أنت تواجه القبلة الآن ✓'
                          : delta > 0
                              ? 'استدر إلى اليمين ${toArabicDigits(delta.abs().round())}°'
                              : 'استدر إلى اليسار ${toArabicDigits(delta.abs().round())}°',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: aligned ? AppColors.gold : AppColors.ivory),
                ),
              ),
              const SizedBox(height: 22),
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(builder: (context, c) {
                  final size = c.maxWidth;
                  return Stack(alignment: Alignment.center, children: [
                    // Glow when aligned
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                        BoxShadow(
                            color: (aligned ? AppColors.gold : AppColors.aqua).withValues(alpha: aligned ? 0.45 : 0.15),
                            blurRadius: 60,
                            spreadRadius: -10),
                      ]),
                    ),
                    GlassCard(
                      radius: size / 2,
                      padding: EdgeInsets.zero,
                      borderGold: aligned,
                      child: SizedBox(width: size, height: size),
                    ),
                    // Rotating dial
                    Transform.rotate(
                      angle: -heading * math.pi / 180,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(painter: _DialPainter()),
                      ),
                    ),
                    // Kaaba marker riding the dial at the qibla bearing
                    Transform.rotate(
                      angle: (qibla - heading) * math.pi / 180,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: size * 0.02),
                            child: Transform.rotate(
                              angle: -(qibla - heading) * math.pi / 180,
                              child: Container(
                                width: size * 0.17,
                                height: size * 0.17,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.midnight.withValues(alpha: 0.7),
                                  border: Border.all(color: AppColors.gold, width: 2),
                                  boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 18)],
                                ),
                                child: Image.asset('assets/images/kaaba.png'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Qibla needle (fixed relative to dial)
                    Transform.rotate(
                      angle: (qibla - heading) * math.pi / 180,
                      child: SizedBox(
                        width: size * 0.62,
                        height: size * 0.62,
                        child: CustomPaint(painter: _NeedlePainter(aligned: aligned)),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
                      ),
                    ),
                    // Fixed top indicator (where the phone points)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Transform.translate(
                        offset: const Offset(0, -14),
                        child: Icon(Icons.arrow_drop_down_rounded, size: 40, color: aligned ? AppColors.gold : AppColors.ivory),
                      ),
                    ),
                  ]);
                }),
              ),
              const SizedBox(height: 22),
              const GlassCard(
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.aqua),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لأفضل دقة: ضع الهاتف بشكل أفقي، وابتعد عن المعادن والأجهزة الكهربائية، وحرّك الهاتف على شكل الرقم ٨ لمعايرة البوصلة.',
                      style: TextStyle(color: AppColors.textSoft, height: 1.6, fontSize: 13.5),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.gold)),
          const SizedBox(height: 2),
          Text(l, style: const TextStyle(color: AppColors.textSoft, fontSize: 11.5)),
        ]),
      );

  Widget _map(LatLng me) => FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([me, kaaba]),
            padding: const EdgeInsets.all(36),
          ),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.noor.noor',
            retinaMode: true,
          ),
          PolylineLayer(polylines: [
            Polyline(
              points: [me, kaaba],
              color: AppColors.gold,
              strokeWidth: 3,
              pattern: const StrokePattern.dotted(spacingFactor: 2),
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: me,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.aqua,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
            Marker(point: kaaba, width: 36, height: 36, child: Image.asset('assets/images/kaaba.png')),
          ]),
          const SimpleAttributionWidget(source: Text('© OpenStreetMap · CARTO', style: TextStyle(fontSize: 9))),
        ],
      );
}

class _DialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 360; i += 3) {
      final major = i % 30 == 0;
      final a = i * math.pi / 180;
      final r1 = r * (major ? 0.80 : 0.85);
      final r2 = r * 0.90;
      tick
        ..color = i == 0 ? AppColors.danger : (major ? AppColors.ivory : Colors.white30)
        ..strokeWidth = major ? 2.4 : 1.2;
      canvas.drawLine(
        c + Offset(math.sin(a) * r1, -math.cos(a) * r1),
        c + Offset(math.sin(a) * r2, -math.cos(a) * r2),
        tick,
      );
    }
    const labels = {0: 'شمال', 90: 'شرق', 180: 'جنوب', 270: 'غرب'};
    labels.forEach((deg, txt) {
      final a = deg * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(
          text: txt,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: r * 0.075,
            fontWeight: FontWeight.w800,
            color: deg == 0 ? AppColors.danger : AppColors.ivory,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      final p = c + Offset(math.sin(a) * r * 0.66, -math.cos(a) * r * 0.66);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    });
    // Inner ring
    canvas.drawCircle(
      c,
      r * 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white12,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NeedlePainter extends CustomPainter {
  _NeedlePainter({required this.aligned});
  final bool aligned;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final h = s.height / 2;
    final w = s.width * 0.07;
    final up = Path()
      ..moveTo(c.dx, c.dy - h)
      ..lineTo(c.dx + w, c.dy)
      ..lineTo(c.dx - w, c.dy)
      ..close();
    final down = Path()
      ..moveTo(c.dx, c.dy + h * 0.7)
      ..lineTo(c.dx + w, c.dy)
      ..lineTo(c.dx - w, c.dy)
      ..close();
    canvas.drawShadow(up, Colors.black, 6, false);
    canvas.drawPath(
      up,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: aligned ? [const Color(0xFFFFE6A8), AppColors.gold] : [AppColors.aqua, AppColors.emerald],
        ).createShader(Rect.fromLTWH(0, 0, s.width, s.height)),
    );
    canvas.drawPath(down, Paint()..color = Colors.white24);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter old) => old.aligned != aligned;
}
