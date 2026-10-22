import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/open.dart';
import '../../core/theme.dart';
import '../../services/hijri_service.dart';
import '../../services/notification_service.dart';
import '../../services/quran_service.dart';
import '../../services/storage.dart';
import '../../services/worship_store.dart';
import '../worship/worship_widgets.dart';

/// App settings: appearance, reminders, Quran defaults, Hijri adjustment, about, reset.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<void> _save(AppSettings s, {bool reschedule = false}) async {
    await Store.saveSettings(s);
    if (reschedule) await NotificationService.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: Store.settings,
      builder: (context, s, _) => NoorPage(
        title: 'الإعدادات',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _Header('المظهر'),
          _Card(children: [
            _Label(icon: PhosphorIconsRegular.circleHalf, title: 'وضع العرض'),
            const SizedBox(height: 10),
            ChipBar(
              labels: const ['تلقائي', 'فاتح', 'داكن'],
              index: const ['system', 'light', 'dark'].indexOf(s.themeMode).clamp(0, 2),
              padding: EdgeInsets.zero,
              onChanged: (i) => _save(s.copyWith(themeMode: const ['system', 'light', 'dark'][i])),
            ),
            const SizedBox(height: 16),
            _Label(icon: PhosphorIconsRegular.palette, title: 'لون التطبيق'),
            const SizedBox(height: 10),
            AccentSwatches(selected: s.accent, onChanged: (id) => _save(s.copyWith(accent: id))),
            const _Divider(),
            _Switch(
              icon: PhosphorIconsRegular.clock,
              title: 'نظام 24 ساعة',
              subtitle: 'مثال: ${Fmt.time(DateTime(2026, 1, 1, 17, 5), h24: s.use24h)} ${Fmt.period(DateTime(2026, 1, 1, 17, 5), h24: s.use24h)}',
              value: s.use24h,
              onChanged: (v) => _save(s.copyWith(use24h: v)),
            ),
            _Switch(
              icon: PhosphorIconsRegular.vibrate,
              title: 'الاهتزاز عند اللمس',
              subtitle: 'في المسبحة والأذكار والأزرار',
              value: s.hapticsOn,
              onChanged: (v) => _save(s.copyWith(hapticsOn: v)),
            ),
          ]),
          const _Header('التذكيرات'),
          _Card(children: [
            _Switch(
              icon: PhosphorIconsRegular.sunHorizon,
              title: 'أذكار الصباح',
              subtitle: 'بعد الفجر بـ ${s.morningAzkarTime} دقيقة',
              value: s.morningAzkar,
              onChanged: (v) => _save(s.copyWith(morningAzkar: v), reschedule: true),
            ),
            if (s.morningAzkar)
              _Offset(
                value: s.morningAzkarTime,
                label: 'بعد الفجر',
                onChanged: (v) => _save(s.copyWith(morningAzkarTime: v), reschedule: true),
              ),
            _Switch(
              icon: PhosphorIconsRegular.moonStars,
              title: 'أذكار المساء',
              subtitle: 'بعد العصر بـ ${s.eveningAzkarTime} دقيقة',
              value: s.eveningAzkar,
              onChanged: (v) => _save(s.copyWith(eveningAzkar: v), reschedule: true),
            ),
            if (s.eveningAzkar)
              _Offset(
                value: s.eveningAzkarTime,
                label: 'بعد العصر',
                onChanged: (v) => _save(s.copyWith(eveningAzkarTime: v), reschedule: true),
              ),
            _Switch(
              icon: PhosphorIconsRegular.bed,
              title: 'أذكار النوم',
              subtitle: 'كل ليلة الساعة ${Fmt.timeFull(DateTime(2026, 1, 1, 22, 30))}',
              value: s.sleepAzkar,
              onChanged: (v) => _save(s.copyWith(sleepAzkar: v), reschedule: true),
            ),
            _Switch(
              icon: PhosphorIconsRegular.bookOpenText,
              title: 'سورة الكهف يوم الجمعة',
              value: s.kahfFriday,
              onChanged: (v) => _save(s.copyWith(kahfFriday: v), reschedule: true),
            ),
            _Switch(
              icon: PhosphorIconsRegular.flowerLotus,
              title: 'الصلاة على النبي يوم الجمعة',
              value: s.salawatFriday,
              onChanged: (v) => _save(s.copyWith(salawatFriday: v), reschedule: true),
            ),
            _Switch(
              icon: PhosphorIconsRegular.calendarCheck,
              title: 'تذكير صيام الإثنين والخميس',
              value: s.fastingReminders,
              onChanged: (v) => _save(s.copyWith(fastingReminders: v), reschedule: true),
            ),
            _Switch(
              icon: PhosphorIconsRegular.moon,
              title: 'الأيام البيض',
              subtitle: '13 و14 و15 من كل شهر هجري',
              value: s.whiteDaysReminder,
              onChanged: (v) => _save(s.copyWith(whiteDaysReminder: v), reschedule: true),
            ),
            _Switch(
              icon: PhosphorIconsRegular.quotes,
              title: 'آية اليوم',
              subtitle: 'كل صباح الساعة ${Fmt.timeFull(DateTime(2026, 1, 1, 8))}',
              value: s.dailyAyah,
              onChanged: (v) => _save(s.copyWith(dailyAyah: v), reschedule: true),
            ),
            _Switch(
              icon: PhosphorIconsRegular.circlesThree,
              title: 'تذكير التسبيح',
              value: s.tasbihReminder,
              onChanged: (v) => _save(s.copyWith(tasbihReminder: v), reschedule: true),
            ),
            const _Divider(),
            _Nav(
              icon: PhosphorIconsRegular.bellRinging,
              title: 'تنبيهات الأذان',
              subtitle: 'الصوت والتنبيه لكل صلاة',
              onTap: () => openRoute(context, 'adhan-settings') || openRoute(context, 'prayer-settings'),
            ),
            _Nav(
              icon: PhosphorIconsRegular.bellSimple,
              title: 'تفعيل الإشعارات',
              subtitle: 'اطلب إذن الإشعارات من النظام',
              onTap: () async {
                final ok = await NotificationService.requestPermissions();
                if (ok) await NotificationService.rescheduleAll();
                if (context.mounted) showToast(context, ok ? 'تم تفعيل الإشعارات' : 'لم يتم منح الإذن، يمكنك تفعيله من إعدادات الجهاز');
              },
            ),
          ]),
          const _Header('القرآن الكريم'),
          _Card(children: [
            _Label(icon: PhosphorIconsRegular.textAa, title: 'حجم خط المصحف', trailing: '${s.quranFontSize.round()}'),
            Slider(
              value: s.quranFontSize.clamp(18, 44).toDouble(),
              min: 18,
              max: 44,
              divisions: 13,
              onChanged: (v) => Store.settings.value = s.copyWith(quranFontSize: v),
              onChangeEnd: (v) => _save(s.copyWith(quranFontSize: v)),
            ),
            Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', textAlign: TextAlign.center, style: NoorText.quran(context, s.quranFontSize * 0.8)),
            const _Divider(),
            _Switch(
              icon: PhosphorIconsRegular.bookBookmark,
              title: 'إظهار التفسير الميسر',
              value: s.showTafsir,
              onChanged: (v) => _save(s.copyWith(showTafsir: v)),
            ),
            _Nav(
              icon: PhosphorIconsRegular.translate,
              title: 'الترجمة',
              subtitle: QuranService.translations[s.translation] ?? 'بدون',
              onTap: () => _pick(context, 'الترجمة', QuranService.translations, s.translation, (v) => _save(s.copyWith(translation: v))),
            ),
            _Nav(
              icon: PhosphorIconsRegular.microphone,
              title: 'القارئ',
              subtitle: QuranService.reciterById(s.reciter).name,
              onTap: () => _pick(context, 'القارئ', QuranService.reciters, s.reciter, (v) => _save(s.copyWith(reciter: v))),
            ),
            const _Divider(),
            _Label(icon: PhosphorIconsRegular.target, title: 'الورد اليومي', trailing: '${s.dailyGoalPages} صفحات'),
            const SizedBox(height: 8),
            ChipBar(
              labels: const ['1', '2', '4', '10', '20'],
              index: const [1, 2, 4, 10, 20].indexOf(s.dailyGoalPages),
              padding: EdgeInsets.zero,
              onChanged: (i) => _save(s.copyWith(dailyGoalPages: const [1, 2, 4, 10, 20][i])),
            ),
            const SizedBox(height: 6),
            Text('${s.dailyGoalPages} صفحات يوميًا = ختمة كل ${(604 / s.dailyGoalPages).ceil()} يومًا', style: NoorText.caption(context)),
          ]),
          const _Header('التاريخ الهجري'),
          _Card(children: [
            _Label(icon: PhosphorIconsRegular.calendarBlank, title: 'تعديل التاريخ الهجري', trailing: '${s.hijriAdjust > 0 ? '+' : ''}${s.hijriAdjust} يوم'),
            const SizedBox(height: 8),
            ChipBar(
              labels: const ['-2', '-1', '0', '+1', '+2'],
              index: (s.hijriAdjust + 2).clamp(0, 4),
              padding: EdgeInsets.zero,
              onChanged: (i) => _save(s.copyWith(hijriAdjust: i - 2), reschedule: true),
            ),
            const SizedBox(height: 8),
            Text('اليوم: ${HijriService.today().formatted}', style: NoorText.label(context)),
            Text('عدّل التاريخ ليوافق رؤية الهلال في بلدك.', style: NoorText.caption(context)),
          ]),
          const _Header('حول التطبيق'),
          _Card(children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) => _Nav(
                icon: PhosphorIconsRegular.info,
                title: 'نور',
                subtitle: snap.hasData ? 'الإصدار ${snap.data!.version} (${snap.data!.buildNumber})' : 'الإصدار',
                onTap: () {},
                showCaret: false,
              ),
            ),
            _Nav(icon: PhosphorIconsRegular.scroll, title: 'مصادر المحتوى', onTap: () => push(context, const SourcesScreen())),
            _Nav(
              icon: PhosphorIconsRegular.fileText,
              title: 'التراخيص',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (ctx) => Localizations.override(
                  context: ctx,
                  locale: const Locale('en'),
                  child: const LicensePage(applicationName: 'Noor'),
                ),
              )),
            ),
          ]),
          const _Header('البيانات'),
          _Card(children: [
            _Nav(
              icon: PhosphorIconsRegular.trash,
              title: 'إعادة ضبط التطبيق',
              subtitle: 'حذف الإعدادات والسجلات والمفضلة',
              danger: true,
              onTap: () => _reset(context),
            ),
          ]),
        ]),
      ),
    );
  }

  static void _pick(BuildContext context, String title, Map<String, String> options, String current, ValueChanged<String> onPick) {
    showGlassSheet(
      context,
      title: title,
      builder: (ctx) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 10, 20, 24), children: [
        for (final e in options.entries)
          GlassTile(
            title: e.value,
            icon: e.key == current ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
            onTap: () {
              onPick(e.key);
              Navigator.pop(ctx);
            },
          ),
      ]),
    );
  }

  static void _reset(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: d.noor.isDark ? const Color(0xFF1E2538) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('إعادة ضبط التطبيق؟', style: NoorText.h3(d)),
        content: Text('سيتم حذف جميع الإعدادات وسجلات الصلاة والصيام والتسبيح والمفضلة والعلامات. لا يمكن التراجع عن ذلك.', style: NoorText.body(d)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: d.noor.danger),
            onPressed: () async {
              final onboarded = Store.getBool('onboarded');
              await WorshipStore.clearAll();
              await Store.prefs.clear();
              await Store.setBool('onboarded', onboarded);
              await Store.saveSettings(AppSettings());
              await NotificationService.rescheduleAll();
              if (d.mounted) Navigator.pop(d);
              if (context.mounted) showToast(context, 'تمت إعادة الضبط');
            },
            child: const Text('حذف كل البيانات'),
          ),
        ],
      ),
    );
  }
}

/// Accent colour picker (round swatches).
class AccentSwatches extends StatelessWidget {
  const AccentSwatches({super.key, required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return Wrap(spacing: 12, runSpacing: 10, children: [
      for (final a in NoorAccent.all)
        Semantics(
          button: true,
          label: a.name,
          selected: a.id == selected,
          child: Pressable(
            onTap: () => onChanged(a.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: a.id == selected ? a.color : p.glassBorder, width: a.id == selected ? 2 : 1),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [a.soft, a.color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: a.id == selected ? const Icon(PhosphorIconsBold.check, size: 16, color: Colors.white) : null,
              ),
            ),
          ),
        ),
    ]);
  }
}

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});
  static const items = [
    ('القرآن الكريم', 'نص المصحف بالرسم العثماني والتفسير الميسر — مضمّن في التطبيق.', PhosphorIconsRegular.bookOpenText),
    ('الأذكار والأدعية', 'كتاب «حصن المسلم» للشيخ سعيد بن علي بن وهف القحطاني مع التخريج، ومطابقته مع موقع hisnmuslim.com الرسمي.', PhosphorIconsRegular.handsPraying),
    ('الأربعون النووية', 'متن الإمام النووي (42 حديثًا) من مجموعة hadith-api، ومراجعته مع نسخة sunnah.com ونسخة ثالثة مستقلة.', PhosphorIconsRegular.quotes),
    ('أسماء الله الحسنى', 'وفق رواية الترمذي (3507)، وتمت مطابقتها مع sunnah.com.', PhosphorIconsRegular.sparkle),
    ('التقويم الهجري', 'تقويم أم القرى، وتمت مقارنته بواجهة api.aladhan.com.', PhosphorIconsRegular.calendarBlank),
    ('مواقيت الصلاة', 'حساب فلكي محلي وفق طرق الحساب المعتمدة.', PhosphorIconsRegular.clock),
  ];
  @override
  Widget build(BuildContext context) => NoorPage(
        title: 'مصادر المحتوى',
        child: Column(children: [
          for (final it in items) GlassTile(title: it.$1, subtitle: it.$2, icon: it.$3),
          const SizedBox(height: 8),
          Text('نحرص على توثيق كل نص ديني. إن وجدت خطأً فأخبرنا ليتم تصحيحه.', textAlign: TextAlign.center, style: NoorText.caption(context)),
        ]),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(6, 22, 6, 10), child: Text(title, style: NoorText.label(context).copyWith(fontWeight: FontWeight.w600)));
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Glass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Container(height: 1, color: context.noor.hairline));
}

class _Label extends StatelessWidget {
  const _Label({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20, color: context.noor.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: NoorText.h3(context).copyWith(fontSize: 14.5))),
        if (trailing != null) Text(trailing!, style: NoorText.number(context, size: 14).copyWith(color: context.noor.textSoft)),
      ]);
}

class _Switch extends StatelessWidget {
  const _Switch({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: context.noor.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: NoorText.h3(context).copyWith(fontSize: 14.5)),
              if (subtitle != null) Text(subtitle!, style: NoorText.caption(context)),
            ]),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              tick();
              onChanged(v);
            },
          ),
        ]),
      );
}

class _Offset extends StatelessWidget {
  const _Offset({required this.value, required this.label, required this.onChanged});
  final int value;
  final String label;
  final ValueChanged<int> onChanged;
  static const options = [0, 15, 30, 45, 60, 90];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 30, bottom: 8),
        child: SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => GlassChip(label: options[i] == 0 ? 'مع الأذان' : '${options[i]} د', selected: options[i] == value, onTap: () => onChanged(options[i])),
          ),
        ),
      );
}

class _Nav extends StatelessWidget {
  const _Nav({required this.icon, required this.title, this.subtitle, required this.onTap, this.danger = false, this.showCaret = true});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool showCaret;
  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final c = danger ? p.danger : p.accent;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: NoorText.h3(context).copyWith(fontSize: 14.5, color: danger ? p.danger : p.text)),
              if (subtitle != null) Text(subtitle!, style: NoorText.caption(context)),
            ]),
          ),
          if (showCaret) Icon(PhosphorIconsRegular.caretLeft, size: 18, color: p.textFaint),
        ]),
      ),
    );
  }
}
