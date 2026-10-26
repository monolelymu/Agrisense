package com.example.agrisense

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID

/** Native owns watering schedules and receipts, including without a Dart engine. */
class AppAlerts(private val context: Context) {
    private val prefs = context.getSharedPreferences("app_alerts_v1", Context.MODE_PRIVATE)
    private val alarms get() = context.getSystemService(AlarmManager::class.java)
    fun precise(): Boolean = Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()
    private fun config() = JSONObject(prefs.getString("watering", "{}") ?: "{}")
    fun snapshot(): Map<String, Any?> {
        val c = config()
        val events = JSONArray(prefs.getString("events", "[]"))
        val tap = prefs.getString("tap", null)?.let { JSONObject(it) }
        val manager = context.getSystemService(NotificationManager::class.java)
        val allowed = manager.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 ||
            manager.getNotificationChannel("watering_reminders")?.importance != NotificationManager.IMPORTANCE_NONE)
        return mapOf("enabled" to c.optBoolean("enabled"), "minute" to
            (if (c.has("minute")) c.getInt("minute") else null), "precise" to precise(), "notifications" to allowed,
            "next" to (if (c.optBoolean("enabled") && c.has("minute")) next(c.getInt("minute")) else null),
            "events" to (0 until events.length()).map { objectMap(events.getJSONObject(it)) },
            "tap" to tap?.let { objectMap(it) })
    }
    fun configure(minute: Int?, enabled: Boolean): Map<String, Any?> {
        require(minute == null || minute in 0..1439)
        require(!enabled || minute != null)
        val previous = prefs.getString("watering", "{}")!!
        val c = JSONObject().put("enabled", enabled).put("revision", config().optLong("revision") + 1)
        if (minute != null) c.put("minute", minute)
        check(prefs.edit().putString("watering", c.toString()).commit())
        try { reschedule() } catch (error: Exception) {
            prefs.edit().putString("watering", previous).commit()
            try { reschedule() } catch (_: Exception) {}
            throw error
        }
        return snapshot()
    }
    fun requestPrecise() {
        if (Build.VERSION.SDK_INT >= 31 && !precise()) {
            context.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
    private fun next(minute: Int): Long {
        val now = System.currentTimeMillis()
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minute / 60); set(Calendar.MINUTE, minute % 60)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= now) add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
    }
    private fun alarmIntent(due: Long = 0, revision: Long = 0) = PendingIntent.getBroadcast(
        context, 7201, Intent(context, WateringReceiver::class.java).setAction("agrisense.WATERING")
            .putExtra("due", due).putExtra("revision", revision),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun reschedule() {
        alarms.cancel(alarmIntent())
        val c = config()
        if (!c.optBoolean("enabled") || !c.has("minute")) return
        val due = next(c.getInt("minute"))
        val intent = alarmIntent(due, c.getLong("revision"))
        if (precise()) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, intent)
        else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, intent)
    }
    fun deliver(intent: Intent) {
        val c = config()
        val due = intent.getLongExtra("due", 0)
        if (!c.optBoolean("enabled") || intent.getLongExtra("revision", -1) != c.optLong("revision")) return
        val now = System.currentTimeMillis()
        // Old days are never replayed after reboot/clock changes or long delays.
        val date = Calendar.getInstance().apply { timeInMillis = due }
        val today = Calendar.getInstance()
        if (due > 0 && due <= now && date.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
            date.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)) {
            val id = "watering-${date.get(Calendar.YEAR)}-${date.get(Calendar.DAY_OF_YEAR)}-${c.getInt("minute")}"
            val event = JSONObject().put("id", id).put("type", "watering")
                .put("title", "Watering reminder")
                .put("body", "Time to check your plant’s soil. Water only if needed.")
                .put("at", now).put("target", id)
            if (saveEvent(event)) notify(event)
        }
        reschedule()
    }
    @Synchronized private fun saveEvent(event: JSONObject): Boolean {
        val old = JSONArray(prefs.getString("events", "[]"))
        if ((0 until old.length()).any { old.getJSONObject(it).getString("id") == event.getString("id") }) return false
        val result = JSONArray()
        for (i in maxOf(0, old.length() - 499) until old.length()) result.put(old.get(i))
        result.put(event)
        check(prefs.edit().putString("events", result.toString()).commit())
        return true
    }
    fun post(event: Map<String, Any?>): Boolean {
        val json = JSONObject(event)
        require(json.optString("type") in listOf("sensor", "scheduled", "watering"))
        require(json.optString("id").length in 1..200 && json.optString("title").length in 1..100 &&
            json.optString("body").length <= 1000 && json.optString("target").length <= 200 && json.optLong("at") > 0)
        return if (saveEvent(json)) notify(json) else true
    }
    private fun notify(event: JSONObject): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        val type = event.getString("type")
        val channel = when(type) { "watering" -> "watering_reminders"; "scheduled" -> "photo_checks"; else -> "sensor_conditions" }
        val name = when(type) { "watering" -> "Watering reminders"; "scheduled" -> "Scheduled photos"; else -> "Sensor condition alerts" }
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(channel, name, NotificationManager.IMPORTANCE_HIGH))
        if (!manager.areNotificationsEnabled() || (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(channel)?.importance == NotificationManager.IMPORTANCE_NONE)) return false
        val id = event.getString("id")
        val open = Intent(context, MainActivity::class.java)
            .setAction("${context.packageName}.OPEN_ALERT.$id")
            .putExtra("alert_type", type).putExtra("alert_target", event.optString("target", id))
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.ic_stat_leaf)
            .setContentTitle(event.getString("title")).setContentText(event.getString("body"))
            .setStyle(Notification.BigTextStyle().bigText(event.getString("body")))
            .setContentIntent(pending).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setCategory(Notification.CATEGORY_REMINDER).build()
        return try { manager.notify(id, 0, notification); true } catch (_: SecurityException) { false }
    }
    fun acceptTap(intent: Intent?) {
        val type = intent?.getStringExtra("alert_type") ?: return
        val target = intent.getStringExtra("alert_target") ?: return
        if (type !in listOf("sensor", "scheduled", "watering") || target.length > 200) return
        val tap = JSONObject().put("type", type).put("target", target).put("token", UUID.randomUUID().toString())
        prefs.edit().putString("tap", tap.toString()).commit()
        intent.removeExtra("alert_type"); intent.removeExtra("alert_target")
    }
    fun acknowledge(token: String) {
        val tap = prefs.getString("tap", null)?.let { JSONObject(it) } ?: return
        if (tap.optString("token") == token) prefs.edit().remove("tap").commit()
    }
    private fun objectMap(value: JSONObject): Map<String, Any?> = value.keys().asSequence().associateWith {
        value.get(it).let { v -> if (v == JSONObject.NULL) null else v }
    }
}

class WateringReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            AppAlerts(context).deliver(intent)
            (context.applicationContext as AgriSenseApplication).alertsChannel?.invokeMethod("changed", null)
        } catch (_: Exception) { /* Future checks re-arm on app resume. */ }
    }
}
class ReminderRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { AppAlerts(context).reschedule() } catch (_: Exception) { /* App shows scheduling availability. */ }
    }
}
