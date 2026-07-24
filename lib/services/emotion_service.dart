import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'vision_service.dart';

/// EmotionService — периодически делает фото с фронталки
/// и анализирует эмоции пользователя во время чата.
class EmotionService {
  static final EmotionService _instance = EmotionService._();
  factory EmotionService() => _instance;
  EmotionService._();

  final _vision = VisionService();
  Timer? _timer;
  bool _active = false;

  /// Последняя обнаруженная эмоция
  String? _lastEmotion;
  String? get lastEmotion => _lastEmotion;

  /// Колбэк при новой эмоции
  void Function(String emotion)? onEmotionDetected;

  /// Запустить наблюдение (каждые 20 сек)
  void start() {
    if (_active) return;
    _active = true;
    debugPrint('[Emotion] наблюдение запущено');
    // Первая проверка через 8 сек (даём время на инициализацию)
    _timer = Timer(const Duration(seconds: 8), _check);
  }

  /// Остановить
  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    _lastEmotion = null;
    debugPrint('[Emotion] наблюдение остановлено');
  }

  bool get isActive => _active;

  void _check() async {
    if (!_active) return;

    try {
      final photo = await _vision.captureFrontPhoto();
      if (photo == null) {
        debugPrint('[Emotion] фото не получено');
        _scheduleNext();
        return;
      }

      final emotion = await _vision.analyzeEmotion(photo);
      debugPrint('[Emotion] результат: $emotion');

      if (emotion != null && emotion != _lastEmotion) {
        _lastEmotion = emotion;
        onEmotionDetected?.call(emotion);
      }

      // Удаляем временный файл
      try { await photo.delete(); } catch (_) {}
    } catch (e) {
      debugPrint('[Emotion] ошибка: $e');
    }

    _scheduleNext();
  }

  void _scheduleNext() {
    if (!_active) return;
    _timer = Timer(const Duration(seconds: 20), _check);
  }
}
