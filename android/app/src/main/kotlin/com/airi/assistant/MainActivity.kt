package com.airi.assistant

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airi.assistant/overlay").setMethodCallHandler { call, result ->
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
                    val v = call.argument<String>("state") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_SHOW)
                        .putExtra(AiriOverlayService.EXTRA_STATE, v)
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
                    val v = call.argument<String>("state") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_UPDATE)
                        .putExtra(AiriOverlayService.EXTRA_STATE, v)
                    startService(intent)
                    result.success(true)
                }
                "configOverlay" -> {
                    val v = (call.argument<Number>("size") ?: 200).toFloat()
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_CONFIG)
                        .putExtra(AiriOverlayService.EXTRA_SIZE, v)
                    startService(intent)
                    result.success(true)
                }
                "switchModel" -> {
                    val v = call.argument<String>("path") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_SWITCH_MODEL)
                        .putExtra(AiriOverlayService.EXTRA_MODEL_PATH, v)
                    startService(intent)
                    result.success(true)
                }
                "setDragEnabled" -> {
                    val v = call.argument<Boolean>("enabled") ?: false
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_DRAG_ENABLED)
                        .putExtra(AiriOverlayService.EXTRA_DRAG_ENABLED, v)
                    startService(intent)
                    result.success(true)
                }
                "musicOverlay" -> {
                    val v = call.argument<Boolean>("playing") ?: false
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_MUSIC)
                        .putExtra(AiriOverlayService.EXTRA_PLAYING, v)
                    startService(intent)
                    result.success(true)
                }
                "animOverlay" -> {
                    val v = call.argument<String>("anim") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_ANIM)
                        .putExtra(AiriOverlayService.EXTRA_ANIM, v)
                    startService(intent)
                    result.success(true)
                }
                "playSound" -> {
                    val v = call.argument<String>("path") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_PLAY_SOUND)
                        .putExtra(AiriOverlayService.EXTRA_SOUND_PATH, v)
                    startService(intent)
                    result.success(true)
                }
                "stopSound" -> {
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_STOP_SOUND)
                    startService(intent)
                    result.success(true)
                }
                "setMode" -> {
                    val v = call.argument<String>("mode") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_SET_MODE)
                        .putExtra(AiriOverlayService.EXTRA_MODE, v)
                    startService(intent)
                    result.success(true)
                }
                "setConfig" -> {
                    val size = (call.argument<Number>("size") ?: 200).toFloat()
                    val opacity = (call.argument<Number>("opacity") ?: 1.0).toFloat()
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_CONFIG)
                        .putExtra(AiriOverlayService.EXTRA_SIZE, size)
                        .putExtra(AiriOverlayService.EXTRA_OPACITY, opacity)
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
