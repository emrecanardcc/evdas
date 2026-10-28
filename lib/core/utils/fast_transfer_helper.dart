import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/haptic_service.dart';

/// FAST (Fonların Anlık ve Sürekli Transferi) ve IBAN Yardımcı Sınıfı
class FastTransferHelper {
  /// IBAN'ı boşluklardan arındırıp standart formata çeker
  static String cleanIban(String rawIban) {
    return rawIban.replaceAll(RegExp(r'\s+'), '').toUpperCase().trim();
  }

  /// IBAN'ı 4'erli bloklar halinde formatlar (TRxx xxxx xxxx xxxx xxxx xxxx xx)
  static String formatIban(String rawIban) {
    final cleaned = cleanIban(rawIban);
    if (cleaned.length < 4) return cleaned;

    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }

  /// FAST transferi için standart banka dekont açıklaması üretir
  static String buildRemittanceDescription({
    required String fromName,
    required String toName,
    required double amount,
  }) {
    return 'Evdas Odesme - $fromName -> $toName (${amount.toStringAsFixed(2)} TL)';
  }

  /// Banka mobil uygulamasına yapıştırılmak üzere tam FAST bilgi metni
  static String buildFullFastSummary({
    required String recipientName,
    required String iban,
    required double amount,
    required String fromName,
  }) {
    final cleanedIban = cleanIban(iban);
    return '''
Alıcı: $recipientName
IBAN: $cleanedIban
Tutar: ${amount.toStringAsFixed(2)} TL
Açıklama: Evdas Odesme - $fromName''';
  }

  /// IBAN'ı henüz kayıtlı olmayan alacaklıya gönderilecek nazik mesaj
  static String buildIbanRequestMessage({
    required String debtorName,
    required String creditorName,
    required double amount,
  }) {
    return 'Selam $creditorName, Evdaş üzerinden ${amount.toStringAsFixed(2)} TL tutarındaki ödemeni FAST ile göndermek istiyorum. Lütfen IBAN ını paylaşır mısın?';
  }

  /// Metni panoya kopyalar ve kullanıcıya şık vektörel bildirim verir
  static Future<void> copyWithFeedback(
    BuildContext context, {
    required String text,
    required String successMessage,
  }) async {
    if (text.trim().isEmpty) return;

    HapticService.light();
    await Clipboard.setData(ClipboardData(text: text.trim()));
    HapticService.selection();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  successMessage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.positive,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
