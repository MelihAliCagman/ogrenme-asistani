import 'package:flutter/material.dart';

/// A rounded, colored box with a small uppercase label and a body text
/// below it. Used for both the question/answer faces of a flashcard and
/// the quiz screen's question/answer display.
class LabeledInfoCard extends StatelessWidget {
  const LabeledInfoCard({
    super.key,
    required this.label,
    required this.text,
    required this.background,
    required this.foreground,
    this.minHeight,
    this.textFontSize = 16,
  });

  final String label;
  final String text;
  final Color background;
  final Color foreground;
  final double? minHeight;
  final double textFontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight!)
          : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: TextStyle(color: foreground, fontSize: textFontSize),
          ),
        ],
      ),
    );
  }
}
