import 'dart:convert';
import 'dart:math';

/// Kriptolojik Olarak Güvenli Davet Kodu ve Token Üreteci
/// Kötü niyetli kişilerin kod tahmin etmesini (brute-force) ve
/// başkalarının ortaklıklarına izinsiz sızmasını engeller.
class CryptoUtils {
  // Karışıklığı önlemek için benzer harfler (0, O, 1, I) çıkarılmıştır
  static const String _safeAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static final Random _secureRandom = Random.secure();

  /// Kriptolojik olarak güvenli 8 haneli kod ve 2 haneli sağlama (checksum) üretir.
  /// Örn: "ORTAK-7K9M-2X4V"
  static String generateSecureInviteCode({String prefix = 'ORTAK'}) {
    final buffer = StringBuffer();

    // 8 rastgele güvenli karakter
    for (int i = 0; i < 8; i++) {
      final index = _secureRandom.nextInt(_safeAlphabet.length);
      buffer.write(_safeAlphabet[index]);
    }

    final body = buffer.toString();
    final checksum = _calculateChecksum(body);

    // Format: ORTAK-XXXX-XXXX-CC
    final part1 = body.substring(0, 4);
    final part2 = body.substring(4, 8);

    return '$prefix-$part1-$part2-$checksum';
  }

  /// 128-bit kriptografik URL token üretir (Deep-link için)
  static String generateSecureDeepLinkToken() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Kodun geçerliliğini ve sağlama toplamını kontrol eder
  static bool validateInviteCode(String code) {
    final clean = code.trim().toUpperCase();
    final parts = clean.split('-');

    // En az 4 parça olmalı: [PREFIX, PART1, PART2, CHECKSUM]
    if (parts.length < 4) return false;

    final body = parts[1] + parts[2];
    final expectedChecksum = parts[3];

    if (body.length != 8) return false;

    for (int i = 0; i < body.length; i++) {
      if (!_safeAlphabet.contains(body[i])) return false;
    }

    return _calculateChecksum(body) == expectedChecksum;
  }

  /// 2 haneli sağlama toplamı hesaplar (Typo ve kurcalama koruması)
  static String _calculateChecksum(String input) {
    int sum = 0;
    for (int i = 0; i < input.length; i++) {
      final charCode = input.codeUnitAt(i);
      sum = (sum * 31 + charCode * (i + 1)) % 1000;
    }
    final c1 = _safeAlphabet[sum % _safeAlphabet.length];
    final c2 = _safeAlphabet[(sum ~/ _safeAlphabet.length) % _safeAlphabet.length];
    return '$c1$c2';
  }
}
