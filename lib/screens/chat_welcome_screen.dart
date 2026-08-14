import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/models/user_profile.dart';
import 'package:ogrenme_asistani/screens/chat_list_screen.dart';
import 'package:ogrenme_asistani/screens/chat_screen.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';
import 'package:ogrenme_asistani/services/user_profile_repository.dart';
import 'package:ogrenme_asistani/widgets/image_source_picker.dart';

/// The default view of the Sohbet tab — a welcome screen instead of
/// jumping straight into a chat. "Sohbetlerim" (the grouped chat list)
/// is still reachable via the top-right icon.
class ChatWelcomeScreen extends StatefulWidget {
  const ChatWelcomeScreen({super.key});

  @override
  State<ChatWelcomeScreen> createState() => _ChatWelcomeScreenState();
}

class _ChatWelcomeScreenState extends State<ChatWelcomeScreen> {
  final _userProfileRepository = UserProfileRepository();
  final _subjectRepository = SubjectRepository();
  final _chatSessionRepository = ChatSessionRepository();
  final _controller = TextEditingController();

  UserProfile? _profile;
  List<Subject> _subjects = [];
  StreamSubscription<List<Subject>>? _subjectsSubscription;
  String? _selectedSubjectId;
  Uint8List? _selectedImageBytes;
  String? _selectedImageMimeType;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _watchSubjects();
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await _userProfileRepository.load(uid);
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  void _watchSubjects() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _subjectsSubscription = _subjectRepository.watchAll(uid).listen((
      subjects,
    ) {
      if (!mounted) return;
      setState(() => _subjects = subjects);
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'günaydın';
    if (hour >= 12 && hour < 18) return 'iyi günler';
    if (hour >= 18 && hour < 22) return 'iyi akşamlar';
    return 'iyi geceler';
  }

  String get _greetingText {
    final name = _profile?.name;
    return name == null || name.isEmpty
        ? 'Merhaba, $_greeting!'
        : '$name, $_greeting!';
  }

  void _openChatList() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ChatListScreen()),
    );
  }

  Future<void> _startChat({String? text, Uint8List? imageBytes, String? imageMimeType}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final chatId = _chatSessionRepository.newChatId(uid);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          initialTitle: 'Yeni Sohbet',
          initialSubjectId: _selectedSubjectId,
          initialText: text,
          initialImageBytes: imageBytes,
          initialImageMimeType: imageMimeType,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _selectedImageBytes = null;
      _selectedImageMimeType = null;
    });
  }

  void _handleBasla() => _startChat();

  void _handleSend() {
    final text = _controller.text.trim();
    final imageBytes = _selectedImageBytes;
    if (text.isEmpty && imageBytes == null) return;
    _startChat(
      text: text.isEmpty ? null : text,
      imageBytes: imageBytes,
      imageMimeType: _selectedImageMimeType,
    );
  }

  Future<void> _pickImage() async {
    final bytes = await pickAndCropImage(context);
    if (bytes == null || !mounted) return;
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageMimeType = 'image/jpeg';
    });
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageMimeType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Sohbetlerim',
            onPressed: _openChatList,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _greetingText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bugün ne çalışmak istersin?',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _handleBasla,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Başla'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      if (_subjects.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSubjectPicker(context),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_selectedImageBytes != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Fotoğraf eklendi'),
                    onDeleted: _removeSelectedImage,
                  ),
                ),
              ),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectPicker(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final subject in _subjects)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(subject.name),
                avatar: CircleAvatar(backgroundColor: subject.color, radius: 6),
                selected: _selectedSubjectId == subject.id,
                onSelected: (selected) {
                  setState(() {
                    _selectedSubjectId = selected ? subject.id : null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Fotoğraf ile soru sor',
          ),
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.mic_none_outlined),
            tooltip: 'Sesli giriş (yakında)',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: 'Bir soru yaz...',
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _handleSend,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
