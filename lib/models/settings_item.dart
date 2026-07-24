import 'package:flutter/material.dart';

class SettingsItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String badge; // 'active' | 'soon' | ''

  const SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.badge = '',
  });
}

const settingsItems = [
  // ── Активные модули ──────────────────────────────────────────
  SettingsItem(
    title: 'Чат с AI',
    subtitle: 'GPT-4o-mini • распознавание изображений',
    icon: Icons.chat_bubble_outline,
    route: '/modules/chat',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Голосовой ввод',
    subtitle: 'Speech-to-Text • ru-RU • dictation',
    icon: Icons.mic_none,
    route: '/modules/voice',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Синтез речи (TTS)',
    subtitle: 'FlutterTTS • ru-RU • 2 персонажа',
    icon: Icons.record_voice_over,
    route: '/modules/tts',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Персонажи',
    subtitle: 'JARVIS и Airi • системные промпты',
    icon: Icons.person_outline,
    route: '/card',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Провайдеры',
    subtitle: 'OpenAI API Key • модель gpt-4o-mini',
    icon: Icons.hub_outlined,
    route: '/providers',
    badge: 'active',
  ),

  // ── В разработке ─────────────────────────────────────────────
  SettingsItem(
    title: 'Зрение (Vision)',
    subtitle: 'Анализ изображений через камеру',
    icon: Icons.visibility_outlined,
    route: '/modules/vision',
    badge: 'soon',
  ),
  SettingsItem(
    title: 'Live2D модели',
    subtitle: 'Анимация персонажей на экране',
    icon: Icons.view_in_ar_outlined,
    route: '/models',
    badge: 'soon',
  ),
  SettingsItem(
    title: 'Память',
    subtitle: 'Контекст диалога и история',
    icon: Icons.memory_outlined,
    route: '/memory',
    badge: 'soon',
  ),
  SettingsItem(
    title: 'Сцены',
    subtitle: 'Виртуальная среда для персонажей',
    icon: Icons.landscape_outlined,
    route: '/scenes',
    badge: 'soon',
  ),
  SettingsItem(
    title: 'Расширения',
    subtitle: 'Плагины и доп. возможности',
    icon: Icons.power_outlined,
    route: '/extensions',
    badge: 'soon',
  ),
  SettingsItem(
    title: 'Разработчик',
    subtitle: 'Отладка, логи и dev-инструменты',
    icon: Icons.code_outlined,
    route: '/developer',
    badge: 'soon',
  ),
];
