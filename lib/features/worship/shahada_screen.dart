import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import 'worship_widgets.dart';

/// The Shahada, its meaning and the pillars of Islam and Iman (hadith of Jibril, Muslim).
class ShahadaScreen extends StatelessWidget {
  const ShahadaScreen({super.key});

  static const shahada = 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ\nوَأَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللَّهِ';

  static const pillarsIslam = [
    (PhosphorIconsRegular.sealCheck, 'شهادة أن لا إله إلا الله وأن محمدًا رسول الله'),
    (PhosphorIconsRegular.mosque, 'إقام الصلاة'),
    (PhosphorIconsRegular.handCoins, 'إيتاء الزكاة'),
    (PhosphorIconsRegular.moonStars, 'صوم رمضان'),
    (PhosphorIconsRegular.compass, 'حج البيت لمن استطاع إليه سبيلًا'),
  ];
  static const pillarsIman = [
    'الإيمان بالله',
    'وملائكته',
    'وكتبه',
    'ورسله',
    'واليوم الآخر',
    'والقدر خيره وشره',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.noor;
    return NoorPage(
      title: 'الشهادة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HeroPhotoCard(
          image: 'assets/images/hero_night.jpg',
          height: 210,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text(shahada,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: NoorFonts.arabic, fontSize: 26, height: 2, color: Color(0xFFF5D894), fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Ashhadu an la ilaha illa Allah, wa ashhadu anna Muhammadan rasulu Allah',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: TextStyle(fontFamily: NoorFonts.ui, fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          MiniAction(icon: PhosphorIconsRegular.copy, onTap: () => copyText(context, shahada)),
          const SizedBox(width: 10),
          MiniAction(icon: PhosphorIconsRegular.shareNetwork, onTap: () => shareText(shahada)),
        ]),
        const SectionHeader('معناها', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
        Glass(
          radius: 22,
          child: Text(
            'أُقرّ وأعترف بلساني وقلبي أنه لا معبود بحقٍّ إلا الله وحده لا شريك له، وأن محمدًا صلى الله عليه وسلم عبده ورسوله؛ '
            'أطيعه فيما أمر، وأصدّقه فيما أخبر، وأجتنب ما نهى عنه وزجر، وألّا يُعبد الله إلا بما شرع.',
            style: NoorText.body(context).copyWith(color: p.text, fontSize: 15, height: 1.9),
          ),
        ),
        const SectionHeader('أركان الإسلام', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
        for (var i = 0; i < pillarsIslam.length; i++)
          GlassTile(title: pillarsIslam[i].$2, icon: pillarsIslam[i].$1, trailing: AyahNumber(i + 1, size: 30)),
        const SectionHeader('أركان الإيمان', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
        Glass(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (var i = 0; i < pillarsIman.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  AyahNumber(i + 1, size: 30),
                  const SizedBox(width: 12),
                  Expanded(child: Text(pillarsIman[i], style: NoorText.h3(context).copyWith(fontSize: 15))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Text('من حديث جبريل عليه السلام، رواه مسلم.', textAlign: TextAlign.center, style: NoorText.caption(context)),
      ]),
    );
  }
}
