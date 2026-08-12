import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/subject.dart';

/// Small colored label showing which subject an item belongs to.
class SubjectChip extends StatelessWidget {
  const SubjectChip({super.key, required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: subject.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: subject.color),
      ),
      child: Text(
        subject.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: subject.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
