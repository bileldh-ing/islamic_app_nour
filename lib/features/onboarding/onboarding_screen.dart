import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_state.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage.dart';
import '../settings/settings_screen.dart';

/// First-run flow: welcome, location, notifications, appearance.
/// On finish it calls [completeOnboarding] (sets `onboarded` and flips
/// [onboardingDone]); main.dart swaps in the root shell.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;
  bool _locBusy = false;
  String? _locResult;
  bool? _notifOk;

  static const _count = 4;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _count - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    tick(true);
    await completeOnboarding();
  }

  Future<void> _location() async {
    setState(() => _locBusy = true);
    final loc = await LocationService.refresh();
    if (!mounted) return;
    setState(() {
      _locBusy = false;
      _locResult = loc != null ? loc.city : (LocationService.error.value ?? 'تعذّر تحديد الموقع');
    });
    if (loc != null) Future.delayed(const Duration(milliseconds: 700), _next);
  }

  Future<void> _notifications() async {
    final ok = await NotificationService.requestPermissions();
    if (!mounted) return;
    setState(() => _notifOk = ok);
    if (ok) {
      await NotificationService.rescheduleAll();
      Future.delayed(const Duration(milliseconds: 600), _next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: p.bgBottom,
      body: NoorBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(children: [
                Row(children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(left: 6),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: i == _page ? p.accent : p.glassStrong),
                    ),
                ]),
                const Spacer(),
                if (_page < _count - 1)
                  GestureDetector(onTap: _finish, child: Text('تخطي', style: NoorText.label(context).copyWith(color: p.textSoft))),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcome(context),
                  _permission(
                    context,
                    icon: PhosphorIconsRegular.mapPin,
                    title: 'موقعك لمواقيت دقيقة',
                    body: 'نستخدم موقعك على جهازك فقط لحساب مواقيت الصلاة واتجاه القبلة. لا نرسل موقعك إلى أي خادم.',
                    action: _locBusy ? 'جارٍ التحديد...' : 'تحديد موقعي',
                    onAction: _locBusy ? null : _location,
                    result: _locResult,
                    resultOk: LocationService.current.value != null && _locResult != null,
                  ),
                  _permission(
                    context,
                    icon: PhosphorIconsRegular.bellRinging,
                    title: 'تنبيهات الأذان والأذكار',
                    body: 'ننبّهك عند دخول وقت الصلاة، ونذكّرك بأذكار الصباح والمساء وسورة الكهف يوم الجمعة. يمكنك تخصيصها لاحقًا.',
                    action: 'السماح بالإشعارات',
                    onAction: _notifications,
                    result: _notifOk == null ? null : (_notifOk! ? 'تم تفعيل الإشعارات' : 'لم يتم منح الإذن، يمكنك تفعيله لاحقًا من الإعدادات'),
                    resultOk: _notifOk == true,
                  ),
                  _appearance(context),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
              child: NoorButton(
                label: _page == _count - 1 ? 'ابدأ' : (_page == 0 ? 'لنبدأ' : 'التالي'),
                icon: _page == _count - 1 ? PhosphorIconsRegular.check : PhosphorIconsRegular.caretLeft,
                expand: true,
                onTap: _next,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final p = context.noor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover,
                errorBuilder: (_, _, _) => IconBadge(PhosphorIconsRegular.moonStars, size: 120)),
          ),
        ),
        const SizedBox(height: 28),
        Text('نور', style: NoorText.display(context)),
        const SizedBox(height: 8),
        Text('رفيقك اليومي للصلاة والقرآن والأذكار', textAlign: TextAlign.center, style: NoorText.h3(context).copyWith(color: p.textSoft)),
        const SizedBox(height: 28),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: const [
          GlassChip(label: 'مواقيت الصلاة', icon: PhosphorIconsRegular.clock),
          GlassChip(label: 'القرآن الكريم', icon: PhosphorIconsRegular.bookOpenText),
          GlassChip(label: 'القبلة', icon: PhosphorIconsRegular.compass),
          GlassChip(label: 'الأذكار', icon: PhosphorIconsRegular.handsPraying),
        ]),
        const SizedBox(height: 28),
        Text('﴿اللَّهُ نُورُ السَّمَاوَاتِ وَالْأَرْضِ﴾', style: NoorText.arabic(context, 22).copyWith(color: p.gold)),
        Text('سورة النور: 35', style: NoorText.caption(context)),
      ]),
    );
  }

  Widget _permission(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required String action,
    required VoidCallback? onAction,
    String? result,
    bool resultOk = false,
  }) {
    final p = context.noor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [p.accent.withValues(alpha: 0.28), p.accent.withValues(alpha: 0)])),
          child: Center(child: IconBadge(icon, size: 88)),
        ),
        const SizedBox(height: 24),
        Text(title, textAlign: TextAlign.center, style: NoorText.h1(context)),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center, style: NoorText.body(context).copyWith(fontSize: 15)),
        const SizedBox(height: 26),
        NoorButton(label: action, icon: icon, secondary: true, onTap: onAction ?? () {}),
        if (result != null) ...[
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(resultOk ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.info, size: 18, color: resultOk ? p.success : p.textSoft),
            const SizedBox(width: 6),
            Flexible(child: Text(result, textAlign: TextAlign.center, style: NoorText.label(context))),
          ]),
        ],
      ]),
    );
  }

  Widget _appearance(BuildContext context) => ValueListenableBuilder<AppSettings>(
        valueListenable: Store.settings,
        builder: (context, s, _) {
          final p = context.noor;
          Widget mode(String id, String label, IconData icon) {
            final sel = s.themeMode == id;
            return Expanded(
              child: Glass(
                radius: 22,
                strong: sel,
                tint: sel ? p.accent : null,
                onTap: () => Store.saveSettings(s.copyWith(themeMode: id)),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(children: [
                  Icon(icon, color: sel ? p.accent : p.textSoft, size: 26),
                  const SizedBox(height: 8),
                  Text(label, style: NoorText.h3(context).copyWith(fontSize: 14)),
                ]),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('اختر مظهرك', style: NoorText.h1(context)),
              const SizedBox(height: 8),
              Text('يمكنك تغييره في أي وقت من الإعدادات', style: NoorText.body(context)),
              const SizedBox(height: 26),
              Row(children: [
                mode('light', 'فاتح', PhosphorIconsRegular.sun),
                const SizedBox(width: 10),
                mode('dark', 'داكن', PhosphorIconsRegular.moon),
                const SizedBox(width: 10),
                mode('system', 'تلقائي', PhosphorIconsRegular.circleHalf),
              ]),
              const SizedBox(height: 26),
              Text('لون التطبيق', style: NoorText.label(context)),
              const SizedBox(height: 12),
              AccentSwatches(selected: s.accent, onChanged: (id) => Store.saveSettings(s.copyWith(accent: id))),
            ]),
          );
        },
      );
}
