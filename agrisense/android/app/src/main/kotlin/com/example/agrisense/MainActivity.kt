package com.example.agrisense

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

class MainActivity : FlutterActivity() {
    private val channelId = "sensor_conditions"
    private var pendingPermission: MethodChannel.Result? = null
    private val permissionRequest = 7041

    private fun manager() = getSystemService(NotificationManager::class.java)
    private fun prepareChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            manager().createNotificationChannel(NotificationChannel(channelId,
                "Sensor condition alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Alerts from sensor readings while AgriSense is open and monitoring."
            })
        }
    }
    private fun allowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        if (Build.VERSION.SDK_INT >= 24 && !manager().areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26 && manager().getNotificationChannel(channelId)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        return true
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "agrisense/sensor_notifications")
            .setMethodCallHandler { call, result ->
                prepareChannel()
                when (call.method) {
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (pendingPermission != null) result.error("busy", "Permission request already open.", null)
                            else {
                                pendingPermission = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionRequest)
                            }
                        } else result.success(allowed())
                    }
                    "show" -> {
                        val id = call.argument<Int>("id")
                        val title = call.argument<String>("title")
                        val body = call.argument<String>("body")
                        if (id == null || title == null || body == null || title.length > 100 || body.length > 1000) {
                            result.error("invalid", "Invalid notification.", null)
                        } else if (!allowed() || !lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED)) {
                            result.success(false)
                        } else {
                            val intent = Intent(this, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            }
                            val pending = PendingIntent.getActivity(this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                            val notification = builder.setSmallIcon(R.drawable.ic_stat_leaf)
                                .setContentTitle(title).setContentText(body)
                                .setStyle(Notification.BigTextStyle().bigText(body))
                                .setContentIntent(pending).setAutoCancel(true)
                                .setCategory(Notification.CATEGORY_STATUS)
                                .setVisibility(Notification.VISIBILITY_PRIVATE).build()
                            try { manager().notify(id, notification); result.success(true) }
                            catch (_: SecurityException) { result.success(false) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequest) {
            pendingPermission?.success(allowed())
            pendingPermission = null
        }
    }
    override fun onDestroy() {
        pendingPermission?.success(false)
        pendingPermission = null
        super.onDestroy()
    }
}
