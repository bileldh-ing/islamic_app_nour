import 'package:flutter/material.dart';

import '../main.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    await LocationService.refresh();
    await NotificationService.requestPermissions();
    await Store.setBool('onboarded', true);
    await NotificationService.rescheduleAll();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RootShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(flex: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Image.asset('assets/images/app_icon.png', width: 130, height: 130),
              ),
              const SizedBox(height: 22),
              ShaderMask(
                shaderCallback: (r) => AppColors.goldGradient.createShader(r),
                child: const Text('نور', style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 64, color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const Text('رفيقك في الصلاة والقرآن والذكر',
                  style: TextStyle(color: AppColors.textSoft, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              _feature(Icons.access_time_filled_rounded, 'أوقات صلاة دقيقة', 'حسب موقعك مع أذان كامل وتذكيرات'),
              _feature(Icons.explore_rounded, 'بوصلة القبلة', 'تشير إلى الكعبة المشرفة بدقة'),
              _feature(Icons.menu_book_rounded, 'القرآن الكريم', 'مصحف كامل مع التفسير الميسر والتلاوة'),
              const Spacer(),
              const Text('نحتاج إذن الموقع لحساب أوقات الصلاة والقبلة، وإذن الإشعارات للأذان.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint, height: 1.6)),
              const SizedBox(height: 16),
              _busy
                  ? const CircularProgressIndicator(color: AppColors.gold)
                  : SizedBox(width: double.infinity, child: Center(child: GoldButton(label: 'ابدأ الآن', icon: Icons.arrow_back_rounded, onTap: _start))),
              const SizedBox(height: 10),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData i, String t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(i, color: AppColors.gold, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(s, style: const TextStyle(color: AppColors.textSoft, fontSize: 13)),
              ]),
            ),
          ]),
        ),
      );
}
