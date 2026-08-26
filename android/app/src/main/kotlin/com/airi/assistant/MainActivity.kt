package com.airi.assistant

import android.content.Intent
import android.util.Log
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.ContextCompat

private const val LAUNCHER_CHANNEL = "com.airi.assistant/launcher"

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Audio focus channel — detect calls and audio conflicts
        val audioMgr = getSystemService(AUDIO_SERVICE) as android.media.AudioManager
        val phoneMgr = getSystemService(TELEPHONY_SERVICE) as android.telephony.TelephonyManager
        
        // Simple audio focus listener
        val focusListener = object : android.media.AudioManager.OnAudioFocusChangeListener {
            override fun onAudioFocusChange(focusChange: Int) {
                when (focusChange) {
                    android.media.AudioManager.AUDIOFOCUS_LOSS,
                    android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                        Log.d("AiriAudio", "Audio focus lost — pausing STT")
                        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airi.assistant/audio")
                            .invokeMethod("audioFocusLost", null)
                    }
                    android.media.AudioManager.AUDIOFOCUS_GAIN -> {
                        Log.d("AiriAudio", "Audio focus regained — resuming STT")
                        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airi.assistant/audio")
                            .invokeMethod("audioFocusGained", null)
                    }
                }
            }
        }
        
        // Method channel for audio control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airi.assistant/audio").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestFocus" -> {
                    val req = android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                        .setAudioAttributes(
                            android.media.AudioAttributes.Builder()
                                .setUsage(android.media.AudioAttributes.USAGE_ASSISTANT)
                                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build()
                        )
                        .setOnAudioFocusChangeListener(focusListener)
                        .build()
                    val r = audioMgr.requestAudioFocus(req)
                    result.success(r == android.media.AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
                }
                "abandonFocus" -> {
                    result.success(true)
                }
                "isCallActive" -> {
                    try {
                        val tm = getSystemService(TELEPHONY_SERVICE) as android.telephony.TelephonyManager
                        val state = tm.callState
                        result.success(state != android.telephony.TelephonyManager.CALL_STATE_IDLE)
                    } catch (_: Throwable) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }


        // JARVIS HUD channel from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airi.assistant/hud").setMethodCallHandler { call, result ->
            when (call.method) {
                "showHud" -> {
                    try {
                        val i = Intent(this, JarvisHudService::class.java)
                            .setAction(JarvisHudService.ACTION_SHOW)
                        ContextCompat.startForegroundService(this, i)
                        result.success(true)
                    } catch (_: Throwable) { result.success(false) }
                }
                "hideHud" -> {
                    try {
                        val i = Intent(this, JarvisHudService::class.java)
                            .setAction(JarvisHudService.ACTION_HIDE)
                        startService(i)
                        result.success(true)
                    } catch (_: Throwable) { result.success(false) }
                }
                "hudTarget" -> {
                    val x = (call.argument<Number>("x") ?: 0f).toFloat()
                    val y = (call.argument<Number>("y") ?: 0f).toFloat()
                    JarvisHudService.showTarget(x, y)
                    result.success(true)
                }
                "hudStatus" -> {
                    val text = call.argument<String>("text") ?: ""
                    JarvisHudService.showStatus(text)
                    result.success(true)
                }
                "hudPulse" -> {
                    try {
                        val i = Intent(this, JarvisHudService::class.java)
                            .setAction(JarvisHudService.ACTION_PULSE)
                        startService(i)
                        result.success(true)
                    } catch (_: Throwable) { result.success(false) }
                }
                else -> result.notImplemented()
            }
        }

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
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "hideOverlay" -> {
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_HIDE)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "updateOverlay" -> {
                    val v = call.argument<String>("state") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_UPDATE)
                        .putExtra(AiriOverlayService.EXTRA_STATE, v)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "configOverlay" -> {
                    val v = (call.argument<Number>("size") ?: 200).toFloat()
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_CONFIG)
                        .putExtra(AiriOverlayService.EXTRA_SIZE, v)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "switchModel" -> {
                    val v = call.argument<String>("path") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_SWITCH_MODEL)
                        .putExtra(AiriOverlayService.EXTRA_MODEL_PATH, v)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "setDragEnabled" -> {
                    val v = call.argument<Boolean>("enabled") ?: false
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_DRAG_ENABLED)
                        .putExtra(AiriOverlayService.EXTRA_DRAG_ENABLED, v)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "musicOverlay" -> {
                    val v = call.argument<Boolean>("playing") ?: false
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_MUSIC)
                        .putExtra(AiriOverlayService.EXTRA_PLAYING, v)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "animOverlay" -> {
                    val v = call.argument<String>("anim") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_ANIM)
                        .putExtra(AiriOverlayService.EXTRA_ANIM, v)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "playSound" -> {
                    val v = call.argument<String>("path") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_PLAY_SOUND)
                        .putExtra(AiriOverlayService.EXTRA_SOUND_PATH, v)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "stopSound" -> {
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_STOP_SOUND)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "setMode" -> {
                    val v = call.argument<String>("mode") ?: ""
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_SET_MODE)
                        .putExtra(AiriOverlayService.EXTRA_MODE, v)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "setConfig" -> {
                    val size = (call.argument<Number>("size") ?: 200).toFloat()
                    val opacity = (call.argument<Number>("opacity") ?: 1.0).toFloat()
                    val intent = Intent(this, AiriOverlayService::class.java)
                        .setAction(AiriOverlayService.ACTION_CONFIG)
                        .putExtra(AiriOverlayService.EXTRA_SIZE, size)
                        .putExtra(AiriOverlayService.EXTRA_OPACITY, opacity)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "launchApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── App launcher channel ─────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchApp" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        Log.d("Airi", "launchApp: $pkg")
                        if (pkg.isEmpty()) { result.success(false); return@setMethodCallHandler }
                        
                        // ── Попытка 1: getLaunchIntentForPackage ──
                        try {
                            val intent = packageManager.getLaunchIntentForPackage(pkg)
                            if (intent != null) {
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                intent.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                                startActivity(intent)
                                Log.d("Airi", "launchApp SUCCESS (method 1): $pkg")
                                result.success(true)
                                return@setMethodCallHandler
                            } else {
                                Log.w("Airi", "launchApp: method 1 returned null for $pkg")
                            }
                        } catch (e: Exception) {
                            Log.w("Airi", "launchApp method 1 failed: ${e.message}")
                        }
                        
                        // ── Попытка 2: ACTION_MAIN + CATEGORY_LAUNCHER ──
                        try {
                            val launchIntent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                                setPackage(pkg)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(launchIntent)
                            Log.d("Airi", "launchApp SUCCESS (method 2): $pkg")
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            Log.w("Airi", "launchApp method 2 failed: ${e.message}")
                        }
                        
                        // ── Попытка 3: resolveActivity ──
                        try {
                            val resolveIntent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            val resolveInfoList = packageManager.queryIntentActivities(resolveIntent, 0)
                            for (info in resolveInfoList) {
                                if (info.activityInfo.packageName == pkg) {
                                    val launchIntent2 = Intent(Intent.ACTION_MAIN).apply {
                                        setClassName(info.activityInfo.packageName, info.activityInfo.name)
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(launchIntent2)
                                    Log.d("Airi", "launchApp SUCCESS (method 3): $pkg")
                                    result.success(true)
                                    return@setMethodCallHandler
                                }
                            }
                        } catch (e: Exception) {
                            Log.w("Airi", "launchApp method 3 failed: ${e.message}")
                        }
                        
                        // ── Попытка 4: проверяем установлен ли пакет ──
                        try {
                            val pkgInfo = packageManager.getPackageInfo(pkg, 0)
                            Log.w("Airi", "launchApp: package installed but no launcher activity: $pkg")
                            result.success(false)
                            return@setMethodCallHandler
                        } catch (_: Exception) {
                            Log.w("Airi", "launchApp: package not installed: $pkg")
                        }
                        
                        result.success(false)
                    }
                    "isInstalled" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        val installed = try {
                            packageManager.getApplicationInfo(pkg, 0)
                            true
                        } catch (_: Exception) { false }
                        result.success(installed)
                    }
                    "findAndLaunch" -> {
                        val name = (call.argument<String>("name") ?: "").lowercase()
                        if (name.isEmpty()) { result.success(false); return@setMethodCallHandler }
                        try {
                            val apps = packageManager.getInstalledApplications(0)
                            val match = apps.firstOrNull { app ->
                                val label = packageManager.getApplicationLabel(app).toString().lowercase()
                                label.contains(name) || app.packageName.contains(name)
                            }
                            if (match != null) {
                                val intent = packageManager.getLaunchIntentForPackage(match.packageName)
                                if (intent != null) {
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                    result.success(true)
                                } else { result.success(false) }
                            } else { result.success(false) }
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "getInstalledApps" -> {
                        try {
                            val apps = packageManager.getInstalledApplications(0)
                            val list = mutableListOf<Map<String, String>>()
                            for (app in apps) {
                                val label = try {
                                    packageManager.getApplicationLabel(app).toString()
                                } catch (_: Exception) { "" }
                                val pkg = app.packageName
                                val hasLauncher = try {
                                    packageManager.getLaunchIntentForPackage(pkg) != null
                                } catch (_: Exception) { false }
                                if (hasLauncher && label.isNotEmpty()) {
                                    list.add(mapOf(
                                        "label" to label,
                                        "package" to pkg
                                    ))
                                }
                            }
                            list.sortBy { it["label"]?.lowercase() ?: "" }
                            result.success(list)
                        } catch (e: Exception) {
                            Log.e("Airi", "getInstalledApps failed: ${e.message}")
                            result.success(emptyList<Map<String, String>>())
                        }
                    }
                    "launchUrl" -> {
                        val url = call.argument<String>("url") ?: ""
                        if (url.isEmpty()) { result.success(false); return@setMethodCallHandler }
                        try {
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                data = android.net.Uri.parse(url)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("Airi", "launchUrl failed: ${e.message}")
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
    
        // Accessibility control channel — full phone control from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airi.assistant/accessibility").setMethodCallHandler { call, result ->
            when (call.method) {
                "tapAt" -> {
                    val x = (call.argument<Number>("x") ?: 0f).toFloat()
                    val y = (call.argument<Number>("y") ?: 0f).toFloat()
                    result.success(AiriAccessibilityService.tapAt(x, y))
                }
                "clickByText" -> {
                    val text = call.argument<String>("text") ?: ""
                    result.success(AiriAccessibilityService.findAndClickByText(text))
                }
                "clickById" -> {
                    val id = call.argument<String>("id") ?: ""
                    result.success(AiriAccessibilityService.findAndClickById(id))
                }
                "typeText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val hint = call.argument<String>("hint")
                    result.success(AiriAccessibilityService.typeText(text, hint))
                }
                "scrollDown" -> result.success(AiriAccessibilityService.scrollDown())
                "scrollUp" -> result.success(AiriAccessibilityService.scrollUp())
                "swipe" -> {
                    val sx = (call.argument<Number>("startX") ?: 0f).toFloat()
                    val sy = (call.argument<Number>("startY") ?: 0f).toFloat()
                    val ex = (call.argument<Number>("endX") ?: 0f).toFloat()
                    val ey = (call.argument<Number>("endY") ?: 0f).toFloat()
                    result.success(AiriAccessibilityService.swipe(sx, sy, ex, ey))
                }
                "pressBack" -> result.success(AiriAccessibilityService.pressBack())
                "pressHome" -> result.success(AiriAccessibilityService.pressHome())
                "pressRecents" -> result.success(AiriAccessibilityService.pressRecents())
                "openNotifications" -> result.success(AiriAccessibilityService.openNotifications())
                "getScreenText" -> result.success(AiriAccessibilityService.getScreenText())
                "executeCommand" -> {
                    val cmd = call.argument<String>("command") ?: ""
                    result.success(AiriAccessibilityService.executeCommand(cmd))
                }
                else -> result.notImplemented()
            }
        }
        }
    }
}
