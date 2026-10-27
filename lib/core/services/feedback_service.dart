import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';

enum FeedbackType {
  suggestion('Öneri ve Fikir'),
  bug('Hata Bildirimi'),
  complaint('Şikayet'),
  support('Soru ve Destek');

  final String label;
  const FeedbackType(this.label);

  IconData get icon {
    switch (this) {
      case FeedbackType.suggestion:
        return Icons.lightbulb_outline_rounded;
      case FeedbackType.bug:
        return Icons.bug_report_outlined;
      case FeedbackType.complaint:
        return Icons.warning_amber_rounded;
      case FeedbackType.support:
        return Icons.help_outline_rounded;
    }
  }
}

class FeedbackService {
  FeedbackService._();

  static const String supportEmail = 'emrecanardc.dev@gmail.com';
  static const String appVersion = '1.0.0 (Build 1)';

  /// E-posta istemcisini açar veya panoya kopyalar
  static Future<bool> sendFeedback({
    required FeedbackType type,
    required String userMessage,
    String? activePartnershipName,
  }) async {
    final user = SupabaseService.currentUser;
    final now = DateTime.now().toIso8601String();
    final platform = defaultTargetPlatform.name;

    final subject = '[Evdaş Destek] ${type.label} - ${user?.email ?? "Anonim"}';

    final body = '''
Kategori: ${type.label}
Tarih: $now
Uygulama Sürümü: $appVersion
İşletim Sistemi: $platform
Kullanıcı ID: ${user?.id ?? "Giriş Yapılmamış"}
Kullanıcı E-Posta: ${user?.email ?? "Belirtilmemiş"}
Aktif Ortaklık: ${activePartnershipName ?? "Yok"}

--------------------------------------------------
MESAJINIZ:
$userMessage
--------------------------------------------------
''';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: _encodeQueryParameters(<String, String>{
        'subject': subject,
        'body': body,
      }),
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        return await launchUrl(emailLaunchUri);
      }
    } catch (_) {}

    // E-posta istemcisi açılamazsa panoya kopyala
    await Clipboard.setData(ClipboardData(
      text: 'Kime: $supportEmail\nKonu: $subject\n\n$body',
    ));
    return false;
  }

  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
