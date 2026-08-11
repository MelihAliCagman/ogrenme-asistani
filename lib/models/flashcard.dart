class Flashcard {
  Flashcard({required this.question, required this.answer});

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }

  final String question;
  final String answer;

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
}
