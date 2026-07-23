package com.example.flutter_webview

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val NETWORK_ROUTE_CHANNEL =
            "com.example.flutter_webview/network_route"
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NETWORK_ROUTE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "repairWifiRoute" -> {
                    val expectedSsid = call.argument<String>("ssid")
                    result.success(repairWifiRoute(expectedSsid))
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Rebinds this app process to the Wi-Fi network Android currently exposes.
     *
     * Wi-Fi connection plugins use ConnectivityManager.bindProcessToNetwork on
     * Android 10+, and that process-wide binding can outlive a network switch.
     * Prefer the Wi-Fi Network whose WifiInfo matches the SSID observed by the
     * app. The single/active Wi-Fi fallbacks cover devices that redact WifiInfo.
     */
    private fun repairWifiRoute(expectedSsid: String?): Boolean {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return false

        return try {
            val wifiNetworks = connectivityManager.allNetworks.filter { network ->
                connectivityManager.getNetworkCapabilities(network)
                    ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
            if (wifiNetworks.isEmpty()) {
                Log.w(TAG, "Cannot repair route: no Wi-Fi Network is available")
                return false
            }

            val normalizedExpectedSsid = normalizeSsid(expectedSsid)
            val matchingNetwork = wifiNetworks.firstOrNull { network ->
                normalizedExpectedSsid != null &&
                    normalizedExpectedSsid == wifiSsid(connectivityManager, network)
            }
            val activeWifiNetwork = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                connectivityManager.activeNetwork?.takeIf(wifiNetworks::contains)
            } else {
                null
            }
            val selectedNetwork =
                matchingNetwork
                    ?: wifiNetworks.singleOrNull()
                    ?: activeWifiNetwork

            if (selectedNetwork == null) {
                Log.w(
                    TAG,
                    "Cannot repair route: multiple Wi-Fi Networks and no SSID match",
                )
                return false
            }

            val bound = bindProcessToNetwork(connectivityManager, selectedNetwork)
            Log.i(
                TAG,
                "Wi-Fi process route repair ${if (bound) "succeeded" else "failed"}",
            )
            bound
        } catch (error: SecurityException) {
            Log.w(TAG, "Cannot inspect Wi-Fi Networks due to missing permission", error)
            false
        } catch (error: RuntimeException) {
            Log.w(TAG, "Wi-Fi process route repair failed", error)
            false
        }
    }

    private fun wifiSsid(
        connectivityManager: ConnectivityManager,
        network: Network,
    ): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val capabilities =
            connectivityManager.getNetworkCapabilities(network) ?: return null
        val wifiInfo = capabilities.transportInfo as? WifiInfo ?: return null
        return normalizeSsid(wifiInfo.ssid)
    }

    @Suppress("DEPRECATION")
    private fun bindProcessToNetwork(
        connectivityManager: ConnectivityManager,
        network: Network,
    ): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivityManager.bindProcessToNetwork(network)
        } else {
            ConnectivityManager.setProcessDefaultNetwork(network)
        }
    }

    private fun normalizeSsid(ssid: String?): String? {
        val value = ssid?.trim()?.takeUnless {
            it.isEmpty() || it.equals("<unknown ssid>", ignoreCase = true)
        } ?: return null
        return if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
            value.substring(1, value.length - 1)
        } else {
            value
        }
    }
}
