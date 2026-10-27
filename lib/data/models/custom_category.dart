import 'package:flutter/material.dart';

/// Evdaş Kullanıcı Tanımlı Özel Kategori Modeli
///
/// Sıfır emoji, keskin vektörel Material Symbols standardında üretilmiştir.
@immutable
class CustomCategory {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;

  const CustomCategory({
    required this.id,
    required this.name,
    this.iconCodePoint = 0xe59c, // Icons.category_rounded
    this.colorValue = 0xFF3B82F6,
  });

  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
      };

  factory CustomCategory.fromJson(Map<String, dynamic> json) => CustomCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        iconCodePoint: json['iconCodePoint'] as int? ?? 0xe59c,
        colorValue: json['colorValue'] as int? ?? 0xFF3B82F6,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
