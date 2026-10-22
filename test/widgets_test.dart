import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/theme/app_theme.dart';
import 'package:noor/widgets/glass.dart';

void main() {
  testWidgets('GlassCard renders child and handles taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: GlassCard(onTap: () => taps++, child: const Text('نور')))),
      ),
    ));
    expect(find.text('نور'), findsOneWidget);
    await tester.tap(find.text('نور'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('AyahMedallion shows arabic number', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AyahMedallion(number: 255))));
    expect(find.text('٢٥٥'), findsOneWidget);
  });
}
