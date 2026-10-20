import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/core/utils/crypto_utils.dart';

void main() {
  group('CryptoUtils Kriptolojik Güvenlik Testleri', () {
    test('Güvenli davet kodu üretimi ve doğrulama', () {
      final code = CryptoUtils.generateSecureInviteCode(prefix: 'EV');

      // Örn: EV-XXXX-XXXX-CC
      expect(code.startsWith('EV-'), true);
      final isValid = CryptoUtils.validateInviteCode(code);
      expect(isValid, true);
    });

    test('Kurcalanmış veya yanlış davet kodu reddedilmelidir', () {
      final validCode = CryptoUtils.generateSecureInviteCode(prefix: 'ORTAK');

      // Son karakteri değiştir (kurcalama simülasyonu)
      final tampered = '${validCode.substring(0, validCode.length - 1)}9';

      if (tampered != validCode) {
        expect(CryptoUtils.validateInviteCode(tampered), false);
      }

      // Rastgele geçersiz kodlar
      expect(CryptoUtils.validateInviteCode('1234'), false);
      expect(CryptoUtils.validateInviteCode('ORTAK-AAAA-BBBB-ZZ'), false);
      expect(CryptoUtils.validateInviteCode(''), false);
    });

    test('128-bit güvenli deep link token üretimi', () {
      final token1 = CryptoUtils.generateSecureDeepLinkToken();
      final token2 = CryptoUtils.generateSecureDeepLinkToken();

      expect(token1.isNotEmpty, true);
      expect(token2.isNotEmpty, true);
      expect(token1 != token2, true);
    });
  });
}
