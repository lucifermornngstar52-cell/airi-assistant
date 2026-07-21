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
        title: const Text('Настройки',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        itemCount: settingsItems.length,
        itemBuilder: (ctx, i) => SettingsCard(
          item: settingsItems[i],
          index: i,
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
    final item = settingsItems.firstWhere((e) => e.route == route,
        orElse: () => const SettingsItem(title: '...', subtitle: '', iconPath: '🔧', route: '/'));
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(padding: EdgeInsets.only(left: 16),
              child: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary)),
        ),
        title: Text(item.title,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(item.iconPath, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        Text(item.subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        const Text('Скоро', style: TextStyle(color: AppTheme.accentBlue, fontSize: 13)),
      ])),
    );
  }
}
