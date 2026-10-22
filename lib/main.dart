import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/azkar_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/duas_screen.dart';
import 'screens/fasting_screen.dart';
import 'screens/home_screen.dart';
import 'screens/names_screen.dart';
import 'screens/shahada_screen.dart';
import 'screens/surah_reader_screen.dart';
import 'screens/tasbih_screen.dart';
import 'screens/tracker_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/settings_screen.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/quran_service.dart';
import 'services/demo.dart';
import 'services/storage.dart';
import 'theme/app_theme.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Store.init();
  LocationService.loadCached();
  if (DemoMode.on) {
    LocationService.current.value = const UserLocation(lat: 36.8065, lng: 10.1815, city: 'تونس', country: 'تونس');
  }
  await NotificationService.init();
  QuranService.load(); // warm up in background
  runApp(const NoorApp());
}

class NoorApp extends StatelessWidget {
  const NoorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نور',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DemoMode.on ? _demoHome() : (Store.getBool('onboarded') ? const RootShell() : const OnboardingScreen()),
    );
  }
}

Widget _demoHome() {
  switch (DemoMode.screen) {
    case 'onboarding':
      return const OnboardingScreen();
    case 'azkar':
      return const AzkarScreen();
    case 'duas':
      return const DuasScreen();
    case 'tasbih':
      return const TasbihScreen();
    case 'tracker':
      return const TrackerScreen();
    case 'calendar':
      return const CalendarScreen();
    case 'names':
      return const NamesScreen();
    case 'shahada':
      return const ShahadaScreen();
    case 'fasting':
      return const FastingScreen();
    case 'reader':
      return SurahReaderScreen(surah: DemoMode.intParam('surah', 1));
    case 'qibla':
      return const RootShell(initialIndex: 1);
    case 'quran':
      return const RootShell(initialIndex: 2);
    case 'settings':
      return const RootShell(initialIndex: 3);
    default:
      return const RootShell();
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  late int _index = widget.initialIndex;
  final _pages = const [HomeScreen(), QiblaScreen(), QuranScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      backgroundColor: AppColors.midnight,
      extendBody: true,
      body: AppBackground(
        showMosque: _index == 0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
        ),
      ),
      bottomNavigationBar: LiquidNavBar(
        index: _index,
        onChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
      ),
    );
  }
}

/// Floating liquid-glass tab bar with a morphing gold "droplet" indicator.
class LiquidNavBar extends StatelessWidget {
  const LiquidNavBar({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_rounded, 'الرئيسية'),
    (Icons.explore_rounded, 'القبلة'),
    (Icons.menu_book_rounded, 'القرآن'),
    (Icons.settings_rounded, 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: LinearGradient(colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.06),
              ]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth / _items.length;
              // RTL: first tab is on the right.
              final rtl = Directionality.of(context) == TextDirection.rtl;
              final left = rtl ? c.maxWidth - w * (index + 1) : w * index;
              return Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  left: left + 8,
                  top: 8,
                  width: w - 16,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.gold.withValues(alpha: 0.42), AppColors.gold.withValues(alpha: 0.14)],
                      ),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 20)],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(_items.length, (i) {
                    final sel = i == index;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          AnimatedScale(
                            duration: const Duration(milliseconds: 300),
                            scale: sel ? 1.12 : 1,
                            child: Icon(_items[i].$1, color: sel ? AppColors.gold : AppColors.textSoft, size: 25),
                          ),
                          const SizedBox(height: 3),
                          Text(_items[i].$2,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                                  color: sel ? AppColors.gold : AppColors.textSoft)),
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
    );
  }
}

// Re-export for screens that need the digit helper without importing glass directly.
String arabicDigits(Object n) => toArabicDigits(n);
