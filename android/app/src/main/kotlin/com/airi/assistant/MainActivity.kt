package com.airi.assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import flutter.overlay_window.FlutterOverlayWindowPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Регистрируем overlay entry point
        flutterEngine.dartExecutor.executeDartEntrypoint(
            io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint(
                null,
                "overlayMain"
            )
        )
    }
}
