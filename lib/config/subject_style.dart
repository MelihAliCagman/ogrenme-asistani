import 'package:flutter/material.dart';

/// Color and icon identity of a YKS ders, so the same ders looks the same
/// on the Müfredat grid, the Ana Sayfa chips and the path screen.
class SubjectStyle {
  const SubjectStyle(this.color, this.icon);

  final Color color;
  final IconData icon;
}

const _styles = <String, SubjectStyle>{
  'Türkçe': SubjectStyle(Color(0xFFEF5350), Icons.menu_book_rounded),
  'Matematik': SubjectStyle(Color(0xFF42A5F5), Icons.calculate_rounded),
  'Geometri': SubjectStyle(Color(0xFF26C6DA), Icons.change_history_rounded),
  'Fizik': SubjectStyle(Color(0xFF7E57C2), Icons.bolt_rounded),
  'Kimya': SubjectStyle(Color(0xFFFFA726), Icons.science_rounded),
  'Biyoloji': SubjectStyle(Color(0xFF66BB6A), Icons.biotech_rounded),
  'Tarih': SubjectStyle(Color(0xFFD4A24C), Icons.account_balance_rounded),
  'Coğrafya': SubjectStyle(Color(0xFF26A69A), Icons.public_rounded),
  'Felsefe': SubjectStyle(Color(0xFF5C6BC0), Icons.psychology_alt_rounded),
  'Din Kültürü': SubjectStyle(Color(0xFF2E9E7B), Icons.mosque_rounded),
  'Edebiyat': SubjectStyle(Color(0xFFEC407A), Icons.auto_stories_rounded),
  'Mantık': SubjectStyle(Color(0xFF78909C), Icons.account_tree_rounded),
  'Psikoloji': SubjectStyle(Color(0xFFAB47BC), Icons.psychology_rounded),
  'Sosyoloji': SubjectStyle(Color(0xFFFF7043), Icons.groups_rounded),
  'İngilizce': SubjectStyle(Color(0xFF29B6F6), Icons.translate_rounded),
};

const _fallback = SubjectStyle(Color(0xFF7C4DFF), Icons.school_rounded);

SubjectStyle subjectStyleFor(String subject) => _styles[subject] ?? _fallback;
