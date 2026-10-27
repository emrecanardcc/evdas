import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/presentation/widgets/staggered_fade_slide.dart';

void main() {
  group('StaggeredFadeSlide Widget Tests', () {
    testWidgets('Temel render testi: Widget ve içeriği ekranda görünür olmalıdır',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredFadeSlide(
              index: 0,
              child: Text('Test Öğesi'),
            ),
          ),
        ),
      );

      // Başlangıçta render edilmeli
      expect(find.text('Test Öğesi'), findsOneWidget);

      // Animasyon tamamlandığında hala yerinde olmalı
      await tester.pumpAndSettle();
      expect(find.text('Test Öğesi'), findsOneWidget);
    });

    testWidgets('Gecikmeli stagger ve indeks artışı testi',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StaggeredFadeSlide(index: 0, child: Text('Öğe 0')),
                StaggeredFadeSlide(index: 2, child: Text('Öğe 2')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Öğe 0'), findsOneWidget);
      expect(find.text('Öğe 2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Öğe 0'), findsOneWidget);
      expect(find.text('Öğe 2'), findsOneWidget);
    });
  });
}
