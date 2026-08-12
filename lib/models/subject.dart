import 'package:flutter/material.dart';

class Subject {
  Subject({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  factory Subject.fromJson(String id, Map<String, dynamic> json) {
    return Subject(
      id: id,
      name: json['name'] as String? ?? 'Ders',
      color: Color(json['color'] as int? ?? defaultColors.first.toARGB32()),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String name;
  final Color color;
  final DateTime createdAt;

  static const icon = Icons.menu_book;

  static const List<Color> defaultColors = [
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.brown,
  ];

  static const List<String> suggestions = [
    'Matematik',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Tarih',
    'Türkçe',
    'İngilizce',
  ];

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color.toARGB32(),
    'createdAt': createdAt.toIso8601String(),
  };
}
