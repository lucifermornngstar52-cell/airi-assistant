import 'dart:async';
import 'package:flutter/material.dart';
import '../models/character_persona.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import 'dart:io';
import 'persona_screen.dart';
import '../services/vision_service.dart';
import '../services/emotion_service.dart';
import '../services/memory_service.dart';
import '../services/overlay_service.dart';
import '../services/app_launcher_service.dart';
import '../services/phone_control_service.dart';
import '../services/web_search_service.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages   = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scroll     = ScrollController();
  final _ai         = AiService();
  final _voice      = VoiceService();
  final _tts        = TtsService();

  bool _loading   = false;
  bool _listening = false;
  bool _speaking  = false;
  CharacterPersona _persona = personaJarvis;

  // Зрение и эмоции
  final _vision = VisionService();
  final _emotion = EmotionService();
  String? _userEmotion;
  bool _emotionWatching = false;
  bool _wakeWordActive = false;
  String? _emotionError;
  File? _pendingImage;
  final _overlay = OverlayService();
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    _loadPersona();
    _initEmotionWatcher();
    _initMemory();
    _initWakeWord();
  }

  Future<void> _initMemory() async {
    await _ai.loadMemoryHistory(limit: 15).then((history) {
      if (!mounted || history.isEmpty) return;
      setState(() {
        for (var m in history) {
          _messages.add(ChatMessage(text: m['content']!, isUser: m['role'] == 'user'));
        }
      });
      _scrollDown();
    });
  }

  void _initEmotionWatcher() {
    _emotion.onEmotionDetected = (emotion) {
      if (!mounted) return;
      setState(() => _userEmotion = emotion);
    };
  }

  void _initWakeWord() {
    _voice.onWakeWordDetected = () {
      debugPrint('[Chat] Wake word detected!');
      if (!mounted) return;
      setState(() => _wakeWordActive = true);
      OverlayService.hudShow();
      OverlayService.hudStatus('LISTENING...');
      _toggleVoice();
    };
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _voice.startWakeWordMode().then((ok) {
          if (ok && mounted) setState(() => _wakeWordActive = true);
        });
      }
    });
  }

  // Proactive spam removed — JARVIS only talks when spoken to

  @override
  void dispose() {
    _emotion.stop();
    _controller.dispose();
    _scroll.dispose();
_voice.stopWakeWordMode();
    _voice.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _loadPersona() async {
    final type = await _ai.loadPersona();
    if (!mounted) return;
    setState(() {
      _persona = allPersonas.firstWhere((p) => p.type == type);
    });
    // Устанавливаем модель оверлея: Airi → Hiyori, Jarvis → Natori
    final modelPath = _persona.type == PersonaType.cute
        ? 'models/Hiyori/Hiyori.model3.json'
        : 'models/Natori/Natori.model3.json';
    _overlay.switchModel(modelPath);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final hasImage = _pendingImage != null;
    if (text.isEmpty && !hasImage) return;
    if (_loading) return;
    _controller.clear();
    // Show HUD only when user asks something
    OverlayService.hudShow();
    OverlayService.hudStatus('PROCESSING...');

    // ── Проверяем команду открытия приложения ПЕРЕД AI ──
    if (!hasImage && text.isNotEmpty) {
      final launchResult = await AppLauncherService.tryLaunch(text);
      if (launchResult != null) {
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: true));
          _messages.add(ChatMessage(text: launchResult, isUser: false));
          _loading = false;
        });
        _scrollDown();
        OverlayService.hudStatus('J.A.R.V.I.S. RESPONDING');
        await _tts.speak(launchResult, _persona.type);
        OverlayService.hudHide();
        return;
      }
    }

    // ── Проверяем команду управления телефоном ПЕРЕД AI ──
    if (!hasImage && text.isNotEmpty) {
      final phoneResult = await PhoneControlService.tryPhoneCommand(text);
      if (phoneResult != null) {
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: true));
          _messages.add(ChatMessage(text: phoneResult, isUser: false));
          _loading = false;
        });
        _scrollDown();
        OverlayService.hudStatus('ACTION COMPLETE');
        await _tts.speak(phoneResult, _persona.type);
        OverlayService.hudHide();
        return;
      }
    }

    // ── Проверяем поисковый запрос ПЕРЕД AI ──
    if (!hasImage && text.isNotEmpty) {
      final searchResult = await WebSearchService.trySearch(text);
      if (searchResult != null) {
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: true));
          _messages.add(ChatMessage(text: searchResult, isUser: false));
          _loading = false;
        });
        _scrollDown();
        await _tts.speak(searchResult, _persona.type);
        OverlayService.hudHide();
        return;
      }
    }

    // Если TTS говорит — останавливаем перед отправкой
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
    }

    final displayText = hasImage
        ? (text.isEmpty ? '📷 [фото]' : '$text 📷')
        : text;

    setState(() {
      _messages.add(ChatMessage(text: displayText, isUser: true));
      _loading = true;
    });
    _scrollDown();
    // Сохраняем в память
    _ai.saveToMemory('user', text.isEmpty ? '[фото]' : text, persona: _persona.type.name);
    // _lastUserMessage removed

    final history = _messages
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    String reply;
    if (hasImage) {
      // Vision запрос — фото + текст
      final prompt = text.isEmpty
          ? 'Опиши что ты видишь на этом фото.'
          : text;
      reply = await _ai.visionChat(prompt, _pendingImage!, persona: _persona);
      _pendingImage = null;
    } else if (_userEmotion != null) {
      // Обычный чат с учётом эмоции
      reply = await _ai.chatWithEmotion(history, persona: _persona, userEmotion: _userEmotion);
    } else {
      reply = await _ai.chat(history, persona: _persona);
    }

    if (!mounted) return;

    // Парсим ответ AI — может он предложил открыть приложение
    final aiLaunchResult = await AppLauncherService.tryLaunchFromAIResponse(reply);

    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
      _loading = false;
    });
    _scrollDown();
    _ai.saveToMemory('assistant', reply, persona: _persona.type.name);
    if (text.isNotEmpty) _ai.extractFact(text);

    // Если AI предложил открыть приложение — открываем
    if (aiLaunchResult != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      // TTS уже скажет "Открываю"
    }

    setState(() => _speaking = true);
    await _tts.speak(reply, _persona.type);
    if (mounted) setState(() => _speaking = false);
    OverlayService.hudHide();
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _voice.stopListening();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    // Если TTS говорит — останавливаем перед голосовым вводом
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
    }

    setState(() => _listening = true);

    final started = await _voice.startListening(
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _controller.text = text;
          _listening = false;
        });
        _send();
      },
      onPartial: (text) {
        if (!mounted) return;
        setState(() => _controller.text = text);
      },
    );

    if (!started && mounted) {
      setState(() => _listening = false);
      _showPermissionSnack();
    }
  }

  Future<void> _toggleSpeaking() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
    } else if (_messages.isNotEmpty) {
      // Перечитать последний ответ AI
      final lastAI = _messages.lastWhere(
        (m) => !m.isUser,
        orElse: () => ChatMessage(text: '', isUser: false),
      );
      if (lastAI.text.isNotEmpty) {
        setState(() => _speaking = true);
        await _tts.speak(lastAI.text, _persona.type);
        if (mounted) setState(() => _speaking = false);
      }
    }
  }

  // ── Камера / Зрение ────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    final hasPermission = await _checkCameraPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Разрешите доступ к камере в настройках'),
          backgroundColor: AppTheme.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final photo = await _vision.capturePhoto();
    if (photo == null) return;
    setState(() => _pendingImage = photo);
  }

  Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  // ── Наблюдение за эмоциями ─────────────────────────────────────

  void _toggleEmotionWatch() {
    if (_emotionWatching) {
      _emotion.stop();
      setState(() {
        _emotionWatching = false;
        _userEmotion = null;
      });
    } else {
      _checkCameraPermission().then((ok) {
        if (ok) {
          _emotion.start();
          setState(() => _emotionWatching = true);
        }
      });
    }
  }

  // ── Live2D Overlay ────────────────────────────────────────────

  void _toggleOverlay() async {
    final result = await _overlay.toggle();
    if (!mounted) return;
    setState(() => _overlayActive = result);
    if (!result && _overlay.isActive == false) {
      // Показываем подсказку если разрешение не дано
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Разрешите отображение поверх других приложений'),
          backgroundColor: AppTheme.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showPermissionSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Разрешите доступ к микрофону в настройках'),
        backgroundColor: AppTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
        onSelect: (p) {
          setState(() => _persona = p);
          // Меняем модель в оверлее: Airi → Hiyori, Jarvis → Natori
          final modelPath = p.type == PersonaType.cute
              ? 'models/Hiyori/Hiyori.model3.json'
              : 'models/Natori/Natori.model3.json';
          OverlayService().switchModel(modelPath);
          // На Windows — обновляем модельку в чате
          if (Platform.isWindows) {
            _currentModelPath = '';
            _loadLive2DModel();
          }
        },
      ),
    ));
  }

  // Live2D WebView для Windows (встроенная моделька в чате)
  InAppWebViewController? _live2dController;
  bool _live2dReady = false;
  String _currentModelPath = '';

  Widget _buildLive2DModel() {
    if (!Platform.isWindows) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('file:///android_asset/flutter_assets/assets/live2d_viewer.html'),
            ),
            initialSettings: InAppWebViewSettings(
              transparentBackground: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
            ),
            onWebViewCreated: (controller) {
              _live2dController = controller;
            },
            onLoadStop: (controller, url) async {
              _live2dReady = true;
              _loadLive2DModel();
            },
          ),
        ],
      ),
    );
  }

  void _loadLive2DModel() async {
    if (!_live2dReady || _live2dController == null) return;
    final modelPath = _persona.type == PersonaType.cute
        ? 'models/Hiyori/Hiyori.model3.json'
        : 'models/Natori/Natori.model3.json';
    if (modelPath == _currentModelPath) return;
    _currentModelPath = modelPath;

    // Загружаем модель через JS
    await Future.delayed(const Duration(milliseconds: 1200));
    await _live2dController!.evaluateJavascript(source: '''
      if (window.loadModel) {
        window.loadModel("assets/$modelPath");
      }
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        titleSpacing: 16,
        title: GestureDetector(
          onTap: _openPersona,
          child: Row(children: [
            _PersonaAvatar(persona: _persona, size: 38),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _persona.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _speaking
                    ? 'говорит...'
                    : _emotionWatching && _userEmotion != null
                        ? 'видит: $_userEmotion'
                        : _emotionWatching
                            ? 'наблюдает за вами'
                            : 'онлайн',
                style: TextStyle(
                  color: _speaking
                      ? AppTheme.accentPurple
                      : _emotionWatching
                          ? AppTheme.accentBlue
                          : Colors.greenAccent,
                  fontSize: 11,
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          // Кнопка TTS — иконка динамика
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _speaking ? Icons.volume_up : Icons.volume_off_outlined,
                key: ValueKey(_speaking),
                color: _speaking ? AppTheme.accentPurple : AppTheme.textSecondary,
              ),
            ),
            onPressed: _toggleSpeaking,
          ),
          // Индикатор скрытного наблюдения за эмоциями
          IconButton(
            icon: Icon(
              _emotionWatching ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: _emotionWatching ? AppTheme.accentBlue.withOpacity(0.6) : AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: _toggleEmotionWatch,
            tooltip: _emotionWatching ? 'Наблюдение активно' : 'Включить наблюдение',
          ),
          // Кнопка Live2D оверлея — только на Android
          if (!Platform.isWindows)
          IconButton(
            icon: Icon(
              _overlayActive ? Icons.layers : Icons.layers_outlined,
              color: _overlayActive ? AppTheme.accentBlue : AppTheme.textSecondary,
            ),
            onPressed: _toggleOverlay,
            tooltip: 'Live2D оверлей',
          ),
          // Кнопка камеры
          IconButton(
            icon: Icon(
              Icons.camera_alt_outlined,
              color: _pendingImage != null ? AppTheme.accentBlue : AppTheme.textSecondary,
            ),
            onPressed: _capturePhoto,
            tooltip: 'Сделать фото',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        // Live2D моделька только на Windows
        if (Platform.isWindows) _buildLive2DModel(),
        Expanded(
          child: _messages.isEmpty
              ? _EmptyState(persona: _persona, onTap: _openPersona)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _messages.length + (_loading ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == _messages.length) return const _TypingBubble();
                    return _MessageBubble(msg: _messages[i], persona: _persona);
                  },
                ),
        ),
        _InputBar(
          controller: _controller,
          loading: _loading,
          listening: _listening,
          persona: _persona,
          onSend: _send,
          onVoice: Platform.isWindows ? null : _toggleVoice,
        ),
      ]),
    );
  }
}

// ── Аватар ──────────────────────────────────────────────────────────────────
class _PersonaAvatar extends StatelessWidget {
  final CharacterPersona persona;
  final double size;
  const _PersonaAvatar({required this.persona, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: persona.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          persona.initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.32,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ── Пустой экран ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final CharacterPersona persona;
  final VoidCallback onTap;
  const _EmptyState({required this.persona, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final greeting = persona.type == PersonaType.jarvis
        ? 'Добрый день. Чем могу помочь?'
        : 'Привет! Я слушаю тебя';
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(onTap: onTap, child: _PersonaAvatar(persona: persona, size: 80)),
        const SizedBox(height: 20),
        Text(greeting, style: const TextStyle(
          color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(persona.name, style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 13)),
      ]),
    );
  }
}

// ── Typing bubble ─────────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 64),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder, width: 0.5),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
              final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.15, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentBlue.withOpacity(opacity),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Пузырь ───────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final CharacterPersona persona;
  const _MessageBubble({required this.msg, required this.persona});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: msg.isUser ? LinearGradient(colors: persona.gradientColors) : null,
          color: msg.isUser ? null : AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(msg.isUser ? 18 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 18),
          ),
          border: msg.isUser ? null : Border.all(color: AppTheme.cardBorder, width: 0.5),
        ),
        child: Text(msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : AppTheme.textPrimary,
            fontSize: 15, height: 1.5,
          )),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final bool listening;
  final CharacterPersona persona;
  final VoidCallback onSend;
  final VoidCallback? onVoice;

  const _InputBar({
    required this.controller,
    required this.loading,
    required this.listening,
    required this.persona,
    required this.onSend,
    this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      decoration: const BoxDecoration(
        color: AppTheme.bgColor,
        border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Row(children: [
        if (onVoice != null) _VoiceButton(listening: listening, onTap: onVoice!),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: listening ? AppTheme.accentBlue.withOpacity(0.6) : AppTheme.cardBorder,
                width: listening ? 1.5 : 0.5,
              ),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              maxLines: 4, minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: listening ? 'Слушаю...' : 'Напиши что-нибудь...',
                hintStyle: TextStyle(
                  color: listening ? AppTheme.accentBlue : AppTheme.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
              gradient: loading ? null : LinearGradient(colors: persona.gradientColors),
              color: loading ? AppTheme.cardColor : null,
            ),
            child: Icon(
              loading ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
              color: loading ? AppTheme.textSecondary : Colors.white,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Кнопка микрофона ──────────────────────────────────────────────────────────
class _VoiceButton extends StatefulWidget {
  final bool listening;
  final VoidCallback onTap;
  const _VoiceButton({required this.listening, required this.onTap});
  @override State<_VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<_VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didUpdateWidget(_VoiceButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening) {
      _pulse.stop();
      _pulse.animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Transform.scale(
          scale: widget.listening ? 1.0 + _pulse.value * 0.12 : 1.0,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 46, height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.listening ? AppTheme.accentBlue.withOpacity(0.18) : AppTheme.cardColor,
            border: Border.all(
              color: widget.listening ? AppTheme.accentBlue : AppTheme.cardBorder,
              width: widget.listening ? 1.5 : 0.5,
            ),
          ),
          child: Icon(
            widget.listening ? Icons.mic : Icons.mic_none_outlined,
            color: widget.listening ? AppTheme.accentBlue : AppTheme.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
