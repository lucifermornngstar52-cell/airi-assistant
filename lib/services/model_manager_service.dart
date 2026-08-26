import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'overlay_service.dart';

/// Модель для списка доступных Live2D моделей
class Live2DModel {
  final String name;
  final String assetPath; // Путь в assets или путь к файлу
  final bool isBuiltin;
  final String? thumbnail;

  Live2DModel({
    required this.name,
    required this.assetPath,
    this.isBuiltin = true,
    this.thumbnail,
  });
}

/// Менеджер моделей — выбирает, загружает кастомные, переключает в оверлее
class ModelManagerService extends ChangeNotifier {
  static final ModelManagerService _i = ModelManagerService._();
  factory ModelManagerService() => _i;
  ModelManagerService._();

  static const _prefKey = 'current_model_path';
  static const _customModelsKey = 'custom_models';

  final _overlay = OverlayService();

  /// Встроенные модели (из assets)
  final List<Live2DModel> builtinModels = [
    Live2DModel(name: 'Hiyori', assetPath: 'assets/models/Hiyori/Hiyori.model3.json'),
    Live2DModel(name: 'Natori', assetPath: 'assets/models/Natori/Natori.model3.json'),
  ];

  /// Кастомные модели (загруженные пользователем)
  final List<Live2DModel> _customModels = [];
  List<Live2DModel> get customModels => List.unmodifiable(_customModels);

  /// Все доступные модели
  List<Live2DModel> get allModels => [...builtinModels, ..._customModels];

  /// Текущая модель
  String _currentPath = 'assets/models/Hiyori/Hiyori.model3.json';
  String get currentPath => _currentPath;
  String get currentName {
    for (final m in allModels) {
      if (m.assetPath == _currentPath) return m.name;
    }
    return 'Неизвестно';
  }

  // ─── Инициализация ──────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentPath = prefs.getString(_prefKey) ?? 'assets/models/Hiyori/Hiyori.model3.json';
    await _loadCustomModels();
  }

  // ─── Загрузка списка кастомных моделей из prefs ────────
  Future<void> _loadCustomModels() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_customModelsKey) ?? [];
    _customModels.clear();
    for (final entry in list) {
      final parts = entry.split('|');
      if (parts.length >= 2) {
        _customModels.add(Live2DModel(
          name: parts[0],
          assetPath: parts[1],
          isBuiltin: false,
        ));
      }
    }
    notifyListeners();
  }

  // ─── Переключить модель ────────────────────────────────
  Future<void> selectModel(String assetPath) async {
    _currentPath = assetPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, assetPath);
    await _overlay.switchModel(assetPath);
    notifyListeners();
  }

  // ─── Загрузить кастомную модель из файла ────────────────
  /// Поддерживает .model3.json файлы. Копирует модель в app storage.
  Future<String?> importCustomModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final filePath = result.files.first.path;
      if (filePath == null) return null;

      final file = File(filePath);
      final fileName = file.uri.pathSegments.last;

      // Проверяем что это model3.json
      if (!fileName.contains('.model3.json') && !fileName.endsWith('.json')) {
        return 'Нужно выбрать .model3.json файл модели';
      }

      // Копируем файл в app documents
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/custom_models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      // Имя модели из имени файла
      final modelDirName = fileName.replaceAll('.model3.json', '').replaceAll('.json', '');
      final modelDir = Directory('${modelsDir.path}/$modelDirName');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      // Копируем model3.json
      final destPath = '${modelDir.path}/$fileName';
      await file.copy(destPath);

      // Также пытаемся скопировать текстуры и moc из той же папки
      final sourceDir = file.parent;
      try {
        await for (final entity in sourceDir.list()) {
          if (entity is File) {
            final name = entity.uri.pathSegments.last;
            if (name.endsWith('.moc3') || name.endsWith('.png') || name.endsWith('.physic') ||
                name.endsWith('.json') || name.endsWith('.cdi3') || name.endsWith('.pose')) {
              await entity.copy('${modelDir.path}/$name');
            }
          }
        }
      } catch (_) {}

      // Регистрируем кастомную модель
      final customPath = '${modelDir.path}/$fileName';
      _customModels.add(Live2DModel(
        name: modelDirName,
        assetPath: customPath,
        isBuiltin: false,
      ));

      // Сохраняем список
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_customModelsKey) ?? [];
      list.add('$modelDirName|$customPath');
      await prefs.setStringList(_customModelsKey, list);

      notifyListeners();
      return customPath;
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  // ─── Удалить кастомную модель ──────────────────────────
  Future<void> removeCustomModel(int index) async {
    if (index < 0 || index >= _customModels.length) return;
    final model = _customModels[index];

    // Удаляем файлы
    try {
      final dir = Directory(model.assetPath).parent;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}

    _customModels.removeAt(index);

    // Обновляем prefs
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_customModelsKey) ?? [])
        .where((e) => !e.startsWith('${model.name}|'))
        .toList();
    await prefs.setStringList(_customModelsKey, list);

    // Если текущая модель удалена — переключаем на встроенную
    if (_currentPath == model.assetPath) {
      await selectModel(builtinModels.first.assetPath);
    }

    notifyListeners();
  }
}
