package com.example.agrisense

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class AgriSenseApplication : Application() {
    private var sharedEngine: FlutterEngine? = null
    var activity: MainActivity? = null
    var alertsChannel: MethodChannel? = null
        private set
    var serviceChannel: MethodChannel? = null
        private set
    private var pendingStart: MethodChannel.Result? = null

    @Synchronized
    fun engine(): FlutterEngine {
        sharedEngine?.let { return it }
        val engine = FlutterEngine(this)
        sharedEngine = engine
        val alerts = AppAlerts(this)
        alertsChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "agrisense/app_alerts").apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "snapshot" -> result.success(alerts.snapshot())
                        "configure" -> result.success(alerts.configure(call.argument<Int>("minute"), call.argument<Boolean>("enabled") == true))
                        "precise" -> { alerts.requestPrecise(); result.success(null) }
                        "restore" -> { alerts.reschedule(); result.success(null) }
                        "acknowledge" -> { alerts.acknowledge(call.argument<String>("token") ?: ""); result.success(null) }
                        "post" -> result.success(alerts.post(call.arguments as Map<String, Any?>))
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) { result.error("alerts_unavailable", "Could not update reminders or alerts. Please retry.", null) }
            }
        }
        val discovery = KitDiscovery(this)
        MethodChannel(engine.dartExecutor.binaryMessenger, "agrisense/discovery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "discover" -> discovery.discover(result)
                    "cancel" -> { discovery.cancel(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(engine.dartExecutor.binaryMessenger, "agrisense/external_links")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                } else {
                    val url = call.argument<String>("url")
                    val uri = url?.let { Uri.parse(it) }
                    if (uri == null || uri.scheme !in listOf("https", "http") || uri.host.isNullOrEmpty() || uri.userInfo != null) {
                        result.success(false)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (_: Exception) { result.success(false) }
                    }
                }
            }
        MethodChannel(engine.dartExecutor.binaryMessenger, "agrisense/sensor_notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        val host = activity
                        if (host == null) result.success(false) else host.requestNotifications(result)
                    }
                    "show" -> {
                        val id = call.argument<Int>("id")
                        val title = call.argument<String>("title")
                        val body = call.argument<String>("body")
                        if (id == null || id !in 5000..5199 || title == null || body == null || title.length > 100 || body.length > 1000) {
                            result.error("invalid", "Invalid notification.", null)
                        } else result.success(showAlert(id, title, body))
                    }
                    else -> result.notImplemented()
                }
            }
        serviceChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "agrisense/monitoring_service").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val host = activity
                        val crop = call.argument<String>("crop")
                        if (host == null || !host.isResumedForMonitoring || crop !in listOf("Tomato", "Chili", "Eggplant")) {
                            result.error("inactive", "Start monitoring while the app is visible.", null)
                        } else if (pendingStart != null) {
                            result.error("busy", "Monitoring is already starting.", null)
                        } else {
                            pendingStart = result
                            try {
                                val intent = Intent(this@AgriSenseApplication, MonitoringService::class.java).putExtra("crop", crop)
                                if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            } catch (_: Exception) { completeServiceStart(false) }
                        }
                    }
                    "stop" -> { stopService(Intent(this@AgriSenseApplication, MonitoringService::class.java)); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return engine
    }

    fun completeServiceStart(success: Boolean) {
        pendingStart?.success(success)
        pendingStart = null
    }

    fun notificationsAllowed(): Boolean {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return false
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel("sensor_conditions")?.importance == NotificationManager.IMPORTANCE_NONE) return false
        return true
    }

    private fun showAlert(id: Int, title: String, body: String): Boolean {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(
            "sensor_conditions", "Sensor condition alerts", NotificationManager.IMPORTANCE_HIGH))
        if (!notificationsAllowed()) return false
        val open = PendingIntent.getActivity(this, id,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "sensor_conditions") else Notification.Builder(this)
        val notification = builder.setSmallIcon(R.drawable.ic_stat_leaf).setContentTitle(title).setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body)).setContentIntent(open).setAutoCancel(true)
            .setCategory(Notification.CATEGORY_STATUS).setVisibility(Notification.VISIBILITY_PRIVATE).build()
        return try { manager.notify(id, notification); true } catch (_: SecurityException) { false }
    }
}
