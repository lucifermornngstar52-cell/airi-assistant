package com.airi.assistant

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.app.NotificationCompat
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * AiriOverlayService — Live2D overlay через нативный Android WebView.
 * Окно ровно по размеру модели, прозрачный фон, перетаскивание.
 * Тот же подход что на aika-assistant.
 */
class AiriOverlayService : Service() {

    companion object {
        const val ACTION_SHOW  = "com.airi.SHOW"
        const val ACTION_HIDE   = "com.airi.HIDE"
        const val ACTION_UPDATE = "com.airi.UPDATE"
        const val ACTION_CONFIG = "com.airi.CONFIG"
        const val ACTION_SWITCH_MODEL = "com.airi.SWITCH_MODEL"
        const val ACTION_DRAG   = "com.airi.DRAG"

        const val EXTRA_STATE  = "state"
        const val EXTRA_SIZE    = "size"
        const val EXTRA_MODEL  = "model_url"
        const val EXTRA_DRAG   = "drag_enabled"

        private const val CHANNEL_ID = "airi_overlay_channel"
        private const val NOTIF_ID   = 1337
        private const val TAG        = "AiriOverlay"
        private const val BASE_URL   = "file:///android_asset/flutter_assets/assets/"

        var isRunning = false
    }

    private val handler = Handler(Looper.getMainLooper())
    private var wm: WindowManager? = null
    private var webView: WebView? = null
    private var params: WindowManager.LayoutParams? = null

    private var dragEnabled  = true
    private var currentState = "idle"
    private var sizeDp       = 200f
    private var modelUrl     = ""

    // Drag
    private var dragStartX  = 0
    private var dragStartY  = 0
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var isDragging  = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        // Загружаем настройки
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        sizeDp = prefs.getFloat("flutter.live2d_model_size", 200f)
        modelUrl = prefs.getString("flutter.live2d_model_url", "") ?: ""
        handler.post { setupWindow() }
    }

    override fun onDestroy() {
        isRunning = false
        handler.post {
            try { webView?.let { wm?.removeView(it) } } catch (_: Exception) {}
            webView?.destroy()
            webView = null
        }
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(CHANNEL_ID, "AIRI Overlay", NotificationManager.IMPORTANCE_LOW)
            chan.description = "Live2D overlay"
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(chan)
        }
    }

    private fun buildNotification(): android.app.Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AIRI")
            .setContentText("Оверлей активен")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    @SuppressLint("SetJavaScriptEnabled", "ClickableViewAccessibility")
    private fun setupWindow() {
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = resources.displayMetrics.density

        val wPx = (sizeDp * density).roundToInt()
        val hPx = (sizeDp * 1.6f * density).roundToInt()

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

        params = WindowManager.LayoutParams(
            wPx, hPx,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSPARENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (16 * density).roundToInt()
            y = (120 * density).roundToInt()
        }

        val wv = WebView(applicationContext)
        webView = wv
        wv.setBackgroundColor(Color.TRANSPARENT)
        wv.background?.alpha = 0

        wv.settings.apply {
            javaScriptEnabled = true
            allowFileAccess = true
            allowContentAccess = true
            @Suppress("DEPRECATION") allowFileAccessFromFileURLs = true
            @Suppress("DEPRECATION") allowUniversalAccessFromFileURLs = true
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            mediaPlaybackRequiresUserGesture = false
            domStorageEnabled = true
            cacheMode = WebSettings.LOAD_DEFAULT
            setSupportZoom(false)
            builtInZoomControls = false
            displayZoomControls = false
        }

        wv.webChromeClient = WebChromeClient()
        wv.webViewClient = object : WebViewClient() {
            override fun onPageFinished(v: WebView?, url: String?) {
                // Ждём 1200мс для PIXI.js инициализации (как на aika)
                handler.postDelayed({
                    v?.evaluateJavascript("window.setAikaState('$currentState')", null)
                    // Загружаем модель если есть URL
                    if (modelUrl.isNotEmpty()) {
                        v?.evaluateJavascript("window.loadCustomModel('$modelUrl')", null)
                    }
                }, 1200)
            }
        }

        wv.addJavascriptInterface(object {
            @JavascriptInterface
            fun onModelLoaded() {
                handler.post {
                    webView?.evaluateJavascript("window.setAikaState('$currentState')", null)
                }
            }
            @JavascriptInterface
            fun onTap() { Log.d(TAG, "tap") }
        }, "AndroidBridge")

        // Drag
        wv.setOnTouchListener { _, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging   = false
                    dragStartX   = params!!.x
                    dragStartY   = params!!.y
                    touchStartX  = ev.rawX
                    touchStartY  = ev.rawY
                    val relY = ev.y / wv.height.toFloat()
                    if (relY < 0.18f) return@setOnTouchListener false
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = ev.rawX - touchStartX
                    val dy = ev.rawY - touchStartY
                    if (!isDragging && (abs(dx) > 8 || abs(dy) > 8)) {
                        isDragging = true
                    }
                    if (isDragging && dragEnabled) {
                        params!!.x = (dragStartX + dx).roundToInt()
                        params!!.y = (dragStartY + dy).roundToInt()
                        try { wm?.updateViewLayout(wv, params) } catch (_: Exception) {}
                        return@setOnTouchListener true
                    }
                    false
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        wv.evaluateJavascript("window.setAikaState('greeting')", null)
                        handler.postDelayed({
                            webView?.evaluateJavascript("window.setAikaState('idle')", null)
                        }, 2500)
                    }
                    isDragging = false
                    false
                }
                else -> false
            }
        }

        wv.loadUrl(BASE_URL + "live2d_viewer.html")

        try {
            wm?.addView(wv, params)
        } catch (e: Exception) {
            Log.e(TAG, "addView failed: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val density = resources.displayMetrics.density

        when (intent?.action) {
            ACTION_SHOW -> {
                val st = intent.getStringExtra(EXTRA_STATE) ?: "idle"
                currentState = st
                handler.post {
                    if (webView == null) setupWindow()
                    else webView?.evaluateJavascript("window.setAikaState('$st')", null)
                }
            }
            ACTION_UPDATE -> {
                val st = intent.getStringExtra(EXTRA_STATE) ?: "idle"
                currentState = st
                handler.post {
                    webView?.evaluateJavascript("window.setAikaState('$st')", null)
                }
            }
            ACTION_HIDE -> {
                handler.post {
                    try { webView?.let { wm?.removeView(it) } } catch (_: Exception) {}
                    webView?.destroy()
                    webView = null
                }
                stopSelf()
            }
            ACTION_CONFIG -> {
                val sz = intent.getFloatExtra(EXTRA_SIZE, sizeDp)
                sizeDp = sz
                handler.post {
                    if (webView != null && params != null) {
                        val wPx = (sizeDp * density).roundToInt()
                        val hPx = (sizeDp * 1.6f * density).roundToInt()
                        params!!.width = wPx
                        params!!.height = hPx
                        try { wm?.updateViewLayout(webView, params) } catch (_: Exception) {}
                        webView?.evaluateJavascript("handleResize()", null)
                    }
                }
            }
            ACTION_SWITCH_MODEL -> {
                val url = intent.getStringExtra(EXTRA_MODEL) ?: ""
                if (url.isNotEmpty()) {
                    modelUrl = url
                    handler.post {
                        webView?.evaluateJavascript("window.loadCustomModel('$url')", null)
                    }
                }
            }
            ACTION_DRAG -> {
                dragEnabled = intent.getBooleanExtra(EXTRA_DRAG, true)
            }
        }

        return START_NOT_STICKY
    }
}
