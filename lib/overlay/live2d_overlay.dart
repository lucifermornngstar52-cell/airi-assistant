import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  @override
  State<Live2DOverlayScreen> createState() => _Live2DOverlayScreenState();
}

class _Live2DOverlayScreenState extends State<Live2DOverlayScreen> {
  InAppWebViewController? _webController;
  String _modelUrl = '';
  double _modelSize = 250;
  double _windowWidth = 250;
  double _windowHeight = 350;
  bool _ready = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    FlutterOverlayWindow.overlayListener.listen((msg) {
      if (msg == 'hide') {
        FlutterOverlayWindow.closeOverlay();
      } else if (msg == 'toggle_controls') {
        setState(() => _showControls = !_showControls);
      } else if (msg.toString().startsWith('size:')) {
        final size = double.tryParse(msg.toString().split(':')[1]);
        if (size != null) _updateSize(size);
      } else if (msg.toString().startsWith('model:')) {
        final url = msg.toString().substring(6);
        _loadModelUrl(url);
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _modelUrl = prefs.getString('live2d_model_url') ??
        'https://cdn.jsdelivr.net/gh/Eikanya/Live2d-model/Live2D/Senko_Normals/senko.model3.json';
    _modelSize = prefs.getDouble('live2d_model_size') ?? 250.0;
    _windowWidth = _modelSize;
    _windowHeight = _modelSize * 1.4;
    if (mounted) setState(() {});
  }

  Future<void> _updateSize(double newSize) async {
    _modelSize = newSize;
    _windowWidth = newSize;
    _windowHeight = newSize * 1.4;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('live2d_model_size', newSize);
    await FlutterOverlayWindow.resizeOverlay(
      _windowWidth.round(), _windowHeight.round(), true
    );
    _webController?.evaluateJavascript(source: 'handleResize()');
    if (mounted) setState(() {});
  }

  void _loadModelUrl(String url) async {
    _modelUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('live2d_model_url', url);
    // Ждём 1200мс как на aika — PIXI.js должен быть готов
    Future.delayed(const Duration(milliseconds: 500), () {
      _webController?.evaluateJavascript(source: "loadCustomModel('$url')");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Container(
          width: _windowWidth,
          height: _windowHeight,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Stack(
            children: [
              InAppWebView(
                initialFile: 'assets/live2d_viewer.html',
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useHybridComposition: true,
                  disableDefaultErrorPage: true,
                  allowContentAccess: true,
                ),
                onWebViewCreated: (ctrl) {
                  _webController = ctrl;
                  ctrl.addJavaScriptHandler(
                    handlerName: 'FlutterChannel',
                    callback: (args) {
                      final msg = args.isNotEmpty ? args[0].toString() : '';
                      debugPrint('[Overlay] $msg');
                      if (msg == 'ready') {
                        // PIXI.js готов — загружаем модель через 1200мс
                        Future.delayed(const Duration(milliseconds: 1200), () {
                          _webController?.evaluateJavascript(
                            source: "loadCustomModel('$_modelUrl')"
                          );
                        });
                      } else if (msg == 'modelLoaded') {
                        if (mounted) setState(() => _ready = true);
                      }
                    },
                  );
                },
                onConsoleMessage: (ctrl, msg) {
                  debugPrint('[Overlay WebView] ${msg.message}');
                },
              ),
              if (_showControls)
                Positioned(
                  top: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
                            SizedBox(
                              width: 120,
                              child: Slider(
                                value: _modelSize, min: 120, max: 400,
                                onChanged: _updateSize,
                                activeColor: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
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
              if (!_ready && !_showControls)
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
}
