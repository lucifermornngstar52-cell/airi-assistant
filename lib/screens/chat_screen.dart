import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser}) : time = DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages   = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scroll     = ScrollController();
  final _ai         = AiService();
  bool _loading     = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _loading = true;
    });
    _scrollDown();

    final history = _messages
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    final reply = await _ai.chat(history);

    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
      _loading = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(150.ms, () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: 300.ms, curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.accentBlue, AppTheme.accentPurple],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AIRI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            Text('онлайн', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
        elevation: 0,
      ),
      body: Column(children: [
        // Сообщения
        Expanded(
          child: _messages.isEmpty ? _emptyState() : ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length) return _typingBubble();
              return _MessageBubble(msg: _messages[i], index: i);
            },
          ),
        ),
        // Инпут
        _InputBar(controller: _controller, loading: _loading, onSend: _send),
      ]),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [AppTheme.accentBlue, AppTheme.accentPurple],
        ).createShader(b),
        child: const Icon(Icons.auto_awesome, size: 64, color: Colors.white),
      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
      const SizedBox(height: 16),
      const Text('Привет, я AIRI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Чем могу помочь?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
    ]),
  );

  Widget _typingBubble() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8, right: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder, width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(color: AppTheme.accentBlue, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat())
           .fadeIn(delay: Duration(milliseconds: i * 150), duration: 300.ms)
           .then().fadeOut(duration: 300.ms),
          if (i < 2) const SizedBox(width: 4),
        ]
      ]),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final int index;
  const _MessageBubble({required this.msg, required this.index});

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        FadeEffect(duration: 250.ms),
        SlideEffect(begin: Offset(msg.isUser ? 0.2 : -0.2, 0), end: Offset.zero, duration: 250.ms),
      ],
      child: Align(
        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: msg.isUser
                ? const LinearGradient(colors: [AppTheme.accentBlue, AppTheme.accentPurple])
                : null,
            color: msg.isUser ? null : AppTheme.cardColor,
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(18),
              topRight:    const Radius.circular(18),
              bottomLeft:  Radius.circular(msg.isUser ? 18 : 4),
              bottomRight: Radius.circular(msg.isUser ? 4 : 18),
            ),
            border: msg.isUser ? null : Border.all(color: AppTheme.cardBorder, width: 0.5),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              color: msg.isUser ? Colors.white : AppTheme.textPrimary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.loading, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              maxLines: 4,
              minLines: 1,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Напиши что-нибудь...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: loading ? null : onSend,
          child: AnimatedContainer(
            duration: 200.ms,
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: loading ? null : const LinearGradient(
                colors: [AppTheme.accentBlue, AppTheme.accentPurple],
              ),
              color: loading ? AppTheme.cardColor : null,
            ),
            child: Icon(
              loading ? Icons.hourglass_top : Icons.arrow_upward,
              color: loading ? AppTheme.textSecondary : Colors.white,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }
}
