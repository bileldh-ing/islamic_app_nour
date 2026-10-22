import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';

/// Location picker: GPS refresh, city search (OSM Nominatim) and manual coordinates.
Future<void> showLocationSheet(BuildContext context) =>
    showGlassSheet<void>(context, title: 'الموقع', builder: (_) => const _LocationSheet());

class _LocationSheet extends StatefulWidget {
  const _LocationSheet();
  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _q = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  Timer? _debounce;
  List<UserLocation> _results = const [];
  bool _searching = false;
  String? _error;
  bool _manual = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(v));
  }

  Future<void> _search(String v) async {
    if (v.trim().length < 2) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r = await LocationService.searchCities(v);
      if (!mounted) return;
      setState(() {
        _results = r;
        _error = r.isEmpty ? 'لا توجد نتائج لهذا الاسم.' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر البحث. تحقّق من اتصالك بالإنترنت.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pick(UserLocation l) async {
    await LocationService.setManual(l);
    NotificationService.rescheduleAll();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _gps() async {
    final before = LocationService.current.value;
    final l = await LocationService.refresh();
    if (!mounted) return;
    if (LocationService.error.value == null && l != null && !identical(l, before)) {
      NotificationService.rescheduleAll();
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  Future<void> _saveManual() async {
    final la = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lo = double.tryParse(_lng.text.trim().replaceAll(',', '.'));
    if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) {
      setState(() => _error = 'أدخل إحداثيات صحيحة: خط العرض بين -90 و 90 وخط الطول بين -180 و 180.');
      return;
    }
    final r = await LocationService.reverse(la, lo);
    await _pick(UserLocation(
      lat: la,
      lng: lo,
      city: r != null && r.city.isNotEmpty ? r.city : '${la.toStringAsFixed(3)}, ${lo.toStringAsFixed(3)}',
      country: r?.country ?? '',
      countryCode: r?.countryCode ?? '',
      manual: true,
    ));
  }

  InputDecoration _dec(BuildContext context, String hint, IconData icon) {
    final p = context.noor;
    return InputDecoration(
      hintText: hint,
      hintStyle: NoorText.body(context).copyWith(color: p.textFaint),
      prefixIcon: Icon(icon, size: 20, color: p.textSoft),
      filled: true,
      fillColor: p.glass,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.glassBorder.withValues(alpha: 0.6))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.accent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final cur = LocationService.current.value;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (cur != null)
          GlassTile(
            icon: PhosphorIconsFill.mapPin,
            title: cur.city,
            subtitle: [if (cur.country.isNotEmpty) cur.country, '${cur.lat.toStringAsFixed(4)}, ${cur.lng.toStringAsFixed(4)}'].join(' · '),
            trailing: const SizedBox(),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: LocationService.busy,
          builder: (context, busy, _) => GlassTile(
            icon: PhosphorIconsRegular.gpsFix,
            title: busy ? 'جارٍ تحديد موقعك…' : 'استخدام موقعي الحالي (GPS)',
            subtitle: 'الأدق لحساب أوقات الصلاة واتجاه القبلة',
            onTap: busy ? null : _gps,
            trailing: busy ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)) : null,
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: LocationService.error,
          builder: (context, e, _) => e == null
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(PhosphorIconsRegular.warningCircle, size: 16, color: p.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e, style: NoorText.caption(context).copyWith(color: p.danger))),
                  ]),
                ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _q,
          onChanged: _onQuery,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          style: NoorText.body(context).copyWith(color: p.text),
          decoration: _dec(context, 'ابحث عن مدينة… (تونس، القاهرة، London)', PhosphorIconsRegular.magnifyingGlass),
        ),
        const SizedBox(height: 10),
        if (_searching)
          Padding(padding: const EdgeInsets.all(18), child: Center(child: CircularProgressIndicator(color: p.accent, strokeWidth: 2.4)))
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(_error!, style: NoorText.caption(context).copyWith(color: p.danger), textAlign: TextAlign.center),
          )
        else
          for (final r in _results)
            GlassTile(
              icon: PhosphorIconsRegular.mapPinLine,
              iconColor: p.textSoft,
              title: r.city,
              subtitle: [if (r.country.isNotEmpty) r.country, '${r.lat.toStringAsFixed(3)}, ${r.lng.toStringAsFixed(3)}'].join(' · '),
              onTap: () => _pick(r),
            ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text('بيانات المدن © مساهمو OpenStreetMap', style: NoorText.caption(context), textAlign: TextAlign.center),
          ),
        const SizedBox(height: 6),
        GlassTile(
          icon: PhosphorIconsRegular.crosshair,
          iconColor: p.gold,
          title: 'إدخال الإحداثيات يدويًا',
          subtitle: 'للاستخدام دون اتصال',
          onTap: () => setState(() => _manual = !_manual),
          trailing: Icon(_manual ? PhosphorIconsRegular.caretDown : PhosphorIconsRegular.caretLeft, size: 18, color: p.textFaint),
        ),
        if (_manual) ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                textDirection: TextDirection.ltr,
                style: NoorText.number(context, size: 15),
                decoration: _dec(context, 'خط العرض', PhosphorIconsRegular.globe),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _lng,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                textDirection: TextDirection.ltr,
                style: NoorText.number(context, size: 15),
                decoration: _dec(context, 'خط الطول', PhosphorIconsRegular.globeHemisphereEast),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          NoorButton(label: 'حفظ الموقع', icon: PhosphorIconsRegular.check, expand: true, onTap: () => _saveManual()),
        ],
      ],
    );
  }
}
