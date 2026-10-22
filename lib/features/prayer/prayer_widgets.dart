import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/prayer_service.dart';
import '../../services/storage.dart';

/// Line icon for each prayer time.
IconData prayerIcon(PrayerName p, {bool fill = false}) => switch (p) {
      PrayerName.fajr => fill ? PhosphorIconsFill.cloudSun : PhosphorIconsRegular.cloudSun,
      PrayerName.sunrise => fill ? PhosphorIconsFill.sunHorizon : PhosphorIconsRegular.sunHorizon,
      PrayerName.dhuhr => fill ? PhosphorIconsFill.sun : PhosphorIconsRegular.sun,
      PrayerName.asr => fill ? PhosphorIconsFill.sunDim : PhosphorIconsRegular.sunDim,
      PrayerName.maghrib => fill ? PhosphorIconsFill.sunHorizon : PhosphorIconsRegular.sunHorizon,
      PrayerName.isha => fill ? PhosphorIconsFill.moonStars : PhosphorIconsRegular.moonStars,
    };

IconData alertIcon(AlertMode m) => switch (m) {
      AlertMode.off => PhosphorIconsRegular.bellSlash,
      AlertMode.notify => PhosphorIconsRegular.bell,
      AlertMode.adhan => PhosphorIconsRegular.speakerHigh,
    };

String alertLabel(AlertMode m) => switch (m) {
      AlertMode.off => 'بدون تنبيه',
      AlertMode.notify => 'إشعار',
      AlertMode.adhan => 'أذان',
    };

/// Rebuilds its child every [period] (default one second) — for countdowns.
class Ticker extends StatefulWidget {
  const Ticker({super.key, required this.builder, this.period = const Duration(seconds: 1)});
  final WidgetBuilder builder;
  final Duration period;
  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.period, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Rebuilds when the location or settings change.
class PrayerDataBuilder extends StatelessWidget {
  const PrayerDataBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, UserLocation loc, AppSettings settings) builder;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<UserLocation?>(
        valueListenable: LocationService.current,
        builder: (context, loc, _) => ValueListenableBuilder<AppSettings>(
          valueListenable: Store.settings,
          builder: (context, s, _) => builder(context, loc ?? UserLocation.makkah, s),
        ),
      );
}

/// Glass pill with the current city. Tap opens the location sheet (supplied by caller).
class LocationPill extends StatelessWidget {
  const LocationPill({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return ValueListenableBuilder<UserLocation?>(
      valueListenable: LocationService.current,
      builder: (context, loc, _) => Pressable(
        onTap: onTap,
        child: Glass(
          radius: 30,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIconsFill.mapPin, size: 16, color: p.accent),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                loc?.city.isNotEmpty == true ? loc!.city : 'حدّد موقعك',
                style: NoorText.label(context).copyWith(color: p.text, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(PhosphorIconsRegular.caretDown, size: 13, color: p.textFaint),
          ]),
        ),
      ),
    );
  }
}

/// Premium "next prayer" card with a live countdown and progress through the
/// current prayer window. Public so the Home screen can embed it
/// (`NextPrayerCard(compact: true, onTap: () => rootTab.value = 1)`).
class NextPrayerCard extends StatelessWidget {
  const NextPrayerCard({super.key, this.compact = false, this.onTap});
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PrayerDataBuilder(builder: (context, loc, s) {
      return Ticker(builder: (context) {
        final p = context.noor;
        final now = DateTime.now();
        final next = PrayerService.next(now);
        final cur = PrayerService.current(now);
        final remaining = next.time.difference(now);
        final start = cur?.time ?? now.subtract(const Duration(hours: 1));
        final span = next.time.difference(start).inSeconds;
        final progress = span <= 0 ? 0.0 : (now.difference(start).inSeconds / span).clamp(0.0, 1.0);
        final label = next.name.arOn(next.time);
        return Glass(
          onTap: onTap,
          strong: true,
          radius: 28,
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Stack(children: [
            PositionedDirectional(
              end: -18,
              top: -22,
              child: Icon(prayerIcon(next.name, fill: true), size: compact ? 96 : 130, color: p.accent.withValues(alpha: p.isDark ? 0.10 : 0.08)),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                  child: Text('الصلاة القادمة', style: NoorText.caption(context).copyWith(color: p.accent, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Icon(prayerIcon(next.name), size: 18, color: p.textSoft),
                const SizedBox(width: 6),
                Text(Fmt.timeFull(next.time), style: NoorText.number(context, size: 15).copyWith(color: p.textSoft)),
              ]),
              SizedBox(height: compact ? 8 : 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(label, style: NoorText.h1(context).copyWith(fontSize: compact ? 24 : 30)),
                const Spacer(),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(Fmt.countdown(remaining),
                      style: NoorText.number(context, size: compact ? 26 : 34, w: FontWeight.w600).copyWith(color: p.accent, letterSpacing: 0.5)),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(cur == null ? '' : 'وقت ${cur.name.arOn(cur.time)} منذ ${Fmt.durationShort(now.difference(cur.time))}',
                    style: NoorText.caption(context)),
                const Spacer(),
                Text('متبقٍّ', style: NoorText.caption(context)),
              ]),
              SizedBox(height: compact ? 10 : 14),
              GlassProgress(progress, height: 5),
            ]),
          ]),
        );
      });
    });
  }
}

/// One prayer time row: icon, name, time, alert toggle, done check.
class PrayerTimeRow extends StatelessWidget {
  const PrayerTimeRow({
    super.key,
    required this.entry,
    required this.day,
    required this.isCurrent,
    required this.isNext,
    required this.passed,
    required this.mode,
    required this.onAlert,
    this.done,
    this.onDone,
  });
  final PrayerEntry entry;
  final DateTime day;
  final bool isCurrent;
  final bool isNext;
  final bool passed;
  final AlertMode mode;
  final VoidCallback onAlert;
  final bool? done;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final highlight = isCurrent;
    final fg = passed && !highlight ? p.textSoft : p.text;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: highlight
          ? BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: [
              BoxShadow(color: p.accent.withValues(alpha: p.isDark ? 0.28 : 0.22), blurRadius: 24, spreadRadius: -6, offset: const Offset(0, 8)),
            ])
          : null,
      child: Glass(
        radius: 22,
        shadow: false,
        tint: highlight ? p.accent : null,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        child: Row(children: [
          IconBadge(prayerIcon(entry.name, fill: highlight), color: highlight ? p.accent : (entry.name.isFard ? p.textSoft : p.gold), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.name.arOn(day), style: NoorText.h3(context).copyWith(color: fg, fontSize: 16)),
              if (highlight || isNext)
                Text(highlight ? 'الوقت الحالي' : 'القادمة',
                    style: NoorText.caption(context).copyWith(color: highlight ? p.accent : p.textFaint, fontWeight: FontWeight.w600)),
            ]),
          ),
          Text(Fmt.time(entry.time), style: NoorText.number(context, size: 19).copyWith(color: fg)),
          if (Fmt.period(entry.time).isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(Fmt.period(entry.time), style: NoorText.caption(context)),
          ],
          const SizedBox(width: 4),
          _RoundAction(icon: alertIcon(mode), active: mode != AlertMode.off, onTap: onAlert, tooltip: alertLabel(mode)),
          if (onDone != null)
            _RoundAction(
              icon: done == true ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
              active: done == true,
              color: p.success,
              onTap: onDone!,
              tooltip: done == true ? 'تمت الصلاة' : 'لم تُسجَّل',
            )
          else
            const SizedBox(width: 40),
        ]),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.active, required this.onTap, required this.tooltip, this.color});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final c = color ?? p.accent;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
              child: Icon(icon, key: ValueKey(icon), size: 21, color: active ? c : p.textFaint),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small stat block used on several screens.
class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.value, required this.label, this.icon, this.color});
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 20, color: color ?? p.accent), const SizedBox(height: 6)],
      Directionality(
        textDirection: TextDirection.ltr,
        child: Text(value, style: NoorText.number(context, size: 20, w: FontWeight.w700).copyWith(color: color ?? p.text)),
      ),
      const SizedBox(height: 2),
      Text(label, style: NoorText.caption(context), textAlign: TextAlign.center),
    ]);
  }
}
