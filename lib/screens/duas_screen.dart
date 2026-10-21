import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../theme/app_theme.dart';
import 'azkar_screen.dart';
import 'home_screen.dart';

class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});
  @override
  Widget build(BuildContext context) => GlassPage(
        title: 'الأدعية',
        child: FutureBuilder(
          future: ContentService.duas(),
          builder: (context, snap) => !snap.hasData
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : CategoryList(categories: snap.data!),
        ),
      );
}
