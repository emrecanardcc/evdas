import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/custom_category.dart';
import 'customization_provider.dart';

/// Kullanıcı Tanımlı Özel Kategoriler Notifier'ı
class CustomCategoryNotifier extends Notifier<List<CustomCategory>> {
  static const String prefKey = 'evdas_user_custom_categories';

  static final List<CustomCategory> defaultCustomCategories = [
    CustomCategory(
      id: 'custom_water',
      name: 'Damacana Su',
      iconCodePoint: Icons.water_drop_rounded.codePoint,
      colorValue: 0xFF0284C7,
    ),
    CustomCategory(
      id: 'custom_pet',
      name: 'Evcil Hayvan',
      iconCodePoint: Icons.pets_rounded.codePoint,
      colorValue: 0xFFF59E0B,
    ),
    CustomCategory(
      id: 'custom_entertainment',
      name: 'İçecek & Eğlence',
      iconCodePoint: Icons.celebration_rounded.codePoint,
      colorValue: 0xFF8B5CF6,
    ),
  ];

  late SharedPreferences _prefs;

  @override
  List<CustomCategory> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final rawList = _prefs.getStringList(prefKey);
    if (rawList == null || rawList.isEmpty) {
      return defaultCustomCategories;
    }

    try {
      return rawList
          .map((str) => CustomCategory.fromJson(jsonDecode(str) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return defaultCustomCategories;
    }
  }

  Future<void> _persist(List<CustomCategory> items) async {
    final rawList = items.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(prefKey, rawList);
    state = items;
  }

  Future<CustomCategory> addCategory(String name, {IconData? icon, Color? color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Kategori adı boş olamaz');
    }

    final newCategory = CustomCategory(
      id: const Uuid().v4(),
      name: trimmed,
      iconCodePoint: (icon ?? Icons.category_rounded).codePoint,
      colorValue: (color ?? const Color(0xFF3B82F6)).toARGB32(),
    );

    final updated = [...state, newCategory];
    await _persist(updated);
    return newCategory;
  }

  Future<void> removeCategory(String id) async {
    final updated = state.where((c) => c.id != id).toList();
    await _persist(updated);
  }

  Future<void> resetToDefaults() async {
    await _persist(defaultCustomCategories);
  }
}

/// Global Custom Categories Provider
final customCategoriesProvider =
    NotifierProvider<CustomCategoryNotifier, List<CustomCategory>>(
  CustomCategoryNotifier.new,
);
