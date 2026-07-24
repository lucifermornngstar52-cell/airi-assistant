import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'live2d_service.dart';

/// OverlayService — включает/выключает Live2D оверлей поверх всех приложений.
class OverlayService {
  static final OverlayService _instance = OverlayService._();
  factory OverlayService() => _instance;
  OverlayService._();

  final _live2d = Live2DService();
  bool _active = false;
  bool get isActive => _active;

  /// Проверить разрешение SYSTEM_ALERT_WINDOW
  Future<bool> hasPermission() async {
    return true;
  }

  /// Запросить разрешение на overlay
  Future<bool> requestPermission() async {
    final status = await Permission.systemAlertWindow.request();
    return status.isGranted;
  }

  /// Включить оверлей
  Future<bool> show() async {
    if (_active) return true;

    // Проверяем разрешение
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('[Overlay] нет разрешения SYSTEM_ALERT_WINDOW');
      return false;
    }

    final size = await _live2d.getModelSize();
    final width = size.round();
    final height = (size * 1.4).round();

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'AIRI',
      overlayContent: 'Модель загружается...',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: height,
      width: width,
      startPosition: OverlayPosition(0, 0),
    );
    _active = true;
    debugPrint('[Overlay] показан (${width}x${height})');
    return true;
  }

  /// Выключить оверлей
  Future<void> hide() async {
    await FlutterOverlayWindow.closeOverlay();
    _active = false;
    debugPrint('[Overlay] скрыт');
  }

  /// Переключить
  Future<bool> toggle() async {
    if (_active) {
      await hide();
      return false;
    } else {
      return show();
    }
  }

  /// Отправить сообщение в оверлей
  Future<void> sendMessage(String msg) async {
    FlutterOverlayWindow.shareData(msg);
  }

  /// Изменить размер оверлея
  Future<void> resize(double size) async {
    await _live2d.setModelSize(size);
    await FlutterOverlayWindow.resizeOverlay(size.round(), (size * 1.4).round(), true);
    await sendMessage('size:$size');
  }
}
