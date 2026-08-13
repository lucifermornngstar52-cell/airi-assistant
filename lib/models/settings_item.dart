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
    subtitle: 'Камера + GPT-4o-mini Vision • анализ фото',
    icon: Icons.visibility_outlined,
    route: '/modules/vision',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Эмоции',
    subtitle: 'Фронтальная камера • анализ эмоций в реальном времени',
    icon: Icons.face_retouching_natural_outlined,
    route: '/modules/emotion',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Live2D оверлей',
    subtitle: 'Модель поверх всех приложений • HTTP загрузка',
    icon: Icons.view_in_ar_outlined,
    route: '/models',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Память',
    subtitle: 'SQLite • история диалогов + факты о пользователе',
    icon: Icons.memory_outlined,
    route: '/memory',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Сцены',
    subtitle: 'Виртуальная среда для персонажей',
    icon: Icons.landscape_outlined,
    route: '/scenes',
    badge: 'active',
  ),
  // ── Расширения ────────────────────────────────────────────────
  SettingsItem(
    title: 'Курсы валют',
    subtitle: 'USD, EUR, GBP, CNY, KZT, BTC • голосовые запросы',
    icon: Icons.attach_money,
    route: '/ext/currency',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Погода',
    subtitle: 'Текущая погода и прогноз • Open-Meteo',
    icon: Icons.wb_cloudy_outlined,
    route: '/ext/weather',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Веб-поиск',
    subtitle: 'Поиск в интернете через AI',
    icon: Icons.search,
    route: '/ext/websearch',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Новости',
    subtitle: 'Лента новостей по категориям',
    icon: Icons.article_outlined,
    route: '/ext/news',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Напоминания',
    subtitle: 'Локальные напоминания с уведомлениями',
    icon: Icons.notifications_outlined,
    route: '/ext/reminders',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Список покупок',
    subtitle: 'Совместный список с категориями',
    icon: Icons.shopping_cart_outlined,
    route: '/ext/shoplist',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Расписание',
    subtitle: 'Календарь и планировщик задач',
    icon: Icons.calendar_today_outlined,
    route: '/ext/schedule',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Дневник настроения',
    subtitle: 'Отслеживание эмоций и триггеров',
    icon: Icons.mood_outlined,
    route: '/ext/mooddiary',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Личность AI',
    subtitle: 'Эволюция характера • Aika и Gabimaru',
    icon: Icons.psychology_outlined,
    route: '/ext/personality',
    badge: 'active',
  ),
  SettingsItem(
    title: 'Буфер обмена',
    subtitle: 'История и управление буфером',
    icon: Icons.content_copy,
    route: '/ext/clipboard',
    badge: 'active',
  ),

  SettingsItem(
    title: 'Разработчик',
    subtitle: 'Отладка, логи и dev-инструменты',
    icon: Icons.code_outlined,
    route: '/developer',
    badge: 'soon',
  ),
];
