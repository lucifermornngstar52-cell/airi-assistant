import 'package:flutter/material.dart';
import '../models/character_persona.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import 'persona_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messages   = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scroll     = ScrollController();
  final _ai         = AiService();
  bool _loading     = false;
  CharacterPersona _persona = personaJarvis;

  @override
  void initState() {
    super.initState();
    _loadPersona();
  }

  Future<void> _loadPersona() async {
    final type = await _ai.loadPersona();
    setState(() {
      _persona = allPersonas.firstWhere((p) => p.type == type);
    });
  }

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

    final reply = await _ai.chat(history, persona: _persona);

    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
      _loading = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openPersona() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PersonaScreen(
        currentType: _persona.type,
        onSelect: (p) => setState(() => _persona = p),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isJarvis = _persona.type == PersonaType.jarvis;
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        title: GestureDetector(
          onTap: _openPersona,
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isJarvis
                      ? [AppTheme.accentBlue, const Color(0xFF1A3A6B)]
                      : [AppTheme.accentPurple, const Color(0xFFFF6BB5)],
                ),
              ),
              child: Center(child: Text(_persona.emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_persona.name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const Text('онлайн', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ]),
          ]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: AppTheme.textSecondary),
            onPressed: _openPersona,
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
        elevation: 0,
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? _emptyState()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_loading ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == _messages.length) return _typingBubble();
                    return _MessageBubble(msg: _messages[i], isJarvis: isJarvis);
                  },
                ),
        ),
        _InputBar(controller: _controller, loading: _loading, onSend: _send),
      ]),
    );
  }

  Widget _emptyState() {
    final isJarvis = _persona.type == PersonaType.jarvis;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isJarvis
                  ? [AppTheme.accentBlue, const Color(0xFF1A3A6B)]
                  : [AppTheme.accentPurple, const Color(0xFFFF6BB5)],
            ),
          ),
          child: Center(child: Text(_persona.emoji, style: const TextStyle(fontSize: 38))),
        ),
        const SizedBox(height: 20),
        Text(
          isJarvis ? 'Добрый день. Чем могу помочь?' : 'Привет! Я здесь ✨',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(_persona.name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder, width: 0.5),
        ),
        child: const SizedBox(
          width: 40, height: 8,
          child: _DotsIndicator(),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();
  @override State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final opacity = ((_ctrl.value * 3 - i) % 1.0).clamp(0.2, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentBlue.withOpacity(opacity),
            ),
          );
        }),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isJarvis;
  const _MessageBubble({required this.msg, required this.isJarvis});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: msg.isUser
              ? LinearGradient(colors: isJarvis
                  ? [AppTheme.accentBlue, const Color(0xFF1565C0)]
                  : [AppTheme.accentPurple, const Color(0xFFE91E8C)])
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
      decoration: const BoxDecoration(
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
              maxLines: 4, minLines: 1,
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
            duration: const Duration(milliseconds: 200),
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
