import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';
import '../../services/prayer_service.dart';
import '../../services/storage.dart';
import 'prayer_widgets.dart';

/// Per-prayer alert mode (off / notification / adhan), pre-reminder, adhan test and worship reminders.
class AdhanSettingsScreen extends StatelessWidget {
  const AdhanSettingsScreen({super.key});

  static Future<void> _save(AppSettings s) async {
    await Store.saveSettings(s);
    await NotificationService.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: Store.settings,
      builder: (context, s, _) {
        final p = context.noor;
        return NoorPage(
          title: 'الأذان والتنبيهات',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!NotificationService.supported)
              Glass(
                margin: const EdgeInsets.only(bottom: 12),
                radius: 20,
                tint: p.gold,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(PhosphorIconsRegular.info, color: p.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('التنبيهات والأذان تعمل في تطبيق الهاتف (Android و iOS). تُحفظ اختياراتك هنا.', style: NoorText.caption(context).copyWith(color: p.text))),
                ]),
              ),
            Glass(
              radius: 26,
              strong: true,
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                IconBadge(PhosphorIconsFill.speakerHigh, size: 52, color: p.gold),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('صوت الأذان', style: NoorText.h3(context)),
                    Text('أذان كامل عند دخول الوقت للصلوات المختارة', style: NoorText.caption(context)),
                  ]),
                ),
                Switch(
                  value: s.adhanSound,
                  onChanged: (v) {
                    final modes = Map<String, String>.from(s.alertModes);
                    if (!v) {
                      modes.updateAll((k, m) => m == AlertMode.adhan.name ? AlertMode.notify.name : m);
                    }
                    _save(s.copyWith(adhanSound: v, alertModes: modes));
                  },
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: NoorButton(
                  label: 'تجربة الأذان',
                  icon: PhosphorIconsRegular.play,
                  onTap: () async {
                    final ok = await NotificationService.testAdhan(mode: s.adhanSound ? AlertMode.adhan : AlertMode.notify);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'تم إرسال تنبيه تجريبي' : 'التجربة متاحة في تطبيق الهاتف فقط'),
                    ));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NoorButton(
                  label: 'السماح بالتنبيهات',
                  icon: PhosphorIconsRegular.bellRinging,
                  secondary: true,
                  onTap: () async {
                    final ok = await NotificationService.requestPermissions();
                    await NotificationService.rescheduleAll();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'تم تفعيل التنبيهات' : 'لم يُمنح الإذن. فعّله من إعدادات الجهاز.'),
                    ));
                  },
                ),
              ),
            ]),
            SectionHeader('تنبيه كل صلاة', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
            for (final n in PrayerName.values) _ModeRow(name: n, mode: NotificationService.modeOf(n, s), adhanAllowed: s.adhanSound),
            SectionHeader('التذكير قبل الصلاة', padding: const EdgeInsets.fromLTRB(4, 18, 4, 10)),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in const [0, 5, 10, 15, 20, 30])
                GlassChip(
                  label: m == 0 ? 'بدون' : '$m د',
                  selected: s.preReminderMinutes == m,
                  onTap: () => _save(s.copyWith(preReminderMinutes: m)),
                ),
            ]),
            SectionHeader('تذكيرات العبادة', padding: const EdgeInsets.fromLTRB(4, 24, 4, 10)),
            _Toggle(
              icon: PhosphorIconsRegular.sunHorizon,
              title: 'أذكار الصباح',
              subtitle: 'بعد الفجر بـ ${s.morningAzkarTime} دقيقة',
              value: s.morningAzkar,
              onChanged: (v) => _save(s.copyWith(morningAzkar: v)),
              offsets: (s.morningAzkarTime, (m) => _save(s.copyWith(morningAzkarTime: m))),
            ),
            _Toggle(
              icon: PhosphorIconsRegular.moon,
              title: 'أذكار المساء',
              subtitle: 'بعد العصر بـ ${s.eveningAzkarTime} دقيقة',
              value: s.eveningAzkar,
              onChanged: (v) => _save(s.copyWith(eveningAzkar: v)),
              offsets: (s.eveningAzkarTime, (m) => _save(s.copyWith(eveningAzkarTime: m))),
            ),
            _Toggle(
              icon: PhosphorIconsRegular.moonStars,
              title: 'أذكار النوم',
              subtitle: 'يوميًا 22:30',
              value: s.sleepAzkar,
              onChanged: (v) => _save(s.copyWith(sleepAzkar: v)),
            ),
            _Toggle(
              icon: PhosphorIconsRegular.bookOpenText,
              title: 'سورة الكهف',
              subtitle: 'الجمعة 10:00',
              value: s.kahfFriday,
              onChanged: (v) => _save(s.copyWith(kahfFriday: v)),
            ),
            _Toggle(
              icon: PhosphorIconsRegular.sparkle,
              title: 'الصلاة على النبي ﷺ',
              subtitle: 'ليلة الجمعة بعد المغرب، ويوم الجمعة قبل الصلاة',
              value: s.salawatFriday,
              onChanged: (v) => _save(s.copyWith(salawatFriday: v)),
            ),
            _Toggle(
              icon: PhosphorIconsRegular.calendarCheck,
              title: 'صيام السنة',
              subtitle: 'مساء الأحد والأربعاء، وقبل عرفة وتاسوعاء وعاشوراء (21:00)',
              value: s.fastingReminders,
              onChanged: (v) => _save(s.copyWith(fastingReminders: v)),
            ),
            _Toggle(
              icon: PhosphorIconsRegular.moon,
              title: 'الأيام البيض',
              subtitle: 'مساء 12 من كل شهر هجري',
              value: s.whiteDaysReminder,
              onChanged: (v) => _save(s.copyWith(whiteDaysReminder: v)),
            ),
            _Toggle(
              icon: PhosphorIconsRegular.bookOpen,
              title: 'آية اليوم',
              subtitle: 'يوميًا 08:00',
              value: s.dailyAyah,
              onChanged: (v) => _save(s.copyWith(dailyAyah: v)),
            ),
            _Toggle(
              icon: PhosphorIconsRegular.circlesFour,
              title: 'تذكير التسبيح',
              subtitle: 'يوميًا 20:00',
              value: s.tasbihReminder,
              onChanged: (v) => _save(s.copyWith(tasbihReminder: v)),
            ),
            const SizedBox(height: 8),
            Text('تُجدول التنبيهات للأيام الخمسة القادمة وتتجدد تلقائيًا عند فتح التطبيق.', style: NoorText.caption(context), textAlign: TextAlign.center),
          ]),
        );
      },
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.name, required this.mode, required this.adhanAllowed});
  final PrayerName name;
  final AlertMode mode;
  final bool adhanAllowed;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final modes = [AlertMode.off, AlertMode.notify, if (name.isFard) AlertMode.adhan];
    return Glass(
      margin: const EdgeInsets.only(bottom: 8),
      radius: 20,
      shadow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
      child: Row(children: [
        Icon(prayerIcon(name), size: 20, color: name.isFard ? p.accent : p.gold),
        const SizedBox(width: 10),
        Expanded(child: Text(name.ar, style: NoorText.h3(context).copyWith(fontSize: 15))),
        for (final m in modes)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: Tooltip(
              message: alertLabel(m),
              child: Pressable(
                onTap: () async {
                  if (m == AlertMode.adhan && !adhanAllowed) {
                    await Store.saveSettings(Store.settings.value.copyWith(adhanSound: true));
                  }
                  await NotificationService.setMode(name, m);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 38,
                  decoration: BoxDecoration(
                    color: mode == m ? p.accent : p.glass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: mode == m ? p.accent : p.glassBorder.withValues(alpha: 0.5)),
                  ),
                  child: Icon(alertIcon(m), size: 19, color: mode == m ? p.onAccent : p.textSoft),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged, this.offsets});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final (int, ValueChanged<int>)? offsets;
  @override
  Widget build(BuildContext context) {
    return Glass(
      margin: const EdgeInsets.only(bottom: 8),
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(children: [
        Row(children: [
          IconBadge(icon, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: NoorText.h3(context).copyWith(fontSize: 14.5)),
              Text(subtitle, style: NoorText.caption(context)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
        if (offsets != null && value)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in const [15, 30, 45, 60, 90])
                GlassChip(label: '$m د', selected: offsets!.$1 == m, onTap: () => offsets!.$2(m)),
            ]),
          ),
      ]),
    );
  }
}
