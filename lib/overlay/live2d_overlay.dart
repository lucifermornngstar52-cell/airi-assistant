import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/live2d_service.dart';

/// Live2D Overlay — виджет который показывается поверх всех приложений.
/// Запускается как отдельный Flutter entry point (@pragma('vm:entry-point')).
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Live2DOverlayApp());
}

class Live2DOverlayApp extends StatelessWidget {
  const Live2DOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Live2DOverlayScreen(),
    );
  }
}

class Live2DOverlayScreen extends StatefulWidget {
  const Live2DOverlayScreen({super.key});
  @override State<Live2DOverlayScreen> createState() => _Live2DOverlayScreenState();
}

class _Live2DOverlayScreenState extends State<Live2DOverlayScreen> {
  InAppWebViewController? _webController;
  final _live2d = Live2DService();
  double _modelSize = 250;
  double _windowWidth = 250;
  double _windowHeight = 350;
  bool _modelLoaded = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Слушаем сообщения из основного приложения
    FlutterOverlayWindow.overlayListener.listen((msg) {
      if (msg == 'hide') {
        FlutterOverlayWindow.closeOverlay();
      } else if (msg == 'toggle_controls') {
        setState(() => _showControls = !_showControls);
      } else if (msg.toString().startsWith('size:')) {
        final size = double.tryParse(msg.toString().split(':')[1]);
        if (size != null) _updateSize(size);
      }
    });
  }

  Future<void> _loadSettings() async {
    _modelSize = await _live2d.getModelSize();
    _windowWidth = _modelSize;
    _windowHeight = _modelSize * 1.4;
    if (mounted) setState(() {});
  }

  Future<void> _updateSize(double newSize) async {
    _modelSize = newSize;
    _windowWidth = newSize;
    _windowHeight = newSize * 1.4;
    await _live2d.setModelSize(newSize);
    await FlutterOverlayWindow.resizeOverlay(_windowWidth.round(), _windowHeight.round());

    // Отправляем в WebView
    _webController?.evaluateJavascript(
      source: 'handleResize($_windowWidth, $_windowHeight)',
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _webController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
        },
        child: Container(
          width: _windowWidth,
          height: _windowHeight,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Stack(
            children: [
              // WebView с Live2D моделью
              InAppWebView(
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                  supportZoom: false,
                  allowsInlineMediaPlayback: true,
                  allowsBackForwardNavigationGestures: false,
                  iframeAllow: 'autoplay; camera; microphone',
                ),
                onWebViewCreated: (controller) {
                  _webController = controller;
                  _loadModel();
                },
                onConsoleMessage: (controller, message) {
                  debugPrint('[Overlay WebView] ${message.message}');
                },
              ),

              // Контролы (показываются по тапу)
              if (_showControls)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Слайдер размера
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
                            SizedBox(
                              width: 120,
                              child: Slider(
                                value: _modelSize,
                                min: 120,
                                max: 400,
                                onChanged: _updateSize,
                                activeColor: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Кнопка закрытия
                        GestureDetector(
                          onTap: () => FlutterOverlayWindow.closeOverlay(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('Закрыть', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Индикатор загрузки
              if (!_modelLoaded && !_showControls)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadModel() async {
    final modelUrl = await _live2d.getModelUrl();
    final html = _live2d.generateHtml(modelUrl, _modelSize);

    if (_webController == null) return;

    await _webController!.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
      baseUrl: Uri.parse('https://localhost/'),
    );

    // Регистрируем хендлеры
    _webController!.addJavaScriptHandler(
      handlerName: 'onModelLoaded',
      callback: (args) {
        debugPrint('[Overlay] Live2D model loaded!');
        if (mounted) setState(() => _modelLoaded = true);
      },
    );
    _webController!.addJavaScriptHandler(
      handlerName: 'onModelError',
      callback: (args) {
        debugPrint('[Overlay] Live2D error: $args');
      },
    );
  }
}
