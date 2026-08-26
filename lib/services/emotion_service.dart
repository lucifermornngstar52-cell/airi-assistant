import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'vision_service.dart';

/// EmotionService — НЕПРЕРЫВНОЕ отслеживание эмоций.
/// Камера работает постоянно, снимает кадры каждые 1.5 секунды.
/// Без периодических пауз — реально постоянное наблюдение.
class EmotionService {
  static final EmotionService _instance = EmotionService._();
  factory EmotionService() => _instance;
  EmotionService._();

  final _vision = VisionService();
  bool _active = false;
  CameraController? _camController;
  bool _camReady = false;
  bool _analyzing = false;

  String? _lastEmotion;
  String? get lastEmotion => _lastEmotion;

  Timer? _captureTimer;

  void Function(String emotion)? onEmotionDetected;
  void Function(String error)? onEmotionError;
  void Function()? onEmotionScan;

  void start() async {
    if (_active) return;
    _active = true;
    debugPrint('[Emotion] непрерывное наблюдение запущено');
    await _initCamera();
    // Start continuous capture loop — every 1.5 seconds
    _captureTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _captureAndAnalyze());
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
      debugPrint('[Emotion] камера готова — непрерывный режим');
    } catch (e) {
      debugPrint('[Emotion] ошибка инициализации камеры: $e');
      _camReady = false;
      onEmotionError?.call('Не удалось инициализировать камеру');
    }
  }

  void _captureAndAnalyze() async {
    if (!_active || !_camReady || _camController == null || _analyzing) return;

    _analyzing = true;
    try {
      final xfile = await _camController!.takePicture();
      final photo = File(xfile.path);

      onEmotionScan?.call();

      final emotion = await _vision.analyzeEmotion(photo);

      if (emotion != null) {
        debugPrint('[Emotion] результат: $emotion');
        if (emotion != _lastEmotion) {
          _lastEmotion = emotion;
          onEmotionDetected?.call(emotion);
        }
      }

      try { await photo.delete(); } catch (_) {}
    } catch (e) {
      debugPrint('[Emotion] ошибка захвата: $e');
    } finally {
      _analyzing = false;
    }
  }

  void stop() {
    _active = false;
    _captureTimer?.cancel();
    _captureTimer = null;
    if (_camController != null) {
      _camController!.dispose();
      _camController = null;
    }
    _camReady = false;
    _lastEmotion = null;
    _analyzing = false;
    debugPrint('[Emotion] наблюдение остановлено');
  }

  bool get isActive => _active;
}
