import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/assistant_profile.dart';
import 'package:ogrenme_asistani/models/chat_message.dart';
import 'package:ogrenme_asistani/services/assistant_profile_repository.dart';
import 'package:ogrenme_asistani/services/chat_font_size.dart';
import 'package:ogrenme_asistani/services/chat_font_size_controller.dart';
import 'package:ogrenme_asistani/services/chat_repository.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/gemini_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.initialTitle,
  });

  final String chatId;
  final String initialTitle;

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
  bool _isAiTyping = false;
  bool _isLoadingHistory = true;
  AssistantProfile? _assistantProfile;
  late String _title = widget.initialTitle;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadAssistantProfile();
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

  String? get _systemInstruction {
    final profile = _assistantProfile;
    if (profile == null) return null;
    final genderWord = profile.gender == AssistantGender.male
        ? 'erkek'
        : 'kadın';
    return 'Sen ${profile.name} adında, $genderWord karakterli, kullanıcıyı '
        'motive eden dostane bir öğrenme koçusun. Öğrencilere sabırlı, '
        'pozitif ve teşvik edici bir üslupla yardımcı ol.';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final isFirstMessage = _messages.isEmpty;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isAiTyping = true;
    });
    _controller.clear();
    _scrollToBottom();
    await _repository.saveAll(_messages);
    if (isFirstMessage) _deriveTitleFromFirstMessage(text);

    var hasReceivedChunk = false;
    try {
      final stream = _geminiService.sendMessageStream(
        text,
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
    final title = text.length > 40 ? '${text.substring(0, 40)}...' : text;
    await _sessionRepository.updateTitle(uid, widget.chatId, title);
    if (!mounted) return;
    setState(() => _title = title);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
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
        child: Text(
          message.text,
          style: TextStyle(color: textColor, fontSize: fontSize),
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
