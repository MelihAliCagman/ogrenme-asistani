class ExamGoal {
  ExamGoal({
    required this.id,
    required this.name,
    required this.date,
    this.targetScore,
  });

  factory ExamGoal.fromJson(String id, Map<String, dynamic> json) {
    return ExamGoal(
      id: id,
      name: json['name'] as String? ?? '',
      date:
          DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.now(),
      targetScore: (json['targetScore'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String name;
  final DateTime date;
  final double? targetScore;

  Map<String, dynamic> toJson() => {
    'name': name,
    'date': date.toIso8601String(),
    'targetScore': targetScore,
  };
}
