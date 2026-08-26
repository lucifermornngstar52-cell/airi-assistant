package com.airi.assistant

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.RectF
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
 * JarvisHudService — Iron Man HUD overlay (GREEN EDITION).
 * Canvas-based rendering via SYSTEM_ALERT_WINDOW.
 * Pass-through (FLAG_NOT_TOUCHABLE) — taps detected via AccessibilityService.
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

        // ── GREEN PALETTE ──
        const val COL_GREEN      = 0xFF00FF66.toInt()   // bright green
        const val COL_GREEN_BRIGHT= 0xFF39FF14.toInt()   // neon green
        const val COL_GREEN_DIM  = 0x6600CC44.toInt()   // dim green
        const val COL_GREEN_DARK = 0x33008822.toInt()   // very dim
        const val COL_WHITE      = 0xFFE0FFE0.toInt()   // green-tinted white

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
                description = "Iron Man HUD overlay"
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
    //  HudView — GREEN Iron Man HUD
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
        private var pulseAlpha: Float = 0f
        private var bgAlpha: Float = 0.9f

        // Random data for corner readouts
        private val rnd = Random(System.currentTimeMillis())
        private var dataTick: Int = 0

        // ── GREEN PAINTS ──
        private val pGreen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GREEN; style = Paint.Style.STROKE; strokeWidth = 2f * d
        }
        private val pGreenBold = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GREEN_BRIGHT; style = Paint.Style.STROKE; strokeWidth = 3f * d
        }
        private val pGreenThin = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GREEN; style = Paint.Style.STROKE; strokeWidth = 1f * d
        }
        private val pDim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GREEN_DIM; style = Paint.Style.STROKE; strokeWidth = 1f * d
        }
        private val pDark = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GREEN_DARK; style = Paint.Style.STROKE; strokeWidth = 1f * d
        }
        private val pFill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        private val pText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GREEN_BRIGHT; textSize = 8f * d; isFakeBoldText = true; letterSpacing = 0.12f
        }
        private val pTextSm = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GREEN; textSize = 6.5f * d; letterSpacing = 0.08f
        }
        private val pTextDim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COL_GREEN_DIM; textSize = 6f * d; letterSpacing = 0.05f
        }

        private val dashFine = DashPathEffect(floatArrayOf(3f, 6f), 0f)
        private val dashMed = DashPathEffect(floatArrayOf(6f, 6f), 0f)

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
                sweepAngle = (sweepAngle + 120f * dt) % 360f
                ringRotation = (ringRotation + 30f * dt) % 360f
                if (pulseAlpha > 0f) pulseAlpha = (pulseAlpha - dt * 2.5f).coerceAtLeast(0f)
                dataTick++
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

            // ── 1. Hex grid background (very dim) ──
            drawHexGrid(canvas, w, h)

            // ── 2. Corner brackets ──
            drawCornerBrackets(canvas, w, h)

            // ── 3. TOP-LEFT data cluster ──
            drawTopLeftData(canvas, w, h)

            // ── 4. TOP-RIGHT data cluster ──
            drawTopRightData(canvas, w, h)

            // ── 5. Center title ──
            drawCenterTitle(canvas, w, h)

            // ── 6. Bottom-left data ──
            drawBottomLeftData(canvas, w, h)

            // ── 7. Bottom-right data ──
            drawBottomRightData(canvas, w, h)

            // ── 8. Target reticle (on tap) ──
            if (targetAlpha > 0 && targetX > 0 && targetY > 0) {
                drawTargetReticle(canvas, targetX, targetY, targetAlpha, targetRadius, targetLockProgress)
            }

            // ── 9. Pulse flash ──
            if (pulseAlpha > 0) {
                pFill.color = COL_GREEN_BRIGHT
                pFill.alpha = (30 * pulseAlpha).toInt()
                canvas.drawRect(0f, 0f, w, h, pFill)
            }

            // ── 10. Sweep scanline ──
            drawSweepLine(canvas, w, h)
        }

        // ══════════════════════════════════════════════════════════
        //  DRAWING METHODS
        // ══════════════════════════════════════════════════════════

        private fun drawHexGrid(c: Canvas, w: Float, h: Float) {
            val r = 26f * d
            val dx = r * 1.5f
            val dy = r * sqrt(3f)
            pDark.pathEffect = dashFine
            pDark.alpha = 30
            var row = 0
            var y = -dy
            while (y < h + dy) {
                val xOff = if (row % 2 == 0) 0f else dx / 2
                var x = -dx + xOff
                while (x < w + dx) {
                    drawHex(c, x, y, r, pDark)
                    x += dx
                }
                y += dy / 2; row++
            }
            pDark.pathEffect = null
        }

        private fun drawHex(c: Canvas, cx: Float, cy: Float, r: Float, p: Paint) {
            val path = Path()
            for (i in 0..5) {
                val a = Math.PI / 3 * i
                val x = cx + r * cos(a).toFloat()
                val y = cy + r * sin(a).toFloat()
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            path.close()
            c.drawPath(path, p)
        }

        private fun drawCornerBrackets(c: Canvas, w: Float, h: Float) {
            val m = 16 * d
            val len = 60 * d
            pGreenBold.alpha = (255 * bgAlpha).toInt()

            // TL
            c.drawLine(m, m, m + len, m, pGreenBold)
            c.drawLine(m, m, m, m + len, pGreenBold)
            // TR
            c.drawLine(w - m, m, w - m - len, m, pGreenBold)
            c.drawLine(w - m, m, w - m, m + len, pGreenBold)
            // BL
            c.drawLine(m, h - m, m + len, h - m, pGreenBold)
            c.drawLine(m, h - m, m, h - m - len, pGreenBold)
            // BR
            c.drawLine(w - m, h - m, w - m - len, h - m, pGreenBold)
            c.drawLine(w - m, h - m, w - m, h - m - len, pGreenBold)
        }

        private fun drawTopLeftData(c: Canvas, w: Float, h: Float) {
            val x = 28 * d
            val y0 = 40 * d
            val lineH = 14 * d

            // Label
            pText.textSize = 7.5f * d
            pText.alpha = (220 * bgAlpha).toInt()
            c.drawText("SYS // STARK-VII", x, y0, pText)

            // Status bars
            val labels = arrayOf("PWR", "CPU", "MEM", "NET")
            val values = arrayOf(0.87f, 0.42f + 0.15f * sin(dataTick * 0.05f), 0.63f, 0.91f + 0.05f * sin(dataTick * 0.03f))
            val barW = 80 * d
            val barH = 4 * d
            for (i in labels.indices) {
                val y = y0 + (i + 1) * lineH
                pTextSm.textSize = 6f * d
                pTextSm.alpha = (180 * bgAlpha).toInt()
                c.drawText(labels[i], x, y, pTextSm)

                // bar background
                pDark.alpha = 80
                c.drawRoundRect(RectF(x + 30 * d, y - 6 * d, x + 30 * d + barW, y - 6 * d + barH), 2f * d, 2f * d, pDark)

                // bar fill
                pFill.color = COL_GREEN_BRIGHT
                pFill.alpha = (200 * bgAlpha).toInt()
                val fillW = barW * values[i]
                c.drawRoundRect(RectF(x + 30 * d, y - 6 * d, x + 30 * d + fillW, y - 6 * d + barH), 2f * d, 2f * d, pFill)

                // percentage
                pTextSm.alpha = (150 * bgAlpha).toInt()
                val pct = "${(values[i] * 100).toInt()}%"
                c.drawText(pct, x + 30 * d + barW + 4 * d, y, pTextSm)
            }
        }

        private fun drawTopRightData(c: Canvas, w: Float, h: Float) {
            val x = w - 28 * d
            val y0 = 40 * d
            val lineH = 14 * d

            // Right-aligned label
            pText.textSize = 7.5f * d
            pText.alpha = (220 * bgAlpha).toInt()
            val label = "DIAGNOSTICS"
            val lw = pText.measureText(label)
            c.drawText(label, x - lw, y0, pText)

            // Compass / mini-circle
            val cx = x - 35 * d
            val cy = y0 + 45 * d
            val r = 28 * d
            pGreenThin.alpha = (180 * bgAlpha).toInt()
            c.drawCircle(cx, cy, r, pGreenThin)
            c.drawCircle(cx, cy, r * 0.65f, pDim)

            // Compass marks
            for (i in 0..11) {
                val a = Math.PI * 2 / 12 * i + ringRotation * Math.PI / 180
                val x1 = cx + r * cos(a).toFloat()
                val y1 = cy + r * sin(a).toFloat()
                val x2 = cx + (r - 6 * d) * cos(a).toFloat()
                val y2 = cy + (r - 6 * d) * sin(a).toFloat()
                c.drawLine(x1, y1, x2, y2, pGreenThin)
            }
            // N marker
            pFill.color = COL_GREEN_BRIGHT
            pFill.alpha = (220 * bgAlpha).toInt()
            c.drawCircle(cx, cy - r, 3f * d, pFill)

            // Data lines
            val data = arrayOf("ALT 412M", "SPD 0.3K", "TEMP 36.6", "SIG 98%")
            for (i in data.indices) {
                val y = cy + r + 14 * d + i * lineH
                pTextSm.textSize = 6f * d
                pTextSm.alpha = (160 * bgAlpha).toInt()
                val tw = pTextSm.measureText(data[i])
                c.drawText(data[i], x - tw, y, pTextSm)
            }
        }

        private fun drawCenterTitle(c: Canvas, w: Float, h: Float) {
            val cx = w / 2
            val ty = 32 * d

            pText.textSize = 9f * d
            pText.alpha = (255 * bgAlpha).toInt()
            val title = "J . A . R . V . I . S ."
            val tw = pText.measureText(title)
            c.drawText(title, cx - tw / 2, ty, pText)

            pTextSm.textSize = 6f * d
            pTextSm.alpha = (180 * bgAlpha).toInt()
            val sub = "STARK INDUSTRIES // MK-VII"
            val sw = pTextSm.measureText(sub)
            c.drawText(sub, cx - sw / 2, ty + 11 * d, pTextSm)

            // Line under title
            pGreenThin.alpha = (160 * bgAlpha).toInt()
            c.drawLine(cx - 70 * d, ty + 18 * d, cx + 70 * d, ty + 18 * d, pGreenThin)
            c.drawLine(cx - 120 * d, ty + 18 * d, cx - 75 * d, ty + 18 * d, pDim)
            c.drawLine(cx + 75 * d, ty + 18 * d, cx + 120 * d, ty + 18 * d, pDim)

            // Status text below
            pTextSm.textSize = 6.5f * d
            pTextSm.alpha = (200 * bgAlpha).toInt()
            val st = statusText
            val stw = pTextSm.measureText(st)
            c.drawText(st, cx - stw / 2, ty + 30 * d, pTextSm)
        }

        private fun drawBottomLeftData(c: Canvas, w: Float, h: Float) {
            val x = 28 * d
            val y0 = h - 60 * d

            pTextSm.textSize = 6f * d
            pTextSm.alpha = (160 * bgAlpha).toInt()
            c.drawText("COORDS", x, y0, pTextSm)

            val lat = "LAT: 43.2" + (rnd.nextInt(100, 999) / 1000.0)
            val lon = "LON: 76.8" + (rnd.nextInt(100, 999) / 1000.0)
            c.drawText(lat, x, y0 + 12 * d, pTextDim)
            c.drawText(lon, x, y0 + 22 * d, pTextDim)

            // Small bar chart
            pGreenThin.alpha = (120 * bgAlpha).toInt()
            for (i in 0..7) {
                val bh = (10 + rnd.nextInt(30)) * d
                c.drawLine(x + i * 8 * d, y0 + 40 * d, x + i * 8 * d, y0 + 40 * d - bh, pGreenThin)
            }
        }

        private fun drawBottomRightData(c: Canvas, w: Float, h: Float) {
            val x = w - 28 * d
            val y0 = h - 60 * d

            pTextSm.textSize = 6f * d
            pTextSm.alpha = (160 * bgAlpha).toInt()
            val lbl = "THREAT LEVEL"
            val lw = pTextSm.measureText(lbl)
            c.drawText(lbl, x - lw, y0, pTextSm)

            pTextDim.textSize = 8f * d
            pTextDim.alpha = (200 * bgAlpha).toInt()
            val tl = "MINIMAL"
            val tlw = pTextDim.measureText(tl)
            c.drawText(tl, x - tlw, y0 + 16 * d, pTextDim)

            // Mini waveform
            pGreenThin.alpha = (140 * bgAlpha).toInt()
            pGreenThin.pathEffect = dashFine
            for (i in 0..30) {
                val wx = x - 120 * d + i * 4 * d
                val wy = y0 + 35 * d + sin(i * 0.5f + dataTick * 0.1f) * 8 * d
                if (i > 0) {
                    val pwx = x - 120 * d + (i - 1) * 4 * d
                    val pwy = y0 + 35 * d + sin((i - 1) * 0.5f + dataTick * 0.1f) * 8 * d
                    c.drawLine(pwx, pwy, wx, wy, pGreenThin)
                }
            }
            pGreenThin.pathEffect = null
        }

        private fun drawTargetReticle(c: Canvas, x: Float, y: Float, a: Float, r: Float, lock: Float) {
            val alpha = (255 * a).toInt()

            // Expanding outer ring (fades)
            pGreenThin.alpha = (alpha * 0.4f).toInt()
            pGreenThin.strokeWidth = 2f * d
            c.drawCircle(x, y, 180f * d * (1f - lock * 0.3f), pGreenThin)

            // Main shrinking ring
            pGreenBold.alpha = alpha
            pGreenBold.strokeWidth = 3f * d
            c.drawCircle(x, y, r, pGreenBold)

            // Inner ring
            pGreen.alpha = (alpha * 0.7f).toInt()
            pGreen.strokeWidth = 1.5f * d
            c.drawCircle(x, y, r * 0.5f, pGreen)

            // Crosshair lines
            pGreenBold.alpha = alpha
            val cl = r + 20 * d
            val gap = r * 0.4f
            c.drawLine(x - cl, y, x - gap, y, pGreenBold)
            c.drawLine(x + gap, y, x + cl, y, pGreenBold)
            c.drawLine(x, y - cl, x, y - gap, pGreenBold)
            c.drawLine(x, y + gap, x, y + cl, pGreenBold)

            // Corner brackets around target
            val bl = r * 0.7f
            pGreenBold.alpha = alpha
            // TL
            c.drawLine(x - bl, y - bl, x - bl + 12 * d, y - bl, pGreenBold)
            c.drawLine(x - bl, y - bl, x - bl, y - bl + 12 * d, pGreenBold)
            // TR
            c.drawLine(x + bl, y - bl, x + bl - 12 * d, y - bl, pGreenBold)
            c.drawLine(x + bl, y - bl, x + bl, y - bl + 12 * d, pGreenBold)
            // BL
            c.drawLine(x - bl, y + bl, x - bl + 12 * d, y + bl, pGreenBold)
            c.drawLine(x - bl, y + bl, x - bl, y + bl - 12 * d, pGreenBold)
            // BR
            c.drawLine(x + bl, y + bl, x + bl - 12 * d, y + bl, pGreenBold)
            c.drawLine(x + bl, y + bl, x + bl, y + bl - 12 * d, pGreenBold)

            // Lock text
            if (lock > 0.5f) {
                pText.textSize = 7f * d
                pText.alpha = alpha
                val txt = if (lock > 0.8f) "TARGET LOCKED" else "LOCKING..."
                val tw = pText.measureText(txt)
                c.drawText(txt, x - tw / 2, y + r + 22 * d, pText)
            }

            // Center dot
            pFill.color = COL_GREEN_BRIGHT
            pFill.alpha = alpha
            c.drawCircle(x, y, 3f * d, pFill)

            // Rotating arc segments
            pGreenThin.alpha = (alpha * 0.6f).toInt()
            pGreenThin.strokeWidth = 2f * d
            for (i in 0..3) {
                val baseAngle = ringRotation + i * 90f
                val arcRect = RectF(x - r * 1.3f, y - r * 1.3f, x + r * 1.3f, y + r * 1.3f)
                c.drawArc(arcRect, baseAngle, 30f, false, pGreenThin)
            }
        }

        private fun drawSweepLine(c: Canvas, w: Float, h: Float) {
            val cx = w / 2
            val cy = h / 2
            val maxR = sqrt(w * w + h * h) / 2

            // Radar sweep — rotating line
            val angle = sweepAngle * Math.PI / 180
            val ex = cx + maxR * cos(angle).toFloat()
            val ey = cy + maxR * sin(angle).toFloat()

            pGreenThin.alpha = (40 * bgAlpha).toInt()
            pGreenThin.strokeWidth = 1.5f * d
            c.drawLine(cx, cy, ex, ey, pGreenThin)

            // Trailing arc
            for (i in 1..20) {
                val trailAngle = (sweepAngle - i * 4f) * Math.PI / 180
                val tex = cx + maxR * cos(trailAngle).toFloat()
                val tey = cy + maxR * sin(trailAngle).toFloat()
                pGreenThin.alpha = ((40 - i * 2) * bgAlpha).toInt().coerceAtLeast(0)
                c.drawLine(cx, cy, tex, tey, pGreenThin)
            }
        }
    }
}
