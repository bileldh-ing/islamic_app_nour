import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';
import '../../services/prayer_calc.dart';
import '../../services/prayer_service.dart';
import '../../services/storage.dart';
import 'adhan_settings_screen.dart';
import 'location_sheet.dart';
import 'prayer_widgets.dart';

/// Calculation method (with country auto-select), Asr madhab, high-latitude rule and per-prayer minute adjustments.
class PrayerSettingsScreen extends StatelessWidget {
  const PrayerSettingsScreen({super.key});

  static Future<void> _save(AppSettings s) async {
    await Store.saveSettings(s);
    await NotificationService.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    return PrayerDataBuilder(builder: (context, loc, s) {
      final p = context.noor;
      final effective = PrayerCalc.method(PrayerService.effectiveMethod(s, loc));
      final countryDefault = loc.isoCode.isEmpty ? null : PrayerCalc.method(PrayerCalc.defaultMethodFor(loc.isoCode));
      final today = PrayerService.forDate(DateTime.now(), loc: loc, settings: s);
      return NoorPage(
        title: 'إعدادات المواقيت',
        subtitle: loc.city,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GlassTile(
            icon: PhosphorIconsFill.mapPin,
            title: loc.city,
            subtitle: loc.country.isEmpty ? 'تغيير الموقع' : loc.country,
            onTap: () => showLocationSheet(context),
          ),
          // Live preview of today's times with the current settings.
          Glass(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Row(children: [
              for (final e in today.entries)
                Expanded(
                  child: Column(children: [
                    Icon(prayerIcon(e.name), size: 18, color: e.name.isFard ? p.accent : p.gold),
                    const SizedBox(height: 4),
                    Text(e.name.ar, style: NoorText.caption(context)),
                    Text(Fmt.time(e.time), style: NoorText.number(context, size: 14)),
                  ]),
                ),
            ]),
          ),
          SectionHeader('طريقة الحساب', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
          _MethodTile(
            title: 'تلقائي حسب البلد',
            subtitle: countryDefault == null ? 'لم يُحدَّد البلد — تُستخدم الطريقة المختارة' : 'حاليًا: ${countryDefault.name}',
            selected: s.methodAuto,
            icon: PhosphorIconsRegular.globeHemisphereEast,
            onTap: () => _save(s.copyWith(methodAuto: true)),
          ),
          for (final m in PrayerCalc.methods)
            _MethodTile(
              title: m.name,
              subtitle: m.detail,
              selected: !s.methodAuto && s.method == m.id,
              onTap: () => _save(s.copyWith(method: m.id, methodAuto: false)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Text('المستخدمة الآن: ${effective.name}. يمكنك مطابقة توقيت مسجدك بالتعديل اليدوي أدناه.', style: NoorText.caption(context)),
          ),
          SectionHeader('صلاة العصر', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
          _Segmented(
            labels: const ['الجمهور (الشافعي، المالكي، الحنبلي)', 'الحنفي'],
            index: s.madhab == 'hanafi' ? 1 : 0,
            onChanged: (i) => _save(s.copyWith(madhab: i == 1 ? 'hanafi' : 'shafi')),
          ),
          SectionHeader('خطوط العرض العليا', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
          for (final r in const [
            ('middleOfTheNight', 'منتصف الليل', 'لا يتأخر العشاء ولا يتقدم الفجر عن منتصف الليل'),
            ('seventhOfTheNight', 'سُبع الليل', 'حدّ العشاء بعد مضي سُبع الليل وحدّ الفجر عند بدء سُبعه الأخير'),
            ('twilightAngle', 'زاوية الشفق', 'جزء من الليل يتناسب مع زاوية الشفق'),
          ])
            _MethodTile(
              title: r.$2,
              subtitle: r.$3,
              selected: s.highLatitude == r.$1,
              onTap: () => _save(s.copyWith(highLatitude: r.$1)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Text('تُطبَّق عند خطوط العرض العالية حين لا يغيب الشفق صيفًا (مثل شمال أوروبا).', style: NoorText.caption(context)),
          ),
          SectionHeader('تعديل يدوي (دقائق)', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
          Glass(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              for (final n in PrayerName.values) _AdjustRow(name: n, settings: s, onSave: _save),
            ]),
          ),
          if (s.adjustments.values.any((v) => v != 0))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: NoorButton(
                label: 'إعادة التعديلات إلى الصفر',
                icon: PhosphorIconsRegular.arrowCounterClockwise,
                secondary: true,
                onTap: () => _save(s.copyWith(adjustments: const {})),
              ),
            ),
          const SizedBox(height: 16),
          GlassTile(
            icon: PhosphorIconsRegular.speakerHigh,
            title: 'الأذان والتنبيهات',
            subtitle: 'صوت الأذان والتذكير قبل الصلاة',
            onTap: () => push(context, const AdhanSettingsScreen()),
          ),
        ]),
      );
    });
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.title, required this.subtitle, required this.selected, required this.onTap, this.icon});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Glass(
      margin: const EdgeInsets.only(bottom: 8),
      radius: 18,
      shadow: false,
      tint: selected ? p.accent : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 20, color: selected ? p.accent : p.textSoft), const SizedBox(width: 10)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: NoorText.h3(context).copyWith(fontSize: 14.5)),
            Text(subtitle, style: NoorText.caption(context)),
          ]),
        ),
        Icon(selected ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle, size: 22, color: selected ? p.accent : p.textFaint),
      ]),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Glass(
      radius: 20,
      padding: const EdgeInsets.all(5),
      shadow: false,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Pressable(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                decoration: BoxDecoration(
                  color: i == index ? p.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(labels[i],
                    textAlign: TextAlign.center,
                    style: NoorText.label(context).copyWith(color: i == index ? p.onAccent : p.textSoft, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _AdjustRow extends StatelessWidget {
  const _AdjustRow({required this.name, required this.settings, required this.onSave});
  final PrayerName name;
  final AppSettings settings;
  final Future<void> Function(AppSettings) onSave;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final v = settings.adjustments[name.name] ?? 0;
    void set(int nv) {
      final m = Map<String, int>.from(settings.adjustments)..[name.name] = nv.clamp(-30, 30);
      onSave(settings.copyWith(adjustments: m));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(prayerIcon(name), size: 18, color: p.textSoft),
        const SizedBox(width: 10),
        Expanded(child: Text(name.ar, style: NoorText.h3(context).copyWith(fontSize: 14.5))),
        GlassIconButton(icon: PhosphorIconsRegular.minus, size: 34, onTap: () => set(v - 1)),
        SizedBox(
          width: 54,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(v == 0 ? '0' : (v > 0 ? '+$v' : '$v'),
                textAlign: TextAlign.center, style: NoorText.number(context, size: 16).copyWith(color: v == 0 ? p.textFaint : p.accent)),
          ),
        ),
        GlassIconButton(icon: PhosphorIconsRegular.plus, size: 34, onTap: () => set(v + 1)),
      ]),
    );
  }
}
