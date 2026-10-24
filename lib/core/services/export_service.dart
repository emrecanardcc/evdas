import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_member.dart';
import '../../domain/reporting_engine.dart';
import '../utils/currency_formatter.dart';

class ExportService {
  ExportService._();

  /// Harcamaları CSV (Comma Separated Values / Excel Uyumlu) formatında hazırlar ve paylaşır
  static Future<void> exportExpensesToCsv({
    required List<Expense> expenses,
    required List<HouseholdMember> members,
    required String householdName,
  }) async {
    final memberMap = {for (final m in members) m.id: m.displayName};
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final buffer = StringBuffer();
    // Excel Türkçe için UTF-8 BOM ekle
    buffer.write('\uFEFF');
    // CSV Başlık Satırı
    buffer.writeln(
        'Tarih;Harcama Başlığı;Kategori;Tür;Tutar;Harcayan;Borçlu / Muhatap;Notlar');

    for (final exp in expenses) {
      final dateStr = dateFormat.format(exp.expenseDate);
      final title = _escapeCsv(exp.title);
      final category = _escapeCsv(exp.category.displayName);
      final type = exp.type == ExpenseType.joint
          ? (exp.splitMemberWeights != null
              ? 'Ortak Masraf (Özel Bölüşüm)'
              : 'Ortak Masraf')
          : exp.type == ExpenseType.personalDebt
              ? 'Şahsi Borç'
              : 'Ödeşme';
      final amount = exp.amount.toStringAsFixed(2).replaceAll('.', ',');
      final paidBy = _escapeCsv(memberMap[exp.paidByMemberId] ?? 'Bilinmeyen');
      final debtor = exp.debtorMemberId != null
          ? _escapeCsv(memberMap[exp.debtorMemberId] ?? '')
          : '';

      String notesStr = exp.notes ?? '';
      if (exp.splitMemberWeights != null && exp.splitMemberWeights!.isNotEmpty) {
        final weightsDesc = exp.splitMemberWeights!.entries
            .map((e) => '${memberMap[e.key] ?? e.key}: ${e.value.toStringAsFixed(0)}x')
            .join(', ');
        notesStr = notesStr.isEmpty
            ? 'Paylar: $weightsDesc'
            : '$notesStr (Paylar: $weightsDesc)';
      }
      final notes = _escapeCsv(notesStr);

      buffer.writeln(
          '$dateStr;$title;$category;$type;$amount;$paidBy;$debtor;$notes');
    }

    final csvContent = buffer.toString();
    await SharePlus.instance.share(
      ShareParams(
        text: csvContent,
        subject: '$householdName - Harcama Kayıtları (CSV)',
      ),
    );
  }

  /// Detaylı Finansal Özet Raporunu formatlı metin / döküman olarak dışa aktarır
  static Future<void> exportFormattedReport({
    required PartnershipReport report,
    required String householdName,
  }) async {
    final now = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
    final buffer = StringBuffer();

    buffer.writeln('==============================================');
    buffer.writeln('🏠 EVDAS FİNANSAL GİDER VE MAHSUPLAŞMA RAPORU');
    buffer.writeln('==============================================');
    buffer.writeln('Ortaklık: $householdName');
    buffer.writeln('Rapor Dönemi: ${report.timeRange.displayName}');
    buffer.writeln('Oluşturulma Tarihi: $now');
    buffer.writeln('----------------------------------------------');
    buffer.writeln('📊 GENEL ÖZET');
    buffer.writeln('Toplam Dönem Harcaması: ${CurrencyFormatter.formatClean(report.grandTotal)}');
    buffer.writeln('Ortak Ev Harcamaları: ${CurrencyFormatter.formatClean(report.totalJointExpenses)}');
    buffer.writeln('Kişi Başı Ortalama Pay: ${CurrencyFormatter.formatClean(report.perMemberAverage)}');
    buffer.writeln('Toplam Şahsi Borçlar: ${CurrencyFormatter.formatClean(report.totalPersonalDebts)}');
    buffer.writeln('Toplam İşlem Adedi: ${report.totalTransactionCount}');
    buffer.writeln('----------------------------------------------');

    if (report.categorySpends.isNotEmpty) {
      buffer.writeln('🛒 KATEGORİ DAĞILIMI:');
      for (final cat in report.categorySpends) {
        buffer.writeln(
            '  • ${cat.category.displayName}: ${CurrencyFormatter.formatClean(cat.amount)} (%${cat.percentage.toStringAsFixed(1)} - ${cat.count} işlem)');
      }
      buffer.writeln('----------------------------------------------');
    }

    if (report.memberSpends.isNotEmpty) {
      buffer.writeln('👥 ORTAKLARIN HARCAMA PAYLARI:');
      for (final mem in report.memberSpends) {
        buffer.writeln(
            '  • ${mem.member.displayName}: ${CurrencyFormatter.formatClean(mem.amount)} (%${mem.percentage.toStringAsFixed(1)})');
      }
      buffer.writeln('----------------------------------------------');
    }

    if (report.personalDebtsBreakdown.isNotEmpty) {
      buffer.writeln('🤝 ŞAHSİ (BİREBİR) BORÇLAR:');
      for (final debt in report.personalDebtsBreakdown) {
        buffer.writeln(
            '  • ${debt.debtorName} ➔ ${debt.creditorName}: ${CurrencyFormatter.formatClean(debt.amount)} (${debt.count} işlem)');
      }
      buffer.writeln('----------------------------------------------');
    }

    buffer.writeln('⚡ Evdaş Ortak Harcama Sistemi tarafından oluşturulmuştur.');

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: '$householdName - Finansal Raporu ($now)',
      ),
    );
  }

  static String _escapeCsv(String val) {
    if (val.contains(';') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
