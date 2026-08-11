import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/chat_message.dart';
import 'package:ogrenme_asistani/services/chat_repository.dart';
import 'package:ogrenme_asistani/services/gemini_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final ChatRepository _chatRepository = ChatRepository();
  bool _isAiTyping = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final messages = await _chatRepository.loadAll();
    if (!mounted) return;
    setState(() {
      _messages.addAll(messages);
      _isLoadingHistory = false;
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isAiTyping = true;
    });
    _controller.clear();
    _scrollToBottom();
    await _chatRepository.saveAll(_messages);

    try {
      final reply = await _geminiService.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _isAiTyping = false;
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    } catch (e) {
      debugPrint('[ChatScreen] Gemini isteği başarısız: $e');
      if (!mounted) return;
      setState(() {
        _isAiTyping = false;
        _messages.add(
          ChatMessage(
            text:
                'Üzgünüm, şu anda cevap veremiyorum. Lütfen internet bağlantını kontrol edip tekrar dener misin?',
            isUser: false,
            isError: true,
          ),
        );
      });
    }
    _scrollToBottom();
    await _chatRepository.saveAll(_messages);
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
      appBar: AppBar(title: const Text('Sohbet')),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && !_isAiTyping
                ? const Center(
                    child: Text('Henüz mesaj yok. Bir şey yazıp gönder!'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_isAiTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingBubble();
                      }
                      return _ChatBubble(message: _messages[index]);
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
  const _ChatBubble({required this.message});

  final ChatMessage message;

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

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
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
          style: TextStyle(color: textColor),
        ),
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
