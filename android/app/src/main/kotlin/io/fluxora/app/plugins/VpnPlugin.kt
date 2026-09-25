package io.fluxora.app.plugins

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.IBinder
import android.widget.Toast
import androidx.core.content.getSystemService
import io.fluxora.app.FluxoraApplication
import io.fluxora.app.GlobalState
import io.fluxora.app.RunState
import io.fluxora.core.Core
import io.fluxora.app.extensions.awaitResult
import io.fluxora.app.extensions.asSocketAddressText
import io.fluxora.app.extensions.resolveDns
import io.fluxora.app.models.StartForegroundParams
import io.fluxora.app.models.VpnOptions
import io.fluxora.app.modules.SuspendModule
import io.fluxora.app.services.BaseServiceInterface
import io.fluxora.app.services.FluxoraService
import io.fluxora.app.services.FluxoraVpnService
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import java.util.Collections
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.InetSocketAddress
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.withLock

data object VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    @Volatile
    private var fluxoraService: BaseServiceInterface? = null
    @Volatile
    private var options: VpnOptions? = null

    @Volatile
    private var isBind = false
    private val isBinding = AtomicBoolean(false)

    private var job = SupervisorJob()
    private var scope = CoroutineScope(Dispatchers.Default + job as kotlin.coroutines.CoroutineContext)
    private var lastStartForegroundParams: StartForegroundParams? = null
    private val uidPageNameMap = ConcurrentHashMap<Int, String>()
    private var suspendModule: SuspendModule? = null

    @Volatile
    private var quickResponseEnabled = false
    private var quickResponseJob: Job? = null
    private var lastNetworkType: Int? = null
    private var lastDns = ""

    val networks: MutableSet<Network> = Collections.newSetFromMap(ConcurrentHashMap())

    private val connectivity by lazy {
        FluxoraApplication.getAppContext().getSystemService<ConnectivityManager>()
    }

    private var bindTimeoutJob: Job? = null
    private val attachedMessengers = Collections.newSetFromMap(ConcurrentHashMap<BinaryMessenger, Boolean>())
    private val channelMap = ConcurrentHashMap<BinaryMessenger, MethodChannel>()
    private val activeChannels = CopyOnWriteArrayList<MethodChannel>()
    private val networkCallbackRegistered = AtomicBoolean(false)

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            bindTimeoutJob?.cancel()
            bindTimeoutJob = null
            isBind = true
            isBinding.set(false)
            fluxoraService = when (service) {
                is FluxoraVpnService.LocalBinder -> service.getService()
                is FluxoraService.LocalBinder -> service.getService()
                else -> throw Exception("invalid binder")
            }
            handleStartService()
        }

        override fun onServiceDisconnected(arg: ComponentName) {
            isBind = false
            isBinding.set(false)
            fluxoraService = null
            if (GlobalState.currentRunState == RunState.START) {
                android.util.Log.w("VpnPlugin", "Service unexpectedly disconnected while running, syncing state")
                GlobalState.updateRunState(RunState.STOP)
                ServicePlugin.notifyVpnStartFailed()
                ServicePlugin.notifyRunStateChanged(RunState.STOP)
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val isFirstAttach = attachedMessengers.isEmpty()
        attachedMessengers.add(flutterPluginBinding.binaryMessenger)

        if (job.isCancelled) {
            job = SupervisorJob()
            scope = CoroutineScope(Dispatchers.Default + job as kotlin.coroutines.CoroutineContext)
        }

        val channel = MethodChannel(flutterPluginBinding.binaryMessenger, "vpn")
        channel.setMethodCallHandler(this)
        channelMap[flutterPluginBinding.binaryMessenger] = channel
        activeChannels.add(channel)

        if (isFirstAttach) {
            scope.launch { registerNetworkCallback() }
        }

        scope.launch {
            var dns = when {
                lastDns.isNotBlank() -> lastDns
                else -> getCurrentDns()
            }
            if (dns.isBlank()) {
                delay(1000)
                dns = getCurrentDns()
                if (dns.isNotBlank()) lastDns = dns
            }
            withContext(Dispatchers.Main) {
                runCatching {
                    channel.invokeMethod("dnsChanged", dns)
                }
            }
        }

        if (GlobalState.currentRunState == RunState.START && fluxoraService == null) {
            android.util.Log.d("VpnPlugin", "VPN is running but service connection lost, rebinding...")
            options?.let { bindService() }
        }
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        attachedMessengers.remove(flutterPluginBinding.binaryMessenger)
        channelMap.remove(flutterPluginBinding.binaryMessenger)?.let { channel ->
            channel.setMethodCallHandler(null)
            activeChannels.remove(channel)
        }

        if (attachedMessengers.isEmpty()) {
            unRegisterNetworkCallback()
            job.cancel()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                try {
                    val data = call.argument<String>("data")
                    if (data == null) {
                        result.error("INVALID_ARGUMENT", "data parameter is required", null)
                        return
                    }
                    val vpnOptions = Gson().fromJson(data, VpnOptions::class.java)
                    result.success(handleStart(vpnOptions))
                } catch (e: Exception) {
                    android.util.Log.e("VpnPlugin", "Failed to start VPN: ${e.message}")
                    result.error("PARSE_ERROR", "Failed to parse VpnOptions: ${e.message}", null)
                }
            }

            "stop" -> {
                handleStop()
                result.success(true)
            }

            "getLocalIpAddresses" -> {
                result.success(getLocalIpAddresses())
            }

            "getLocalGateways" -> {
                result.success(getLocalGateways())
            }

            "setSmartStopped" -> {
                val value = call.argument<Boolean>("value") ?: false
                GlobalState.isSmartStopped = value
                result.success(true)
            }

            "isSmartStopped" -> {
                result.success(GlobalState.isSmartStopped)
            }

            "smartStop" -> {
                handleSmartStop()
                result.success(true)
            }

            "smartResume" -> {
                val data = call.argument<String>("data")
                result.success(handleSmartResume(Gson().fromJson(data, VpnOptions::class.java)))
            }
            
            "setQuickResponse" -> {
                quickResponseEnabled = call.argument<Boolean>("enabled") ?: false
                result.success(true)
            }

            "updateNotificationSpeed" -> {
                handleUpdateNotificationSpeed(
                    call.argument<String>("profileName") ?: "",
                    call.argument<String>("speedInfo") ?: ""
                )
                result.success(true)
            }

            "status" -> {
                result.success(GlobalState.currentRunState == RunState.START)
            }

            else -> {
                result.notImplemented()
            }
        }
    }
    
    fun setQuickResponse(enabled: Boolean) {
        quickResponseEnabled = enabled
    }

    private fun getActivePhysicalNetworks(): Set<Network> {
        val current = networks
        if (current.isNotEmpty()) return current

        val cm = connectivity ?: return emptySet()
        val isPhysical: (Network) -> Boolean = { net ->
            cm.getNetworkCapabilities(net)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == false
        }

        val available = cm.allNetworks.filter(isPhysical).toSet()
        if (available.isNotEmpty()) return available

        return cm.activeNetwork?.takeIf(isPhysical)?.let { setOf(it) } ?: emptySet()
    }

    fun getLocalIpAddresses(): List<String> = runCatching {
        getActivePhysicalNetworks().flatMap { network ->
            connectivity?.getLinkProperties(network)
                ?.linkAddresses
                ?.mapNotNull { it.address }
                ?.filter { !it.isLoopbackAddress && it.hostAddress?.contains(":") == false }
                ?.mapNotNull { it.hostAddress }
                ?: emptyList()
        }
    }.getOrElse {
        android.util.Log.e("VpnPlugin", "getLocalIpAddresses error: ${it.message}")
        emptyList()
    }

    fun getLocalGateways(): List<String> = runCatching {
        getActivePhysicalNetworks().flatMap { network ->
            connectivity?.getLinkProperties(network)
                ?.routes
                ?.filter { it.isDefaultRoute() }
                ?.mapNotNull { it.gateway }
                ?.filter {
                    !it.isLoopbackAddress && !it.isAnyLocalAddress &&
                        it.hostAddress?.contains(":") == false
                }
                ?.mapNotNull { it.hostAddress }
                ?: emptyList()
        }
    }.getOrElse {
        android.util.Log.e("VpnPlugin", "getLocalGateways error: ${it.message}")
        emptyList()
    }

    fun handleStart(options: VpnOptions): Boolean {
        onUpdateNetwork()
        if (options.enable != this.options?.enable) {
            this.fluxoraService = null
        }
        this.options = options
        when (options.enable) {
            true -> handleStartVpn()
            false -> handleStartService()
        }
        return true
    }

    private fun handleStartVpn() {
        GlobalState.getCurrentAppPlugin()?.requestVpnPermission {
            handleStartService()
        }
    }

    fun requestGc() {
        invokeDart("gc")
    }

    fun onUpdateNetwork() {
        val dns = getCurrentDns()
        if (dns == lastDns) return
        lastDns = dns
        invokeDart("dnsChanged", dns)
    }

    fun notifyScreenStateChanged(isOn: Boolean) {
        invokeDart("screenStateChanged", isOn)
    }

    private fun getCurrentDns(): String {
        val dnsSet = when {
            networkDnsMap.isNotEmpty() -> networkDnsMap.values.flatMap { it }
            else -> {
                val cm = connectivity
                val activeNetwork = cm?.activeNetwork
                activeNetwork?.let { cm.resolveDns(it) } ?: emptyList()
            }
        }.toSet()
        return when {
            dnsSet.isNotEmpty() -> dnsSet.joinToString(",")
            else -> getAllNetworksDns()
        }
    }

    private fun getAllNetworksDns(): String {
        return runCatching {
            connectivity?.allNetworks?.flatMap { network ->
                connectivity?.resolveDns(network) ?: emptyList()
            }?.filter { it.isNotBlank() }?.toSet()?.joinToString(",") ?: ""
        }.getOrElse { "" }
    }

    private val networkDnsMap = ConcurrentHashMap<Network, List<String>>()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            networks.add(network)
            handleNetworkChange()
            invokeDart("networkChanged")
        }

        override fun onLost(network: Network) {
            networks.remove(network)
            networkDnsMap.remove(network)
            onUpdateNetwork()
            handleNetworkChange()
            invokeDart("networkChanged")
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            val dnsList = linkProperties.dnsServers.map { it.asSocketAddressText(53) }
            networkDnsMap[network] = dnsList
            onUpdateNetwork()
        }
    }

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private fun registerNetworkCallback() {
        if (!networkCallbackRegistered.compareAndSet(false, true)) return
        runCatching {
            networks.clear()
            connectivity?.registerNetworkCallback(request, callback)
        }.onFailure {
            networkCallbackRegistered.set(false)
            android.util.Log.e("VpnPlugin", "Failed to register network callback: ${it.message}")
        }
    }

    private fun unRegisterNetworkCallback() {
        if (!networkCallbackRegistered.compareAndSet(true, false)) return
        runCatching {
            connectivity?.unregisterNetworkCallback(callback)
        }.onFailure {
            android.util.Log.e("VpnPlugin", "Failed to unregister network callback: ${it.message}")
        }.also {
            networks.clear()
            networkDnsMap.clear()
            onUpdateNetwork()
        }
    }
    
    private fun handleNetworkChange() {
        val currentNetworkType = getCurrentNetworkType()
        if (lastNetworkType == null) {
            lastNetworkType = currentNetworkType
            return
        }

        if (currentNetworkType != lastNetworkType) {
            lastNetworkType = currentNetworkType

            ServicePlugin.notifyNetworkChanged()
            invokeDart("networkChanged")

            if (!quickResponseEnabled) return

            quickResponseJob?.cancel()
            quickResponseJob = scope.launch {
                delay(150)
                if (GlobalState.currentRunState == RunState.START) {
                    android.util.Log.d("VpnPlugin", "Quick Response: Network changed, notifying Dart")
                    ServicePlugin.notifyQuickResponse()
                }
            }
        }
    }

    private fun invokeDart(method: String, arguments: Any? = null) {
        if (activeChannels.isEmpty()) return
        scope.launch {
            withContext(Dispatchers.Main) {
                activeChannels.forEach { channel ->
                    runCatching { channel.invokeMethod(method, arguments) }
                        .onFailure {
                            android.util.Log.w("VpnPlugin", "invokeDart($method) failed: ${it.message}")
                        }
                }
            }
        }
    }
    
    private fun getCurrentNetworkType(): Int {
        val activeNetwork = connectivity?.activeNetwork ?: return -1
        val caps = connectivity?.getNetworkCapabilities(activeNetwork) ?: return -1
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 1
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 2
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 3
            else -> 0
        }
    }

    private suspend fun startForeground() {
        val shouldUpdate = GlobalState.runLock.withLock {
            GlobalState.currentRunState == RunState.START || GlobalState.isSmartStopped
        }
        if (!shouldUpdate) return

        try {
            fluxoraService?.startForeground()
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "startForeground error: ${e.message}")
        }
    }

    fun updateNotificationIcon() {
        scope.launch {
            runCatching {
                val context = FluxoraApplication.getAppContext()
                val notificationManager = context.getSystemService(android.app.NotificationManager::class.java)
                notificationManager?.cancel(GlobalState.NOTIFICATION_ID)
                (fluxoraService as? FluxoraService)?.resetNotificationBuilder()
                (fluxoraService as? FluxoraVpnService)?.resetNotificationBuilder()
                fluxoraService?.startForeground()
            }.onFailure {
                android.util.Log.e("VpnPlugin", "updateNotificationIcon error: ${it.message}")
            }
        }
    }

    fun handleUpdateNotificationSpeed(profileName: String, speedInfo: String) {
        if (profileName != GlobalState.currentProfileName ||
            !GlobalState.isSpeedNotificationEnabled
        ) {
            GlobalState.currentProfileName = profileName
            GlobalState.isSpeedNotificationEnabled = true
        }
        updateNotificationSpeed(profileName, speedInfo)
    }

    fun updateNotificationSpeed(profileName: String, speedInfo: String) {
        scope.launch {
            runCatching {
                (fluxoraService as? FluxoraVpnService)?.updateNotificationSpeed(profileName, speedInfo)
            }.onFailure {
                android.util.Log.e("VpnPlugin", "updateNotificationSpeed error: ${it.message}")
            }
        }
    }

    fun setHighPriorityNotification(enabled: Boolean) {
        GlobalState.isNotificationHighPriority = enabled
        (fluxoraService as? FluxoraService)?.resetNotificationBuilder()
        (fluxoraService as? FluxoraVpnService)?.resetNotificationBuilder()
        if (GlobalState.currentRunState == RunState.START) {
            scope.launch {
                startForeground()
            }
        }
    }

    fun getStatus(): Boolean {
        return GlobalState.runLock.withLock {
            GlobalState.currentRunState == RunState.START && fluxoraService != null
        }
    }

    private fun handleStartService() {
        if (GlobalState.isCurrentlyStopping()) {
            android.util.Log.w("VpnPlugin", "VPN is in stopping state, ignore start request")
            return
        }
        if (fluxoraService == null) {
            bindService()
            return
        }
        
        scope.launch {
            try {
                if (options?.enable == true) {
                    val prepareIntent = try {
                        android.net.VpnService.prepare(FluxoraApplication.getAppContext())
                    } catch (e: Exception) {
                        null
                    }

                    if (prepareIntent != null) {
                        android.util.Log.w("VpnPlugin", "VPN permission required before start")
                        GlobalState.updateRunState(RunState.STOP)
                        withContext(Dispatchers.Main) {
                            GlobalState.getCurrentAppPlugin()?.requestVpnPermission {
                                handleStartService()
                            }
                        }
                        return@launch
                    }
                }

                val currentOptions = options
                val startAllowed = GlobalState.runLock.withLock {
                    if (GlobalState.currentRunState == RunState.START) {
                        android.util.Log.d("VpnPlugin", "Service already running, refreshing notification")
                        scope.launch { startForeground() }
                        return@withLock false
                    }
                    if (currentOptions == null) {
                        android.util.Log.e("VpnPlugin", "Start failed: options is null")
                        GlobalState.updateRunState(RunState.STOP)
                        return@withLock false
                    }
                    GlobalState.updateRunState(RunState.START)
                    lastStartForegroundParams = null
                    true
                }

                if (!startAllowed || currentOptions == null) return@launch

                performStartCore(currentOptions, retry = true, notifyOnFailure = true)
            } catch (e: Exception) {
                android.util.Log.e("VpnPlugin", "Fatal error in start flow: ${e.message}")
                GlobalState.updateRunState(RunState.STOP)
            }
        }
    }

    private suspend fun performStartCore(
        currentOptions: VpnOptions,
        retry: Boolean,
        notifyOnFailure: Boolean
    ) {
        var fd: Int? = 0
        try {
            fd = fluxoraService?.start(currentOptions)
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "First start attempt failed: ${e.message}")
        }

        if (fd == null || (currentOptions.enable && fd <= 0)) {
            if (retry) {
                android.util.Log.w("VpnPlugin", "VPN establish failed, retrying...")
                delay(300)
                try {
                    fd = fluxoraService?.start(currentOptions)
                } catch (e: Exception) {
                    android.util.Log.e("VpnPlugin", "Retry start failed: ${e.message}")
                }
            }
        }

        if (fd == null || (currentOptions.enable && fd <= 0)) {
            android.util.Log.e("VpnPlugin", "VPN start failed after all attempts")
            GlobalState.runLock.withLock { GlobalState.updateRunState(RunState.STOP) }
            if (notifyOnFailure) {
                ServicePlugin.notifyVpnStartFailed()
            }
            return
        }

        val canStart = GlobalState.runLock.withLock {
            if (GlobalState.currentRunState != RunState.START) {
                fluxoraService?.stop()
                false
            } else true
        }
        if (!canStart) return

        io.fluxora.core.Core.startTun(
            fd = fd ?: 0,
            protect = this@VpnPlugin::protect,
            resolverProcess = this@VpnPlugin::resolverProcess,
        )

        GlobalState.runLock.withLock {
            if (GlobalState.currentRunState != RunState.START) {
                Core.stopTun()
                return@withLock
            }
            scope.launch { startForeground() }
            if (currentOptions.dozeSuspend) {
                suspendModule?.uninstall()
                suspendModule = SuspendModule(FluxoraApplication.getAppContext())
                suspendModule?.install()
            }
        }
        onUpdateNetwork()
    }

    private fun protect(fd: Int): Boolean {
        var retries = 0
        while (retries < 5) {
            val success = runCatching {
                (fluxoraService as? FluxoraVpnService)?.protect(fd) == true
            }.getOrDefault(false)
            
            if (success) return true
            
            retries++
            if (retries < 5) {
                Thread.sleep(60)
            }
        }
        android.util.Log.e("VpnPlugin", "protect failed for fd $fd after retries")
        return false
    }

    private fun resolverProcess(
        protocol: Int,
        source: InetSocketAddress,
        target: InetSocketAddress,
        uid: Int,
    ): String = runCatching {
        val nextUid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectivity?.getConnectionOwnerUid(protocol, source, target) ?: -1
        } else {
            uid
        }
        if (nextUid == -1) {
            return@runCatching ""
        }
        uidPageNameMap.getOrPut(nextUid) {
            FluxoraApplication.getAppContext().packageManager?.getPackagesForUid(nextUid)
                ?.firstOrNull() ?: ""
        }
    }.getOrElse {
        android.util.Log.e("VpnPlugin", "resolverProcess error: ${it.message}")
        ""
    }

    fun handleStop(force: Boolean = false) {
        val serviceRef: BaseServiceInterface?
        val wasBound: Boolean
        val shouldForceStop: Boolean
        GlobalState.runLock.withLock {
            if (!force && GlobalState.currentRunState == RunState.STOP) return
            GlobalState.updateIsStopping(true)
            GlobalState.updateRunState(RunState.STOP)
            ServicePlugin.notifyRunStateChanged(RunState.STOP)
            serviceRef = fluxoraService
            wasBound = isBind
            shouldForceStop = force || fluxoraService == null
        }

        suspendModule?.uninstall()
        suspendModule = null
        Core.stopTun()
        serviceRef?.stop()

        runCatching {
            if (wasBound) {
                FluxoraApplication.getAppContext().unbindService(connection)
                isBind = false
            }
            fluxoraService = null
        }.onFailure {
            android.util.Log.e("VpnPlugin", "unbindService error: ${it.message}")
        }

        val context = FluxoraApplication.getAppContext()
        if (shouldForceStop) {
            context.stopService(Intent(context, FluxoraVpnService::class.java))
            context.stopService(Intent(context, FluxoraService::class.java))
        }

        runCatching {
            context.getSystemService<android.app.NotificationManager>()
                ?.cancel(GlobalState.NOTIFICATION_ID)
        }.onFailure {
            android.util.Log.e("VpnPlugin", "cancel notification error: ${it.message}")
        }

        scope.launch {
            delay(300)
            GlobalState.updateIsStopping(false)
            delay(200)
            withContext(Dispatchers.Main) {
                GlobalState.handleTryDestroy()
            }
        }
    }

    fun handleSmartStop() {
        GlobalState.runLock.withLock {
            if (GlobalState.currentRunState == RunState.STOP) return
            GlobalState.updateRunState(RunState.STOP)
            GlobalState.isSmartStopped = true
        }
        suspendModule?.uninstall()
        suspendModule = null
        Core.stopTun()
        Core.suspended(true)
        (fluxoraService as? FluxoraService)?.resetNotificationBuilder()
        (fluxoraService as? FluxoraVpnService)?.resetNotificationBuilder()
        scope.launch {
            startForeground()
        }
        scope.launch(Dispatchers.Main) {
            Toast.makeText(FluxoraApplication.getAppContext(), "Fluxora Suspended", Toast.LENGTH_SHORT).show()
        }
        ServicePlugin.notifyNetworkChanged()
    }

    fun handleSmartResume(options: VpnOptions): Boolean {
        scope.launch {
            val startAllowed = GlobalState.runLock.withLock {
                if (GlobalState.currentRunState == RunState.START) return@withLock false
                GlobalState.isSmartStopped = false
                this@VpnPlugin.options = options

                if (fluxoraService == null) {
                    bindService()
                    return@withLock false
                }

                GlobalState.updateRunState(RunState.START)
                lastStartForegroundParams = null
                true
            }
            if (!startAllowed) return@launch

            Core.suspended(false)
            (fluxoraService as? FluxoraService)?.resetNotificationBuilder()
            (fluxoraService as? FluxoraVpnService)?.resetNotificationBuilder()
            performStartCore(options, retry = false, notifyOnFailure = false)
            withContext(Dispatchers.Main) {
                Toast.makeText(FluxoraApplication.getAppContext(), "Fluxora Connected", Toast.LENGTH_SHORT).show()
            }
            ServicePlugin.notifyNetworkChanged()
        }
        return true
    }

    private fun bindService() {
        if (!isBinding.compareAndSet(false, true)) return

        bindTimeoutJob?.cancel()
        bindTimeoutJob = scope.launch {
            delay(10_000L)
            if (isBinding.compareAndSet(true, false)) {
                android.util.Log.w("VpnPlugin", "bindService timeout (10s), resetting bind state")
                GlobalState.runLock.withLock {
                    if (GlobalState.currentRunState == RunState.PENDING) {
                        GlobalState.updateRunState(RunState.STOP)
                    }
                }
            }
        }

        try {
            if (isBind) {
                FluxoraApplication.getAppContext().unbindService(connection)
                isBind = false
            }
            val intent = Intent(
                FluxoraApplication.getAppContext(),
                if (options?.enable == true) FluxoraVpnService::class.java else FluxoraService::class.java
            )
            val res = FluxoraApplication.getAppContext().bindService(intent, connection, Context.BIND_AUTO_CREATE)
            if (!res) {
                isBinding.set(false)
                bindTimeoutJob?.cancel()
                bindTimeoutJob = null
                android.util.Log.e("VpnPlugin", "bindService returned false (rejected by system)")
            }
        } catch (e: Exception) {
            isBinding.set(false)
            bindTimeoutJob?.cancel()
            bindTimeoutJob = null
            android.util.Log.e("VpnPlugin", "bindService error: ${e.message}")
        }
    }
}