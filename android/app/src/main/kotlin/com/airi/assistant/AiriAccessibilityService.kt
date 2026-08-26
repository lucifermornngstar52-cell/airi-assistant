package com.airi.assistant

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * AiriAccessibilityService — FULL PHONE CONTROL.
 * Can: tap, long-tap, scroll, type text, find elements, press back/home,
 * and execute multi-step voice commands within any app.
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

        // ── FULL CONTROL METHODS ──

        /** Find a clickable node by text and click it */
        fun findAndClickByText(text: String): Boolean {
            val svc = instance ?: return false
            val root = svc.rootInActiveWindow ?: return false
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                var clickTarget: AccessibilityNodeInfo? = node
                // Walk up to find a clickable parent
                while (clickTarget != null && !clickTarget.isClickable) {
                    clickTarget = clickTarget.parent
                }
                if (clickTarget != null) {
                    val bounds = Rect()
                    clickTarget.getBoundsInScreen(bounds)
                    JarvisHudService.showTarget(bounds.centerX().toFloat(), bounds.centerY().toFloat())
                    val result = clickTarget.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    Log.d(TAG, "Click '$text': $result")
                    return result
                }
            }
            return false
        }

        /** Find by resource ID (e.g. "com.whatsapp:id/send") */
        fun findAndClickById(id: String): Boolean {
            val svc = instance ?: return false
            val root = svc.rootInActiveWindow ?: return false
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            for (node in nodes) {
                if (node.isClickable) {
                    val bounds = Rect()
                    node.getBoundsInScreen(bounds)
                    JarvisHudService.showTarget(bounds.centerX().toFloat(), bounds.centerY().toFloat())
                    return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                }
            }
            return false
        }

        /** Type text into focused or found input field */
        fun typeText(text: String, fieldHint: String? = null): Boolean {
            val svc = instance ?: return false
            val root = svc.rootInActiveWindow ?: return false

            var target: AccessibilityNodeInfo? = null
            if (fieldHint != null) {
                val nodes = root.findAccessibilityNodeInfosByText(fieldHint)
                for (n in nodes) {
                    if (n.isEditable) { target = n; break }
                    var p = n.parent
                    while (p != null) {
                        if (p.isEditable) { target = p; break }
                        p = p.parent
                    }
                    if (target != null) break
                }
            }
            if (target == null) {
                target = findEditableNode(root)
            }
            if (target == null) return false

            val args = Bundle()
            args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        }

        /** Find first editable text field in the tree */
        private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            if (node.isEditable) return node
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                val result = findEditableNode(child)
                if (result != null) return result
            }
            return null
        }

        /** Scroll down/up */
        fun scrollDown(): Boolean {
            val svc = instance ?: return false
            val root = svc.rootInActiveWindow ?: return false
            return performScroll(root, true)
        }

        fun scrollUp(): Boolean {
            val svc = instance ?: return false
            val root = svc.rootInActiveWindow ?: return false
            return performScroll(root, false)
        }

        private fun performScroll(node: AccessibilityNodeInfo, down: Boolean): Boolean {
            val action = if (down) AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                         else AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            // Try scrollable containers first
            if (node.isScrollable) {
                return node.performAction(action)
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                if (performScroll(child, down)) return true
            }
            // Fallback: gesture-based swipe
            return false
        }

        /** Swipe gesture — for scrolling when node actions fail */
        fun swipe(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Long = 300L): Boolean {
            val svc = instance ?: return false
            val path = Path().apply { moveTo(startX, startY); lineTo(endX, endY) }
            val stroke = GestureDescription.StrokeDescription(path, 0L, durationMs)
            return svc.dispatchGesture(
                GestureDescription.Builder().addStroke(stroke).build(), null, null
            )
        }

        /** Press back button */
        fun pressBack(): Boolean {
            val svc = instance ?: return false
            return svc.performGlobalAction(GLOBAL_ACTION_BACK)
        }

        /** Press home button */
        fun pressHome(): Boolean {
            val svc = instance ?: return false
            return svc.performGlobalAction(GLOBAL_ACTION_HOME)
        }

        /** Open recents */
        fun pressRecents(): Boolean {
            val svc = instance ?: return false
            return svc.performGlobalAction(GLOBAL_ACTION_RECENTS)
        }

        /** Open notifications */
        fun openNotifications(): Boolean {
            val svc = instance ?: return false
            return svc.performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
        }

        /** Get all text on screen */
        fun getScreenText(): String {
            val svc = instance ?: return ""
            val root = svc.rootInActiveWindow ?: return ""
            val sb = StringBuilder()
            collectText(root, sb)
            return sb.toString()
        }

        private fun collectText(node: AccessibilityNodeInfo, sb: StringBuilder) {
            if (node.text != null) {
                sb.append(node.text).append("\n")
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                collectText(child, sb)
            }
        }

        /**
         * Execute a high-level voice command.
         * Supports: tap <text>, type <text>, scroll down/up, back, home,
         * click <text>, send <message> to <contact> (multi-step).
         */
        fun executeCommand(command: String): Boolean {
            val cmd = command.lowercase().trim()
            Log.d(TAG, "Execute: $cmd")

            return when {
                cmd.startsWith("нажми ") || cmd.startsWith("клик ") || cmd.startsWith("тап ") -> {
                    val target = command.substringAfter("нажми ").substringAfter("клик ").substringAfter("тап ").trim()
                    findAndClickByText(target)
                }
                cmd.startsWith("печата ") || cmd.startsWith("введи ") || cmd.startsWith("напиши ") -> {
                    val text = command.substringAfter("печата ").substringAfter("введи ").substringAfter("напиши ").trim()
                    typeText(text)
                }
                cmd == "листай вниз" || cmd == "скролл вниз" || cmd == "прокрути вниз" -> {
                    scrollDown()
                }
                cmd == "листай вверх" || cmd == "скролл вверх" || cmd == "прокрути вверх" -> {
                    scrollUp()
                }
                cmd == "назад" -> pressBack()
                cmd == "домой" || cmd == "на главный" -> pressHome()
                cmd == "недавние" || cmd == "недавние приложения" -> pressRecents()
                cmd == "уведомления" -> openNotifications()
                else -> false
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility service connected — FULL CONTROL")
        // HUD is shown on demand from Flutter, not auto-started
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
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
