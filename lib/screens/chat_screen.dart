import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:ogrenme_asistani/models/assistant_profile.dart';
import 'package:ogrenme_asistani/models/chat_message.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/services/assistant_profile_repository.dart';
import 'package:ogrenme_asistani/services/chat_font_size.dart';
import 'package:ogrenme_asistani/services/chat_font_size_controller.dart';
import 'package:ogrenme_asistani/services/chat_repository.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/gemini_service.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';
import 'package:ogrenme_asistani/widgets/subject_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.initialTitle,
    this.initialSubjectId,
  });

  final String chatId;
  final String initialTitle;
  final String? initialSubjectId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  late final ChatRepository _repository = ChatRepository(
    chatId: widget.chatId,
  );
  final ChatSessionRepository _sessionRepository = ChatSessionRepository();
  final AssistantProfileRepository _assistantProfileRepository =
      AssistantProfileRepository();
  final SubjectRepository _subjectRepository = SubjectRepository();
  final StreakRepository _streakRepository = StreakRepository();
  bool _isAiTyping = false;
  bool _isLoadingHistory = true;
  AssistantProfile? _assistantProfile;
  late String _title = widget.initialTitle;
  bool _titleEditedByUser = false;
  List<Subject> _subjects = [];
  late String? _subjectId = widget.initialSubjectId;

  /// Whether `users/{uid}/chats/{chatId}` has actually been written yet.
  /// A brand-new chat stays a local draft — nothing is persisted, and it
  /// won't show up in the chat list — until the first message is sent.
  bool _sessionExists = false;
  StreamSubscription<List<Subject>>? _subjectsSubscription;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadAssistantProfile();
    _loadSubjectId();
    _watchSubjects();
  }

  Future<void> _loadSubjectId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final session = await _sessionRepository.getById(uid, widget.chatId);
    if (!mounted) return;
    _sessionExists = session != null;
    if (session == null) return;
    setState(() => _subjectId = session.subjectId);
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

  Future<void> _assignSubject() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final result = await pickSubject(
      context,
      subjects: _subjects,
      currentSubjectId: _subjectId,
    );
    if (result == null) return;
    final subjectId = result == noSubjectPicked ? null : result;
    if (subjectId == _subjectId) return;
    // A draft chat has nothing to update yet — createWithId() will pick
    // up _subjectId once the first message is sent.
    if (_sessionExists) {
      await _sessionRepository.updateSubject(uid, widget.chatId, subjectId);
    }
    if (!mounted) return;
    setState(() => _subjectId = subjectId);
  }

  Future<void> _loadHistory() async {
    final messages = await _repository.loadAll();
    if (!mounted) return;
    setState(() {
      _messages.addAll(messages);
      _isLoadingHistory = false;
    });
    _scrollToBottom();
  }

  Future<void> _loadAssistantProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await _assistantProfileRepository.load(uid);
    if (!mounted) return;
    setState(() => _assistantProfile = profile);
  }

  String get _systemInstruction {
    final buffer = StringBuffer();
    final profile = _assistantProfile;
    if (profile != null) {
      final genderWord = profile.gender == AssistantGender.male
          ? 'erkek'
          : 'kadın';
      buffer.writeln(
        'Sen ${profile.name} adında, $genderWord karakterli, kullanıcıyı '
        'motive eden dostane bir öğrenme koçusun. Öğrencilere sabırlı, '
        'pozitif ve teşvik edici bir üslupla yardımcı ol.',
      );
    }
    buffer.writeln(
      'Bir konu hakkında soru geldiğinde ilk yanıtını kısa ve genel bir özet '
      'olarak ver; uzun listeler veya çok detaylı açıklamalarla başlamaktan '
      'kaçın. İlk yanıtının sonunda kullanıcıya hangi kısmı detaylandırmak '
      'istediğini sor (ör. "Hangi kısmı daha ayrıntılı anlatmamı istersin?"). '
      'Kullanıcı "detaylandır", "devam et" derse ya da belirli bir alt '
      'başlık/soru sorarsa, o zaman o konuyu derinlemesine ve kapsamlı bir '
      'şekilde anlat.',
    );
    return buffer.toString();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final isFirstMessage = _messages.isEmpty;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isAiTyping = true;
    });
    _controller.clear();
    _scrollToBottom();
    await _repository.saveAll(_messages);
    if (uid != null) {
      String? subjectName;
      for (final subject in _subjects) {
        if (subject.id == _subjectId) {
          subjectName = subject.name;
          break;
        }
      }
      _streakRepository.recordActivityToday(
        uid,
        subjectId: _subjectId,
        subjectName: subjectName,
      );
    }

    if (isFirstMessage && uid != null && !_sessionExists) {
      await _sessionRepository.createWithId(
        uid,
        widget.chatId,
        subjectId: _subjectId,
        title: _title,
        titleEditedByUser: _titleEditedByUser,
      );
      _sessionExists = true;
    }
    if (isFirstMessage) _deriveTitleFromFirstMessage(text);

    var hasReceivedChunk = false;
    try {
      final stream = _geminiService.sendMessageStream(
        List.of(_messages),
        systemInstruction: _systemInstruction,
      );
      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() {
          if (!hasReceivedChunk) {
            hasReceivedChunk = true;
            _isAiTyping = false;
            _messages.add(ChatMessage(text: chunk, isUser: false));
          } else {
            final last = _messages.last;
            _messages[_messages.length - 1] = ChatMessage(
              text: last.text + chunk,
              isUser: false,
            );
          }
        });
        _scrollToBottom();
      }
      if (!hasReceivedChunk) throw GeminiException('Yanıt boş döndü.');
    } catch (e) {
      debugPrint('[ChatScreen] Gemini isteği başarısız: $e');
      if (!mounted) return;
      setState(() {
        _isAiTyping = false;
        if (!hasReceivedChunk) {
          _messages.add(
            ChatMessage(
              text:
                  'Üzgünüm, şu anda cevap veremiyorum. Lütfen internet bağlantını kontrol edip tekrar dener misin?',
              isUser: false,
              isError: true,
            ),
          );
        }
      });
    }
    _scrollToBottom();
    await _repository.saveAll(_messages);
    await _touchUpdatedAt();
  }

  Future<void> _deriveTitleFromFirstMessage(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final session = await _sessionRepository.getById(uid, widget.chatId);
    if (session != null && session.titleEditedByUser) return;

    String title;
    try {
      title = await _geminiService.generateChatTitle(text);
      if (title.isEmpty) throw GeminiException('Başlık boş döndü.');
    } catch (e) {
      debugPrint('[ChatScreen] Otomatik başlık üretilemedi: $e');
      title = text.length > 40 ? '${text.substring(0, 40)}...' : text;
    }

    if (!mounted) return;
    if (_titleEditedByUser) return;
    await _sessionRepository.updateTitle(uid, widget.chatId, title);
    if (!mounted) return;
    setState(() => _title = title);
  }

  Future<void> _renameChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final controller = TextEditingController(text: _title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbeti yeniden adlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty || newTitle == _title) return;
    _titleEditedByUser = true;
    // A draft chat has nothing to update yet — createWithId() will pick
    // up _title/_titleEditedByUser once the first message is sent.
    if (_sessionExists) {
      await _sessionRepository.updateTitle(
        uid,
        widget.chatId,
        newTitle,
        editedByUser: true,
      );
    }
    if (!mounted) return;
    setState(() => _title = newTitle);
  }

  Future<void> _touchUpdatedAt() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _sessionRepository.touchUpdatedAt(uid, widget.chatId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Ders Ata/Değiştir',
            onPressed: _assignSubject,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Yeniden adlandır',
            onPressed: _renameChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && !_isAiTyping
                ? const Center(
                    child: Text('Henüz mesaj yok. Bir şey yazıp gönder!'),
                  )
                : ValueListenableBuilder<ChatFontSize>(
                    valueListenable: ChatFontSizeController.fontSize,
                    builder: (context, fontSize, _) {
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length + (_isAiTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return const _TypingBubble();
                          }
                          return _ChatBubble(
                            message: _messages[index],
                            assistantProfile: _assistantProfile,
                            fontSize: fontSize.fontSize,
                          );
                        },
                      );
                    },
                  ),
          ),
          _MessageInput(controller: _controller, onSend: _sendMessage),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.assistantProfile,
    this.fontSize,
  });

  final ChatMessage message;
  final AssistantProfile? assistantProfile;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final isError = message.isError;

    final Color backgroundColor;
    final Color textColor;
    if (isUser) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else if (isError) {
      backgroundColor = colorScheme.errorContainer;
      textColor = colorScheme.onErrorContainer;
    } else {
      backgroundColor = colorScheme.surfaceContainerHigh;
      textColor = colorScheme.onSurface;
    }

    final bubble = Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: isUser || isError
                  ? SelectableText(
                      message.text,
                      style: TextStyle(color: textColor, fontSize: fontSize),
                    )
                  : MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(
                        p: TextStyle(color: textColor, fontSize: fontSize),
                        strong: TextStyle(
                          color: textColor,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: textColor,
                          fontSize: fontSize,
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: TextStyle(
                          color: textColor,
                          fontSize: fontSize,
                        ),
                        h1: TextStyle(color: textColor, fontSize: (fontSize ?? 16) * 1.4, fontWeight: FontWeight.bold),
                        h2: TextStyle(color: textColor, fontSize: (fontSize ?? 16) * 1.25, fontWeight: FontWeight.bold),
                        h3: TextStyle(color: textColor, fontSize: (fontSize ?? 16) * 1.1, fontWeight: FontWeight.bold),
                        code: TextStyle(
                          color: textColor,
                          fontSize: fontSize,
                          backgroundColor: textColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            _CopyIconButton(text: message.text, color: textColor),
          ],
        ),
      );

    if (isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              assistantProfile?.emoji ?? '🤖',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _CopyIconButton extends StatelessWidget {
  const _CopyIconButton({required this.text, required this.color});

  final String text;
  final Color color;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kopyalandı'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _copy(context),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.copy, size: 14, color: color.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SizedBox(
          width: 32,
          height: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (_) => CircleAvatar(
                radius: 3,
                backgroundColor: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Bir mesaj yaz...',
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
              onPressed: onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
