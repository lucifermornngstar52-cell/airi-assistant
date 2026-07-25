import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OverlayService — управляет нативным Live2D оверлеем через MethodChannel.
/// Тот же подход что на aika-assistant.
class OverlayService {
  static final OverlayService _i = OverlayService._();
  factory OverlayService() => _i;
  OverlayService._();

  static const _channel = MethodChannel('com.airi.assistant/overlay');
  bool _active = false;
  bool get isActive => _active;

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod('hasPermission') ?? false;
    } catch (_) { return false; }
  }

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod('requestPermission') ?? false;
    } catch (_) { return false; }
  }

  Future<bool> show({String state = 'idle'}) async {
    if (_active) return true;
    final hasPerm = await hasPermission();
    if (!hasPerm) {
      await requestPermission();
      return false;
    }
    try {
      await _channel.invokeMethod('showOverlay', {'state': state});
      _active = true;
      return true;
    } catch (_) { return false; }
  }

  Future<void> hide() async {
    try {
      await _channel.invokeMethod('hideOverlay');
      _active = false;
    } catch (_) {}
  }

  Future<bool> toggle() async {
    if (_active) {
      await hide();
      return false;
    } else {
      return show();
    }
  }

  Future<void> setState(String state) async {
    try { await _channel.invokeMethod('updateOverlay', {'state': state}); } catch (_) {}
  }

  Future<void> setSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('live2d_model_size', size);
    try { await _channel.invokeMethod('configOverlay', {'size': size}); } catch (_) {}
  }

  Future<void> switchModel(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('live2d_model_url', url);
    try { await _channel.invokeMethod('switchModel', {'model_url': url}); } catch (_) {}
  }

  Future<void> setDragEnabled(bool enabled) async {
    try { await _channel.invokeMethod('setDragEnabled', {'enabled': enabled}); } catch (_) {}
  }
}
