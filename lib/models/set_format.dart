enum SetFormat { flashcards, multipleChoice, fillBlank, trueFalse }

extension SetFormatLabel on SetFormat {
  String get label {
    switch (this) {
      case SetFormat.flashcards:
        return 'Hafıza Kartı';
      case SetFormat.multipleChoice:
        return 'Çoktan Seçmeli Test';
      case SetFormat.fillBlank:
        return 'Boşluk Doldurma';
      case SetFormat.trueFalse:
        return 'Doğru/Yanlış';
    }
  }

  bool get isQuiz => this != SetFormat.flashcards;
}

enum SetDifficulty { aiDecide, easy, medium, hard }

extension SetDifficultyLabel on SetDifficulty {
  String get label {
    switch (this) {
      case SetDifficulty.aiDecide:
        return 'AI Karar Versin';
      case SetDifficulty.easy:
        return 'Kolay';
      case SetDifficulty.medium:
        return 'Orta';
      case SetDifficulty.hard:
        return 'Zor';
    }
  }

  /// Extra instruction appended to the Gemini prompt, or `null` when the
  /// AI should pick the difficulty itself (no explicit instruction).
  String? get promptInstruction {
    switch (this) {
      case SetDifficulty.aiDecide:
        return null;
      case SetDifficulty.easy:
        return 'Soruların/kartların zorluk seviyesi kolay olsun.';
      case SetDifficulty.medium:
        return 'Soruların/kartların zorluk seviyesi orta olsun.';
      case SetDifficulty.hard:
        return 'Soruların/kartların zorluk seviyesi zor olsun.';
    }
  }
}
