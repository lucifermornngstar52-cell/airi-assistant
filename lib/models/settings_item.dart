import 'package:flutter/material.dart';

class SettingsItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}

const settingsItems = [
  SettingsItem(
    title: 'Карта AIRI',
    subtitle: 'Предустановленные карты персонажей',
    icon: Icons.person_outline,
    route: '/card',
  ),
  SettingsItem(
    title: 'Модули',
    subtitle: 'Зрение, синтез речи, дополнения',
    icon: Icons.extension_outlined,
    route: '/modules',
  ),
  SettingsItem(
    title: 'Сцены',
    subtitle: 'Виртуальная среда для персонажей',
    icon: Icons.landscape_outlined,
    route: '/scenes',
  ),
  SettingsItem(
    title: 'Модели',
    subtitle: 'Live2D, VRM, Spine и др.',
    icon: Icons.view_in_ar_outlined,
    route: '/models',
  ),
  SettingsItem(
    title: 'Память',
    subtitle: 'Хранилище и организация воспоминаний',
    icon: Icons.memory_outlined,
    route: '/memory',
  ),
  SettingsItem(
    title: 'Провайдеры',
    subtitle: 'LLM-модели и провайдеры речи',
    icon: Icons.hub_outlined,
    route: '/providers',
  ),
  SettingsItem(
    title: 'Расширения',
    subtitle: 'Плагины и дополнительные возможности',
    icon: Icons.power_outlined,
    route: '/extensions',
  ),
  SettingsItem(
    title: 'Разработчик',
    subtitle: 'Отладка, логи и dev-инструменты',
    icon: Icons.code_outlined,
    route: '/developer',
  ),
];
