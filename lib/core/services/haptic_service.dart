import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/customization_models.dart';

class HapticService {
  HapticService._();

  static const String _keyHapticLevel = 'evdas_haptic_level_v1';
  static HapticLevel _currentLevel = HapticLevel.medium;

  static HapticLevel get level => _currentLevel;

  static Future<void> init(SharedPreferences prefs) async {
    final raw = prefs.getString(_keyHapticLevel);
    if (raw != null) {
      _currentLevel = HapticLevel.values.firstWhere(
        (l) => l.name == raw,
        orElse: () => HapticLevel.medium,
      );
    }
  }

  static Future<void> setLevel(HapticLevel newLevel, SharedPreferences prefs) async {
    _currentLevel = newLevel;
    await prefs.setString(_keyHapticLevel, newLevel.name);
  }

  static void light() {
    if (_currentLevel == HapticLevel.off) return;
    if (_currentLevel == HapticLevel.strong) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  static void medium() {
    if (_currentLevel == HapticLevel.off) return;
    if (_currentLevel == HapticLevel.light) {
      HapticFeedback.lightImpact();
    } else if (_currentLevel == HapticLevel.strong) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  static void heavy() {
    if (_currentLevel == HapticLevel.off) return;
    if (_currentLevel == HapticLevel.light) {
      HapticFeedback.lightImpact();
    } else if (_currentLevel == HapticLevel.medium) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  static void selection() {
    if (_currentLevel == HapticLevel.off) return;
    HapticFeedback.selectionClick();
  }

  static void success() {
    if (_currentLevel == HapticLevel.off) return;
    if (_currentLevel == HapticLevel.strong) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  static void error() {
    if (_currentLevel == HapticLevel.off) return;
    HapticFeedback.heavyImpact();
  }
}
