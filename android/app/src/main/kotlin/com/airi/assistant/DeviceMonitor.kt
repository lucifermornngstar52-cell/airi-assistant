package com.airi.assistant

import android.app.ActivityManager
import android.content.*
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.SystemClock
import java.io.BufferedReader
import java.io.File
import java.io.FileReader

/**
 * DeviceMonitorService — reads REAL device telemetry.
 * CPU temp, GPU temp, battery temp/level, RAM, CPU usage, storage, uptime.
 * Feeds data to the cyberpunk HUD.
 */
object DeviceMonitor {

    data class Telemetry(
        val cpuTemp: Float,       // °C
        val gpuTemp: Float,       // °C (best effort)
        val batteryTemp: Float,   // °C
        val batteryLevel: Int,    // %
        val isCharging: Boolean,
        val ramTotal: Long,       // MB
        val ramUsed: Float,      // 0..1
        val cpuUsage: Float,      // 0..1
        val storageUsed: Float,   // 0..1
        val uptimeHours: Float,
        val availableCores: Int,
    )

    @Volatile
    private var lastCpuJiffies: Long = 0
    @Volatile
    private var lastTotalJiffies: Long = 0
    @Volatile
    private var cachedCpuUsage: Float = 0f

    private fun readCpuTemp(): Float {
        // Try multiple thermal zones
        val zones = listOf(
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone1/temp",
            "/sys/class/hwmon/hwmon0/temp1_input",
            "/sys/class/hwmon/hwmon1/temp1_input",
        )
        for (path in zones) {
            try {
                val f = File(path)
                if (f.exists()) {
                    val raw = f.readText().trim().toInt()
                    // Some report in milli-degrees, some in degrees
                    return if (raw > 1000) raw / 1000f else raw.toFloat()
                }
            } catch (_: Exception) {}
        }
        // Fallback — try all thermal zones
        try {
            val thermalDir = File("/sys/class/thermal/")
            if (thermalDir.exists()) {
                for (f in thermalDir.listFiles() ?: emptyArray()) {
                    if (f.name.startsWith("thermal_zone")) {
                        val tempFile = File(f, "temp")
                        if (tempFile.exists()) {
                            val raw = tempFile.readText().trim().toInt()
                            return if (raw > 1000) raw / 1000f else raw.toFloat()
                        }
                    }
                }
            }
        } catch (_: Exception) {}
        return 0f
    }

    private fun readGpuTemp(): Float {
        // GPU temp is harder — try common paths
        val gpuPaths = listOf(
            "/sys/class/thermal/thermal_zone1/temp",
            "/sys/class/thermal/thermal_zone2/temp",
            "/sys/class/kgsl/kgsl-3d0/temperature",
            "/sys/class/hwmon/hwmon1/temp1_input",
            "/sys/class/hwmon/hwmon2/temp1_input",
        )
        for (path in gpuPaths) {
            try {
                val f = File(path)
                if (f.exists()) {
                    val raw = f.readText().trim().toInt()
                    val temp = if (raw > 1000) raw / 1000f else raw.toFloat()
                    // Filter to plausible GPU temp range
                    if (temp in 20f..120f) return temp
                }
            } catch (_: Exception) {}
        }
        return 0f
    }

    private fun readCpuUsage(): Float {
        try {
            val br = BufferedReader(FileReader("/proc/stat"))
            val line = br.readLine()
            br.close()
            if (line == null) return cachedCpuUsage

            val parts = line.split("\\s+".toRegex())
            if (parts.size < 5) return cachedCpuUsage

            // user, nice, system, idle, iowait, irq, softirq, steal
            var total = 0L
            var idle = 0L
            for (i in 1 until parts.size) {
                val v = parts[i].toLong()
                total += v
                if (i == 4 || i == 5) idle += v  // idle + iowait
            }

            val totalDiff = total - lastTotalJiffies
            val idleDiff = idle - lastCpuJiffies

            lastTotalJiffies = total
            lastCpuJiffies = idle

            if (totalDiff > 0) {
                cachedCpuUsage = (1f - idleDiff.toFloat() / totalDiff.toFloat()).coerceIn(0f, 1f)
            }
            return cachedCpuUsage
        } catch (_: Exception) {
            return cachedCpuUsage
        }
    }

    private fun getBatteryInfo(context: Context): Pair<Float, Pair<Int, Boolean>> {
        // Returns (tempC, (level%, isCharging))
        try {
            val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val battery = context.registerReceiver(null, filter)
            if (battery != null) {
                val level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                val pct = if (level >= 0 && scale > 0) (level * 100 / scale) else -1
                val temp = battery.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) / 10f
                val status = battery.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                               status == BatteryManager.BATTERY_STATUS_FULL
                return Pair(temp, Pair(pct, charging))
            }
        } catch (_: Exception) {}
        return Pair(0f, Pair(-1, false))
    }

    private fun getRamInfo(context: Context): Pair<Long, Float> {
        // Returns (totalMB, usedFraction)
        try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            val totalMB = mi.totalMem / (1024 * 1024)
            val usedFrac = 1f - (mi.availMem.toFloat() / mi.totalMem.toFloat())
            return Pair(totalMB, usedFrac)
        } catch (_: Exception) {}
        return Pair(0L, 0f)
    }

    private fun getStorageUsage(): Float {
        try {
            val stat = StatFs(Environment.getDataDirectory().path)
            val total = stat.totalBytes
            val avail = stat.availableBytes
            return 1f - (avail.toFloat() / total.toFloat())
        } catch (_: Exception) {}
        return 0f
    }

    fun getTelemetry(context: Context): Telemetry {
        val cpuTemp = readCpuTemp()
        val gpuTemp = readGpuTemp()
        val (battTemp, battInfo) = getBatteryInfo(context)
        val (ramTotal, ramUsed) = getRamInfo(context)
        val cpuUsage = readCpuUsage()
        val storageUsed = getStorageUsage()
        val uptimeMs = SystemClock.elapsedRealtime()
        val uptimeHours = uptimeMs / (1000f * 60 * 60)

        return Telemetry(
            cpuTemp = cpuTemp,
            gpuTemp = gpuTemp,
            batteryTemp = battTemp,
            batteryLevel = battInfo.first,
            isCharging = battInfo.second,
            ramTotal = ramTotal,
            ramUsed = ramUsed,
            cpuUsage = cpuUsage,
            storageUsed = storageUsed,
            uptimeHours = uptimeHours,
            availableCores = Runtime.getRuntime().availableProcessors(),
        )
    }
}
