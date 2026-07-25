package com.airi.assistant

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.airi.assistant/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        Settings.canDrawOverlays(this) else true)
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName"))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "showOverlay" -> {
                    val state = call.argument<String>("state") ?: "idle"
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_SHOW)
                        .putExtra(AiriOverlayService.EXTRA_STATE, state)
                    startService(intent)
                    result.success(true)
                }
                "hideOverlay" -> {
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_HIDE)
                    startService(intent)
                    result.success(true)
                }
                "updateOverlay" -> {
                    val state = call.argument<String>("state") ?: "idle"
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_UPDATE)
                        .putExtra(AiriOverlayService.EXTRA_STATE, state)
                    startService(intent)
                    result.success(true)
                }
                "configOverlay" -> {
                    val size = (call.argument<Number>("size") ?: 200).toFloat()
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_CONFIG)
                        .putExtra(AiriOverlayService.EXTRA_SIZE, size)
                    startService(intent)
                    result.success(true)
                }
                "switchModel" -> {
                    val url = call.argument<String>("model_url") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_SWITCH_MODEL)
                        .putExtra(AiriOverlayService.EXTRA_MODEL, url)
                    startService(intent)
                    result.success(true)
                }
                "setDragEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_DRAG)
                        .putExtra(AiriOverlayService.EXTRA_DRAG, enabled)
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
