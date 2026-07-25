import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live2DService — хранит URL модели и размер.
/// HTML рендеринг через assets/live2d_viewer.html (как на aika).
class Live2DService {
  static final Live2DService _instance = Live2DService._();
  factory Live2DService() => _instance;
  Live2DService._();

  Future<String> getModelUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('live2d_model_url') ??
        'https://cdn.jsdelivr.net/gh/Eikanya/Live2d-model/Live2D/Senko_Normals/senko.model3.json';
  }

  Future<void> setModelUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('live2d_model_url', url);
  }

  Future<double> getModelSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('live2d_model_size') ?? 250.0;
  }

  Future<void> setModelSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('live2d_model_size', size);
  }
}
