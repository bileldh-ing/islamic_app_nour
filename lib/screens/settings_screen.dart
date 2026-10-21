import 'package:flutter/material.dart';

import '../services/hijri_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../services/quran_service.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _save(AppSettings s) async {
    await Store.saveSettings(s);
    await NotificationService.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder(
        valueListenable: Store.settings,
        builder: (context, s, _) => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
          children: [
            const GlassHeader(title: 'الإعدادات', showBack: false),
            const SectionTitle('الموقع'),
            ValueListenableBuilder(
              valueListenable: LocationService.current,
              builder: (context, loc, _) => GlassCard(
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(loc?.city ?? 'غير محدد', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        if (loc != null)
                          Text('${loc.lat.toStringAsFixed(4)}، ${loc.lng.toStringAsFixed(4)}',
                              style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GoldButton(
                        label: 'تحديد تلقائي',
                        icon: Icons.my_location_rounded,
                        onTap: () async {
                          await LocationService.refresh();
                          await NotificationService.rescheduleAll();
                          final err = LocationService.error.value;
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassCard(
                        radius: 40,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        onTap: () => _manualCity(context),
                        child: const Text('بحث عن مدينة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
            const SectionTitle('حساب أوقات الصلاة'),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(children: [
                _tile(context, 'طريقة الحساب', PrayerService.methods[s.method] ?? s.method,
                    () => _pick(context, 'طريقة الحساب', PrayerService.methods, s.method, (v) => _save(s.copyWith(method: v)))),
                _tile(context, 'المذهب (صلاة العصر)', s.madhab == 'hanafi' ? 'الحنفي' : 'الجمهور (شافعي، مالكي، حنبلي)',
                    () => _pick(context, 'المذهب', const {'shafi': 'الجمهور (شافعي، مالكي، حنبلي)', 'hanafi': 'الحنفي'}, s.madhab,
                        (v) => _save(s.copyWith(madhab: v)))),
                _tile(
                    context,
                    'خطوط العرض العليا',
                    const {'middleOfTheNight': 'منتصف الليل', 'seventhOfTheNight': 'سُبع الليل', 'twilightAngle': 'زاوية الشفق'}[s.highLatitude]!,
                    () => _pick(
                        context,
                        'خطوط العرض العليا',
                        const {'middleOfTheNight': 'منتصف الليل', 'seventhOfTheNight': 'سُبع الليل', 'twilightAngle': 'زاوية الشفق'},
                        s.highLatitude,
                        (v) => _save(s.copyWith(highLatitude: v)))),
                _tile(context, 'تعديل الأوقات يدويًا', 'بالدقائق لكل صلاة', () => _adjustments(context)),
              ]),
            ),
            const SectionTitle('التنبيهات والأذان'),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(children: [
                ...PrayerName.values.map((p) => SwitchListTile(
                      title: Text(p == PrayerName.sunrise ? 'تنبيه الشروق' : 'أذان ${p.ar}'),
                      value: s.prayerAlerts[p.name] ?? false,
                      onChanged: (v) => _save(s.copyWith(prayerAlerts: {...s.prayerAlerts, p.name: v})),
                    )),
                SwitchListTile(
                  title: const Text('صوت الأذان الكامل'),
                  subtitle: const Text('عند الإيقاف يُستخدم صوت الإشعار الافتراضي', style: TextStyle(color: AppColors.textFaint)),
                  value: s.adhanSound,
                  onChanged: (v) => _save(s.copyWith(adhanSound: v)),
                ),
                _tile(
                  context,
                  'تذكير قبل الصلاة',
                  s.preReminderMinutes == 0 ? 'متوقف' : '${toArabicDigits(s.preReminderMinutes)} دقيقة',
                  () => _pick(
                    context,
                    'تذكير قبل الصلاة',
                    const {'0': 'متوقف', '5': '٥ دقائق', '10': '١٠ دقائق', '15': '١٥ دقيقة', '20': '٢٠ دقيقة', '30': '٣٠ دقيقة'},
                    '${s.preReminderMinutes}',
                    (v) => _save(s.copyWith(preReminderMinutes: int.parse(v))),
                  ),
                ),
                ListTile(
                  title: const Text('تجربة التنبيه'),
                  trailing: const Icon(Icons.notifications_active_rounded, color: AppColors.gold),
                  onTap: NotificationService.testAdhan,
                ),
              ]),
            ),
            const SectionTitle('تذكيرات العبادة'),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(children: [
                SwitchListTile(
                    title: const Text('أذكار الصباح (٧:٠٠ ص)'),
                    value: s.morningAzkar,
                    onChanged: (v) => _save(s.copyWith(morningAzkar: v))),
                SwitchListTile(
                    title: const Text('أذكار المساء (٥:٣٠ م)'),
                    value: s.eveningAzkar,
                    onChanged: (v) => _save(s.copyWith(eveningAzkar: v))),
                SwitchListTile(
                    title: const Text('سورة الكهف يوم الجمعة'), value: s.kahfFriday, onChanged: (v) => _save(s.copyWith(kahfFriday: v))),
                SwitchListTile(
                    title: const Text('تذكير صيام السنن (الإثنين والخميس والأيام البيض)'),
                    value: s.fastingReminders,
                    onChanged: (v) => _save(s.copyWith(fastingReminders: v))),
              ]),
            ),
            const SectionTitle('القرآن والتقويم'),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(children: [
                _tile(context, 'القارئ', QuranService.reciters[s.reciter] ?? s.reciter,
                    () => _pick(context, 'القارئ', QuranService.reciters, s.reciter, (v) => Store.saveSettings(s.copyWith(reciter: v)))),
                _tile(context, 'الترجمة الإضافية', QuranService.translations[s.translation] ?? '',
                    () => _pick(context, 'الترجمة', QuranService.translations, s.translation,
                        (v) => Store.saveSettings(s.copyWith(translation: v)))),
                SwitchListTile(
                    title: const Text('إظهار التفسير الميسر'),
                    value: s.showTafsir,
                    onChanged: (v) => Store.saveSettings(s.copyWith(showTafsir: v))),
                ListTile(
                  title: const Text('تعديل التاريخ الهجري'),
                  subtitle: Text(HijriService.today().formatted, style: const TextStyle(color: AppColors.textSoft)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        onPressed: () => _save(s.copyWith(hijriAdjust: (s.hijriAdjust - 1).clamp(-2, 2))),
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.gold)),
                    Text(toArabicDigits(s.hijriAdjust), style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconButton(
                        onPressed: () => _save(s.copyWith(hijriAdjust: (s.hijriAdjust + 1).clamp(-2, 2))),
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.gold)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            const Center(
              child: Text('نور · الإصدار ١٫٠\nالقرآن: مصحف المدينة (عثماني) · التفسير الميسر · أذكار حصن المسلم',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint, fontSize: 12, height: 1.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String t, String v, VoidCallback onTap) => ListTile(
        title: Text(t),
        subtitle: Text(v, style: const TextStyle(color: AppColors.gold, fontSize: 13)),
        trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: AppColors.textFaint),
        onTap: onTap,
      );

  void _pick(BuildContext context, String title, Map<String, String> options, String current, ValueChanged<String> onPick) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: GlassCard(
            blur: 30,
            tint: AppColors.deepTeal,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.entries
                      .map((e) => ListTile(
                            title: Text(e.value),
                            trailing: e.key == current ? const Icon(Icons.check_circle_rounded, color: AppColors.gold) : null,
                            onTap: () {
                              Navigator.pop(context);
                              onPick(e.key);
                            },
                          ))
                      .toList(),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _adjustments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ValueListenableBuilder(
        valueListenable: Store.settings,
        builder: (context, s, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            blur: 30,
            tint: AppColors.deepTeal,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('تعديل الأوقات (دقائق)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ...PrayerName.values.map((p) {
                final v = s.adjustments[p.name] ?? 0;
                return Row(children: [
                  Expanded(child: Text(p.ar)),
                  IconButton(
                      onPressed: () => _save(s.copyWith(adjustments: {...s.adjustments, p.name: v - 1})),
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.gold)),
                  SizedBox(width: 36, child: Text(toArabicDigits(v), textAlign: TextAlign.center)),
                  IconButton(
                      onPressed: () => _save(s.copyWith(adjustments: {...s.adjustments, p.name: v + 1})),
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.gold)),
                ]);
              }),
            ]),
          ),
        ),
      ),
    );
  }

  void _manualCity(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepTeal,
        title: const Text('ابحث عن مدينة'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'مثال: تونس، القاهرة، Paris')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final loc = await LocationService.search(c.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (loc == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على المدينة')));
                return;
              }
              await LocationService.setManual(loc);
              await NotificationService.rescheduleAll();
            },
            child: const Text('حفظ', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}
