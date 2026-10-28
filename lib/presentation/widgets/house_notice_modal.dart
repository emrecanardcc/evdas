import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/house_notice_service.dart';
import '../../data/models/house_notice_board.dart';
import '../providers/app_providers.dart';

/// Ev Panosu ve Acil Durum Bilgileri Modalı
class HouseNoticeModal extends ConsumerStatefulWidget {
  const HouseNoticeModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HouseNoticeModal(),
    );
  }

  @override
  ConsumerState<HouseNoticeModal> createState() => _HouseNoticeModalState();
}

class _HouseNoticeModalState extends ConsumerState<HouseNoticeModal> {
  final TextEditingController _ruleController = TextEditingController();

  @override
  void dispose() {
    _ruleController.dispose();
    super.dispose();
  }

  void _addNewRule() {
    final text = _ruleController.text.trim();
    if (text.isEmpty) return;

    HapticService.selection();
    ref.read(houseNoticeProvider.notifier).addRule(text);
    _ruleController.clear();
  }

  void _showEditBoardDialog(HouseNoticeBoard board) {
    final ssidCtrl = TextEditingController(text: board.wifiSsid);
    final passCtrl = TextEditingController(text: board.wifiPassword);
    final doorCtrl = TextEditingController(text: board.buildingDoorCode ?? '');
    final trashCtrl = TextEditingController(text: board.trashSchedule ?? '');
    final boilerCtrl =
        TextEditingController(text: board.boilerValveLocation ?? '');
    final waterCtrl =
        TextEditingController(text: board.mainWaterValveLocation ?? '');
    final electricCtrl =
        TextEditingController(text: board.electricalPanelLocation ?? '');
    final keyCtrl = TextEditingController(text: board.spareKeyLocation ?? '');
    final landNameCtrl =
        TextEditingController(text: board.landlordName ?? '');
    final landPhoneCtrl =
        TextEditingController(text: board.landlordPhone ?? '');
    final landIbanCtrl =
        TextEditingController(text: board.landlordIban ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text('Ev Panosu Bilgilerini Düzenle',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Wi-Fi Bilgileri',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ssidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi Ağ Adı (SSID)',
                      prefixIcon: Icon(Icons.wifi_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi Şifresi',
                      prefixIcon: Icon(Icons.key_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Bina & Kapı',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: doorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bina Dış Kapı Şifresi',
                      prefixIcon: Icon(Icons.pin_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: trashCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Çöp Çıkarma Saatleri',
                      prefixIcon: Icon(Icons.delete_outline_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Tesisat & Acil Durum',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: boilerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kombi Su Vanası Yeri / Notu',
                      prefixIcon: Icon(Icons.thermostat_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: waterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ana Su Vanası Yeri',
                      prefixIcon: Icon(Icons.water_drop_outlined, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: electricCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sigorta Panosu Yeri',
                      prefixIcon: Icon(Icons.bolt_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: keyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Yedek Anahtar Nerede / Kimde',
                      prefixIcon: Icon(Icons.vpn_key_outlined, size: 20),
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Ev Sahibi & Kira IBAN',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: landNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ev Sahibi / Yönetici Adı',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: landPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'İletişim Telefonu',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: landIbanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kira / Aidat IBAN',
                      prefixIcon:
                          Icon(Icons.account_balance_outlined, size: 20),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = board.copyWith(
                  wifiSsid: ssidCtrl.text.trim(),
                  wifiPassword: passCtrl.text.trim(),
                  buildingDoorCode: doorCtrl.text.trim().isEmpty
                      ? null
                      : doorCtrl.text.trim(),
                  trashSchedule: trashCtrl.text.trim().isEmpty
                      ? null
                      : trashCtrl.text.trim(),
                  boilerValveLocation: boilerCtrl.text.trim().isEmpty
                      ? null
                      : boilerCtrl.text.trim(),
                  mainWaterValveLocation: waterCtrl.text.trim().isEmpty
                      ? null
                      : waterCtrl.text.trim(),
                  electricalPanelLocation: electricCtrl.text.trim().isEmpty
                      ? null
                      : electricCtrl.text.trim(),
                  spareKeyLocation: keyCtrl.text.trim().isEmpty
                      ? null
                      : keyCtrl.text.trim(),
                  landlordName: landNameCtrl.text.trim().isEmpty
                      ? null
                      : landNameCtrl.text.trim(),
                  landlordPhone: landPhoneCtrl.text.trim().isEmpty
                      ? null
                      : landPhoneCtrl.text.trim(),
                  landlordIban: landIbanCtrl.text.trim().isEmpty
                      ? null
                      : landIbanCtrl.text.trim(),
                );

                ref.read(houseNoticeProvider.notifier).updateNoticeBoard(updated);
                Navigator.pop(ctx);
                HapticService.success();
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final house = ref.watch(householdProvider);
    final board = ref.watch(houseNoticeProvider) ??
        HouseNoticeBoard.initial(house?.id ?? 'house');
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // TUTAMAÇ ŞERİDİ
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // BAŞLIK BÖLÜMÜ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ev Panosu ve Acil Bilgiler',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Wi-Fi, vanalar, kapı şifresi ve ev kuralları',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Düzenle',
                    onPressed: () => _showEditBoardDialog(board),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // İÇERİK LİSTESİ
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // 1. WI-FI BİLGİ KARTI
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.wifi_rounded,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Ev İnterneti (Wi-Fi)',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.router_outlined,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  board.wifiSsid.isNotEmpty
                                      ? board.wifiSsid
                                      : 'Ağ adı belirtilmedi',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (board.wifiSsid.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 14),
                                  label: const Text('Kopyala',
                                      style: TextStyle(fontSize: 11)),
                                  onPressed: () =>
                                      HouseNoticeNotifier.copyToClipboard(
                                          context,
                                          board.wifiSsid,
                                          'Wi-Fi Ağ Adı'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.key_rounded,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  board.wifiPassword.isNotEmpty
                                      ? board.wifiPassword
                                      : 'Şifre belirtilmedi',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8),
                                ),
                              ),
                              if (board.wifiPassword.isNotEmpty)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 14),
                                  label: const Text('Şifreyi Kopyala',
                                      style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () =>
                                      HouseNoticeNotifier.copyToClipboard(
                                          context,
                                          board.wifiPassword,
                                          'Wi-Fi Şifresi'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2. DIŞ KAPI & ÇÖP KARTI
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.apartment_rounded,
                                    color: Colors.amber, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Bina ve Giriş Bilgileri',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (board.buildingDoorCode != null &&
                              board.buildingDoorCode!.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.pin_rounded,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text('Dış Kapı Şifresi: ',
                                    style: TextStyle(fontSize: 12)),
                                Text(
                                  board.buildingDoorCode!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 16),
                                  tooltip: 'Kopyala',
                                  onPressed: () =>
                                      HouseNoticeNotifier.copyToClipboard(
                                          context,
                                          board.buildingDoorCode!,
                                          'Kapı Şifresi'),
                                ),
                              ],
                            ),
                          if (board.trashSchedule != null &&
                              board.trashSchedule!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.delete_outline_rounded,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Çöp Çıkarma: ${board.trashSchedule}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 3. TESİSAT & ACİL DURUM NOKTALARI
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.personalDebt
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.plumbing_rounded,
                                    color: AppColors.personalDebt, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Tesisat ve Acil Durum',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (board.boilerValveLocation != null) ...[
                            _buildInfoRow(
                              Icons.thermostat_rounded,
                              'Kombi Su Vanası',
                              board.boilerValveLocation!,
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (board.mainWaterValveLocation != null) ...[
                            _buildInfoRow(
                              Icons.water_drop_outlined,
                              'Ana Su Vanası',
                              board.mainWaterValveLocation!,
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (board.electricalPanelLocation != null) ...[
                            _buildInfoRow(
                              Icons.bolt_rounded,
                              'Sigorta Panosu',
                              board.electricalPanelLocation!,
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (board.spareKeyLocation != null)
                            _buildInfoRow(
                              Icons.vpn_key_outlined,
                              'Yedek Anahtar',
                              board.spareKeyLocation!,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. EV SAHİBİ & KİRA IBAN KARTI
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.positive
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.contact_phone_rounded,
                                    color: AppColors.positive, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Ev Sahibi ve Kira Bilgileri',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (board.landlordName != null) ...[
                            _buildInfoRow(
                              Icons.person_outline_rounded,
                              'İsim',
                              board.landlordName!,
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (board.landlordPhone != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tel: ${board.landlordPhone}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 14),
                                  label: const Text('Kopyala',
                                      style: TextStyle(fontSize: 11)),
                                  onPressed: () =>
                                      HouseNoticeNotifier.copyToClipboard(
                                          context,
                                          board.landlordPhone!,
                                          'Telefon Numarası'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (board.landlordIban != null)
                            Row(
                              children: [
                                const Icon(Icons.account_balance_outlined,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'IBAN: ${board.landlordIban}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 14),
                                  label: const Text('IBAN Kopyala',
                                      style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () =>
                                      HouseNoticeNotifier.copyToClipboard(
                                          context,
                                          board.landlordIban!,
                                          'Kira IBAN'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 5. EV İÇİ ANLAŞMALAR VE KURALLAR
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.gavel_rounded,
                                    color: Colors.purple, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Ev İçi Kurallar ve Düzen',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (board.customRules.isEmpty)
                            const Text(
                              'Henüz belirlenmiş özel bir kural yok.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          else
                            ...List.generate(board.customRules.length, (idx) {
                              final rule = board.customRules[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(Icons.circle,
                                          size: 6, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        rule,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        HapticService.light();
                                        ref
                                            .read(houseNoticeProvider.notifier)
                                            .removeRule(idx);
                                      },
                                      child: const Icon(Icons.close_rounded,
                                          size: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ruleController,
                                  onSubmitted: (_) => _addNewRule(),
                                  decoration: InputDecoration(
                                    hintText: 'Yeni kural ekle...',
                                    hintStyle: const TextStyle(fontSize: 12),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_rounded),
                                tooltip: 'Kural Ekle',
                                onPressed: _addNewRule,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
