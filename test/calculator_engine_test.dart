import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/core/utils/calculator_engine.dart';

void main() {
  group('CalculatorEngine Unit Tests', () {
    test('Temel toplama ve çıkarma işlemlerini doğru hesaplamalıdır', () {
      expect(CalculatorEngine.evaluate('100 + 50'), 150.0);
      expect(CalculatorEngine.evaluate('250.50 - 50.25'), 200.25);
    });

    test('Çarpma ve bölme işlemlerini ve sembollerini (×, ÷) doğru hesaplamalıdır', () {
      expect(CalculatorEngine.evaluate('12 * 5'), 60.0);
      expect(CalculatorEngine.evaluate('12 × 5'), 60.0);
      expect(CalculatorEngine.evaluate('100 / 4'), 25.0);
      expect(CalculatorEngine.evaluate('100 ÷ 4'), 25.0);
    });

    test('İşlem önceliğini (çarpma/bölme önce) doğru uygulamalıdır', () {
      expect(CalculatorEngine.evaluate('10 + 2 * 5'), 20.0);
      expect(CalculatorEngine.evaluate('50 - 20 / 2'), 40.0);
    });

    test('Yüzde (%) ifadelerini doğru çözümlemelidir', () {
      expect(CalculatorEngine.evaluate('200 * 10%'), 20.0);
      expect(CalculatorEngine.evaluate('500 * 20%'), 100.0);
      expect(CalculatorEngine.evaluate('200 + 10%'), 220.0);
      expect(CalculatorEngine.evaluate('200 - 10%'), 180.0);
    });

    test('Virgüllü (Türkçe format) ve sondaki tamamlanmamış işleçleri güvenle tolere etmelidir', () {
      expect(CalculatorEngine.evaluate('12,5 + 7,5'), 20.0);
      expect(CalculatorEngine.evaluate('150 +'), 150.0);
      expect(CalculatorEngine.evaluate('150 ×'), 150.0);
      expect(CalculatorEngine.evaluate('150 + %'), 150.0);
      expect(CalculatorEngine.evaluate('150.'), 150.0);
      expect(CalculatorEngine.evaluate('150 + .'), 150.0);
      expect(CalculatorEngine.evaluate('%'), 0.0);
      expect(CalculatorEngine.evaluate(''), 0.0);
      expect(CalculatorEngine.evaluate('    '), 0.0);
    });

    test('Ondalıklı zincirleme işlemleri ve negatif sayıları doğru hesaplamalıdır', () {
      expect(CalculatorEngine.evaluate('15.5 + 2.5'), 18.0);
      expect(CalculatorEngine.evaluate('100 * -5'), -500.0);
      expect(CalculatorEngine.evaluate('100 / -4'), -25.0);
    });

    test('Sıfıra bölme durumunda güvenle çökmeden sonuç vermelidir', () {
      final res = CalculatorEngine.evaluate('100 / 0');
      expect(res, isA<double>());
    });
  });
}
