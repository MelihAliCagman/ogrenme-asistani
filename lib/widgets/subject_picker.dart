import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/subject.dart';

/// Sentinel returned by [pickSubject] when the user explicitly picks
/// "Genel" (no subject) — distinct from `null`, which means the sheet
/// was dismissed without a choice (so the caller should keep whatever
/// subject was already set instead of clearing it).
const noSubjectPicked = '';

/// Shows a bottom sheet letting the user optionally pick a subject.
/// Returns the chosen subject's id, [noSubjectPicked] if "Genel" was
/// explicitly chosen, or `null` if the sheet was dismissed without a
/// choice.
Future<String?> pickSubject(
  BuildContext context, {
  required List<Subject> subjects,
  String? currentSubjectId,
}) async {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Ders seç (opsiyonel)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.inbox_outlined)),
              title: const Text('Genel'),
              trailing: currentSubjectId == null
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(noSubjectPicked),
            ),
            for (final subject in subjects)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: subject.color,
                  child: Icon(Subject.icon, color: Colors.white),
                ),
                title: Text(subject.name),
                trailing: currentSubjectId == subject.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(subject.id),
              ),
          ],
        ),
      );
    },
  );
}
