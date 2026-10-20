import 'package:share_plus/share_plus.dart';
import '../../data/models/settlement_item.dart';
import '../utils/currency_formatter.dart';

class ShareService {
  /// Ortaklık davet kodunu sistem paylaşım menüsü üzerinden paylaşır
  static Future<void> shareInviteCode({
    required String householdName,
    required String inviteCode,
  }) async {
    final message = '''
🤝 $householdName ortaklığına davet edildiniz!

Ortak masraflarımızı, harcamalarımızı ve borç mahsuplaşmasını Evdaş uygulaması ile kolayca takip ediyoruz.

Uygulamayı indirip aşağıdaki davet koduyla ortaklığımıza hemen katılabilirsiniz:
🔑 Davet Kodu: $inviteCode

Evdaş uygulamasını indir ve masrafları anında bölüşelim!
''';

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: '$householdName Ortaklık Daveti - Evdaş',
      ),
    );
  }

  /// Hesaplaşma / Ödeşme özetini ortaklarla paylaşmak için metin üretir ve paylaşır
  static Future<void> shareSettlementSummary({
    required String householdName,
    required double totalExpenses,
    required List<SettlementItem> settlements,
    String? ibanInfo,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('📊 *$householdName - Masraf & Hesaplaşma Özeti*');
    buffer.writeln('------------------------------------');
    buffer.writeln('💰 Toplam Ortak Harcama: ${CurrencyFormatter.formatClean(totalExpenses)}');
    buffer.writeln('------------------------------------');
    buffer.writeln('*Ödeşme Durumu:*');

    if (settlements.isEmpty) {
      buffer.writeln('✅ Hesaplar tamamen denk, kimsenin borcu bulunmuyor.');
    } else {
      for (final item in settlements) {
        buffer.writeln('👉 *${item.fromMemberName}* ➔ *${item.toMemberName}*: ${CurrencyFormatter.formatClean(item.amount)}');
      }
    }

    if (ibanInfo != null && ibanInfo.trim().isNotEmpty) {
      buffer.writeln('------------------------------------');
      buffer.writeln('💳 *Ödeme Bilgileri (IBAN):*');
      buffer.writeln(ibanInfo.trim());
    }

    buffer.writeln('------------------------------------');
    buffer.writeln('✨ Evdaş ile hesaplandı');

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: '$householdName Masraf Özeti',
      ),
    );
  }
}
