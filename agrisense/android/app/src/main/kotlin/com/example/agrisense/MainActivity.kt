package com.example.agrisense

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val app get() = application as AgriSenseApplication
    private var pendingPermission: MethodChannel.Result? = null
    private val permissionRequest = 7041
    var isResumedForMonitoring = false
        private set
    override fun provideFlutterEngine(context: Context): FlutterEngine = app.engine()
    override fun shouldDestroyEngineWithHost(): Boolean = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Application-created engine already registers plugins and channels.
        app.activity = this
    }
    override fun onResume() {
        super.onResume()
        app.activity = this
        isResumedForMonitoring = true
        app.serviceChannel?.invokeMethod("activityResumed", null)
    }
    override fun onPause() {
        isResumedForMonitoring = false
        app.serviceChannel?.invokeMethod("activityPaused", null)
        super.onPause()
    }
    fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            if (pendingPermission != null) result.error("busy", "Permission request already open.", null)
            else {
                pendingPermission = result
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionRequest)
            }
        } else result.success(app.notificationsAllowed())
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequest) {
            pendingPermission?.success(app.notificationsAllowed())
            pendingPermission = null
        }
    }
    override fun onDestroy() {
        if (app.activity === this) app.activity = null
        pendingPermission?.success(false)
        pendingPermission = null
        super.onDestroy()
    }
}
