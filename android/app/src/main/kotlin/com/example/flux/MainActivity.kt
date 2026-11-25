package com.example.flux

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.net.VpnService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.atomic.AtomicLong
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.content.FileProvider
import android.net.Uri
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flux/v2ray"
    private val STATUS_CHANNEL = "com.example.flux/v2ray_status"
    private var isV2rayRunning = false
    private var xrayProcess: Process? = null
    // private var hysteria2Process: Process? = null // Removed
    private var currentProtocol: String = ""
    private var isInitialized = false
    private var isGeoDataReady = false

    private val connectionGeneration = AtomicLong(0L)
    private val vpnOperationLock = Any()

    @Volatile
    private var pendingPermissionGeneration: Long = -1L

    private fun isConnectionCurrent(generation: Long): Boolean =
        connectionGeneration.get() == generation
    
    companion object {
        private const val TAG = "Flux"
        private const val REQUEST_VPN_PERMISSION = 1
        @Volatile
        private var vpnStatusSink: EventChannel.EventSink? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        @JvmStatic
        fun emitVpnStatus(isConnected: Boolean) {
            mainHandler.post {
                vpnStatusSink?.success(isConnected)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val configJson = call.argument<String>("config")
                    if (configJson == null) {
                        result.error("INVALID_ARGUMENT", "Config is null", null)
                        return@setMethodCallHandler
                    }

                    val generation = connectionGeneration.incrementAndGet()
                    pendingPermissionGeneration = -1L
                    FluxVpnService.nodeName = call.argument<String>("nodeName") ?: ""

                    Thread {
                        try {
                            val success = connectV2ray(configJson, generation)
                            mainHandler.post { result.success(success) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("CONNECTION_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "disconnect" -> {
                    val generation = connectionGeneration.incrementAndGet()
                    pendingPermissionGeneration = -1L

                    Thread {
                        try {
                            disconnectV2ray(generation)
                            mainHandler.post { result.success(true) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("DISCONNECT_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "isConnected" -> {
                    result.success(FluxVpnService.isVpnRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STATUS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    vpnStatusSink = events
                    events?.success(FluxVpnService.isVpnRunning)
                }

                override fun onCancel(arguments: Any?) {
                    vpnStatusSink = null
                }
            })

        setupUpdateChannel(flutterEngine)
    }

    private val UPDATE_CHANNEL = "com.yugenb/app_update"

    private fun setupUpdateChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> {
                    result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                }
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "installApk" -> {
                    val apkPath = call.argument<String>("path")
                    if (apkPath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "APK path is empty", null)
                    } else {
                        val apkFile = File(apkPath)
                        if (!apkFile.exists() || !apkFile.isFile) {
                            result.error("APK_NOT_FOUND", "APK file does not exist", null)
                        } else if (
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            !packageManager.canRequestPackageInstalls()
                        ) {
                            result.error(
                                "INSTALL_PERMISSION_REQUIRED",
                                "Allow this app to install unknown apps first",
                                null
                            )
                        } else {
                            try {
                                val apkUri = FileProvider.getUriForFile(
                                    this,
                                    "$packageName.updatefileprovider",
                                    apkFile
                                )
                                val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(
                                        apkUri,
                                        "application/vnd.android.package-archive"
                                    )
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(installIntent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("INSTALL_FAILED", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        splashScreen.setKeepOnScreenCondition { false }
        window.setBackgroundDrawableResource(android.R.color.black)
        
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1002)
        }

        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE

        window.statusBarColor = android.graphics.Color.rgb(23, 27, 46)
        window.navigationBarColor = android.graphics.Color.BLACK
    }

    override fun onDestroy() {
        val generation = connectionGeneration.incrementAndGet()
        pendingPermissionGeneration = -1L
        disconnectV2ray(generation)
        super.onDestroy()
    }

    /**
     * 获取 Xray 可执行文件路径
     * 1. 尝试从 nativeLibraryDir 获取 (libxray.so)
     * 2. 如果失败，尝试从 Assets 复制到 filesDir 并赋予执行权限
     */
    private fun getXrayExecutable(): String? {
        // 1. 尝试从 nativeLibraryDir 查找
        val libDir = applicationInfo.nativeLibraryDir
        val libFile = File(libDir, "libxray.so")
        if (libFile.exists()) {
            Log.d(TAG, "Found Xray in nativeLibraryDir: ${libFile.absolutePath}")
            return libFile.absolutePath
        }

        // 2. 尝试查找含有 xray 的文件 (针对 weird naming)
        val dir = File(libDir)
        val files = dir.listFiles { _, name -> name.contains("xray") }
        if (files != null && files.isNotEmpty()) {
            Log.d(TAG, "Found Xray (fuzzy) in nativeLibraryDir: ${files[0].absolutePath}")
            return files[0].absolutePath
        }

        // 3. 都没有，尝试从 Assets 复制到 filesDir
        Log.w(TAG, "Xray not found in nativeLibraryDir, trying to copy from assets...")
        val internalBin = File(filesDir, "libxray.so")
        
        // 尝试从 assets 复制 "libxray.so" (Flutter assets mapping needed? No, binary stays in Android assets/libs)
        // 注意：这里需要确保 binary 确实在 android assets 里。
        // 由于用户说 assets/bin 是 Flutter assets，所以 binary 必须通过 nativeLibraryDir 找到最稳。
        // 这里保留 fallback 逻辑，假设用户手动放了 assets
        if (copyBinaryFromAssets("libxray.so", internalBin)) {
             return internalBin.absolutePath
        }
        
        if (copyBinaryFromAssets("xray-android-arm64-v8a", internalBin)) {
             return internalBin.absolutePath
        }

        Log.e(TAG, "Xray binary not found in libs or assets!")
        return null
    }

    private fun copyBinaryFromAssets(assetName: String, targetFile: File): Boolean {
        try {
            assets.open(assetName).use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            if (!targetFile.setExecutable(true, true)) {
                Runtime.getRuntime().exec("chmod 700 ${targetFile.absolutePath}").waitFor()
            }
            return true
        } catch (e: Exception) {
            return false
        }
    }

    private fun connectV2ray(configJson: String, generation: Long): Boolean =
        synchronized(vpnOperationLock) {
            if (!isConnectionCurrent(generation)) return@synchronized false

            try {
                if (isV2rayRunning) {
                    stopVpnService()
                    xrayProcess?.destroy()
                    xrayProcess = null
                    isV2rayRunning = false
                    currentProtocol = ""
                    Thread.sleep(500)
                }

                if (!isConnectionCurrent(generation)) return@synchronized false

                val fullConfigObj = JSONObject(configJson)
                val outboundConfig = if (fullConfigObj.has("outbound")) {
                    fullConfigObj.getJSONObject("outbound")
                } else {
                    fullConfigObj
                }

                val routingMode = fullConfigObj.optString("routingMode", "rule")
                val routingRules = fullConfigObj.optJSONArray("routingRules")
                val protocol = outboundConfig.optString("protocol", "")
                currentProtocol = protocol

                Log.d(TAG, "Connecting protocol: $protocol, Mode: $routingMode")

                if (!isConnectionCurrent(generation)) return@synchronized false

                connectXray(outboundConfig, routingMode, routingRules, generation)
            } catch (e: Exception) {
                Log.e(TAG, "Error connecting: ${e.message}")
                e.printStackTrace()
                false
            }
        }

    // Old Hysteria2 methods removed (unified into Xray)
    
    /**
     * 使用 Xray 连接（非 Hysteria2 协议）
     */
    private fun connectXray(
        outboundConfig: JSONObject,
        routingMode: String,
        customRules: org.json.JSONArray?,
        generation: Long
    ): Boolean {
        if (!isConnectionCurrent(generation)) return false

        val executablePath = getXrayExecutable()
        if (executablePath == null) {
            Log.e(TAG, "Xray binary not found!")
            return false
        }

        val configDir = filesDir.absolutePath
        val configFile = File(configDir, "config.json")
        val fullConfig = buildV2rayConfig(outboundConfig, routingMode, customRules)

        FileOutputStream(configFile).use {
            it.write(fullConfig.toByteArray())
        }

        if (!isConnectionCurrent(generation)) return false

        Log.d(TAG, "Starting Xray process: $executablePath -c ${configFile.absolutePath}")
        val pb = ProcessBuilder(executablePath, "-c", configFile.absolutePath)
        pb.directory(filesDir)
        val env = pb.environment()
        env["xray.location.asset"] = configDir

        val process = pb.start()
        xrayProcess = process

        Thread {
            try {
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    Log.d("XrayCore", line ?: "")
                }
            } catch (e: Exception) {
                Log.d("XrayCore", "Process output stream closed")
            }
        }.start()

        Thread {
            try {
                val reader = BufferedReader(InputStreamReader(process.errorStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    Log.e("XrayCore", line ?: "")
                }
            } catch (e: Exception) {
                Log.d("XrayCore", "Process error stream closed")
            }
        }.start()

        // 监控 Xray 核心意外退出，避免 VPN 状态长期停留在已连接
        Thread {
            try {
                val exitCode = process.waitFor()
                synchronized(vpnOperationLock) {
                    if (xrayProcess === process &&
                        isConnectionCurrent(generation)
                    ) {
                        Log.e(TAG, "Xray exited unexpectedly, code=$exitCode")
                        pendingPermissionGeneration = -1L
                        xrayProcess = null
                        isV2rayRunning = false
                        currentProtocol = ""
                        FluxVpnService.nodeName = ""
                        stopVpnService()
                    }
                }
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }.start()

        Thread.sleep(500)

        if (!isConnectionCurrent(generation)) {
            process.destroy()
            if (xrayProcess === process) xrayProcess = null
            isV2rayRunning = false
            currentProtocol = ""
            return false
        }

        if (process.isAlive) {
            isV2rayRunning = true
            requestVpnPermission(generation)
            return true
        }

        Log.e(TAG, "Xray process died immediately")
        if (xrayProcess === process) xrayProcess = null
        isV2rayRunning = false
        return false
    }

    private fun disconnectV2ray(expectedGeneration: Long) {
        synchronized(vpnOperationLock) {
            if (!isConnectionCurrent(expectedGeneration)) return

            pendingPermissionGeneration = -1L
            try {
                stopVpnService()
                xrayProcess?.destroy()
                xrayProcess = null
                isV2rayRunning = false
                currentProtocol = ""
            } catch (e: Exception) {
                Log.e(TAG, "Error disconnecting: ${e.message}")
            }
        }
    }

    private fun requestVpnPermission(generation: Long) {
        if (!isConnectionCurrent(generation)) return

        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingPermissionGeneration = generation
            mainHandler.post {
                if (isConnectionCurrent(generation) &&
                    pendingPermissionGeneration == generation
                ) {
                    startActivityForResult(intent, REQUEST_VPN_PERMISSION)
                }
            }
        } else {
            mainHandler.post {
                startVpnServiceIfCurrent(generation)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_VPN_PERMISSION) {
            val generation = pendingPermissionGeneration
            pendingPermissionGeneration = -1L

            if (generation >= 0L && isConnectionCurrent(generation)) {
                if (resultCode == RESULT_OK) {
                    startVpnServiceIfCurrent(generation)
                } else {
                    synchronized(vpnOperationLock) {
                        if (isConnectionCurrent(generation)) {
                            Log.w(TAG, "VPN permission denied")
                            xrayProcess?.destroy()
                            xrayProcess = null
                            isV2rayRunning = false
                            currentProtocol = ""
                            FluxVpnService.nodeName = ""
                        }
                    }
                }
            }
        }
    }

    private fun startVpnServiceIfCurrent(generation: Long) {
        synchronized(vpnOperationLock) {
            if (!isConnectionCurrent(generation)) return
            if (xrayProcess?.isAlive != true) return

            try {
                val intent = Intent(this, FluxVpnService::class.java).apply {
                    action = FluxVpnService.ACTION_START
                }
                startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Error starting VPN service", e)
                xrayProcess?.destroy()
                xrayProcess = null
                isV2rayRunning = false
                currentProtocol = ""
                FluxVpnService.nodeName = ""
            }
        }
    }

    private fun stopVpnService() {
        try {
            val intent = Intent(this, FluxVpnService::class.java).apply {
                action = FluxVpnService.ACTION_STOP
            }
            // 只发送停止指令，由 VPN Service 完成资源清理后自行 stopSelf()
            startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping VPN service: ${e.message}")
        }
    }

    private fun buildV2rayConfig(outbound: JSONObject, routingMode: String, customRules: org.json.JSONArray?): String {
        val config = JSONObject()
        ensureStreamSettings(outbound)
        
        // 1. Log
        val log = JSONObject().put("loglevel", "warning")
        config.put("log", log)
        
        // 2. Stats
        config.put("stats", JSONObject())
        
        // 3. Policy
        val policy = JSONObject()
        val levels = JSONObject().put("0", JSONObject()
            .put("handshake", 4)
            .put("connIdle", 300)
            .put("uplinkOnly", 2)
            .put("downlinkOnly", 5)
            .put("statsUserUplink", true)
            .put("statsUserDownlink", true)
            .put("bufferSize", 4)
        )
        val system = JSONObject()
            .put("statsInboundUplink", true)
            .put("statsInboundDownlink", true)
            .put("statsOutboundUplink", true)
            .put("statsOutboundDownlink", true)
        policy.put("levels", levels)
        policy.put("system", system)
        config.put("policy", policy)
        
        // 4. DNS
        val dns = JSONObject()
        dns.put("queryStrategy", "UseIPv4")
        val dnsServers = org.json.JSONArray()
        
        // Domestic DNS
        val domesticDns = JSONObject()
        domesticDns.put("address", "223.5.5.5")
        
        val domesticDomains = org.json.JSONArray()
        domesticDomains.put("geosite:cn")
        
        // Add Server Address to Domestic DNS
        val settings = outbound.optJSONObject("settings")
        if (settings != null && settings.has("address")) {
            val serverAddress = settings.getString("address")
            if (serverAddress.isNotEmpty()) {
                domesticDomains.put(serverAddress)
            }
        }
        
        domesticDns.put("domains", domesticDomains)
        domesticDns.put("expectIPs", org.json.JSONArray().put("geoip:cn"))
        dnsServers.put(domesticDns)

        // Foreign DNS: DoH, 查询经代理发出
        dnsServers.put("https://1.1.1.1/dns-query")
        dnsServers.put("https://8.8.8.8/dns-query")
        dnsServers.put("localhost")
        
        dns.put("servers", dnsServers)
        config.put("dns", dns)
        
        // 5. Inbounds
        val inbounds = org.json.JSONArray()
        val socksInbound = JSONObject()
        socksInbound.put("tag", "socks")
        socksInbound.put("port", 10808)
        socksInbound.put("listen", "127.0.0.1")
        socksInbound.put("protocol", "socks")
        socksInbound.put("settings", JSONObject().put("auth", "noauth").put("udp", true))
        socksInbound.put("sniffing", JSONObject().put("enabled", true)
            .put("destOverride", org.json.JSONArray().put("http").put("tls").put("quic")))
        inbounds.put(socksInbound)
        
        val httpInbound = JSONObject()
        httpInbound.put("tag", "http")
        httpInbound.put("port", 10809)
        httpInbound.put("listen", "127.0.0.1")
        httpInbound.put("protocol", "http")
        httpInbound.put("sniffing", JSONObject().put("enabled", true)
            .put("destOverride", org.json.JSONArray().put("http").put("tls").put("quic")))
        inbounds.put(httpInbound)
        
        config.put("inbounds", inbounds)
        
        // 6. Routing
        val routing = JSONObject()
        routing.put("domainStrategy", "IPIfNonMatch")
        val rules = org.json.JSONArray()
        
        // 6.1 Bootstrap Direct
        if (settings != null && settings.has("address")) {
            val serverAddress = settings.getString("address")
            if (serverAddress.isNotEmpty()) {
                rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("domain", org.json.JSONArray().put(serverAddress)))
            }
        }
        
        // 6.2 (已移除) 不再让 8.8.8.8 / 1.1.1.1 直连, 国外 DNS 查询走代理
        
        // 6.3 Mode Handling
        if (routingMode == "global") {
            // Global Mode: Only bypass private/LAN
            rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("ip", org.json.JSONArray().put("geoip:private")))
            rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("domain", org.json.JSONArray().put("geosite:private")))
        } else {
            // Rule Mode: restore 2026-11-22 rule priority
            var hasCustomRules = false
            if (customRules != null && customRules.length() > 0) {
                Log.d(TAG, "Applying ${customRules.length()} custom routing rules")
                for (i in 0 until customRules.length()) {
                    rules.put(customRules.getJSONObject(i))
                }
                hasCustomRules = true
            }

            // Append private and domestic direct rules after remote custom rules
            if (true) {
                Log.d(TAG, "Applying default routing rules")
                rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("ip", org.json.JSONArray().put("geoip:private")))
                rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("domain", org.json.JSONArray().put("geosite:private")))

                val geoip = File(filesDir, "geoip.dat")
                if (geoip.exists() && File(filesDir, "geosite.dat").exists()) {
                    rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("domain", org.json.JSONArray().put("geosite:cn")))
                    rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("ip", org.json.JSONArray().put("geoip:cn")))
                }
            }
        }

        // Final Catch-all Proxy
        rules.put(JSONObject().put("type", "field").put("outboundTag", "proxy").put("network", "tcp,udp"))
        
        routing.put("rules", rules)
        config.put("routing", routing)
        
        // 7. Outbounds
        val outbounds = org.json.JSONArray()
        if (!outbound.has("tag")) outbound.put("tag", "proxy")
        outbounds.put(outbound)
        
        outbounds.put(JSONObject().put("protocol", "freedom").put("tag", "direct").put("settings", JSONObject().put("domainStrategy", "UseIP")))
        outbounds.put(JSONObject().put("protocol", "blackhole").put("tag", "block"))
        
        config.put("outbounds", outbounds)
        
        return config.toString()
    }
    
    private fun ensureStreamSettings(outbound: JSONObject) {
        val protocol = outbound.optString("protocol", "")
        if (protocol == "trojan") {
            var streamSettings = outbound.optJSONObject("streamSettings")
            if (streamSettings == null) {
                streamSettings = JSONObject()
                outbound.put("streamSettings", streamSettings)
            }
            if (!streamSettings.has("security")) streamSettings.put("security", "tls")
            if (!streamSettings.has("network")) streamSettings.put("network", "tcp")
            if (!streamSettings.has("tlsSettings")) streamSettings.put("tlsSettings", JSONObject())
        }
    }
}
