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
