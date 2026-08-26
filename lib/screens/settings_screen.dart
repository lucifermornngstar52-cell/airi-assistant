import 'dart:io';
import 'package:flutter/material.dart';
import '../models/settings_item.dart';
import '../models/character_persona.dart';
import '../widgets/settings_card.dart';
import '../theme/app_theme.dart';
import 'persona_screen.dart';
import 'providers_screen.dart';
import 'model_selection_screen.dart';
import '../services/live2d_service.dart';
import 'currency_screen.dart';
import 'weather_screen.dart';
import 'schedule_screen.dart';
import 'mood_diary_screen.dart';
import 'scenes_screen.dart';
import 'functional_screens.dart';

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
        screen = const VoiceTestScreen();
        break;
      case '/modules/tts':
        screen = const TtsTestScreen();
        break;
      case '/modules/chat':
        screen = const ChatInfoScreen();
        break;
      case '/modules/vision':
        screen = const VisionTestScreen();
        break;
      case '/modules/emotion':
        screen = const EmotionTestScreen();
        break;
      case '/memory':
        screen = const MemoryViewScreen();
        break;
      case '/models':
        screen = const Live2DSettingsScreen();
        break;
      case '/ext/currency':
        screen = const CurrencyScreen();
        break;
      case '/ext/weather':
        screen = const WeatherScreen();
        break;
      case '/ext/schedule':
        screen = const ScheduleScreen();
        break;
      case '/ext/mooddiary':
        screen = const MoodDiaryScreen();
        break;
      case '/ext/websearch':
        screen = const WebSearchInfoScreen();
        break;
      case '/ext/news':
        screen = const NewsScreen();
        break;
      case '/ext/reminders':
        screen = const RemindersScreen();
        break;
      case '/ext/shoplist':
        screen = const ShopListScreen();
        break;
      case '/ext/personality':
        screen = const PersonalityScreen();
        break;
      case '/ext/clipboard':
        screen = const ClipboardScreen();
        break;
      case '/scenes':
        screen = const ScenesScreen();
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
        const SizedBox(height: 4),
                ],
              )),
        // ─── Выбор модели ─────────────────────────────────────
        ListTile(
          leading: const Icon(Icons.face_retouching_natural, color: Colors.blueAccent),
          title: const Text('Выбор модели'),
          subtitle: const Text('Встроенные + свои модели'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ModelSelectionScreen(),
            ));
          },
        ),
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

