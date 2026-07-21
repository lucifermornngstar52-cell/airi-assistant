class SettingsItem {
  final String title;
  final String subtitle;
  final String iconPath; // emoji или путь к иконке
  final String route;

  const SettingsItem({
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.route,
  });
}

const settingsItems = [
  SettingsItem(
    title: 'Карта AIRI',
    subtitle: 'Используйте предустановленные карты персонажей AIRI',
    iconPath: '🎴',
    route: '/card',
  ),
  SettingsItem(
    title: 'Модули',
    subtitle: 'Мыслительный процесс, зрение, синтез речи, игры и т. д.',
    iconPath: '🧩',
    route: '/modules',
  ),
  SettingsItem(
    title: 'Сцены',
    subtitle: 'Настройте виртуальную среду для персонажей.',
    iconPath: '🛋',
    route: '/scenes',
  ),
  SettingsItem(
    title: 'Модели',
    subtitle: 'Live2D, VRM, Spine и др.',
    iconPath: '🧍',
    route: '/models',
  ),
  SettingsItem(
    title: 'Память',
    subtitle: 'Хранилище и организация воспоминаний',
    iconPath: '💭',
    route: '/memory',
  ),
  SettingsItem(
    title: 'Провайдеры',
    subtitle: 'LLM-модели, провайдеры речи и др.',
    iconPath: '⚙️',
    route: '/providers',
  ),
  SettingsItem(
    title: 'Расширения',
    subtitle: 'Плагины и дополнительные возможности',
    iconPath: '🔌',
    route: '/extensions',
  ),
  SettingsItem(
    title: 'Разработчик',
    subtitle: 'Отладка, логи и dev-инструменты',
    iconPath: '🛠',
    route: '/developer',
  ),
];
