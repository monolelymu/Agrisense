package com.example.agrisense

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.util.ArrayDeque

/** One bounded session; every completion releases multicast and discovery. */
@Suppress("DEPRECATION")
class KitDiscovery(context: Context) {
    private val manager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val handler = Handler(Looper.getMainLooper())
    private var session: Session? = null

    fun discover(result: MethodChannel.Result) {
        if (session != null) { result.error("busy", "Discovery already in progress.", null); return }
        val next = Session(result)
        session = next
        next.start()
    }
    fun cancel() { session?.finish() }

    private inner class Session(val result: MethodChannel.Result) : NsdManager.DiscoveryListener {
        private val addresses = linkedSetOf<String>()
        private val queue = ArrayDeque<NsdServiceInfo>()
        private val seen = mutableSetOf<String>()
        private var resolving = false
        private var closed = false
        private var started = false
        private var lock: WifiManager.MulticastLock? = null
        private val timeout = Runnable { finish() }

        fun start() {
            try {
                lock = wifi.createMulticastLock("agrisense-discovery").also { it.setReferenceCounted(false); it.acquire() }
                handler.postDelayed(timeout, 8000)
                manager.discoverServices("_agrisense._tcp.", NsdManager.PROTOCOL_DNS_SD, this)
            } catch (_: Exception) { finish("Discovery could not start. Check Wi-Fi and local network permissions.") }
        }
        fun finish(error: String? = null) {
            if (closed) return
            closed = true
            handler.removeCallbacks(timeout)
            if (started) try { manager.stopServiceDiscovery(this) } catch (_: Exception) {}
            lock?.let { if (it.isHeld) it.release() }
            queue.clear()
            if (session === this) session = null
            if (error == null) result.success(addresses.toList()) else result.error("discovery_failed", error, null)
        }
        override fun onDiscoveryStarted(type: String) { handler.post {
            started = true
            if (closed) try { manager.stopServiceDiscovery(this) } catch (_: Exception) {}
        } }
        override fun onStartDiscoveryFailed(type: String, code: Int) { handler.post { finish("Discovery unavailable. Check the pocket Wi-Fi and try again.") } }
        override fun onStopDiscoveryFailed(type: String, code: Int) { handler.post { finish() } }
        override fun onDiscoveryStopped(type: String) { handler.post { finish() } }
        override fun onServiceLost(info: NsdServiceInfo) { /* HTTP re-verifies every candidate. */ }
        override fun onServiceFound(info: NsdServiceInfo) { handler.post {
            if (!closed && info.serviceType.trimEnd('.') == "_agrisense._tcp" && seen.size < 16 && seen.add(info.serviceName)) {
                queue.add(info)
                resolveNext()
            }
        } }
        private fun resolveNext() {
            if (closed || resolving || queue.isEmpty()) return
            resolving = true
            val candidate = queue.removeFirst()
            try {
                manager.resolveService(candidate, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(info: NsdServiceInfo, code: Int) { handler.post { resolving = false; resolveNext() } }
                    override fun onServiceResolved(info: NsdServiceInfo) { handler.post {
                        if (!closed && info.host is Inet4Address && info.port in 1..65535) {
                            info.host?.hostAddress?.let { addresses.add("http://$it:${info.port}") }
                        }
                        resolving = false
                        resolveNext()
                    } }
                })
            } catch (_: Exception) { resolving = false; resolveNext() }
        }
    }
}
