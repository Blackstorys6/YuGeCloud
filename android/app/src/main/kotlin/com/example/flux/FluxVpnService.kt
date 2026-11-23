package com.example.flux

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.pm.ServiceInfo
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.File

/**
 * VPN 服务 - 基于 v2rayNG 的实现
 * 将 VPN 流量转发到本地 SOCKS5 代理 (127.0.0.1:10808)
 */
class FluxVpnService : VpnService() {
    private var mInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    private var tun2SocksService: Tun2SocksControl? = null
    private val connectivity by lazy { getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager }
    private val defaultNetworkRequest by lazy {
        NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .build()
    }
    private val defaultNetworkCallback by lazy {
        object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                setUnderlyingNetworks(arrayOf(network))
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                setUnderlyingNetworks(arrayOf(network))
            }

            override fun onLost(network: Network) {
                setUnderlyingNetworks(null)
            }
        }
    }
    
    companion object {
        private const val TAG = "Flux"
        const val ACTION_START = "com.example.flux.VPN_START"
        const val ACTION_STOP = "com.example.flux.VPN_STOP"
        private const val VPN_ADDRESS = "10.0.0.2"
        private const val VPN_ROUTE = "0.0.0.0"
        private const val VPN_MTU = 1450  // 移动网络下适当提高 MTU，减少分片提升吞吐
        private const val SOCKS_PROXY_HOST = "127.0.0.1"
        private const val SOCKS_PROXY_PORT = 10808
        private const val VPN_ADDRESS_V6 = "fd00:1:fd00:1::2"

        @Volatile
        var isVpnRunning: Boolean = false

        private const val NOTIF_ID = 7001
        private const val CHANNEL_ID = "flux_vpn_status"

        /** 当前连接的节点名，由 MainActivity 在连接前设置 */
        @Volatile
        var nodeName: String = ""
    }

    // ---------- 状态栏通知：节点名 + 实时网速 ----------
    private val uiHandler = Handler(Looper.getMainLooper())
    private var lastUp = 0L
    private var lastDown = 0L
    private var lastTs = 0L
    private var ticking = false
    private val speedTick = object : Runnable {
        override fun run() {
            if (!ticking) return
            refreshNotification()
            uiHandler.postDelayed(this, 1000)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "连接状态",
                NotificationManager.IMPORTANCE_LOW
            ).apply { setShowBadge(false) }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun fmtSpeed(b: Long): String = when {
        b >= 1024L * 1024L -> String.format(java.util.Locale.US, "%.2f MiB/s", b / 1048576.0)
        b >= 1024L -> String.format(java.util.Locale.US, "%.2f KiB/s", b / 1024.0)
        else -> "$b B/s"
    }

    private fun buildStatusNotification(up: Long, down: Long): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = if (launch != null) {
            PendingIntent.getActivity(
                this, 0, launch,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        } else null
        val title = if (nodeName.isNotBlank()) nodeName else "屿哥云 已连接"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_vpn)
            .setContentTitle(title)
            .setContentText("${fmtSpeed(up)} ↑   ${fmtSpeed(down)} ↓")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pi)
            .build()
    }

    private fun startStatusNotification() {
        try {
            ensureChannel()
            lastTs = 0L
            val n = buildStatusNotification(0L, 0L)
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIF_ID, n)
            }
            ticking = true
            uiHandler.removeCallbacks(speedTick)
            uiHandler.postDelayed(speedTick, 1000)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start status notification: ${e.message}")
        }
    }

    @Suppress("DEPRECATION")
    private fun stopStatusNotification() {
        ticking = false
        uiHandler.removeCallbacks(speedTick)
        try {
            stopForeground(true)
        } catch (ignored: Exception) {
            // ignored
        }
    }

    private fun refreshNotification() {
        var up = 0L
        var down = 0L
        try {
            // hev-socks5-tunnel: [txPackets, txBytes, rxPackets, rxBytes]
            val st = hev.htproxy.TProxyService.TProxyGetStats()
            if (st != null && st.size >= 4) {
                val u = st[1]
                val d = st[3]
                val now = SystemClock.elapsedRealtime()
                if (lastTs > 0L) {
                    val dt = (now - lastTs).coerceAtLeast(1L)
                    up = ((u - lastUp) * 1000L / dt).coerceAtLeast(0L)
                    down = ((d - lastDown) * 1000L / dt).coerceAtLeast(0L)
                }
                lastUp = u
                lastDown = d
                lastTs = now
            }
        } catch (ignored: Throwable) {
            // ignored
        }
        try {
            getSystemService(NotificationManager::class.java)
                .notify(NOTIF_ID, buildStatusNotification(up, down))
        } catch (ignored: Exception) {
            // ignored
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "FluxVpnService onCreate")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
        stopStatusNotification()
        Log.d(TAG, "FluxVpnService onDestroy")
    }

    override fun onRevoke() {
        stopVpn()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                Log.d(TAG, "Starting VPN service")
                startVpn()
            }
            ACTION_STOP -> {
                Log.d(TAG, "Stopping VPN service")
                stopVpn()
            }
        }
        return START_STICKY
    }

    /**
     * 启动 VPN 服务
     */
    private fun startVpn() {
        if (isRunning) {
            Log.d(TAG, "VPN already running")
            return
        }

        setupService()
    }

    /**
     * 设置 VPN 服务
     */
    private fun setupService() {
        // 检查 VPN 权限
        val prepare = prepare(this)
        if (prepare != null) {
            Log.e(TAG, "VPN permission not granted")
            return
        }

        // 配置 VPN 接口
        if (!configureVpnService()) {
            Log.e(TAG, "Failed to configure VPN service")
            return
        }

        // 启动 tun2socks
        runTun2socks()
    }

    /**
     * 配置 VPN 服务
     */
    private fun configureVpnService(): Boolean {
        val builder = Builder()

        // 配置网络设置
        configureNetworkSettings(builder)

        // 配置应用规则（禁用 VPN 服务自身，避免流量回环）
        configurePerAppProxy(builder)

        // 关闭旧的接口（如果存在）
        try {
            mInterface?.close()
        } catch (ignored: Exception) {
            // ignored
        }

        // 配置平台特定功能
        configurePlatformFeatures(builder)

        // 创建新的 VPN 接口
        try {
            val establishedInterface = builder.establish()
                ?: throw IllegalStateException("VPN interface establishment returned null")

            mInterface = establishedInterface
            Log.d(TAG, "VPN interface established successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN interface", e)
            stopVpn()
            return false
        }
    }
    
    /**
     * 配置应用规则（禁用 VPN 服务自身，避免流量回环）
     */
    private fun configurePerAppProxy(builder: Builder) {
        val selfPackageName = packageName
        try {
            // 禁用自身应用，避免流量回环
            builder.addDisallowedApplication(selfPackageName)
            Log.d(TAG, "Disallowed self package: $selfPackageName")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to configure per-app proxy: ${e.message}")
        }
    }

    /**
     * 配置网络设置（IP 地址、路由、DNS）
     * 基于 v2rayNG 的实现
     */
    private fun configureNetworkSettings(builder: Builder) {
        // 设置 MTU
        builder.setMtu(VPN_MTU)
        
        // 配置 IPv4 地址（使用 10.0.0.2，与 v2rayNG OPTION_3 类似）
        builder.addAddress(VPN_ADDRESS, 30) // /30 子网

        // 配置路由（路由所有流量）
        // v2rayNG 默认路由所有流量，除非启用 bypass LAN
        builder.addRoute("0.0.0.0", 0)

        // 配置 IPv6（移动网络下更常用） - 暂时禁用以解决连接问题
        // builder.addAddress(VPN_ADDRESS_V6, 126)
        // builder.addRoute("::", 0)

        // 配置 DNS 服务器
        // 移动网络下优先使用国内公共 DNS，降低解析延迟
        builder.addDnsServer("223.5.5.5")  // AliDNS
        builder.addDnsServer("119.29.29.29")  // DNSPod
        builder.addDnsServer("1.1.1.1")  // Cloudflare DNS（备选）

        // 设置会话名称
        builder.setSession("Flux VPN")
    }

    /**
     * 配置平台特定功能
     */
    private fun configurePlatformFeatures(builder: Builder) {
        // Android P (API 28) 及以上：绑定默认网络，避免 VPN 出站回环
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                connectivity.requestNetwork(defaultNetworkRequest, defaultNetworkCallback)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to request default network", e)
            }
        }

        // Android Q (API 29) 及以上：设置非计量网络
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }
    }

    /**
     * 启动 tun2socks
     * 基于 v2rayNG 的实现方式
     */
    private fun runTun2socks() {
        val vpnInterface = mInterface ?: run {
            Log.e(TAG, "VPN interface not available")
            return
        }

        // 使用 TProxyService（基于 v2rayNG 的实现）
        tun2SocksService = TProxyService(
            context = applicationContext,
            vpnInterface = vpnInterface,
            isRunningProvider = { isRunning },
            restartCallback = { runTun2socks() }
        )

        tun2SocksService?.startTun2Socks()
    }

    /**
     * 停止 VPN 服务
     */
    private fun stopVpn() {
        isRunning = false
        isVpnRunning = false

        try {
            MainActivity.emitVpnStatus(false)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to emit VPN stopped status", e)
        }

        try {
            stopStatusNotification()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to stop status notification", e)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                connectivity.unregisterNetworkCallback(defaultNetworkCallback)
            } catch (e: Exception) {
                Log.d(TAG, "Network callback already unregistered: ${e.message}")
            }
        }

        try {
            setUnderlyingNetworks(null)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to clear underlying networks", e)
        }

        try {
            tun2SocksService?.stopTun2Socks()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop tun2socks", e)
        } finally {
            tun2SocksService = null
        }

        try {
            mInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to close VPN interface", e)
        } finally {
            mInterface = null
        }

        stopSelf()
        Log.d(TAG, "VPN cleanup completed")
    }
}

/**
 * Tun2Socks 控制接口
 * 基于 v2rayNG 的 Tun2SocksControl 接口
 */
interface Tun2SocksControl {
    /**
     * 启动 tun2socks 进程
     */
    fun startTun2Socks()

    /**
     * 停止 tun2socks 进程
     */
    fun stopTun2Socks()
}

/**
 * TProxyService - 管理 tun2socks 进程
 * 基于 v2rayNG 的 TProxyService 实现
 * 
 * 注意：完整实现需要 hev-socks5-tunnel native 库
 * 可以从 v2rayNG 项目复制相关代码和库文件
 */
class TProxyService(
    private val context: Context,
    private val vpnInterface: ParcelFileDescriptor,
    private val isRunningProvider: () -> Boolean,
    private val restartCallback: () -> Unit
) : Tun2SocksControl {
    
    companion object {
        private const val TAG = "Flux"
        private const val SOCKS_PROXY_HOST = "127.0.0.1"
        private const val SOCKS_PROXY_PORT = 10808
        private const val TUN_MTU = 1450
        private const val TUN_IPV4 = "10.0.0.2"
        private const val TUN_IPV6 = "fd00:1:fd00:1::2"
        
        // hev-socks5-tunnel native 库的 JNI 接口
        // 注意：需要将 hev-socks5-tunnel 库添加到项目中才能使用
        // 可以从 v2rayNG 项目复制相关库文件，或从 https://github.com/heiher/hev-socks5-tunnel 编译
        // 注意：实际的 native 方法在 hev.htproxy.TProxyService 中声明
        // 库会在 hev.htproxy.TProxyService 初始化时自动加载
    }

    override fun startTun2Socks() {
        // 构建配置文件内容
        val configContent = buildConfig()
        val configFile = File(context.filesDir, "hev-socks5-tunnel.yaml").apply {
            writeText(configContent)
        }
        
        Log.d(TAG, "Tun2Socks config file: ${configFile.absolutePath}")
        Log.d(TAG, "Config content:\n$configContent")

        try {
            // 调用 hev.htproxy.TProxyService 的 native 方法
            hev.htproxy.TProxyService.TProxyStartService(configFile.absolutePath, vpnInterface.fd)
            Log.d(TAG, "Tun2Socks started successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "hev-socks5-tunnel native library unavailable", e)
            throw IllegalStateException("Tun2Socks native library unavailable", e)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Tun2Socks: ${e.message}", e)
            throw e
        }
    }

    private fun buildConfig(): String {
        return buildString {
            appendLine("tunnel:")
            appendLine("  mtu: $TUN_MTU")  // 与 VPN MTU 保持一致，避免数据包过大
            appendLine("  ipv4: $TUN_IPV4")
            appendLine("  ipv6: '$TUN_IPV6'")
            appendLine()
            appendLine("socks5:")
            appendLine("  port: $SOCKS_PROXY_PORT")
            appendLine("  address: $SOCKS_PROXY_HOST")
            appendLine("  udp: 'udp'")
            appendLine()
            appendLine("misc:")
            appendLine("  tcp-read-write-timeout: 300000")
            appendLine("  udp-read-write-timeout: 60000")
            appendLine("  log-level: warn")
        }
    }

    override fun stopTun2Socks() {
        try {
            // 调用 hev.htproxy.TProxyService 的 native 方法
            hev.htproxy.TProxyService.TProxyStopService()
            Log.d(TAG, "Tun2Socks stopped successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "hev-socks5-tunnel library not found, skip stop", e)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop Tun2Socks: ${e.message}", e)
        }
    }
}
