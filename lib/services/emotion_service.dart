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

  /// Запустить скрытное наблюдение
  void start() async {
    if (_active) return;
    _active = true;
    debugPrint('[Emotion] скрытное наблюдение запущено');

    await _initCamera();
    _timer = Timer(const Duration(seconds: 10), _check);
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

  void _check() async {
    if (!_active || !_camReady || _camController == null) {
      _scheduleNext();
      return;
    }

    try {
      final xfile = await _camController!.takePicture();
      final photo = File(xfile.path);

      final emotion = await _vision.analyzeEmotion(photo);
      debugPrint('[Emotion] результат: $emotion');

      if (emotion != null && emotion != _lastEmotion) {
        _lastEmotion = emotion;
        onEmotionDetected?.call(emotion);
      }

      try { await photo.delete(); } catch (_) {}
    } catch (e) {
      debugPrint('[Emotion] ошибка съёмки: $e');
    }

    _scheduleNext();
  }

  void _scheduleNext() {
    if (!_active) return;
    _timer = Timer(const Duration(seconds: 20), _check);
  }
}
