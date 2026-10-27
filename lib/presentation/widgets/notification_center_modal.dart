import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/reminder_service.dart';
import 'approval_center_modal.dart';
import 'staggered_fade_slide.dart';

/// Bildirim ve Hatırlatıcı Merkezi Modalı
class NotificationCenterModal extends ConsumerWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const NotificationCenterModal({
    super.key,
    this.onNavigateTab,
  });

  static Future<void> show(
    BuildContext context, {
    void Function(int tabIndex)? onNavigateTab,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationCenterModal(onNavigateTab: onNavigateTab),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderState = ref.watch(reminderProvider);
    final items = reminderState.items;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Tutamaç
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Başlık ve Eylemler
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bildirim Merkezi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        items.isEmpty
                            ? 'Tüm bildirimler güncel'
                            : '${items.length} aktif bildirim',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      HapticService.light();
                      ref.read(reminderProvider.notifier).markAllAsRead();
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text(
                      'Tümünü Oku',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Liste veya Boş Durum
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 48,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Her Şey Güncel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Şu anda bekleyen bir onay, gecikmiş ödeşme veya hatırlatıcı bulunmuyor.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return StaggeredFadeSlide(
                        index: index,
                        child: _buildReminderCard(context, ref, item, isDark),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    WidgetRef ref,
    ReminderItem item,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? (item.isRead ? const Color(0xFF0F172A) : const Color(0xFF1E293B))
            : (item.isRead ? Colors.white : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isRead
              ? (isDark ? Colors.white10 : Colors.black12)
              : item.type.color.withValues(alpha: 0.35),
          width: item.isRead ? 1.0 : 1.5,
        ),
        boxShadow: item.isRead
            ? null
            : [
                BoxShadow(
                  color: item.type.color.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Kategori İkonu, Tür Rozeti, Okunmadı Noktası ve Kapatma Butonu
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: item.type.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.type.icon,
                    size: 16,
                    color: item.type.color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.type.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: item.type.color,
                  ),
                ),
                if (!item.isRead) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: item.type.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatTime(item.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  tooltip: 'Kaldır',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    HapticService.light();
                    ref.read(reminderProvider.notifier).dismiss(item.id);
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Başlık
            Text(
              item.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
              ),
            ),

            const SizedBox(height: 4),

            // Açıklama Metni
            Text(
              item.message,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.8),
              ),
            ),

            // Eylem Butonu
            if (item.actionRoute != null && item.actionLabel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticService.medium();
                    ref.read(reminderProvider.notifier).markAsRead(item.id);
                    Navigator.of(context).pop();

                    _handleAction(context, item.actionRoute!);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(
                    item.actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: item.type.color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String route) {
    if (route == 'settlement') {
      onNavigateTab?.call(3); // Ödeşme Sekmesi
    } else if (route == 'quick_expense') {
      onNavigateTab?.call(0); // Hızlı Harcama
    } else if (route == 'reports') {
      onNavigateTab?.call(2); // Raporlar Sekmesi
    } else if (route == 'approvals') {
      ApprovalCenterModal.show(context);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Az önce' : '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else {
      return '${diff.inDays} gün önce';
    }
  }
}
