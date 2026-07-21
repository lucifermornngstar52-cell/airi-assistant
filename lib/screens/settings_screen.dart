import 'package:flutter/material.dart';
import '../models/settings_item.dart';
import '../widgets/settings_card.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 22),
          ),
        ),
        title: const Text(
          'Настройки',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 4,
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PlaceholderScreen(route: route)),
    );
  }
}

// Заглушка для разделов
class _PlaceholderScreen extends StatelessWidget {
  final String route;
  const _PlaceholderScreen({required this.route});

  @override
  Widget build(BuildContext context) {
    final item = settingsItems.firstWhere((e) => e.route == route);
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          ),
        ),
        title: Text(item.title,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item.iconPath, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(item.subtitle,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const Text('Скоро', style: TextStyle(color: AppTheme.accentBlue, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
