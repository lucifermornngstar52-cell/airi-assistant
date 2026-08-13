import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'vision_service.dart';

/// EmotionService — скрытно делает фото с фронтальной камеры
/// через camera пакет (без UI), анализирует эмоции.
class EmotionService {
  static final EmotionService _instance = EmotionService._();
  factory EmotionService() => _instance;
  EmotionService._();

  final _vision = VisionService();
  Timer? _timer;
  bool _active = false;
  CameraController? _camController;
  bool _camReady = false;

  String? _lastEmotion;
  String? get lastEmotion => _lastEmotion;

  void Function(String emotion)? onEmotionDetected;
  void Function(String error)? onEmotionError;
  void Function()? onEmotionScan;

  /// Запустить скрытное наблюдение
  void start() async {
    if (_active) return;
    _active = true;
    debugPrint('[Emotion] скрытное наблюдение запущено');

    await _initCamera();
    _timer = Timer(const Duration(seconds: 3), _check);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _camController = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _camController!.initialize();
      _camReady = true;
      debugPrint('[Emotion] фронтальная камера готова');
    } catch (e) {
      debugPrint('[Emotion] ошибка инициализации камеры: $e');
      _camReady = false;
    }
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    _lastEmotion = null;
    _camController?.dispose();
    _camController = null;
    _camReady = false;
    debugPrint('[Emotion] наблюдение остановлено, камера освобождена');
  }

  bool get isActive => _active;

  int _errorCount = 0;
  static const int _maxErrors = 3;

  void _check() async {
    if (!_active || !_camReady || _camController == null) {
      _scheduleNext();
      return;
    }

    // Если太多 ошибок подряд — пауза на 60 сек
    if (_errorCount >= _maxErrors) {
      debugPrint('[Emotion] слишком много ошибок, пауза 60 сек');
      _errorCount = 0;
      if (_active) _timer = Timer(const Duration(seconds: 60), _check);
      return;
    }

    try {
      final xfile = await _camController!.takePicture();
      final photo = File(xfile.path);

      final emotion = await _vision.analyzeEmotion(photo);

      if (emotion != null) {
        _errorCount = 0;
        debugPrint('[Emotion] результат: $emotion');
        if (emotion != _lastEmotion) {
          _lastEmotion = emotion;
          onEmotionDetected?.call(emotion);
        }
      } else {
        _errorCount++;
        debugPrint('[Emotion] нет результата, ошибки: $_errorCount/$_maxErrors');
      }

      try { await photo.delete(); } catch (_) {}
    } catch (e) {
      _errorCount++;
      debugPrint('[Emotion] ошибка: $e ($_errorCount/$_maxErrors)');
    }

    _scheduleNext();
  }

  void _scheduleNext() {
    if (!_active) return;
    _timer = Timer(const Duration(seconds: 10), _check);
  }
}
