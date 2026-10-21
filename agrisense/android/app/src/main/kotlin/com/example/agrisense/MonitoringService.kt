package com.example.agrisense

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/** User-started only. A single cached Flutter engine owns all monitoring/storage. */
class MonitoringService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val renew = object : Runnable {
        override fun run() {
            wakeLock?.acquire(10 * 60 * 1000L)
            handler.postDelayed(this, 5 * 60 * 1000L)
        }
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val app = application as AgriSenseApplication
        if (intent == null) { stopSelf(); return START_NOT_STICKY }
        if (intent.action == "STOP") {
            app.serviceChannel?.invokeMethod("stopRequested", null)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val crop = intent.getStringExtra("crop")
        if (crop !in listOf("Tomato", "Chili", "Eggplant")) {
            app.completeServiceStart(false); stopSelf(); return START_NOT_STICKY
        }
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(
                "monitoring_active", "Active monitoring", NotificationManager.IMPORTANCE_LOW))
            val open = PendingIntent.getActivity(this, 4000, Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val stop = PendingIntent.getService(this, 4001, Intent(this, MonitoringService::class.java).setAction("STOP"),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "monitoring_active") else Notification.Builder(this)
            val notification = builder.setSmallIcon(R.drawable.ic_stat_leaf).setContentTitle("AgriSense monitoring active")
                .setContentText("$crop · monitoring every 10 seconds").setContentIntent(open).setOngoing(true)
                .setCategory(Notification.CATEGORY_SERVICE).setVisibility(Notification.VISIBILITY_PRIVATE)
                .addAction(Notification.Action.Builder(null, "Open", open).build())
                .addAction(Notification.Action.Builder(null, "Stop", stop).build()).build()
            if (Build.VERSION.SDK_INT >= 29) startForeground(4000, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            else startForeground(4000, notification)
            if (wakeLock == null) {
                wakeLock = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AgriSense:Monitoring").apply { setReferenceCounted(false) }
                renew.run()
            }
            app.completeServiceStart(true)
        } catch (_: Exception) {
            app.completeServiceStart(false); stopSelf()
        }
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        handler.removeCallbacks(renew)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        (application as AgriSenseApplication).serviceChannel?.invokeMethod("serviceStopped", null)
        super.onDestroy()
    }
}
