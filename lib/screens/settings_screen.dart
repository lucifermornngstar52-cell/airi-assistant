import 'package:flutter/material.dart';
import '../models/settings_item.dart';
import '../models/character_persona.dart';
import '../widgets/settings_card.dart';
import '../theme/app_theme.dart';
import 'persona_screen.dart';
import 'providers_screen.dart';
import '../services/live2d_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: const Text(
          'Настройки',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        itemCount: settingsItems.length,
        itemBuilder: (ctx, i) => SettingsCard(
          item: settingsItems[i],
          onTap: () => _navigate(context, settingsItems[i].route),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Widget screen;
    switch (route) {
      case '/card':
        screen = PersonaScreen(
          currentType: PersonaType.jarvis,
          onSelect: (_) {},
        );
        break;
      case '/providers':
        screen = const ProvidersScreen();
        break;
      case '/modules/voice':
        screen = const _ModuleDetailScreen(
          title: 'Голосовой ввод',
          icon: Icons.mic_none,
          items: [
            ('Распознавание речи', 'SpeechToText (speech_to_text)'),
            ('Язык', 'ru-RU (без fallback)'),
            ('Режим', 'Dictation — фиксация фразы целиком'),
            ('Пауза', '2 сек после последнего слова'),
            ('Таймаут', '20 сек макс'),
            ('Авто-retry', 'Повтор при временной ошибке (до 3 попыток)'),
            ('Частичные результаты', 'Включены — текст в реальном времени'),
          ],
        );
        break;
      case '/modules/tts':
        screen = const _ModuleDetailScreen(
          title: 'Синтез речи',
          icon: Icons.record_voice_over,
          items: [
            ('Движок', 'FlutterTTS (flutter_tts)'),
            ('Язык', 'ru-RU'),
            ('Персонажей', '2 (JARVIS и Airi)'),
            ('JARVIS', 'Speed 0.48, Pitch 0.85'),
            ('Airi', 'Speed 0.44, Pitch 1.1'),
            ('Очистка текста', 'Markdown stripping перед TTS'),
          ],
        );
        break;
      case '/modules/chat':
        screen = const _ModuleDetailScreen(
          title: 'Чат с AI',
          icon: Icons.chat_bubble_outline,
          items: [
            ('Провайдер', 'OpenAI API'),
            ('Модель', 'gpt-4o-mini'),
            ('Max tokens', '1000'),
            ('Temperature', '0.85'),
            ('Персонажи', 'JARVIS / Airi — разные промпты'),
            ('Сохранение ключа', 'SharedPreferences (локально)'),
          ],
        );
        break;
      case '/modules/vision':
        screen = const _ModuleDetailScreen(
          title: 'Зрение (Vision)',
          icon: Icons.visibility_outlined,
          items: [
            ('Источник', 'Камера (image_picker)'),
            ('Движок', 'GPT-4o-mini Vision API'),
            ('Размер фото', '1024x1024, качество 85%'),
            ('Формат', 'JPEG / PNG -> base64'),
            ('Макс. токенов', '800'),
            ('Промпт', 'Описание фото или ответ на вопрос'),
          ],
        );
        break;
      case '/modules/emotion':
        screen = const _ModuleDetailScreen(
          title: 'Анализ эмоций',
          icon: Icons.face_retouching_natural_outlined,
          items: [
            ('Камера', 'Фронтальная (CameraDevice.front)'),
            ('Интервал', 'Каждые 20 секунд'),
            ('Первая проверка', 'Через 8 сек после запуска'),
            ('Движок', 'GPT-4o-mini Vision API'),
            ('Max tokens', '50 (короткий ответ)'),
            ('Интеграция', 'Эмоция влияет на тон ответа AI'),
            ('Размер фото', '768x768, качество 75%'),
          ],
        );
        break;
      case '/memory':
        screen = const _ModuleDetailScreen(
          title: 'Память',
          icon: Icons.memory_outlined,
          items: [
            ('Хранилище', 'SQLite (sqflite) — локально на устройстве'),
            ('База данных', 'airi_memory.db'),
            ('Таблицы', 'messages, facts, sessions'),
            ('Контекст', 'Последние 20 сообщений в system prompt'),
            ('Факты', 'Имя, работа, город, возраст — автоизвлечение'),
            ('Загрузка', 'История восстанавливается при открытии чата'),
            ('Синхронизация', 'Локально, без облака'),
          ],
        );
        break;
      case '/models':
        screen = const Live2DSettingsScreen();
        break;
      default:
        screen = _PlaceholderScreen(route: route);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String route;
  const _PlaceholderScreen({required this.route});

  @override
  Widget build(BuildContext context) {
    final item = settingsItems.firstWhere(
      (e) => e.route == route,
      orElse: () => const SettingsItem(
        title: 'Раздел',
        subtitle: '',
        icon: Icons.settings_outlined,
        route: '/',
      ),
    );
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder, width: 0.5),
          ),
          child: Icon(item.icon, color: AppTheme.textSecondary, size: 32),
        ),
        const SizedBox(height: 18),
        Text(
          item.title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Скоро',
            style: TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ])),
    );
  }
}


class _ModuleDetailScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String)> items;

  const _ModuleDetailScreen({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accentBlue.withOpacity(0.25), width: 1),
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.accentBlue, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('работает',
                        style: TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),
          // Items
          ...items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12,
                      )),
                      const SizedBox(height: 4),
                      Text(item.$2, style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}


class Live2DSettingsScreen extends StatefulWidget {
  const Live2DSettingsScreen({super.key});
  @override State<Live2DSettingsScreen> createState() => _Live2DSettingsScreenState();
}

class _Live2DSettingsScreenState extends State<Live2DSettingsScreen> {
  final _live2d = Live2DService();
  final _urlCtrl = TextEditingController();
  double _size = 250;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _urlCtrl.text = await _live2d.getModelUrl();
    _size = await _live2d.getModelSize();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Live2D оверлей',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Статус
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accentBlue.withOpacity(0.25), width: 1),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.view_in_ar_outlined, color: AppTheme.accentBlue, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live2D Overlay', style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Модель плавает поверх всех приложений',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // URL модели
          const Text('URL МОДЕЛИ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: TextField(
              controller: _urlCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'https://...model3.json',
                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                contentPadding: EdgeInsets.all(14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                await _live2d.setModelUrl(_urlCtrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('URL сохранён'),
                    backgroundColor: AppTheme.cardColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: const Text('Сохранить URL'),
            ),
          ),
          const SizedBox(height: 24),

          // Размер модели
          const Text('РАЗМЕР МОДЕЛИ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: Row(children: [
              const Icon(Icons.zoom_in, color: AppTheme.textSecondary, size: 20),
              Expanded(
                child: Slider(
                  value: _size,
                  min: 120,
                  max: 400,
                  divisions: 28,
                  label: _size.round().toString() + 'px',
                  onChanged: (v) => setState(() => _size = v),
                  onChangeEnd: (v) => _live2d.setModelSize(v),
                  activeColor: AppTheme.accentBlue,
                ),
              ),
              Text(_size.round().toString() + 'px',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),

          // Инструкция
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder, width: 0.5),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 18),
                  SizedBox(width: 8),
                  Text('Как использовать', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
                SizedBox(height: 10),
                Text('1. Нажми иконку слоёв в чате чтобы включить оверлей\n'
                     '2. Модель появится поверх всех приложений\n'
                     '3. Тап по модели → покажутся контролы (размер, закрыть)\n'
                     '4. Модель можно перетаскивать по экрану\n'
                     '5. Фон прозрачный — видна только модель',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

