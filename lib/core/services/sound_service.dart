import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  SoundService._();

  static const String _keySoundEnabled = 'evdas_sound_effects_enabled_v1';
  static bool _soundEnabled = true;

  static bool get isEnabled => _soundEnabled;

  static Future<void> init(SharedPreferences prefs) async {
    _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
  }

  static Future<void> setEnabled(bool enabled, SharedPreferences prefs) async {
    _soundEnabled = enabled;
    await prefs.setBool(_keySoundEnabled, enabled);
  }

  /// Numpad tuş basma tık sesi
  static void playNumpadTick() {
    if (!_soundEnabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Masraf kayıt "Ka-Ching" / Yazar kasa efekti (Düşük gecikmeli çift vuruş sentezi)
  static void playKaChing() {
    if (!_soundEnabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
      Future.delayed(const Duration(milliseconds: 70), () {
        SystemSound.play(SystemSoundType.click);
      });
      Future.delayed(const Duration(milliseconds: 140), () {
        SystemSound.play(SystemSoundType.alert);
      });
    } catch (_) {}
  }

  /// Karar Çarkı her dilim geçtiğindeki tıkırtı sesi
  static void playWheelTick() {
    if (!_soundEnabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Borçlar kapandığında veya ödeme onaylandığında zafer melodisi efekti
  static void playSettlementChime() {
    if (!_soundEnabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
      Future.delayed(const Duration(milliseconds: 100), () {
        SystemSound.play(SystemSoundType.click);
      });
      Future.delayed(const Duration(milliseconds: 220), () {
        SystemSound.play(SystemSoundType.alert);
      });
    } catch (_) {}
  }
}
