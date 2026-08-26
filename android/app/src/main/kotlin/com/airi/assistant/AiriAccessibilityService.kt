package com.airi.assistant

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * AiriAccessibilityService — управление тапами и интеграция с JARVIS HUD.
 * Ловит физические тапы пользователя через accessibility events
 * и показывает прицел HUD в точке касания.
 */
class AiriAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile private var instance: AiriAccessibilityService? = null
        private const val TAG = "AiriA11y"

        fun tapAt(x: Float, y: Float): Boolean {
            val svc = instance ?: return false
            try { JarvisHudService.showTarget(x, y) } catch (_: Throwable) {}
            val path = Path().apply { moveTo(x, y); lineTo(x + 1f, y + 1f) }
            val stroke = GestureDescription.StrokeDescription(path, 0L, 50L)
            return svc.dispatchGesture(
                GestureDescription.Builder().addStroke(stroke).build(), null, null
            )
        }

        fun longTapAt(x: Float, y: Float, durationMs: Long = 800L): Boolean {
            val svc = instance ?: return false
            try { JarvisHudService.showTarget(x, y) } catch (_: Throwable) {}
            val path = Path().apply { moveTo(x, y); lineTo(x + 1f, y + 1f) }
            val stroke = GestureDescription.StrokeDescription(path, 0L, durationMs.coerceAtLeast(350L))
            return svc.dispatchGesture(
                GestureDescription.Builder().addStroke(stroke).build(), null, null
            )
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility service connected")
        try {
            val i = Intent(this, JarvisHudService::class.java)
                .setAction(JarvisHudService.ACTION_SHOW)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(i)
            } else {
                startService(i)
            }
        } catch (_: Throwable) {}
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        // Ловим клики пользователя — показываем прицел HUD
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED,
            AccessibilityEvent.TYPE_VIEW_LONG_CLICKED -> {
                try {
                    val source = event.source
                    if (source != null) {
                        val bounds = Rect()
                        source.getBoundsInScreen(bounds)
                        val cx = bounds.centerX().toFloat()
                        val cy = bounds.centerY().toFloat()
                        Log.d(TAG, "Tap at ($cx, $cy)")
                        JarvisHudService.showTarget(cx, cy)
                        source.recycle()
                    }
                } catch (_: Throwable) {}
            }
        }
    }

    override fun onInterrupt() { /* no-op */ }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
