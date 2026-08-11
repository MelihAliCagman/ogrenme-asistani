import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/assistant_profile.dart';
import 'package:ogrenme_asistani/services/assistant_profile_repository.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key, required this.onSaved});

  final void Function(AssistantProfile profile) onSaved;

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  static const _nameSuggestions = ['Mira', 'Kaan', 'Elif', 'Ege', 'Zeynep', 'Deniz'];

  final _repository = AssistantProfileRepository();
  final _nameController = TextEditingController();
  AssistantGender _gender = AssistantGender.female;
  bool _isSaving = false;
  bool _isLoadingInitial = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final existing = await _repository.load(uid);
      if (existing != null && mounted) {
        setState(() {
          _nameController.text = existing.name;
          _gender = existing.gender;
        });
      }
    }
    if (mounted) setState(() => _isLoadingInitial = false);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = _nameController.text.trim();
    if (uid == null || name.isEmpty) return;

    setState(() => _isSaving = true);
    final profile = AssistantProfile(name: name, gender: _gender);
    await _repository.save(uid, profile);
    if (!mounted) return;
    setState(() => _isSaving = false);
    widget.onSaved(profile);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canSave = _nameController.text.trim().isNotEmpty && !_isSaving;

    return Scaffold(
      appBar: AppBar(title: const Text('Asistanını Seç')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Öğrenme yolculuğunda sana eşlik edecek asistana bir isim ver ve bir karakter seç.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Asistanın adı',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _nameSuggestions.map((name) {
                  return ActionChip(
                    label: Text(name),
                    onPressed: () {
                      _nameController.text = name;
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _GenderCard(
                      emoji: '👩‍🏫',
                      label: 'Kadın Karakter',
                      selected: _gender == AssistantGender.female,
                      onTap: () =>
                          setState(() => _gender = AssistantGender.female),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _GenderCard(
                      emoji: '🧑‍🏫',
                      label: 'Erkek Karakter',
                      selected: _gender == AssistantGender.male,
                      onTap: () =>
                          setState(() => _gender = AssistantGender.male),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: canSave ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Devam Et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? colorScheme.primaryContainer : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
