import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/currency_formatter.dart';

class InstantSavedDialog {
  static Future<void> show(
    BuildContext context, {
    required double amount,
    required String title,
    required String paidByName,
    String? debtorName,
    bool isPersonal = false,
  }) async {
    HapticService.success();
    SoundService.playKaChing();

    if (!context.mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogCtx, anim1, anim2) {
        // Otomatik 1.8 saniye sonra kapatma
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (dialogCtx.mounted) {
            Navigator.of(dialogCtx, rootNavigator: true).maybePop();
          }
        });

        final color = isPersonal ? AppColors.personalDebt : AppColors.positive;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Theme.of(dialogCtx).cardTheme.color,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(Icons.check_rounded, color: color, size: 40),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '⚡ Masraf Kaydedildi!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatClean(amount),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPersonal
                          ? '$title\n($debtorName ➔ $paidByName)'
                          : '$title ($paidByName)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(dialogCtx).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogCtx, rootNavigator: true).maybePop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tamam'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
