import 'package:flutter/material.dart';
import '../models/settings_item.dart';
import '../models/character_persona.dart';
import '../widgets/settings_card.dart';
import '../theme/app_theme.dart';
import 'persona_screen.dart';
import 'providers_screen.dart';

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

