class ChatMessage {
  ChatMessage({required this.text, required this.isUser, this.isError = false});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      isError: json['isError'] as bool? ?? false,
    );
  }

  final String text;
  final bool isUser;
  final bool isError;

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'isError': isError,
  };
}
