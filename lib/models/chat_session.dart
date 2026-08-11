class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(String id, Map<String, dynamic> json) {
    return ChatSession(
      id: id,
      title: json['title'] as String? ?? 'Yeni Sohbet',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const defaultTitle = 'Yeni Sohbet';

  Map<String, dynamic> toJson() => {
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
