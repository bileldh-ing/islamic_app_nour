import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'core/glass.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/qibla/qibla_screen.dart';
import 'features/quran/quran_home_screen.dart';
import 'features/tools/more_screen.dart';
import 'services/demo.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/quran_service.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Store.init();
  LocationService.loadCached();
  if (DemoMode.on) {
    LocationService.current.value = const UserLocation(lat: 36.8065, lng: 10.1815, city: 'تونس', country: 'تونس');
    final t = DemoMode.theme;
    if (t != null) Store.settings.value = Store.settings.value.copyWith(themeMode: t);
    final a = DemoMode.params['accent'];
    if (a != null) Store.settings.value = Store.settings.value.copyWith(accent: a);
    await QuranService.load();
  } else {
    QuranService.load(); // warm up in background
  }
  await NotificationService.init();
  runApp(const NoorApp());
}

class NoorApp extends StatelessWidget {
  const NoorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: Store.settings,
      builder: (context, s, _) {
        final accent = NoorAccent.byId(s.accent);
        final mode = switch (s.themeMode) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
        return MaterialApp(
          title: 'نور',
          debugShowCheckedModeBanner: false,
          theme: NoorTheme.build(Brightness.light, accent),
          darkTheme: NoorTheme.build(Brightness.dark, accent),
          themeMode: mode,
          themeAnimationDuration: const Duration(milliseconds: 450),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            ));
            return child!;
          },
          home: DemoMode.on ? demoHome() : (Store.getBool('onboarded') ? const RootShell() : const OnboardingScreen()),
        );
      },
    );
  }
}

/// Web demo deep links: `?demo&screen=<id>` (see core/routes.dart).
Widget demoHome() {
  final id = DemoMode.screen;
  const tabs = {'home': 0, 'prayer': 1, 'quran': 2, 'qibla': 3, 'more': 4};
  if (id == null || tabs.containsKey(id)) return RootShell(initialIndex: tabs[id] ?? 0);
  if (id == 'onboarding') return const OnboardingScreen();
  final b = allDemoRoutes()[id];
  return b == null ? const RootShell() : Builder(builder: b);
}

class RootShell extends StatefulWidget {
  const RootShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  static final ValueNotifier<int> tab = ValueNotifier(0);
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  final _pages = const [HomeScreen(), PrayerScreen(), QuranHomeScreen(), QiblaScreen(), MoreScreen()];

  @override
  void initState() {
    super.initState();
    RootShell.tab.value = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) NotificationService.rescheduleAll();
  }

  Future<void> _refresh() async {
    if (LocationService.current.value == null) await LocationService.refresh();
    await NotificationService.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return ValueListenableBuilder<int>(
      valueListenable: RootShell.tab,
      builder: (context, index, _) => Scaffold(
        backgroundColor: p.bgBottom,
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          child: KeyedSubtree(key: ValueKey(index), child: _pages[index]),
        ),
        bottomNavigationBar: NoorNavBar(index: index, onChanged: (i) => RootShell.tab.value = i),
      ),
    );
  }
}

/// Floating liquid-glass tab bar: the selected tab sits in a raised glass capsule.
class NoorNavBar extends StatelessWidget {
  const NoorNavBar({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const items = [
    (PhosphorIconsRegular.house, PhosphorIconsFill.house, 'الرئيسية'),
    (PhosphorIconsRegular.clock, PhosphorIconsFill.clock, 'الصلاة'),
    (PhosphorIconsRegular.bookOpenText, PhosphorIconsFill.bookOpenText, 'القرآن'),
    (PhosphorIconsRegular.compass, PhosphorIconsFill.compass, 'القبلة'),
    (PhosphorIconsRegular.squaresFour, PhosphorIconsFill.squaresFour, 'المزيد'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 30, offset: const Offset(0, 12), spreadRadius: -6)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: 70,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                color: p.isDark ? const Color(0x8C232A3D) : const Color(0xB3FFFFFF),
                border: Border.all(color: p.glassBorder.withValues(alpha: p.isDark ? 0.6 : 1)),
              ),
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth / items.length;
                final rtl = Directionality.of(context) == TextDirection.rtl;
                final left = rtl ? c.maxWidth - w * (index + 1) : w * index;
                return Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: p.isDark
                              ? [Colors.white.withValues(alpha: 0.20), Colors.white.withValues(alpha: 0.08)]
                              : [Colors.white, const Color(0xFFF1F4F9)],
                        ),
                        border: Border.all(color: p.isDark ? Colors.white.withValues(alpha: 0.28) : Colors.white),
                        boxShadow: [BoxShadow(color: p.shadow.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(items.length, (i) {
                      final sel = i == index;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            tick();
                            onChanged(i);
                          },
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(sel ? items[i].$2 : items[i].$1, size: 23, color: sel ? p.accent : p.textSoft),
                            const SizedBox(height: 3),
                            Text(items[i].$3,
                                style: TextStyle(
                                  fontFamily: NoorFonts.ui,
                                  fontSize: 11,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                                  color: sel ? p.text : p.textSoft,
                                )),
                          ]),
                        ),
                      );
                    }),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}
