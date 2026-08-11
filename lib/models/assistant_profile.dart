enum AssistantGender { female, male }

class AssistantProfile {
  AssistantProfile({required this.name, required this.gender});

  factory AssistantProfile.fromJson(Map<String, dynamic> json) {
    return AssistantProfile(
      name: json['name'] as String? ?? 'Mira',
      gender: (json['gender'] as String?) == 'male'
          ? AssistantGender.male
          : AssistantGender.female,
    );
  }

  final String name;
  final AssistantGender gender;

  String get emoji => gender == AssistantGender.male ? '🧑‍🏫' : '👩‍🏫';

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender == AssistantGender.male ? 'male' : 'female',
  };
}
