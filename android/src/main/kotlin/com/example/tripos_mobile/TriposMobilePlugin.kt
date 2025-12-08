package com.example.tripos_mobile

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.math.BigDecimal
import java.util.ArrayList

// --- 核心 SDK 引用 ---
import com.vantiv.triposmobilesdk.VTP
import com.vantiv.triposmobilesdk.triPOSMobileSDK
import com.vantiv.triposmobilesdk.Configuration
import com.vantiv.triposmobilesdk.ApplicationConfiguration
import com.vantiv.triposmobilesdk.HostConfiguration
import com.vantiv.triposmobilesdk.DeviceConfiguration
import com.vantiv.triposmobilesdk.TcpIpConfiguration
// 移除 BluetoothConfiguration 引用，因为它导致报错
// import com.vantiv.triposmobilesdk.BluetoothConfiguration 
import com.vantiv.triposmobilesdk.TransactionConfiguration
import com.vantiv.triposmobilesdk.StoreAndForwardConfiguration

// --- 监听器 ---
import com.vantiv.triposmobilesdk.DeviceConnectionListener
import com.vantiv.triposmobilesdk.DeviceInteractionListener
import com.vantiv.triposmobilesdk.SaleRequestListener

// --- 枚举 ---
import com.vantiv.triposmobilesdk.enums.DeviceType
import com.vantiv.triposmobilesdk.enums.PaymentProcessor
import com.vantiv.triposmobilesdk.enums.ApplicationMode
import com.vantiv.triposmobilesdk.enums.MarketCode
import com.vantiv.triposmobilesdk.enums.CurrencyCode
import com.vantiv.triposmobilesdk.enums.TransactionStoringMode

// --- 请求与响应 ---
import com.vantiv.triposmobilesdk.requests.SaleRequest
import com.vantiv.triposmobilesdk.responses.SaleResponse

import com.vantiv.triposmobilesdk.BluetoothScanRequestListener

class TriposMobilePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    
    companion object {
        private const val TAG = "TriPOSMobile"
    }
    
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    
    private var sharedVtp: VTP? = null
    private var eventSink: EventChannel.EventSink? = null
    private val uiHandler = Handler(Looper.getMainLooper())

    private var savedHostConfig: HostConfiguration? = null
    private var savedAppConfig: ApplicationConfiguration? = null
    private var savedStoreForwardConfig: StoreAndForwardConfiguration? = null
    private var isProductionMode: Boolean = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "tripos_mobile")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tripos_mobile/events")
        eventChannel.setStreamHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "initialize" -> {
                val config = call.arguments as? Map<String, Any>
                if (config != null) initializeSdk(config, result) else result.error("ARGS", "Config null", null)
            }
            "scanDevices" -> scanDevices(result)
            "connectDevice" -> {
                val device = call.arguments as? Map<String, Any>
                if (device != null) connectDevice(device, result) else result.error("ARGS", "Device info null", null)
            }
            "processPayment" -> {
                val request = call.arguments as? Map<String, Any>
                if (request != null) processPayment(request, result) else result.error("ARGS", "Request null", null)
            }
            "disconnect" -> disconnectDevice(result)
            else -> result.notImplemented()
        }
    }

    private fun initializeSdk(config: Map<String, Any>, result: Result) {
        try {
            Log.d(TAG, "Initializing triPOS SDK...")
            
            // Validate required parameters
            val acceptorId = config["acceptorId"] as? String
            val accountId = config["accountId"] as? String
            val accountToken = config["accountToken"] as? String
            
            if (acceptorId.isNullOrEmpty() || accountId.isNullOrEmpty() || accountToken.isNullOrEmpty()) {
                Log.e(TAG, "Missing required credentials")
                result.error("INVALID_CONFIG", "Missing required credentials (acceptorId, accountId, or accountToken)", null)
                return
            }
            
            sharedVtp = triPOSMobileSDK.getSharedVtp()
            isProductionMode = (config["isProduction"] as? Boolean) ?: false
            Log.d(TAG, "Production mode: $isProductionMode")

            savedHostConfig = HostConfiguration()
            savedHostConfig?.apply {
                setAcceptorId(acceptorId)
                setAccountId(accountId)
                setAccountToken(accountToken)
                setApplicationId((config["applicationId"] as? String) ?: "12345")
                setApplicationName((config["applicationName"] as? String) ?: "FlutterPlugin")
                setApplicationVersion((config["applicationVersion"] as? String) ?: "1.0.0")
                setPaymentProcessor(PaymentProcessor.Worldpay)
            }
            Log.d(TAG, "Host configuration created")

            savedAppConfig = ApplicationConfiguration()
            savedAppConfig?.apply {
                setApplicationMode(if (isProductionMode) ApplicationMode.Production else ApplicationMode.TestCertification)
                setMarketCode(MarketCode.Retail)
            }
            Log.d(TAG, "Application configuration created")

            // 3. Store and Forward (Offline Payment) Configuration
            val storeModeStr = config["storeMode"] as? String ?: "Auto"
            val offlineLimit = (config["offlineAmountLimit"] as? Double) ?: 100.00
            val retentionDays = (config["retentionDays"] as? Int) ?: 7
            
            savedStoreForwardConfig = StoreAndForwardConfiguration()
            savedStoreForwardConfig?.apply {
                try {
                    transactionStoringMode = TransactionStoringMode.valueOf(storeModeStr)
                } catch (e: Exception) {
                    Log.w(TAG, "Invalid storeMode: $storeModeStr, defaulting to Auto")
                    transactionStoringMode = TransactionStoringMode.Auto
                }
                // Set amount limit using the correct method/property
                try {
                    // Try direct property assignment first
                    val limitField = this.javaClass.getDeclaredField("transactionAmountLimit")
                    limitField.isAccessible = true
                    limitField.set(this, BigDecimal(offlineLimit))
                } catch (e: Exception) {
                    // Fallback: try setter method
                    try {
                        val method = this.javaClass.getMethod("setTransactionAmountLimit", BigDecimal::class.java)
                        method.invoke(this, BigDecimal(offlineLimit))
                    } catch (e2: Exception) {
                        Log.w(TAG, "Could not set transaction amount limit: ${e2.message}")
                    }
                }
                // Set retention days using reflection to find correct property name
                try {
                    val daysField = this.javaClass.getDeclaredField("expirationPeriod")
                    daysField.isAccessible = true
                    daysField.set(this, retentionDays)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not set expiration period: ${e.message}")
                }
            }
            Log.d(TAG, "Store and Forward configured: Mode=$storeModeStr, Limit=$offlineLimit, Days=$retentionDays")

            Log.i(TAG, "SDK initialized successfully")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize SDK", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun connectDevice(deviceMap: Map<String, Any>, result: Result) {
        if (savedHostConfig == null || sharedVtp == null) {
            result.error("NOT_INIT", "Please call initialize() first", null)
            return
        }

        val identifier = deviceMap["identifier"] as? String ?: ""
        val isIpConnection = (deviceMap["isIp"] as? Boolean) ?: false
        
        val devConfig = DeviceConfiguration()
        
        if (isIpConnection) {
            devConfig.setDeviceType(DeviceType.IngenicoUppTcpIp)
            val tcpConfig = TcpIpConfiguration()
            tcpConfig.setIpAddress(identifier)
            tcpConfig.setPort(12000)
            devConfig.setTcpIpConfiguration(tcpConfig)
        } else {
            // Bluetooth connection
            Log.d(TAG, "Configuring Bluetooth device: $identifier")
            devConfig.setDeviceType(DeviceType.IngenicoRuaBluetooth)
            
            try {
                // Set bluetooth identifier
                devConfig.identifier = identifier
                Log.d(TAG, "Bluetooth identifier set successfully")
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to set bluetooth identifier, trying alternative method", e)
                try {
                    // Alternative: try setIdentifier method if property access fails
                    val setIdentifierMethod = devConfig.javaClass.getMethod("setIdentifier", String::class.java)
                    setIdentifierMethod.invoke(devConfig, identifier)
                    Log.d(TAG, "Bluetooth identifier set via setter method")
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to set bluetooth identifier via all methods", e2)
                    sendEvent("error", "Failed to configure bluetooth: ${e2.message}")
                }
            }
        }
        
        val config = Configuration()
        config.setHostConfiguration(savedHostConfig)
        config.setDeviceConfiguration(devConfig)
        if (savedAppConfig != null) {
            config.setApplicationConfiguration(savedAppConfig)
        }
        
        // Apply Store and Forward configuration for offline payments
        if (savedStoreForwardConfig != null) {
            config.storeAndForwardConfiguration = savedStoreForwardConfig
            Log.d(TAG, "Store and Forward configuration applied")
        }

        Thread {
            try {
                Log.d(TAG, "Starting device connection...")
                if (sharedVtp!!.isInitialized) {
                    Log.d(TAG, "Deinitializing existing VTP instance")
                    sharedVtp!!.deinitialize()
                }
                
                Log.d(TAG, "Initializing VTP with device configuration")
                sharedVtp!!.initialize(context, config, object : DeviceConnectionListener {
                    override fun onConnected(device: com.vantiv.triposmobilesdk.Device?, desc: String?, model: String?, serial: String?) {
                        Log.i(TAG, "Device connected: $model ($serial)")
                        sendEvent("connected", "Connected to $model ($serial)")
                        uiHandler.post { result.success(true) }
                    }
                    override fun onDisconnected(device: com.vantiv.triposmobilesdk.Device?) {
                        Log.i(TAG, "Device disconnected")
                        sendEvent("disconnected", "Device disconnected")
                    }
                    override fun onError(e: Exception?) {
                        Log.e(TAG, "Connection error", e)
                        sendEvent("error", "Connection Error: ${e?.message}")
                    }
                    override fun onBatteryLow() { sendEvent("message", "WARNING: Battery Low") }
                    override fun onWarning(e: Exception?) { sendEvent("message", "Warning: ${e?.message}") }
                    override fun onConfirmPairing(ledSequences: MutableList<com.vantiv.triposmobilesdk.BTPairingLedSequence>?, deviceName: String?, listener: DeviceConnectionListener.ConfirmPairingListener?) {
                        sendEvent("message", "请在设备上确认配对")
                        listener?.confirmPairing()
                    }
                })
            } catch (e: Exception) {
                Log.e(TAG, "Device connection failed", e)
                uiHandler.post { result.error("CONNECT_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun processPayment(request: Map<String, Any>, result: Result) {
        if (sharedVtp == null || !sharedVtp!!.isInitialized) {
            Log.e(TAG, "Cannot process payment: SDK not initialized")
            result.error("SDK_ERROR", "SDK not initialized", null)
            return
        }

        val amount = (request["amount"] as? Double) ?: 0.0
        Log.d(TAG, "Processing payment for amount: $amount")
        
        val saleRequest = SaleRequest()
        saleRequest.setTransactionAmount(BigDecimal(amount))

        try {
            sharedVtp!!.processSaleRequest(saleRequest, object : SaleRequestListener {
                override fun onSaleRequestCompleted(saleResponse: SaleResponse) {
                    Log.i(TAG, "Sale request completed")
                    uiHandler.post {
                        try {
                            val responseMap = mutableMapOf<String, Any?>()
                            
                            // Use reflection to get all available fields since we don't know exact names
                            Log.d(TAG, "Inspecting SaleResponse class...")
                            
                            // List all methods for debugging
                            val methods = saleResponse.javaClass.methods
                            Log.d(TAG, "Available methods in SaleResponse:")
                            methods.forEach { method ->
                                if (method.name.startsWith("get") || method.name.startsWith("is")) {
                                    Log.d(TAG, "  - ${method.name}()")
                                }
                            }
                            
                            // Try common field name patterns (including offline payment fields)
                            val possibleFields = mapOf(
                                "isApproved" to listOf("getIsApproved", "isApproved", "getApproved"),
                                "authCode" to listOf("getAuthorizationCode", "getAuthCode", "getApprovalCode"),
                                "transactionId" to listOf("getTransactionId", "getTransactionID", "getTxnId"),
                                "message" to listOf("getResponseMessage", "getMessage", "getStatusMessage"),
                                "amount" to listOf("getAuthorizedAmount", "getAmount", "getTransactionAmount"),
                                "isStored" to listOf("isStored", "getIsStored", "getStored")
                            )
                            
                            possibleFields.forEach { (fieldName, methodNames) ->
                                var found = false
                                for (methodName in methodNames) {
                                    try {
                                        val method = saleResponse.javaClass.getMethod(methodName)
                                        val value = method.invoke(saleResponse)
                                        responseMap[fieldName] = value?.toString() ?: ""
                                        Log.d(TAG, "Found $fieldName via $methodName: $value")
                                        found = true
                                        break
                                    } catch (e: Exception) {
                                        // Method doesn't exist, try next one
                                    }
                                }
                                if (!found) {
                                    responseMap[fieldName] = ""
                                    Log.w(TAG, "Could not find field: $fieldName")
                                }
                            }
                            
                            // Special handling for offline transactions
                            val isStored = (responseMap["isStored"] as? String)?.toBoolean() == true
                            if (isStored) {
                                Log.i(TAG, "Transaction stored offline - will be forwarded when connection available")
                                responseMap["isOffline"] = true
                            } else {
                                responseMap["isOffline"] = false
                            }
                            
                            // Always include raw response for debugging
                            responseMap["rawResponse"] = saleResponse.toString()
                            
                            Log.d(TAG, "Payment response: $responseMap")
                            result.success(responseMap)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error parsing sale response", e)
                            result.error("PARSE_ERROR", "Failed to parse response: ${e.message}", null)
                        }
                    }
                }

                override fun onSaleRequestError(e: Exception) {
                    Log.e(TAG, "Sale request error", e)
                    uiHandler.post { result.error("SALE_ERROR", e.message, null) }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process sale request", e)
            result.error("SALE_EXCEPTION", e.message, null)
        }
    }
    
    private fun disconnectDevice(result: Result) {
        try { 
            sharedVtp?.deinitialize()
            result.success(true) 
        } catch (e: Exception) { 
            result.error("ERR", e.message, null) 
        }
    }

    private fun scanDevices(result: Result) {
        // 1. 权限检查 (Android 12+ 需要 BLUETOOTH_SCAN)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasScan = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
            val hasConnect = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            
            if (!hasScan || !hasConnect) {
                result.error("PERMISSION_DENIED", "Need BLUETOOTH_SCAN and CONNECT permissions", null)
                return
            }
        } else {
            // Android 11 及以下需要定位权限才能扫描蓝牙
            val hasLoc = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!hasLoc) {
                result.error("PERMISSION_DENIED", "Need ACCESS_FINE_LOCATION permission", null)
                return
            }
        }

        // 2. 检查蓝牙适配器状态
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter?.isEnabled != true) {
            result.error("BT_OFF", "Bluetooth is not enabled", null)
            return
        }

        // 3. 检查 SDK 是否初始化
        if (sharedVtp == null) {
            // 如果还没初始化，尝试先获取单例
            try {
                sharedVtp = triPOSMobileSDK.getSharedVtp()
            } catch (e: Exception) {
                result.error("SDK_ERROR", "SDK not initialized", null)
                return
            }
        }

        // 4. 准备配置 (扫描需要传入完整的 Config，包括设备类型)
        val config = Configuration()
        if (savedHostConfig != null) {
            config.hostConfiguration = savedHostConfig
        }
        if (savedAppConfig != null) {
            config.applicationConfiguration = savedAppConfig
        }
        
        // 关键：必须指定要扫描的设备类型，否则会报 "device type : Null" 错误
        val deviceConfig = DeviceConfiguration()
        deviceConfig.setDeviceType(DeviceType.IngenicoRuaBluetooth) // Moby 5500 使用蓝牙
        config.setDeviceConfiguration(deviceConfig)

        Log.d(TAG, "Starting SDK Bluetooth Scan...")

        // 5. 在后台线程调用 SDK 扫描方法（避免阻塞主线程）
        Thread {
            try {
                sharedVtp!!.scanBluetoothDevicesWithConfiguration(context, config, object : BluetoothScanRequestListener {
                    
                    // 扫描成功回调
                    override fun onScanRequestCompleted(devices: ArrayList<String>?) {
                        val devicesList = ArrayList<Map<String, String>>()
                        
                        // 支付设备名称关键词列表（用于过滤非支付设备）
                        val paymentDeviceKeywords = listOf(
                            "mob", "ingenico", "icmp", "lane", "tablet", 
                            "vantiv", "worldpay", "tripos", "rba", "rua"
                        )
                        
                        devices?.forEach { deviceString ->
                            // triPOS 返回的通常是 "设备名 (MAC地址)" 格式
                            // 使用正则解析设备名称和 MAC 地址
                            val regex = Regex("(.+?)\\s*\\(([0-9A-Fa-f:]+)\\)")
                            val match = regex.find(deviceString)
                            
                            var name = ""
                            var mac = ""
                            
                            if (match != null) {
                                // 成功解析出名称和 MAC
                                name = match.groupValues[1].trim()
                                mac = match.groupValues[2].trim()
                            } else {
                                // 如果无法解析，可能直接是 MAC 地址或其他格式
                                name = deviceString
                                mac = deviceString
                            }
                            
                            // 过滤：只保留支付设备
                            val isPaymentDevice = paymentDeviceKeywords.any { keyword ->
                                name.lowercase().contains(keyword)
                            }
                            
                            if (isPaymentDevice) {
                                devicesList.add(mapOf(
                                    "name" to name,
                                    "identifier" to mac
                                ))
                                Log.d(TAG, "✓ Payment device found: $name ($mac)")
                            } else {
                                Log.d(TAG, "✗ Filtered out non-payment device: $name")
                            }
                        }
                        
                        uiHandler.post { 
                            Log.i(TAG, "Scan completed, found ${devicesList.size} payment devices (filtered from ${devices?.size ?: 0} total)")
                            result.success(devicesList) 
                        }
                    }

                    // 扫描失败回调
                    override fun onScanRequestError(e: Exception?) {
                        uiHandler.post {
                            Log.e(TAG, "Scan failed", e)
                            result.error("SCAN_ERROR", e?.message ?: "Unknown scan error", null)
                        }
                    }
                })
            } catch (e: Exception) {
                uiHandler.post {
                    Log.e(TAG, "Scan exception", e)
                    result.error("SCAN_EXCEPTION", e.message, null)
                }
            }
        }.start()
    }

    private fun sendEvent(type: String, msg: String?) {
        uiHandler.post { eventSink?.success(mapOf("type" to type, "message" to msg)) }
    }

    override fun onListen(args: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(args: Any?) { eventSink = null }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        try { sharedVtp?.deinitialize() } catch (e: Exception) {}
    }
}