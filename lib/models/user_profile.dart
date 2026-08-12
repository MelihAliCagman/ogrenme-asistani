import 'package:flutter/material.dart';

class UserProfile {
  UserProfile({
    required this.name,
    required this.avatarIconCodePoint,
    required this.avatarColor,
    this.age,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      avatarIconCodePoint:
          json['avatarIconCodePoint'] as int? ??
          defaultIcons.first.codePoint,
      avatarColor: Color(
        json['avatarColor'] as int? ?? defaultColors.first.toARGB32(),
      ),
      age: json['age'] as int?,
    );
  }

  final String name;
  final int avatarIconCodePoint;
  final Color avatarColor;
  final int? age;

  IconData get avatarIcon =>
      // ignore: non_const_argument_for_const_parameter
      IconData(avatarIconCodePoint, fontFamily: 'MaterialIcons');

  static const List<IconData> defaultIcons = [
    Icons.person,
    Icons.face,
    Icons.emoji_emotions,
    Icons.pets,
    Icons.star,
    Icons.favorite,
    Icons.rocket_launch,
    Icons.sports_esports,
  ];

  static const List<Color> defaultColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.brown,
  ];

  UserProfile copyWith({
    String? name,
    int? avatarIconCodePoint,
    Color? avatarColor,
    int? age,
    bool clearAge = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      avatarIconCodePoint: avatarIconCodePoint ?? this.avatarIconCodePoint,
      avatarColor: avatarColor ?? this.avatarColor,
      age: clearAge ? null : (age ?? this.age),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatarIconCodePoint': avatarIconCodePoint,
    'avatarColor': avatarColor.toARGB32(),
    'age': age,
  };
}
