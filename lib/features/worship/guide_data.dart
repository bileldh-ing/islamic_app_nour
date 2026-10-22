import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GuideStep {
  const GuideStep(this.title, this.body, this.icon, {this.dhikr});
  final String title;
  final String body;
  final IconData icon;

  /// Words to say at this step (shown in the Amiri face).
  final String? dhikr;
}

class GuideSection {
  const GuideSection(this.title, this.steps, {this.intro});
  final String title;
  final String? intro;
  final List<GuideStep> steps;
}

class Guide {
  const Guide(this.id, this.title, this.subtitle, this.image, this.sections, {this.note});
  final String id;
  final String title;
  final String subtitle;
  final String image;
  final List<GuideSection> sections;
  final String? note;
}

/// Concise step-by-step guides following the mainstream (jumhur) positions,
/// based on the prophetic descriptions in Sahih al-Bukhari and Sahih Muslim
/// (wudu: hadith of Uthman; salah: hadiths of Abu Humayd and Aisha; Hajj: hadith of Jabir in Muslim).
class Guides {
  Guides._();

  static const salah = Guide(
    'salah',
    'الوضوء والصلاة',
    'خطوة بخطوة',
    'assets/images/hero_dusk.jpg',
    [
      GuideSection('الوضوء', [
        GuideStep('النية', 'أن تنوي بقلبك رفع الحدث للصلاة، ولا يُشرع التلفظ بها.', PhosphorIconsRegular.heart),
        GuideStep('التسمية', 'تقول عند البدء:', PhosphorIconsRegular.chatCircleText, dhikr: 'بِسْمِ اللَّهِ'),
        GuideStep('غسل الكفين', 'اغسل كفيك ثلاث مرات.', PhosphorIconsRegular.handPalm),
        GuideStep('المضمضة والاستنشاق', 'تمضمض واستنشق الماء ثم استنثره ثلاث مرات.', PhosphorIconsRegular.drop),
        GuideStep('غسل الوجه', 'اغسل وجهك ثلاثًا: من منابت شعر الرأس إلى أسفل الذقن طولًا، ومن الأذن إلى الأذن عرضًا.', PhosphorIconsRegular.smiley),
        GuideStep('غسل اليدين', 'اغسل يديك إلى المرفقين ثلاثًا، مبتدئًا باليمنى.', PhosphorIconsRegular.handWaving),
        GuideStep('مسح الرأس', 'امسح رأسك مرة واحدة: من مقدمه إلى قفاك ثم تردّ يديك إلى المكان الذي بدأت منه.', PhosphorIconsRegular.userCircle),
        GuideStep('مسح الأذنين', 'امسح باطن الأذنين بالسبابتين وظاهرهما بالإبهامين.', PhosphorIconsRegular.ear),
        GuideStep('غسل الرجلين', 'اغسل رجليك إلى الكعبين ثلاثًا، مبتدئًا باليمنى، مع تخليل الأصابع.', PhosphorIconsRegular.footprints),
        GuideStep('الذكر بعد الوضوء', 'تقول بعد الفراغ (رواه مسلم):', PhosphorIconsRegular.sparkle,
            dhikr: 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ'),
      ]),
      GuideSection('الصلاة (ركعتان مثل صلاة الفجر)', intro: 'عدد الركعات: الفجر 2، الظهر 4، العصر 4، المغرب 3، العشاء 4.', [
        GuideStep('الاستعداد', 'تطهّر، واستر عورتك، واستقبل القبلة، وانوِ الصلاة التي تريدها بقلبك.', PhosphorIconsRegular.compass),
        GuideStep('تكبيرة الإحرام', 'ارفع يديك حذو منكبيك أو أذنيك وقل:', PhosphorIconsRegular.handsPraying, dhikr: 'اللَّهُ أَكْبَرُ'),
        GuideStep('دعاء الاستفتاح', 'ضع يدك اليمنى على اليسرى على صدرك، واقرأ دعاء الاستفتاح، ومنه:', PhosphorIconsRegular.bookOpen,
            dhikr: 'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ، وَتَبَارَكَ اسْمُكَ، وَتَعَالَى جَدُّكَ، وَلَا إِلَهَ غَيْرُكَ'),
        GuideStep('القراءة', 'استعذ وبسمل سرًّا، ثم اقرأ سورة الفاتحة، ثم ما تيسر من القرآن في الركعتين الأوليين.', PhosphorIconsRegular.bookOpenText),
        GuideStep('الركوع', 'كبّر واركع، واضعًا يديك على ركبتيك مع استواء الظهر، وقل ثلاثًا:', PhosphorIconsRegular.personSimple,
            dhikr: 'سُبْحَانَ رَبِّيَ الْعَظِيمِ'),
        GuideStep('الرفع من الركوع', 'ارفع رأسك قائلًا «سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ»، فإذا اعتدلت قائمًا قل:', PhosphorIconsRegular.arrowUp,
            dhikr: 'رَبَّنَا وَلَكَ الْحَمْدُ'),
        GuideStep('السجود', 'كبّر واسجد على الأعضاء السبعة: الجبهة مع الأنف، والكفين، والركبتين، وأطراف القدمين، وقل ثلاثًا:', PhosphorIconsRegular.arrowDown,
            dhikr: 'سُبْحَانَ رَبِّيَ الْأَعْلَى'),
        GuideStep('الجلسة بين السجدتين', 'كبّر واجلس مطمئنًا مفترشًا رجلك اليسرى، وقل:', PhosphorIconsRegular.pause, dhikr: 'رَبِّ اغْفِرْ لِي، رَبِّ اغْفِرْ لِي'),
        GuideStep('السجدة الثانية', 'كبّر واسجد سجدة ثانية مثل الأولى، ثم انهض إلى الركعة الثانية وصلّها كالأولى.', PhosphorIconsRegular.repeat),
        GuideStep('التشهد', 'اجلس بعد الركعة الثانية واقرأ التشهد:', PhosphorIconsRegular.handPointing,
            dhikr: 'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ، وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ'),
        GuideStep('الصلاة على النبي', 'في التشهد الأخير صلِّ على النبي صلى الله عليه وسلم (الصلاة الإبراهيمية)، ثم ادعُ بما شئت.', PhosphorIconsRegular.flowerLotus,
            dhikr: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ، اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ'),
        GuideStep('التسليم', 'التفت عن يمينك ثم عن يسارك قائلًا:', PhosphorIconsRegular.arrowsLeftRight, dhikr: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ'),
      ]),
      GuideSection('الصلاة الثلاثية والرباعية', [
        GuideStep('بعد التشهد الأول', 'في المغرب والظهر والعصر والعشاء: بعد التشهد الأول في الركعة الثانية قم مكبّرًا رافعًا يديك.', PhosphorIconsRegular.arrowUp),
        GuideStep('الركعات الباقية', 'اقرأ فيها الفاتحة فقط، ثم اجلس للتشهد الأخير وسلّم.', PhosphorIconsRegular.listNumbers),
      ]),
    ],
    note: 'هذه صفة مختصرة على قول جمهور العلماء، ولبعض المذاهب تفاصيل في السنن والهيئات.',
  );

  static const talbiyah = 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، لَا شَرِيكَ لَكَ';

  static const hajj = Guide(
    'hajj',
    'الحج والعمرة',
    'المناسك خطوة بخطوة',
    'assets/images/hero_night.jpg',
    [
      GuideSection('العمرة', [
        GuideStep('الإحرام من الميقات', 'اغتسل وتطيّب في بدنك، ويلبس الرجل إزارًا ورداءً أبيضين، ثم انوِ العمرة قائلًا «لَبَّيْكَ عُمْرَةً».', PhosphorIconsRegular.tShirt),
        GuideStep('التلبية', 'أكثر من التلبية حتى تبدأ الطواف:', PhosphorIconsRegular.speakerHigh, dhikr: talbiyah),
        GuideStep('الطواف', 'طف سبعة أشواط حول الكعبة، تبدأ من الحجر الأسود وتجعل الكعبة عن يسارك، ويُسنّ للرجل الاضطباع، والرمل في الأشواط الثلاثة الأولى.', PhosphorIconsRegular.arrowsClockwise),
        GuideStep('ركعتا الطواف', 'صلِّ ركعتين خلف مقام إبراهيم إن تيسّر، أو في أي مكان من المسجد.', PhosphorIconsRegular.handsPraying),
        GuideStep('السعي', 'اسعَ بين الصفا والمروة سبعة أشواط، تبدأ بالصفا وتنتهي بالمروة.', PhosphorIconsRegular.personSimpleWalk),
        GuideStep('الحلق أو التقصير', 'يحلق الرجل رأسه أو يقصّره، والحلق أفضل، وتقصّر المرأة من شعرها قدر أنملة. وبهذا تتم العمرة.', PhosphorIconsRegular.scissors),
      ]),
      GuideSection('الحج (التمتع)', intro: 'أركان الحج: الإحرام، والوقوف بعرفة، وطواف الإفاضة، والسعي.', [
        GuideStep('يوم التروية · 8 ذو الحجة', 'أحرم بالحج من مكانك وتوجّه إلى منى، وصلِّ بها الظهر والعصر والمغرب والعشاء والفجر، كل صلاة في وقتها مع قصر الرباعية.', PhosphorIconsRegular.tent),
        GuideStep('يوم عرفة · 9 ذو الحجة', 'سر إلى عرفة، وصلِّ الظهر والعصر جمعًا وقصرًا، وقف بعرفة إلى غروب الشمس مكثرًا من الذكر والدعاء. «الحج عرفة».', PhosphorIconsRegular.mountains,
            dhikr: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ'),
        GuideStep('مزدلفة · ليلة 10', 'بعد الغروب انصرف إلى مزدلفة، وصلِّ المغرب والعشاء جمعًا، وبِتْ بها حتى تصلي الفجر، وتلتقط الحصى.', PhosphorIconsRegular.moonStars),
        GuideStep('يوم النحر · 10 ذو الحجة', 'ارمِ جمرة العقبة بسبع حصيات مكبّرًا مع كل حصاة، ثم اذبح الهدي، ثم احلق أو قصّر، ثم طف طواف الإفاضة واسعَ سعي الحج.', PhosphorIconsRegular.flag),
        GuideStep('أيام التشريق · 11 - 13', 'بِتْ بمنى، وارمِ الجمرات الثلاث كل يوم بعد الزوال: الصغرى ثم الوسطى ثم العقبة، ويجوز التعجل بعد رمي اليوم الثاني عشر.', PhosphorIconsRegular.circlesThree),
        GuideStep('طواف الوداع', 'آخر ما تفعله قبل السفر من مكة، ويسقط عن الحائض والنفساء.', PhosphorIconsRegular.handWaving),
      ]),
    ],
    note: 'مختصر على صفة حج النبي صلى الله عليه وسلم في حديث جابر رضي الله عنه (رواه مسلم). راجع مرشدي حملتك وأهل العلم في التفاصيل.',
  );
}
