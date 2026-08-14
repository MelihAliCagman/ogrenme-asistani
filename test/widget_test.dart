import 'package:flutter_test/flutter_test.dart';

import 'package:ogrenme_asistani/main.dart';

void main() {
  testWidgets('Splash screen shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(const OgrenmeAsistaniApp());

    expect(find.text('Öğrenme Asistanı'), findsOneWidget);

    // Flush the splash screen's navigation timer before the test tears down.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Main screen shows bottom navigation tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OgrenmeAsistaniApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Sohbet'), findsWidgets);
    expect(find.text('Setlerim'), findsWidgets);
    expect(find.text('Dersler'), findsWidgets);
    expect(find.text('Profil'), findsWidgets);
  });
}
