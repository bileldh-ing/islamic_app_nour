import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';

class ShahadaScreen extends StatelessWidget {
  const ShahadaScreen({super.key});

  static const pillarsIslam = [
    'شهادة أن لا إله إلا الله وأن محمدًا رسول الله',
    'إقام الصلاة',
    'إيتاء الزكاة',
    'صوم رمضان',
    'حج البيت لمن استطاع إليه سبيلًا',
  ];
  static const pillarsIman = [
    'الإيمان بالله',
    'وملائكته',
    'وكتبه',
    'ورسله',
    'واليوم الآخر',
    'وبالقدر خيره وشره',
  ];

  @override
  Widget build(BuildContext context) => GlassPage(
        title: 'الشهادة',
        showMosque: true,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
          children: [
            const GlassCard(
              glow: true,
              borderGold: true,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(children: [
                Text(
                  'أَشْهَدُ أَنْ لَا إِلَٰهَ إِلَّا اللَّهُ\nوَأَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللَّهِ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 30, height: 2, color: AppColors.gold, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 16),
                Text(
                  'Ashhadu an lā ilāha illā-llāh, wa ashhadu anna Muḥammadan rasūlu-llāh',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: AppColors.textSoft, fontStyle: FontStyle.italic, height: 1.5),
                ),
              ]),
            ),
            const SectionTitle('معناها'),
            const GlassCard(
              child: Text(
                'أُقِرّ وأعترف بلساني وقلبي أنه لا معبود بحقٍّ إلا الله وحده لا شريك له، وأن محمدًا ﷺ عبده ورسوله، أُطيعه فيما أمر، وأُصدّقه فيما أخبر، وأجتنب ما نهى عنه وزجر، ولا أعبد الله إلا بما شرع.',
                style: TextStyle(height: 1.9, fontSize: 15.5),
              ),
            ),
            const SectionTitle('أركان الإسلام'),
            _list(pillarsIslam),
            const SectionTitle('أركان الإيمان'),
            _list(pillarsIman),
          ],
        ),
      );

  Widget _list(List<String> items) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  AyahMedallion(number: i + 1, size: 30),
                  const SizedBox(width: 12),
                  Expanded(child: Text(items[i], style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
                ]),
              ),
          ],
        ),
      );
}
