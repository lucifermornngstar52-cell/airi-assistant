package com.airi.assistant

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import androidx.core.app.NotificationCompat
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * JarvisHudService — ULTRA CYBERPUNK HUD.
 * Neon circuits, digital rain, glitch effects, spectrum analyzer,
 * binary streams, rotating data rings — pure cyberpunk aesthetic.
 */
class JarvisHudService : Service() {

    companion object {
        const val ACTION_SHOW        = "com.aika.HUD_SHOW"
        const val ACTION_HIDE         = "com.aika.HUD_HIDE"
        const val ACTION_SHOW_TARGET  = "com.aika.HUD_TARGET"
        const val ACTION_STATUS       = "com.aika.HUD_STATUS"
        const val ACTION_PULSE        = "com.aika.HUD_PULSE"

        const val EXTRA_X = "x"
        const val EXTRA_Y = "y"
        const val EXTRA_TEXT = "text"

        const val CHANNEL_ID = "jarvis_hud"
        const val NOTIF_ID = 7771

        // ── CYBERPUNK NEON PALETTE ──
        const val COL_CYAN      = 0xFF00FFF0.toInt()   // electric cyan
        const val COL_CYAN_BR   = 0xFF00FFAA.toInt()   // bright neon green-cyan
        const val COL_MAGENTA   = 0xFFFF00FF.toInt()   // neon magenta
        const val COL_PINK      = 0xFFFF0088.toInt()   // hot pink
        const val COL_PURPLE    = 0xFFAA00FF.toInt()   // electric purple
        const val COL_YELLOW    = 0xFFFFFF00.toInt()   // neon yellow
        const val COL_RED       = 0xFFFF0044.toInt()   // neon red
        const val COL_WHITE     = 0xFFE0FFFF.toInt()   // icy white
        const val COL_DIM_CYAN  = 0x3300FFF0.toInt()   // dim cyan
        const val COL_DIM_MAG   = 0x33FF00FF.toInt()   // dim magenta
        const val COL_GRID      = 0x1A00FFF0.toInt()   // very dim grid

        @Volatile private var instance: JarvisHudService? = null
        fun showTarget(x: Float, y: Float) {
            instance?.let {
                val i = Intent(it, JarvisHudService::class.java)
                    .setAction(ACTION_SHOW_TARGET)
                    .putExtra(EXTRA_X, x)
                    .putExtra(EXTRA_Y, y)
                it.startService(i)
            }
        }
        fun showStatus(text: String) {
            instance?.let {
                val i = Intent(it, JarvisHudService::class.java)
                    .setAction(ACTION_STATUS)
                    .putExtra(EXTRA_TEXT, text)
                it.startService(i)
            }
        }
        fun showBackground() {
            instance?.let {
                val i = Intent(it, JarvisHudService::class.java).setAction(ACTION_SHOW)
                it.startService(i)
            }
        }
        fun hide() {
            instance?.let {
                val i = Intent(it, JarvisHudService::class.java).setAction(ACTION_HIDE)
                it.startService(i)
            }
        }
    }

    private var wm: WindowManager? = null
    private var hudView: HudView? = null
    private var statusText: String = "J.A.R.V.I.S. ONLINE"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannel()
        startForeground(NOTIF_ID, buildNotification("J.A.R.V.I.S. HUD active"))
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW        -> showHud()
            ACTION_HIDE        -> hideHud()
            ACTION_SHOW_TARGET -> {
                val x = intent.getFloatExtra(EXTRA_X, -1f)
                val y = intent.getFloatExtra(EXTRA_Y, -1f)
                if (x >= 0 && y >= 0) triggerTarget(x, y)
            }
            ACTION_STATUS      -> {
                statusText = intent.getStringExtra(EXTRA_TEXT) ?: statusText
                hudView?.setStatusText(statusText)
            }
            ACTION_PULSE       -> hudView?.pulse()
            null               -> showHud()
        }
        return START_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "JARVIS HUD", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Cyberpunk HUD overlay"
                setShowBadge(false)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("J.A.R.V.I.S.")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showHud() {
        if (hudView != null) return
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT

        val p = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0; y = 0
        }
        val v = HudView(this)
        hudView = v
        v.setStatusText(statusText)
        try { wm?.addView(v, p) } catch (e: Exception) { Log.e("JarvisHUD", "addView: ${e.message}") }
    }

    private fun hideHud() {
        hudView?.let { try { wm?.removeView(it) } catch (_: Exception) {} }
        hudView = null
    }

    private fun triggerTarget(x: Float, y: Float) {
        if (hudView == null) showHud()
        hudView?.triggerTarget(x, y)
    }

    override fun onDestroy() {
        hideHud()
        instance = null
        super.onDestroy()
    }

    // ════════════════════════════════════════════════════════════════
    //  HudView — ULTRA CYBERPUNK HUD
    // ════════════════════════════════════════════════════════════════
    private class HudView(ctx: Context) : View(ctx) {
        private val d = ctx.resources.displayMetrics.density
        private val W get() = width.toFloat()
        private val H get() = height.toFloat()

        private var statusText: String = "J.A.R.V.I.S. ONLINE"
        private var targetX: Float = -1f
        private var targetY: Float = -1f
        private var targetAlpha: Float = 0f
        private var targetRadius: Float = 0f
        private var targetLockProgress: Float = 0f
        private var sweepAngle: Float = 0f
        private var ringRotation: Float = 0f
        private var ringRotation2: Float = 0f
        private var pulseAlpha: Float = 0f
        private var bgAlpha: Float = 0.9f
        private var glitchOffset: Float = 0f
        private var glitchTimer: Int = 0
        private var telemetry: DeviceMonitor.Telemetry? = null
        private var telemetryTick: Int = 0

        private val rnd = Random(System.currentTimeMillis())
        private var dataTick: Int = 0

        // Digital rain columns
        private val rainCols = IntArray(60) { rnd.nextInt(20) }
        private val rainSpeed = FloatArray(60) { 2f + rnd.nextFloat() * 6f }
        private val rainY = FloatArray(60) { rnd.nextFloat() * 800f }

        // Spectrum bars
        private val spectrum = FloatArray(32) { 0.1f }

        // Binary stream
        private val binChars = arrayOf("0", "1", "0", "1", "0", "1", "0", "1", "0", "1", "0", "1")
        private val binStream = StringBuilder()

        // ── CYBERPUNK NEON PAINTS ──
        private val pCyan = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_CYAN; style = Paint.Style.STROKE; strokeWidth = 2f * d
        }
        private val pCyanBr = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_CYAN_BR; style = Paint.Style.STROKE; strokeWidth = 3f * d
        }
        private val pCyanThin = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_CYAN; style = Paint.Style.STROKE; strokeWidth = 1f * d
        }
        private val pMagenta = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_MAGENTA; style = Paint.Style.STROKE; strokeWidth = 2.5f * d
        }
        private val pPink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_PINK; style = Paint.Style.STROKE; strokeWidth = 2f * d
        }
        private val pPurple = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_PURPLE; style = Paint.Style.STROKE; strokeWidth = 2f * d
        }
        private val pRed = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_RED; style = Paint.Style.STROKE; strokeWidth = 2.5f * d
        }
        private val pRedBr = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_RED; style = Paint.Style.STROKE; strokeWidth = 3.5f * d
        }
        private val pDim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_DIM_CYAN; style = Paint.Style.STROKE; strokeWidth = 1f * d
        }
        private val pGrid = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GRID; style = Paint.Style.STROKE; strokeWidth = 0.5f * d
        }
        private val pFill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        private val pText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_WHITE; textSize = 8f * d; isFakeBoldText = true; letterSpacing = 0.15f
        }
        private val pTextCyan = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_CYAN_BR; textSize = 6.5f * d; letterSpacing = 0.1f
        }
        private val pTextMagenta = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_MAGENTA; textSize = 6f * d; letterSpacing = 0.08f
        }
        private val pTextRed = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_RED; textSize = 7f * d; isFakeBoldText = true; letterSpacing = 0.1f
        }
        private val pTextDim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_DIM_CYAN; textSize = 5.5f * d; letterSpacing = 0.05f
        }
        private val pTextGlitch = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_MAGENTA; textSize = 8f * d; isFakeBoldText = true; letterSpacing = 0.15f
        }

        private val dashFine = DashPathEffect(floatArrayOf(2f, 4f), 0f)
        private val dashMed = DashPathEffect(floatArrayOf(6f, 4f), 0f)

        init { setLayerType(LAYER_TYPE_HARDWARE, null) }

        fun setStatusText(t: String) { statusText = t; invalidate() }
        fun pulse() { pulseAlpha = 1f }

        fun triggerTarget(x: Float, y: Float) {
            targetX = x; targetY = y
            targetAlpha = 1f
            targetRadius = 180f * d
            targetLockProgress = 0f
            val anim = ValueAnimator.ofFloat(0f, 1f)
            anim.duration = 600
            anim.interpolator = LinearInterpolator()
            anim.addUpdateListener {
                targetLockProgress = it.animatedValue as Float
                targetRadius = (180f * d) * (1f - targetLockProgress * 0.72f)
                invalidate()
            }
            anim.start()
            object : android.os.CountDownTimer(2000, 30) {
                override fun onTick(m: Long) {
                    if (m < 900) targetAlpha = (m / 900f)
                    invalidate()
                }
                override fun onFinish() { targetAlpha = 0f; invalidate() }
            }.start()
        }

        private val frameHandler = Handler(Looper.getMainLooper())
        private var lastMs: Long = 0L
        private val tick = object : Runnable {
            override fun run() {
                val now = System.currentTimeMillis()
                val dt = if (lastMs > 0) (now - lastMs) / 1000f else 0.016f
                lastMs = now
                sweepAngle = (sweepAngle + 180f * dt) % 360f
                ringRotation = (ringRotation + 45f * dt) % 360f
                ringRotation2 = (ringRotation2 - 30f * dt) % 360f
                if (pulseAlpha > 0f) pulseAlpha = (pulseAlpha - dt * 2.5f).coerceAtLeast(0f)

                // Glitch effect
                glitchTimer++
                if (glitchTimer > 60 + rnd.nextInt(120)) {
                    glitchOffset = (rnd.nextFloat() - 0.5f) * 8f * d
                    glitchTimer = 0
                } else {
                    glitchOffset *= 0.8f
                }

                // Digital rain
                for (i in rainCols.indices) {
                    rainY[i] += rainSpeed[i] * d * dt * 30
                    if (rainY[i] > H + 50) {
                        rainY[i] = -rnd.nextFloat() * 200f
                        rainSpeed[i] = 2f + rnd.nextFloat() * 6f
                    }
                }

                // Spectrum animation
                for (i in spectrum.indices) {
                    spectrum[i] += (rnd.nextFloat() * 0.3f - 0.15f)
                    spectrum[i] = spectrum[i].coerceIn(0.05f, 1f)
                }

                dataTick++
                // Update device telemetry every ~2 seconds
                telemetryTick++
                if (telemetryTick >= 120) {
                    telemetryTick = 0
                    try { telemetry = DeviceMonitor.getTelemetry(context) } catch (_: Exception) {}
                }
                invalidate()
                frameHandler.postDelayed(this, 16)
            }
        }

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            lastMs = 0L
            frameHandler.post(tick)
        }

        override fun onDetachedFromWindow() {
            frameHandler.removeCallbacks(tick)
            super.onDetachedFromWindow()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            val w = W; val h = H
            if (w < 1 || h < 1) return

            // ── 1. Circuit grid background ──
            drawCircuitGrid(canvas, w, h)

            // ── 2. Digital rain ──
            drawDigitalRain(canvas, w, h)

            // ── 3. Corner brackets (neon) ──
            drawCornerBrackets(canvas, w, h)

            // ── 4. TOP-LEFT: system data + spectrum ──
            drawTopLeftData(canvas, w, h)

            // ── 5. TOP-RIGHT: rotating rings + diagnostics ──
            drawTopRightData(canvas, w, h)

            // ── 6. Center title (with glitch) ──
            drawCenterTitle(canvas, w, h)

            // ── 7. Center rotating rings ──
            drawCenterRings(canvas, w, h)

            // ── 8. Bottom-left: binary stream + coords ──
            drawBottomLeftData(canvas, w, h)

            // ── 9. Bottom-right: waveform + threat ──
            drawBottomRightData(canvas, w, h)

            // ── 10. Target reticle ──
            if (targetAlpha > 0 && targetX > 0 && targetY > 0) {
                drawTargetReticle(canvas, targetX, targetY, targetAlpha, targetRadius, targetLockProgress)
            }

            // ── 11. Pulse flash ──
            if (pulseAlpha > 0) {
                pFill.color = COL_CYAN_BR
                pFill.alpha = (30 * pulseAlpha).toInt()
                canvas.drawRect(0f, 0f, w, h, pFill)
            }

            // ── 12. Sweep scanline (radar) ──
            drawSweepLine(canvas, w, h)

            // ── 13. Scanline overlay ──
            drawScanlines(canvas, w, h)

            // ── 14. Glitch bars ──
            drawGlitchBars(canvas, w, h)
        }

        // ══════════════════════════════════════════════════════════
        //  CYBERPUNK DRAWING METHODS
        // ══════════════════════════════════════════════════════════

        private fun drawCircuitGrid(c: Canvas, w: Float, h: Float) {
            val step = 40f * d
            pGrid.alpha = 40
            // Vertical lines
            var x = 0f
            while (x < w) {
                c.drawLine(x, 0f, x, h, pGrid)
                x += step
            }
            // Horizontal lines
            var y = 0f
            while (y < h) {
                c.drawLine(0f, y, w, y, pGrid)
                y += step
            }
            // Circuit nodes at intersections
            pFill.color = COL_CYAN
            pFill.alpha = 30
            x = 0f
            while (x < w) {
                y = 0f
                while (y < h) {
                    if (rnd.nextFloat() < 0.15f) {
                        c.drawCircle(x, y, 1.5f * d, pFill)
                    }
                    y += step
                }
                x += step
            }
            // Circuit traces (random glowing lines)
            pCyanThin.alpha = 50
            pCyanThin.pathEffect = dashFine
            for (i in 0..8) {
                val sx = rnd.nextFloat() * w
                val sy = rnd.nextFloat() * h
                val len = (30 + rnd.nextInt(80)) * d
                val horizontal = rnd.nextBoolean()
                if (horizontal) {
                    c.drawLine(sx, sy, sx + len, sy, pCyanThin)
                    val bend = (rnd.nextInt(-40, 40)) * d
                    c.drawLine(sx + len, sy, sx + len, sy + bend, pCyanThin)
                } else {
                    c.drawLine(sx, sy, sx, sy + len, pCyanThin)
                    val bend = (rnd.nextInt(-40, 40)) * d
                    c.drawLine(sx, sy + len, sx + bend, sy + len, pCyanThin)
                }
            }
            pCyanThin.pathEffect = null
        }

        private fun drawDigitalRain(c: Canvas, w: Float, h: Float) {
            val colW = w / rainCols.size
            pTextCyan.textSize = 7f * d
            for (i in rainCols.indices) {
                val x = i * colW + colW / 2
                val y = rainY[i]
                // Draw a few characters in each column
                for (j in 0..8) {
                    val charY = y - j * 12 * d
                    if (charY < 0 || charY > h) continue
                    val alpha = if (j == 0) 200 else (200 - j * 25).coerceAtLeast(0)
                    if (j == 0) {
                        pTextCyan.color = COL_WHITE
                    } else {
                        pTextCyan.color = COL_CYAN_BR
                    }
                    pTextCyan.alpha = alpha
                    val ch = if (rnd.nextFloat() < 0.5f) "0" else "1"
                    c.drawText(ch, x, charY, pTextCyan)
                }
            }
            pTextCyan.color = COL_CYAN_BR
        }

        private fun drawCornerBrackets(c: Canvas, w: Float, h: Float) {
            val m = 14 * d
            val len = 50 * d
            val tip = 14 * d

            // Cyan brackets
            pCyanBr.alpha = (255 * bgAlpha).toInt()
            // TL
            c.drawLine(m, m, m + len, m, pCyanBr)
            c.drawLine(m, m, m, m + len, pCyanBr)
            // TR
            c.drawLine(w - m, m, w - m - len, m, pCyanBr)
            c.drawLine(w - m, m, w - m, m + len, pCyanBr)
            // BL
            c.drawLine(m, h - m, m + len, h - m, pCyanBr)
            c.drawLine(m, h - m, m, h - m - len, pCyanBr)
            // BR
            c.drawLine(w - m, h - m, w - m - len, h - m, pCyanBr)
            c.drawLine(w - m, h - m, w - m, h - m - len, pCyanBr)

            // Magenta accent tips
            pMagenta.alpha = (200 * bgAlpha).toInt()
            pMagenta.strokeWidth = 3f * d
            c.drawLine(m, m, m + tip, m, pMagenta)
            c.drawLine(m, m, m, m + tip, pMagenta)
            c.drawLine(w - m, m, w - m - tip, m, pMagenta)
            c.drawLine(w - m, m, w - m, m + tip, pMagenta)
            c.drawLine(m, h - m, m + tip, h - m, pMagenta)
            c.drawLine(m, h - m, m, h - m - tip, pMagenta)
            c.drawLine(w - m, h - m, w - m - tip, h - m, pMagenta)
            c.drawLine(w - m, h - m, w - m, h - m - tip, pMagenta)

            // Small data tags near corners
            pTextMagenta.textSize = 5f * d
            pTextMagenta.alpha = (150 * bgAlpha).toInt()
            c.drawText("[0x4F]", m + len + 4 * d, m + 8 * d, pTextMagenta)
            c.drawText("[0xA2]", w - m - len - 30 * d, m + 8 * d, pTextMagenta)
            c.drawText("[0x7B]", m + len + 4 * d, h - m - 4 * d, pTextMagenta)
            c.drawText("[0xE1]", w - m - len - 30 * d, h - m - 4 * d, pTextMagenta)
        }

        private fun drawTopLeftData(c: Canvas, w: Float, h: Float) {
            val x = 24 * d
            val y0 = 40 * d
            val lineH = 13 * d

            // Label
            pText.textSize = 7f * d
            pText.alpha = (220 * bgAlpha).toInt()
            c.drawText("SYS//NEURAL-LINK", x, y0, pText)

            // Spectrum bars
            val barW = 3f * d
            val barH = 40 * d
            val startX = x
            val specY = y0 + 8 * d
            for (i in spectrum.indices) {
                val bx = startX + i * (barW + 1.5f * d)
                val bh = barH * spectrum[i]
                // Background bar
                pFill.color = COL_DIM_CYAN
                pFill.alpha = 40
                c.drawRect(bx, specY, bx + barW, specY + barH, pFill)
                // Filled bar — gradient color
                val color = if (spectrum[i] > 0.7f) COL_MAGENTA else COL_CYAN_BR
                pFill.color = color
                pFill.alpha = (200 * bgAlpha).toInt()
                c.drawRect(bx, specY + barH - bh, bx + barW, specY + barH, pFill)
            }

            // Status bars
            val t = telemetry
            val labels = arrayOf("PWR", "CPU", "MEM", "NET", "GPU", "BIO")
            val values = if (t != null) arrayOf(
                t.batteryLevel / 100f,
                t.cpuUsage,
                t.ramUsed,
                0.91f + 0.05f * sin(dataTick * 0.03f),
                (t.gpuTemp / 100f).coerceIn(0f, 1f),
                0.98f
            ) else arrayOf(0.87f, 0.42f + 0.15f * sin(dataTick * 0.05f), 0.63f, 0.91f + 0.05f * sin(dataTick * 0.03f), 0.55f + 0.1f * sin(dataTick * 0.07f), 0.98f)
            val barW2 = 70 * d
            val barH2 = 3 * d
            for (i in labels.indices) {
                val y = y0 + 55 * d + i * lineH
                pTextCyan.textSize = 5.5f * d
                pTextCyan.alpha = (180 * bgAlpha).toInt()
                c.drawText(labels[i], x, y, pTextCyan)

                pFill.color = COL_DIM_CYAN
                pFill.alpha = 60
                c.drawRoundRect(RectF(x + 28 * d, y - 5 * d, x + 28 * d + barW2, y - 5 * d + barH2), 1.5f * d, 1.5f * d, pFill)

                val fillColor = if (values[i] > 0.85f) COL_MAGENTA else COL_CYAN_BR
                pFill.color = fillColor
                pFill.alpha = (220 * bgAlpha).toInt()
                val fillW = barW2 * values[i]
                c.drawRoundRect(RectF(x + 28 * d, y - 5 * d, x + 28 * d + fillW, y - 5 * d + barH2), 1.5f * d, 1.5f * d, pFill)

                pTextCyan.alpha = (150 * bgAlpha).toInt()
                val pct = "${(values[i] * 100).toInt()}%"
                c.drawText(pct, x + 28 * d + barW2 + 3 * d, y, pTextCyan)
            }

            // Real temperature readouts
            if (t != null) {
                pTextMagenta.textSize = 5.5f * d
                pTextMagenta.alpha = (180 * bgAlpha).toInt()
                val tempY = y0 + 55 * d + labels.size * lineH + 4 * d
                c.drawText("CPU ${t.cpuTemp.toInt()}C", x, tempY, pTextMagenta)
                c.drawText("GPU ${t.gpuTemp.toInt()}C", x + 50 * d, tempY, pTextMagenta)
                c.drawText("BAT ${t.batteryTemp.toInt()}C", x + 100 * d, tempY, pTextMagenta)
                
                pTextCyan.textSize = 5f * d
                pTextCyan.alpha = (150 * bgAlpha).toInt()
                c.drawText("RAM ${t.ramTotal}MB", x, tempY + 10 * d, pTextCyan)
                c.drawText("CORES ${t.availableCores}", x + 60 * d, tempY + 10 * d, pTextCyan)
                c.drawText("UP ${"%.1f".format(t.uptimeHours)}h", x + 110 * d, tempY + 10 * d, pTextCyan)
                
                if (t.isCharging) {
                    pTextMagenta.alpha = (200 * bgAlpha).toInt()
                    c.drawText("[CHG]", x + 160 * d, tempY + 10 * d, pTextMagenta)
                }
            }
        }

        private fun drawTopRightData(c: Canvas, w: Float, h: Float) {
            val x = w - 24 * d
            val y0 = 40 * d

            pText.textSize = 7f * d
            pText.alpha = (220 * bgAlpha).toInt()
            val label = "DIAG//SCAN-7X"
            val lw = pText.measureText(label)
            c.drawText(label, x - lw, y0, pText)

            // Double rotating rings (cyan + magenta)
            val cx = x - 32 * d
            val cy = y0 + 38 * d
            val r1 = 26 * d
            val r2 = 18 * d

            // Outer ring — cyan, rotating
            pCyanThin.alpha = (180 * bgAlpha).toInt()
            pCyanThin.strokeWidth = 1.5f * d
            c.drawCircle(cx, cy, r1, pCyanThin)
            // Arc segments on outer ring
            pCyanBr.alpha = (200 * bgAlpha).toInt()
            pCyanBr.strokeWidth = 2.5f * d
            for (i in 0..3) {
                val baseAngle = ringRotation + i * 90f
                val arcRect = RectF(cx - r1, cy - r1, cx + r1, cy + r1)
                c.drawArc(arcRect, baseAngle, 40f, false, pCyanBr)
            }

            // Inner ring — magenta, counter-rotating
            pMagenta.alpha = (180 * bgAlpha).toInt()
            pMagenta.strokeWidth = 1.5f * d
            c.drawCircle(cx, cy, r2, pMagenta)
            for (i in 0..2) {
                val baseAngle = ringRotation2 + i * 120f
                val arcRect = RectF(cx - r2, cy - r2, cx + r2, cy + r2)
                c.drawArc(arcRect, baseAngle, 50f, false, pMagenta)
            }

            // Center dot
            pFill.color = COL_MAGENTA
            pFill.alpha = (200 * bgAlpha).toInt()
            c.drawCircle(cx, cy, 2f * d, pFill)

            // Data lines
            val lineH = 12 * d
            val t = telemetry
            val data = if (t != null) arrayOf(
                "CPU ${t.cpuTemp.toInt()}C",
                "GPU ${t.gpuTemp.toInt()}C",
                "BAT ${t.batteryTemp.toInt()}C",
                "BAT ${t.batteryLevel}%",
                "RAM ${(t.ramUsed * 100).toInt()}%",
                "CPU ${(t.cpuUsage * 100).toInt()}%"
            ) else arrayOf("ALT 412M", "SPD 0.3K", "TMP 36.6C", "SIG 98%", "ENC AES-256", "VPN ACTIVE")
            for (i in data.indices) {
                val y = cy + r1 + 10 * d + i * lineH
                pTextCyan.textSize = 5.5f * d
                pTextCyan.alpha = (160 * bgAlpha).toInt()
                val tw = pTextCyan.measureText(data[i])
                c.drawText(data[i], x - tw, y, pTextCyan)
            }
        }

        private fun drawCenterTitle(c: Canvas, w: Float, h: Float) {
            val cx = w / 2
            val ty = 32 * d

            // Glitch shadow (magenta offset)
            pTextGlitch.textSize = 9f * d
            pTextGlitch.alpha = (100 * bgAlpha).toInt()
            val title = "J.A.R.V.I.S."
            val tw = pTextGlitch.measureText(title)
            c.drawText(title, cx - tw / 2 + glitchOffset, ty, pTextGlitch)

            // Main title (cyan)
            pText.textSize = 9f * d
            pText.alpha = (255 * bgAlpha).toInt()
            c.drawText(title, cx - tw / 2, ty, pText)

            // Subtitle
            pTextCyan.textSize = 5.5f * d
            pTextCyan.alpha = (180 * bgAlpha).toInt()
            val sub = "NEURAL//NET v7.2 // CYBER"
            val sw = pTextCyan.measureText(sub)
            c.drawText(sub, cx - sw / 2, ty + 10 * d, pTextCyan)

            // Neon line under title
            pCyanThin.alpha = (180 * bgAlpha).toInt()
            pCyanThin.strokeWidth = 1.5f * d
            c.drawLine(cx - 80 * d, ty + 16 * d, cx + 80 * d, ty + 16 * d, pCyanThin)
            // Magenta segments
            pMagenta.alpha = (150 * bgAlpha).toInt()
            pMagenta.strokeWidth = 2f * d
            c.drawLine(cx - 120 * d, ty + 16 * d, cx - 82 * d, ty + 16 * d, pMagenta)
            c.drawLine(cx + 82 * d, ty + 16 * d, cx + 120 * d, ty + 16 * d, pMagenta)

            // Status text
            pTextCyan.textSize = 6.5f * d
            pTextCyan.alpha = (200 * bgAlpha).toInt()
            val st = statusText
            val stw = pTextCyan.measureText(st)
            c.drawText(st, cx - stw / 2, ty + 28 * d, pTextCyan)

            // Hex code under status
            pTextDim.textSize = 5f * d
            pTextDim.alpha = (120 * bgAlpha).toInt()
            val hex = "0x" + Integer.toHexString(dataTick * 17 and 0xFFFF).uppercase().padStart(4, '0')
            val hw = pTextDim.measureText(hex)
            c.drawText(hex, cx - hw / 2, ty + 38 * d, pTextDim)
        }

        private fun drawCenterRings(c: Canvas, w: Float, h: Float) {
            val cx = w / 2
            val cy = h / 2
            val baseR = 80 * d

            // Outermost ring — very dim, dashed
            pDim.alpha = 60
            pDim.pathEffect = dashFine
            pDim.strokeWidth = 1f * d
            c.drawCircle(cx, cy, baseR * 1.8f, pDim)
            pDim.pathEffect = null

            // Ring 1 — cyan, rotating with arc segments
            pCyanThin.alpha = (100 * bgAlpha).toInt()
            pCyanThin.strokeWidth = 1.5f * d
            c.drawCircle(cx, cy, baseR * 1.5f, pCyanThin)
            pCyanBr.alpha = (150 * bgAlpha).toInt()
            pCyanBr.strokeWidth = 2.5f * d
            for (i in 0..5) {
                val a = ringRotation + i * 60f
                val rect = RectF(cx - baseR * 1.5f, cy - baseR * 1.5f, cx + baseR * 1.5f, cy + baseR * 1.5f)
                c.drawArc(rect, a, 25f, false, pCyanBr)
            }

            // Ring 2 — magenta, counter-rotating
            pMagenta.alpha = (100 * bgAlpha).toInt()
            pMagenta.strokeWidth = 1.5f * d
            c.drawCircle(cx, cy, baseR * 1.2f, pMagenta)
            pPink.alpha = (150 * bgAlpha).toInt()
            pPink.strokeWidth = 2.5f * d
            for (i in 0..3) {
                val a = ringRotation2 + i * 90f
                val rect = RectF(cx - baseR * 1.2f, cy - baseR * 1.2f, cx + baseR * 1.2f, cy + baseR * 1.2f)
                c.drawArc(rect, a, 40f, false, pPink)
            }

            // Ring 3 — cyan, fast rotation
            pCyanThin.alpha = (80 * bgAlpha).toInt()
            pCyanThin.strokeWidth = 1f * d
            c.drawCircle(cx, cy, baseR, pCyanThin)
            // Tick marks
            pCyanThin.alpha = (120 * bgAlpha).toInt()
            for (i in 0..23) {
                val a = Math.PI * 2 / 24 * i + ringRotation * Math.PI / 180
                val x1 = cx + baseR * cos(a).toFloat()
                val y1 = cy + baseR * sin(a).toFloat()
                val x2 = cx + (baseR - 5 * d) * cos(a).toFloat()
                val y2 = cy + (baseR - 5 * d) * sin(a).toFloat()
                c.drawLine(x1, y1, x2, y2, pCyanThin)
            }

            // Crosshair at center
            pCyanBr.alpha = (120 * bgAlpha).toInt()
            pCyanBr.strokeWidth = 1.5f * d
            val cl = 20 * d
            val gap = 6 * d
            c.drawLine(cx - cl, cy, cx - gap, cy, pCyanBr)
            c.drawLine(cx + gap, cy, cx + cl, cy, pCyanBr)
            c.drawLine(cx, cy - cl, cx, cy - gap, pCyanBr)
            c.drawLine(cx, cy + gap, cx, cy + cl, pCyanBr)

            // Center dot
            pFill.color = COL_MAGENTA
            pFill.alpha = (200 * bgAlpha).toInt()
            c.drawCircle(cx, cy, 2f * d, pFill)
        }

        private fun drawBottomLeftData(c: Canvas, w: Float, h: Float) {
            val x = 24 * d
            val y0 = h - 70 * d

            // Label
            pTextCyan.textSize = 5.5f * d
            pTextCyan.alpha = (160 * bgAlpha).toInt()
            c.drawText("GEO//TRACE", x, y0, pTextCyan)

            // Coordinates
            pTextDim.textSize = 5.5f * d
            pTextDim.alpha = (140 * bgAlpha).toInt()
            val lat = "LAT: 43.2" + (rnd.nextInt(100, 999) / 1000.0)
            val lon = "LON: 76.8" + (rnd.nextInt(100, 999) / 1000.0)
            c.drawText(lat, x, y0 + 10 * d, pTextDim)
            c.drawText(lon, x, y0 + 20 * d, pTextDim)

            // Binary stream
            pTextCyan.textSize = 5f * d
            pTextCyan.alpha = (120 * bgAlpha).toInt()
            val sb = StringBuilder()
            for (i in 0..15) {
                sb.append(if (rnd.nextFloat() < 0.5f) "0" else "1")
            }
            c.drawText("BIN: $sb", x, y0 + 32 * d, pTextCyan)

            // Another line
            val sb2 = StringBuilder()
            for (i in 0..15) {
                sb2.append(if (rnd.nextFloat() < 0.5f) "0" else "1")
            }
            c.drawText("BIN: $sb2", x, y0 + 42 * d, pTextCyan)

            // Mini bar chart
            pCyanThin.alpha = (120 * bgAlpha).toInt()
            pCyanThin.strokeWidth = 1.5f * d
            for (i in 0..9) {
                val bh = (8 + rnd.nextInt(25)) * d
                c.drawLine(x + i * 7 * d, y0 + 60 * d, x + i * 7 * d, y0 + 60 * d - bh, pCyanThin)
            }
        }

        private fun drawBottomRightData(c: Canvas, w: Float, h: Float) {
            val x = w - 24 * d
            val y0 = h - 70 * d

            // Label
            pTextCyan.textSize = 5.5f * d
            pTextCyan.alpha = (160 * bgAlpha).toInt()
            val lbl = "THREAT//LVL"
            val lw = pTextCyan.measureText(lbl)
            c.drawText(lbl, x - lw, y0, pTextCyan)

            // Threat level
            pTextRed.textSize = 8f * d
            pTextRed.alpha = (200 * bgAlpha).toInt()
            val tl = "MINIMAL"
            val tlw = pTextRed.measureText(tl)
            c.drawText(tl, x - tlw, y0 + 14 * d, pTextRed)

            // Waveform
            pCyanThin.alpha = (140 * bgAlpha).toInt()
            pCyanThin.pathEffect = dashFine
            pCyanThin.strokeWidth = 1.5f * d
            for (i in 0..35) {
                val wx = x - 130 * d + i * 3.5f * d
                val wy = y0 + 30 * d + sin(i * 0.4f + dataTick * 0.15f) * 10 * d
                if (i > 0) {
                    val pwx = x - 130 * d + (i - 1) * 3.5f * d
                    val pwy = y0 + 30 * d + sin((i - 1) * 0.4f + dataTick * 0.15f) * 10 * d
                    c.drawLine(pwx, pwy, wx, wy, pCyanThin)
                }
            }
            pCyanThin.pathEffect = null

            // Data readout
            pTextMagenta.textSize = 5f * d
            pTextMagenta.alpha = (140 * bgAlpha).toInt()
            val freq = "FREQ: ${(440 + rnd.nextInt(60)).toFloat() / 10f}GHz"
            val fw = pTextMagenta.measureText(freq)
            c.drawText(freq, x - fw, y0 + 50 * d, pTextMagenta)

            // Uplink status
            val up = "UPLINK: STABLE"
            val uw = pTextCyan.measureText(up)
            pTextCyan.textSize = 5f * d
            pTextCyan.alpha = (140 * bgAlpha).toInt()
            c.drawText(up, x - uw, y0 + 60 * d, pTextCyan)
        }

        private fun drawTargetReticle(c: Canvas, x: Float, y: Float, a: Float, r: Float, lock: Float) {
            val alpha = (255 * a).toInt()

            // Expanding outer ring (magenta, fades)
            pMagenta.alpha = (alpha * 0.4f).toInt()
            pMagenta.strokeWidth = 2f * d
            c.drawCircle(x, y, 180f * d * (1f - lock * 0.3f), pMagenta)

            // Main shrinking ring — cyan
            pCyanBr.alpha = alpha
            pCyanBr.strokeWidth = 3f * d
            c.drawCircle(x, y, r, pCyanBr)

            // Inner ring — magenta
            pMagenta.alpha = (alpha * 0.6f).toInt()
            pMagenta.strokeWidth = 1.5f * d
            c.drawCircle(x, y, r * 0.5f, pMagenta)

            // Crosshair lines (cyan)
            pCyanBr.alpha = alpha
            pCyanBr.strokeWidth = 2.5f * d
            val cl = r + 20 * d
            val gap = r * 0.4f
            c.drawLine(x - cl, y, x - gap, y, pCyanBr)
            c.drawLine(x + gap, y, x + cl, y, pCyanBr)
            c.drawLine(x, y - cl, x, y - gap, pCyanBr)
            c.drawLine(x, y + gap, x, y + cl, pCyanBr)

            // Corner brackets around target (magenta)
            val bl = r * 0.7f
            pMagenta.alpha = alpha
            pMagenta.strokeWidth = 3f * d
            val tip = 12 * d
            c.drawLine(x - bl, y - bl, x - bl + tip, y - bl, pMagenta)
            c.drawLine(x - bl, y - bl, x - bl, y - bl + tip, pMagenta)
            c.drawLine(x + bl, y - bl, x + bl - tip, y - bl, pMagenta)
            c.drawLine(x + bl, y - bl, x + bl, y - bl + tip, pMagenta)
            c.drawLine(x - bl, y + bl, x - bl + tip, y + bl, pMagenta)
            c.drawLine(x - bl, y + bl, x - bl, y + bl - tip, pMagenta)
            c.drawLine(x + bl, y + bl, x + bl - tip, y + bl, pMagenta)
            c.drawLine(x + bl, y + bl, x + bl, y + bl - tip, pMagenta)

            // Lock text (magenta)
            if (lock > 0.5f) {
                pTextRed.textSize = 7f * d
                pTextRed.alpha = alpha
                pTextRed.color = COL_MAGENTA
                val txt = if (lock > 0.8f) "TARGET LOCKED" else "LOCKING..."
                val tw = pTextRed.measureText(txt)
                c.drawText(txt, x - tw / 2, y + r + 22 * d, pTextRed)
                pTextRed.color = COL_RED
            }

            // Center dot (magenta)
            pFill.color = COL_MAGENTA
            pFill.alpha = alpha
            c.drawCircle(x, y, 3f * d, pFill)

            // Rotating arc segments (cyan + magenta)
            pCyanThin.alpha = (alpha * 0.6f).toInt()
            pCyanThin.strokeWidth = 2f * d
            for (i in 0..3) {
                val baseAngle = ringRotation + i * 90f
                val arcRect = RectF(x - r * 1.3f, y - r * 1.3f, x + r * 1.3f, y + r * 1.3f)
                c.drawArc(arcRect, baseAngle, 30f, false, pCyanThin)
            }
            pMagenta.alpha = (alpha * 0.5f).toInt()
            pMagenta.strokeWidth = 1.5f * d
            for (i in 0..2) {
                val baseAngle = ringRotation2 + i * 120f
                val arcRect = RectF(x - r * 1.5f, y - r * 1.5f, x + r * 1.5f, y + r * 1.5f)
                c.drawArc(arcRect, baseAngle, 20f, false, pMagenta)
            }
        }

        private fun drawSweepLine(c: Canvas, w: Float, h: Float) {
            val cx = w / 2
            val cy = h / 2
            val maxR = sqrt(w * w + h * h) / 2

            val angle = sweepAngle * Math.PI / 180
            val ex = cx + maxR * cos(angle).toFloat()
            val ey = cy + maxR * sin(angle).toFloat()

            pCyanThin.alpha = (40 * bgAlpha).toInt()
            pCyanThin.strokeWidth = 1.5f * d
            c.drawLine(cx, cy, ex, ey, pCyanThin)

            // Trailing arc with gradient
            for (i in 1..15) {
                val trailAngle = (sweepAngle - i * 6f) * Math.PI / 180
                val tex = cx + maxR * cos(trailAngle).toFloat()
                val tey = cy + maxR * sin(trailAngle).toFloat()
                pCyanThin.alpha = ((40 - i * 3) * bgAlpha).toInt().coerceAtLeast(0)
                c.drawLine(cx, cy, tex, tey, pCyanThin)
            }
        }

        private fun drawScanlines(c: Canvas, w: Float, h: Float) {
            pFill.color = COL_CYAN
            pFill.alpha = 8
            val step = 4 * d
            var y = 0f
            while (y < h) {
                c.drawRect(0f, y, w, y + 1f * d, pFill)
                y += step
            }
        }

        private fun drawGlitchBars(c: Canvas, w: Float, h: Float) {
            // Random glitch bars
            if (glitchOffset.abs() > 1f * d) {
                pFill.color = COL_MAGENTA
                pFill.alpha = (40 * (glitchOffset.abs() / (8f * d))).toInt()
                val gy = rnd.nextFloat() * h
                val gh = (5 + rnd.nextInt(15)) * d
                c.drawRect(0f, gy, w, gy + gh, pFill)

                pFill.color = COL_CYAN
                pFill.alpha = 30
                val gy2 = rnd.nextFloat() * h
                val gh2 = (3 + rnd.nextInt(10)) * d
                c.drawRect(glitchOffset, gy2, w + glitchOffset, gy2 + gh2, pFill)
            }
        }

        private fun Float.abs(): Float = if (this < 0) -this else this
    }
}
