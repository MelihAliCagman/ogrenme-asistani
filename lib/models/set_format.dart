import 'package:flutter/material.dart';

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

  /// Short label for the format segmented button — the full [label] is
  /// too long ("Çoktan Seçmeli Test") to fit three-up on a phone screen.
  String get shortLabel {
    switch (this) {
      case SetFormat.flashcards:
        return 'Hafıza Kartı';
      case SetFormat.multipleChoice:
        return 'Çoktan Seçmeli';
      case SetFormat.fillBlank:
        return 'Boşluk Doldurma';
      case SetFormat.trueFalse:
        return 'Doğru/Yanlış';
    }
  }

  IconData get icon {
    switch (this) {
      case SetFormat.flashcards:
        return Icons.style_outlined;
      case SetFormat.multipleChoice:
        return Icons.checklist_outlined;
      case SetFormat.fillBlank:
        return Icons.short_text_outlined;
      case SetFormat.trueFalse:
        return Icons.rule_outlined;
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
