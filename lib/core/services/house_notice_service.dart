import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../data/models/house_notice_board.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/customization_provider.dart';

/// Ev Panosu ve Acil Durum Yönetim Notifier'ı (Riverpod 3.x)
class HouseNoticeNotifier extends Notifier<HouseNoticeBoard?> {
  static const String _prefPrefix = 'evdas_house_notice_board_';

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  HouseNoticeBoard? build() {
    final house = ref.watch(householdProvider);
    if (house == null) return null;

    final prefs = _prefs;
    if (prefs == null) return _loadInitialForHousehold(house.id);

    final key = '$_prefPrefix${house.id}';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        return HouseNoticeBoard.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[HouseNoticeService] Ayrıştırma hatası: $e');
      }
    }

    return _loadInitialForHousehold(house.id);
  }

  HouseNoticeBoard _loadInitialForHousehold(String householdId) {
    return HouseNoticeBoard(
      householdId: householdId,
      wifiSsid: 'Kadikoy_Evi_5G',
      wifiPassword: 'KadikoyEvdas2026',
      buildingDoorCode: '1453#',
      trashSchedule: 'Her akşam 20:00 - 21:00 arası kapı önüne',
      boilerValveLocation:
          'Mutfak tezgahı altındaki mavi kelebek vana (1.5 bar olmalı)',
      mainWaterValveLocation:
          'Daire kapısı dışı, su saati solundaki kırmızı vana',
      electricalPanelLocation:
          'Giriş holü vestiyer arkasındaki sigorta kutusu',
      spareKeyLocation:
          'Vestiyer üst çekmecesi / Can da yedek anahtar var',
      landlordName: 'Ahmet Bey (Ev Sahibi)',
      landlordPhone: '0532 555 12 34',
      landlordIban: 'TR33 0006 1005 1234 5678 9012 34',
      customRules: const [
        'Gece 23:30 dan sonra ortak alanda sessizlik',
        'Mutfak tezgahı ve lavabo kullandıktan sonra temiz bırakılır',
        'Kapıda ayakkabı bırakılmaz, ayakkabılığa yerleştirilir',
        'Balkon kapısı kışın cereyan yapmaması için kapalı tutulur',
      ],
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _persist(HouseNoticeBoard board) async {
    state = board;
    final prefs = _prefs;
    if (prefs != null) {
      final key = '$_prefPrefix${board.householdId}';
      await prefs.setString(key, jsonEncode(board.toJson()));
    }
  }

  Future<void> updateNoticeBoard(HouseNoticeBoard updated) async {
    final finalBoard = updated.copyWith(updatedAt: DateTime.now());
    await _persist(finalBoard);
  }

  Future<void> addRule(String rule) async {
    final current = state;
    if (current == null || rule.trim().isEmpty) return;

    final updatedRules = List<String>.from(current.customRules)..add(rule.trim());
    final updated = current.copyWith(
      customRules: updatedRules,
      updatedAt: DateTime.now(),
    );
    await _persist(updated);
  }

  Future<void> removeRule(int index) async {
    final current = state;
    if (current == null || index < 0 || index >= current.customRules.length) {
      return;
    }

    final updatedRules = List<String>.from(current.customRules)..removeAt(index);
    final updated = current.copyWith(
      customRules: updatedRules,
      updatedAt: DateTime.now(),
    );
    await _persist(updated);
  }

  /// Metni panoya kopyalama ve geri bildirim
  static Future<void> copyToClipboard(
    BuildContext context,
    String text,
    String label,
  ) async {
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
                  '$label panoya kopyalandı.',
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

/// Ev Panosu Provider
final houseNoticeProvider =
    NotifierProvider<HouseNoticeNotifier, HouseNoticeBoard?>(
        HouseNoticeNotifier.new);
