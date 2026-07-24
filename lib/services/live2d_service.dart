import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live2DService — генерирует HTML для WebView с PIXI.js Live2D,
/// загружает модель по HTTP URL, управляет размером.
class Live2DService {
  static final Live2DService _instance = Live2DService._();
  factory Live2DService() => _instance;
  Live2DService._();

  /// Получить текущий URL модели из SharedPreferences
  Future<String> getModelUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('live2d_model_url') ??
        'https://cdn.jsdelivr.net/gh/Eikanya/Live2d-model/Live2D/Senko_Normals/senko.model3.json';
  }

  /// Сохранить URL модели
  Future<void> setModelUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('live2d_model_url', url);
  }

  /// Получить размер модели (ширина в px, по умолчанию 250)
  Future<double> getModelSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('live2d_model_size') ?? 250.0;
  }

  /// Сохранить размер
  Future<void> setModelSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('live2d_model_size', size);
  }

  /// Сгенерировать HTML для WebView — прозрачный фон, PIXI.js Live2D
  String generateHtml(String modelUrl, double width) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<script src="https://cdn.jsdelivr.net/npm/pixi.js@6.5.10/dist/browser/pixi.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/pixi-live2d-display/dist/index.min.js"></script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%;
    height: 100%;
    background: transparent !important;
    overflow: hidden;
  }
  #canvas {
    width: 100%;
    height: 100%;
    background: transparent !important;
    display: block;
  }
  /* Прозрачный canvas */
  canvas { background: transparent !important; }
</style>
</head>
<body>
<canvas id="canvas"></canvas>
<script>
  let app, model, resizeTimer;
  const MODEL_URL = "$modelUrl";
  const INITIAL_WIDTH = $width;

  async function init() {
    try {
      //PIXI.js с прозрачным фоном
      app = new PIXI.Application({
        view: document.getElementById("canvas"),
        autoStart: true,
        backgroundAlpha: 0,
        transparent: true,
        antialias: true,
        resolution: window.devicePixelRatio || 1,
        autoDensity: true,
      });

      // Загружаем модель по HTTP
      model = await PIXI.live2d.Live2DModel.from(MODEL_URL);

      // Отключаем звук модели
      if (PIXI.live2d.config) {
        PIXI.live2d.config.sound = false;
      }
      if (model && model.internalModel) {
        if (model.internalModel.motionManager) {
          model.internalModel.motionManager.onMotionStart = null;
        }
        if (model.internalModel.coreModel && model.internalModel.coreModel.setVolume) {
          model.internalModel.coreModel.setVolume(0);
        }
      }

      app.stage.addChild(model);

      // Авто-подгон размера модели под canvas
      fitModel();

      // Центрируем модель по нижней части
      model.anchor.set(0.5, 0.5);
      model.x = app.screen.width / 2;
      model.y = app.screen.height / 2;

      // Авто-движение (idle motion)
      if (model.internalModel && model.internalModel.motionManager) {
        try {
          model.internalModel.motionManager.startRandomMotion();
        } catch(e) {}
      }

      console.log("Live2D model loaded:", MODEL_URL);
      window.flutter_inappwebview.callHandler("onModelLoaded", JSON.stringify({success: true}));
    } catch (e) {
      console.error("Live2D load error:", e);
      window.flutter_inappwebview.callHandler("onModelError", e.toString());
    }
  }

  function fitModel() {
    if (!model || !app) return;
    const scale = Math.min(
      app.screen.width / model.width,
      app.screen.height / model.height
    );
    model.scale.set(scale);
    model.x = app.screen.width / 2;
    model.y = app.screen.height / 2;
  }

  // Resize через сообщение из Flutter
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(fitModel, 200);
  });

  // Принять команду изменения размера от Flutter
  window.handleResize = function(w, h) {
    if (!app) return;
    app.renderer.resize(w, h);
    fitModel();
  };

  // Принать команду движения
  window.playMotion = function(name) {
    if (!model) return;
    try {
      model.motion(name || "Idle");
    } catch(e) {
      console.error("motion error:", e);
    }
  };

  // Тап по модели → движение
  document.addEventListener("click", (e) => {
    if (!model) return;
    try {
      const x = e.offsetX;
      const y = e.offsetY;
      // Focus на точку клика
      model.focus(x, y);
      // Через 2 сек убрать фокус
      setTimeout(() => { if (model) model.focus(0, 0); }, 2000);
    } catch(err) {}
  });

  init();
</script>
</body>
</html>''';
  }
}
