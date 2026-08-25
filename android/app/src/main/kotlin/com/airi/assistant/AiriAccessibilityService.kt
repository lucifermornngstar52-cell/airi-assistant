package com.airi.assistant

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.os.Build
import android.view.accessibility.AccessibilityEvent

/**
 * AiriAccessibilityService — управление тапами и интеграция с JARVIS HUD.
 * Минимальная версия: тапы по координатам + триггер HUD-прицела.
 */
class AiriAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile private var instance: AiriAccessibilityService? = null

        /** Программный тап по координатам. Вызывается из Flutter через MethodChannel. */
        fun tapAt(x: Float, y: Float): Boolean {
            val svc = instance ?: return false
            // ── JARVIS HUD targeting animation ──
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
        // ── Запускаем JARVIS HUD оверлей при активации accessibility ──
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

    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* no-op */ }
    override fun onInterrupt() { /* no-op */ }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
