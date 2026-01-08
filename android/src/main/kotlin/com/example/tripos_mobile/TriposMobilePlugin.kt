package com.example.tripos_mobile

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.vantiv.triposmobilesdk.*
import com.vantiv.triposmobilesdk.enums.*
import com.vantiv.triposmobilesdk.requests.*
import com.vantiv.triposmobilesdk.responses.*
import java.math.BigDecimal

/** TriposMobilePlugin */
class TriposMobilePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    companion object {
        private const val TAG = "TriposMobilePlugin"
    }

    private lateinit var channel: MethodChannel
    private lateinit var statusEventChannel: EventChannel
    private lateinit var deviceEventChannel: EventChannel
    
    private var context: Context? = null
    private var activity: Activity? = null
    private var statusEventSink: EventChannel.EventSink? = null
    private var deviceEventSink: EventChannel.EventSink? = null
    
    private val mainHandler = Handler(Looper.getMainLooper())
    private val vtp: VTP get() = triPOSMobileSDK.getSharedVtp()
    private var currentConfiguration: Configuration? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "tripos_mobile")
        channel.setMethodCallHandler(this)
        
        statusEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tripos_mobile/status")
        statusEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statusEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                statusEventSink = null
            }
        })
        
        deviceEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tripos_mobile/device")
        deviceEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                deviceEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                deviceEventSink = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "getSdkVersion" -> result.success(triPOSMobileSDK.getVersion())
            "scanBluetoothDevices" -> scanBluetoothDevices(call, result)
            // SDK and Device management (new separated methods)
            "initializeSdk" -> initializeSdk(call, result)
            "connectDevice" -> connectDevice(call, result)
            "disconnectDevice" -> disconnectDevice(result)
            // Legacy combined method (backward compatible)
            "initialize" -> initialize(call, result)
            "isInitialized" -> result.success(vtp.isInitialized)
            "isDeviceConnected" -> result.success(isDeviceReady)
            "deinitialize" -> deinitialize(result)
            "processSale" -> processSale(call, result)
            "processRefund" -> processRefund(call, result)
            "processLinkedRefund" -> processLinkedRefund(call, result)
            "processVoid" -> processVoid(call, result)
            "processAuthorization" -> processAuthorization(call, result)
            "cancelTransaction" -> cancelTransaction(result)
            "getDeviceInfo" -> getDeviceInfo(result)
            // Store-and-Forward methods
            "getStoredTransactions" -> getStoredTransactions(result)
            "getStoredTransactionByTpId" -> getStoredTransactionByTpId(call, result)
            "getStoredTransactionsByState" -> getStoredTransactionsByState(call, result)
            "forwardTransaction" -> forwardTransaction(call, result)
            "deleteStoredTransaction" -> deleteStoredTransaction(call, result)
            else -> result.notImplemented()
        }
    }

    private fun scanBluetoothDevices(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context is not available", null)
            return
        }
        
        try {
            // If already initialized/connected, deinitialize first before scanning
            if (vtp.isInitialized) {
                Log.i(TAG, "SDK already initialized, deinitializing before scan...")
                vtp.deinitialize()
                isDeviceReady = false
            }
            
            val configMap = call.arguments as? Map<*, *>
            val config = buildConfiguration(configMap)
            
            Log.i(TAG, "Starting Bluetooth scan...")
            
            // Track if scan has completed (to prevent timeout callback after result)
            var scanCompleted = false
            
            // Set a 10 second timeout for scanning
            val timeoutRunnable = Runnable {
                if (!scanCompleted) {
                    scanCompleted = true
                    Log.i(TAG, "Scan timeout - returning empty list")
                    // Cleanup SDK state on timeout to allow rescan
                    try { vtp.deinitialize() } catch (e: Exception) { /* ignore */ }
                    isDeviceReady = false
                    mainHandler.post {
                        result.success(ArrayList<String>())
                    }
                }
            }
            mainHandler.postDelayed(timeoutRunnable, 10000)
            
            vtp.scanBluetoothDevicesWithConfiguration(ctx, config, object : BluetoothScanRequestListener {
                override fun onScanRequestCompleted(devices: ArrayList<String>?) {
                    if (scanCompleted) return  // Timeout already fired
                    scanCompleted = true
                    mainHandler.removeCallbacks(timeoutRunnable)
                    
                    Log.i(TAG, "Scan completed. Found ${devices?.size ?: 0} device(s): $devices")
                    
                    // Filter and sort devices - payment devices first
                    val paymentKeywords = listOf("mob", "ingenico", "icmp", "lane", "tripos", "worldpay", "vantiv", "rba", "rua")
                    val paymentDevices = mutableListOf<String>()
                    val otherDevices = mutableListOf<String>()
                    
                    devices?.forEach { device ->
                        val lowerDevice = device.lowercase()
                        val isPaymentDevice = paymentKeywords.any { keyword -> lowerDevice.contains(keyword) }
                        if (isPaymentDevice) {
                            paymentDevices.add(device)
                            Log.d(TAG, "✓ Payment device: $device")
                        } else {
                            otherDevices.add(device)
                            Log.d(TAG, "✗ Filtered non-payment device: $device")
                        }
                    }
                    
                    // Payment devices first, then others
                    val sortedDevices = ArrayList<String>().apply {
                        addAll(paymentDevices)
                        // addAll(otherDevices)
                    }
                    
                    Log.i(TAG, "Filtered: ${paymentDevices.size} payment devices, ${otherDevices.size} other devices")
                    
                    mainHandler.post {
                        result.success(sortedDevices)
                    }
                }
                
                override fun onScanRequestError(exception: Exception?) {
                    if (scanCompleted) return  // Timeout already fired
                    scanCompleted = true
                    mainHandler.removeCallbacks(timeoutRunnable)
                    
                    Log.e(TAG, "Scan error: ${exception?.message}", exception)
                    mainHandler.post {
                        result.error("SCAN_ERROR", exception?.message ?: "Unknown error", null)
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Exception during scan setup: ${e.message}", e)
            result.error("SCAN_ERROR", e.message, null)
        }
    }

    // Track device ready state
    @Volatile
    private var isDeviceReady = false
    
    private fun initialize(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context is not available", null)
            return
        }
        
        try {
            val configMap = call.arguments as? Map<*, *>
            val config = buildConfiguration(configMap)
            currentConfiguration = config
            
            // Reset device ready state
            isDeviceReady = false
            
            // Use CountDownLatch to wait for device connection
            val connectionLatch = java.util.concurrent.CountDownLatch(1)
            var connectionError: Exception? = null
            
            val connectionListener = object : DeviceConnectionListener {
                override fun onConnected(device: Device?, description: String?, model: String?, serialNumber: String?) {
                    Log.i(TAG, "Device connected: $description, $model, $serialNumber")

                    isDeviceReady = true
                    connectionLatch.countDown()
                    mainHandler.post {
                        deviceEventSink?.success(mapOf(
                            "event" to "connected",
                            "description" to description,
                            "model" to model,
                            "serialNumber" to serialNumber
                        ))
                    }
                }
                
                override fun onDisconnected(device: Device?) {
                    Log.i(TAG, "Device disconnected")
                    isDeviceReady = false
                    mainHandler.post {
                        deviceEventSink?.success(mapOf("event" to "disconnected"))
                    }
                }
                
                override fun onError(exception: Exception?) {
                    Log.e(TAG, "Device error: ${exception?.message}")
                    connectionError = exception
                    connectionLatch.countDown()
                    mainHandler.post {
                        deviceEventSink?.success(mapOf(
                            "event" to "error",
                            "message" to (exception?.message ?: "Unknown error")
                        ))
                    }
                }
                
                override fun onBatteryLow() {
                    Log.w(TAG, "Device battery low")
                    mainHandler.post {
                        deviceEventSink?.success(mapOf("event" to "batteryLow"))
                    }
                }
                
                override fun onWarning(exception: Exception?) {
                    Log.w(TAG, "Device warning: ${exception?.message}")
                    mainHandler.post {
                        deviceEventSink?.success(mapOf(
                            "event" to "warning",
                            "message" to (exception?.message ?: "Unknown warning")
                        ))
                    }
                }

                override fun onConfirmPairing(
                    ledSequence: MutableList<BTPairingLedSequence>?,
                    deviceName: String?,
                    confirmPairingListener: DeviceConnectionListener.ConfirmPairingListener?
                ) {
                    // Auto-confirm pairing for now
                    confirmPairingListener?.confirmPairing()
                }
            }
            
            Thread {
                try {
                    Log.i(TAG, "Starting SDK initialization...")
                    
                    // Send connecting event to Flutter
                    mainHandler.post {
                        deviceEventSink?.success(mapOf("event" to "connecting"))
                    }
                    
                    vtp.initialize(ctx, config, connectionListener, null)
                    Log.i(TAG, "SDK initialize() returned, waiting for onConnected callback...")
                    
                    // Wait for onConnected callback (timeout: 30 seconds)
                    val connected = connectionLatch.await(30, java.util.concurrent.TimeUnit.SECONDS)
                    
                    if (!connected) {
                        Log.e(TAG, "Connection timeout waiting for device")
                        mainHandler.post {
                            result.error("CONNECTION_TIMEOUT", "Timeout waiting for device connection", null)
                        }
                        return@Thread
                    }
                    
                    if (connectionError != null) {
                        Log.e(TAG, "Connection error: ${connectionError?.message}")
                        mainHandler.post {
                            result.error("CONNECTION_ERROR", connectionError?.message, null)
                        }
                        return@Thread
                    }
                    
                    // Wait for device to fully stabilize after connection
                    // The SDK fires onConnected before internal initialization is complete,
                    // which can cause the first card swipe to be unresponsive.
                    Log.i(TAG, "Device connected, waiting for stabilization...")
                    Thread.sleep(2000)
                    Log.i(TAG, "Device stabilization complete, ready for transactions")
                    
                    mainHandler.post {
                        result.success(true)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Initialize error: ${e.message}")
                    mainHandler.post {
                        result.error("INIT_ERROR", e.message, null)
                    }
                }
            }.start()
        } catch (e: Exception) {
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun deinitialize(result: Result) {
        try {
            if (vtp.isInitialized) {
                Thread {
                    try {
                        vtp.deinitialize()
                        currentConfiguration = null
                        mainHandler.post {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("DEINIT_ERROR", e.message, null)
                        }
                    }
                }.start()
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            result.error("DEINIT_ERROR", e.message, null)
        }
    }

    // ===== NEW: Separated SDK Initialization and Device Connection =====
    
    /**
     * Initialize SDK only (without connecting to a device).
     * Uses initializeDevicePool() which sets up the SDK configuration
     * but doesn't establish a device connection.
     */
    private fun initializeSdk(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context is not available", null)
            return
        }
        
        try {
            val configMap = call.arguments as? Map<*, *>
            val config = buildConfiguration(configMap)
            currentConfiguration = config
            
            // Reset device state
            isDeviceReady = false
            
            Log.i(TAG, "initializeSdk: Configuration stored for later device connection.")
            
            // For Bluetooth devices, we just store the configuration.
            // The actual SDK initialization happens in connectDevice() when a specific
            // device identifier is provided and vtp.initialize() is called.
            
            result.success(mapOf(
                "success" to true,
                "message" to "SDK configuration stored. Ready to scan and connect device."
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "initializeSdk setup error: ${e.message}", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }
    
    /**
     * Connect to a specific device after SDK has been initialized.
     * Uses vtp.initialize() with the device identifier to establish connection.
     * For Bluetooth devices, we need to use the standard initialize flow.
     */
    private fun connectDevice(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context is not available", null)
            return
        }
        
        try {
            val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val identifier = args["identifier"] as? String
            val deviceTypeStr = args["deviceType"] as? String
            
            if (identifier.isNullOrEmpty()) {
                result.error("INVALID_ARGS", "Device identifier is required", null)
                return
            }
            
            val currentConfig = currentConfiguration ?: run {
                result.error("NO_CONFIG", "Configuration not set. Call initializeSdk first.", null)
                return
            }
            
            Log.i(TAG, "connectDevice: Connecting to device: $identifier (type: $deviceTypeStr)")
            
            // Update the device configuration with the new identifier
            val deviceType = parseDeviceType(deviceTypeStr)
            currentConfig.deviceConfiguration.identifier = identifier
            currentConfig.deviceConfiguration.deviceType = deviceType
            
            isDeviceReady = false
            
            // Store identifier in final val for closure capture
            val finalIdentifier = identifier
            Log.i(TAG, "connectDevice: Using identifier for fallback: $finalIdentifier")
            
            // Use initialize with DeviceConnectionListener for Bluetooth devices
            val connectionLatch = java.util.concurrent.CountDownLatch(1)
            var connectionError: String? = null
            var deviceDescription = ""
            var deviceModel = ""
            var deviceSerial = ""
            
            val connectionListener = object : DeviceConnectionListener {
                override fun onConnected(device: Device?, description: String?, model: String?, serialNumber: String?) {
                    Log.i(TAG, "connectDevice: Raw callback - description=$description, model=$model, serial=$serialNumber")
                    Log.i(TAG, "connectDevice: Device object - ${device?.toString()}")
                    Log.i(TAG, "connectDevice: finalIdentifier in closure = $finalIdentifier")
                    
                    // Try to get info from Device object if callback params are null/empty/NULL strings
                    val resolvedDescription = when {
                        description.isNullOrEmpty() || description == "NULL DEVICE" || description == "null" -> 
                            device?.description ?: finalIdentifier ?: "Unknown Device"
                        else -> description
                    }
                    
                    val resolvedModel = when {
                        model.isNullOrEmpty() || model == "NULL" || model == "null" -> 
                            device?.model ?: _detectDeviceTypeFromIdentifier(finalIdentifier) ?: finalIdentifier ?: "Unknown"
                        else -> model
                    }
                    
                    val resolvedSerial = when {
                        serialNumber.isNullOrEmpty() || serialNumber.startsWith("NULL") || serialNumber == "null" -> 
                            device?.serialNumber ?: finalIdentifier ?: "Unknown"
                        else -> serialNumber
                    }
                    
                    Log.i(TAG, "connectDevice: Resolved - description=$resolvedDescription, model=$resolvedModel, serial=$resolvedSerial")
                    
                    deviceDescription = resolvedDescription
                    deviceModel = resolvedModel
                    deviceSerial = resolvedSerial
                    isDeviceReady = true
                    connectionLatch.countDown()
                }
                
                override fun onDisconnected(device: Device?) {
                    Log.w(TAG, "connectDevice: Device disconnected during connection")
                    connectionError = "Device disconnected"
                    isDeviceReady = false
                    connectionLatch.countDown()
                }
                
                override fun onError(exception: Exception?) {
                    Log.e(TAG, "connectDevice: Connection error: ${exception?.message}")
                    connectionError = exception?.message ?: "Unknown error"
                    isDeviceReady = false
                    connectionLatch.countDown()
                }
                
                override fun onBatteryLow() {
                    Log.w(TAG, "connectDevice: Device battery low")
                }
                
                override fun onWarning(exception: Exception?) {
                    Log.w(TAG, "connectDevice: Device warning: ${exception?.message}")
                }
                
                override fun onConfirmPairing(
                    ledSequence: MutableList<BTPairingLedSequence>?,
                    deviceName: String?,
                    confirmPairingListener: DeviceConnectionListener.ConfirmPairingListener?
                ) {
                    Log.i(TAG, "connectDevice: Pairing confirmation requested for $deviceName")
                    // Auto-confirm pairing
                    confirmPairingListener?.confirmPairing()
                }
            }
            
            Thread {
                try {
                    vtp.initialize(ctx, currentConfig, connectionListener, null)
                    
                    val connected = connectionLatch.await(30, java.util.concurrent.TimeUnit.SECONDS)
                    
                    mainHandler.post {
                        if (!connected) {
                            result.error("CONNECTION_TIMEOUT", "Connection timed out", null)
                        } else if (connectionError != null) {
                            result.error("CONNECTION_ERROR", connectionError, null)
                        } else {
                            // Send device connected event
                            deviceEventSink?.success(mapOf(
                                "event" to "connected",
                                "description" to deviceDescription,
                                "model" to deviceModel,
                                "serialNumber" to deviceSerial
                            ))
                            
                            result.success(mapOf(
                                "success" to true,
                                "description" to deviceDescription,
                                "model" to deviceModel,
                                "serialNumber" to deviceSerial
                            ))
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "connectDevice exception: ${e.message}", e)
                    mainHandler.post {
                        result.error("CONNECTION_ERROR", e.message, null)
                    }
                }
            }.start()
        } catch (e: Exception) {
            Log.e(TAG, "connectDevice setup error: ${e.message}", e)
            result.error("CONNECTION_ERROR", e.message, null)
        }
    }
    
    /**
     * Disconnect from the current device.
     * For Bluetooth devices, we use deinitialize() since closeSession() is for USB device pools.
     * After disconnecting, the stored configuration remains so user can connect to another device.
     */
    private fun disconnectDevice(result: Result) {
        if (!vtp.isInitialized) {
            // SDK not initialized, but that's okay - just reset state
            isDeviceReady = false
            result.success(mapOf("success" to true, "message" to "No device connected"))
            return
        }
        
        Log.i(TAG, "disconnectDevice: Deinitializing to disconnect device...")
        
        Thread {
            try {
                // For Bluetooth devices, use deinitialize() to disconnect
                // The closeSession() API is for USB device pool mode
                vtp.deinitialize()
                
                isDeviceReady = false
                Log.i(TAG, "disconnectDevice: Device disconnected successfully")
                
                mainHandler.post {
                    deviceEventSink?.success(mapOf("event" to "disconnected"))
                    result.success(mapOf(
                        "success" to true, 
                        "message" to "Device disconnected (configuration retained)"
                    ))
                }
            } catch (e: Exception) {
                Log.e(TAG, "disconnectDevice exception: ${e.message}", e)
                // Even if deinitialize fails, reset state
                isDeviceReady = false
                mainHandler.post {
                    result.error("DISCONNECT_ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun processSale(call: MethodCall, result: Result) {
        Log.i(TAG, "processSale called")
        
        if (!vtp.isInitialized) {
            Log.e(TAG, "processSale: SDK not initialized")
            result.error("NOT_INITIALIZED", "SDK is not initialized", null)
            return
        }
        
        // Run on background thread to allow for delay
        Thread {
            try {
                // Cancel any ongoing transaction first and wait for device to reset
                try {
                    Log.d(TAG, "Cancelling any previous flow...")
                    vtp.cancelCurrentFlow()
                    Log.d(TAG, "Cancelled previous flow, waiting for device reset...")
                    // Give device time to fully reset before starting new transaction
                    Thread.sleep(1500)
                } catch (e: Exception) {
                    Log.d(TAG, "No flow to cancel or cancel error: ${e.message}")
                }
                
                val requestMap = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                val saleRequest = buildSaleRequest(requestMap)
                Log.i(TAG, "Sale request built: amount=${saleRequest.transactionAmount}")
                
                mainHandler.post {
                    setupStatusListener()
                }

                // DeviceInteractionListener - 处理 SDK 交互提示（如 Credit/Debit 选择）
                val interactionListener = object : DeviceInteractionListener {
                    // 使用反射调用回调方法 - 根据值类型查找匹配的方法
                    private fun invokeCallbackMethod(listener: Any?, value: Any) {
                        if (listener == null) return
                        try {
                            val valueClass = when (value) {
                                is String -> String::class.java
                                is Boolean -> java.lang.Boolean.TYPE  // primitive boolean
                                is Int -> java.lang.Integer.TYPE
                                else -> value.javaClass
                            }
                            
                            // 首先查找参数类型匹配的方法
                            val methods = listener.javaClass.declaredMethods
                            for (method in methods) {
                                if (method.parameterTypes.size == 1 && 
                                    method.parameterTypes[0].isAssignableFrom(valueClass)) {
                                    method.isAccessible = true
                                    method.invoke(listener, value)
                                    Log.i(TAG, "Callback invoked: ${method.name}($value)")
                                    return
                                }
                            }
                            
                            // 如果没找到匹配的类型，尝试接口方法
                            for (iface in listener.javaClass.interfaces) {
                                for (method in iface.methods) {
                                    if (method.parameterTypes.size == 1 &&
                                        method.parameterTypes[0].isAssignableFrom(valueClass)) {
                                        method.invoke(listener, value)
                                        Log.i(TAG, "Callback invoked via interface: ${method.name}($value)")
                                        return
                                    }
                                }
                            }
                            
                            // 最后尝试所有单参数方法
                            Log.w(TAG, "No matching method found for type $valueClass, trying all single-param methods")
                            for (method in methods) {
                                if (method.parameterTypes.size == 1) {
                                    try {
                                        method.isAccessible = true
                                        method.invoke(listener, value)
                                        Log.i(TAG, "Callback invoked (fallback): ${method.name}($value)")
                                        return
                                    } catch (e: Exception) {
                                        Log.d(TAG, "Method ${method.name} failed: ${e.message}")
                                    }
                                }
                            }
                            
                            Log.e(TAG, "No suitable callback method found")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to invoke callback: ${e.message}")
                        }
                    }

                    // 当 SDK 需要用户在 Credit 和 Debit 之间选择时调用
                    override fun onChoiceSelections(choices: Array<String>?, selectionType: SelectionType?, listener: DeviceInteractionListener.SelectChoiceListener?) {
                        Log.i(TAG, "SDK Request Choice: ${choices?.contentToString()}, type: $selectionType")
                        if (choices != null && choices.isNotEmpty() && listener != null) {
                            Log.i(TAG, "Auto-selecting first option (index 0): ${choices[0]}")
                            // selectChoice 方法需要的是选项索引 (int)，不是字符串
                            invokeCallbackMethod(listener, 0)  // 选择第一个选项 (Credit)
                        }
                    }

                    // 当 SDK 需要确认金额时调用
                    override fun onAmountConfirmation(
                        amountType: AmountConfirmationType?,
                        amount: java.math.BigDecimal?,
                        listener: DeviceInteractionListener.ConfirmAmountListener?
                    ) {
                        Log.i(TAG, "SDK Request Amount Confirmation: $amount, type: $amountType")
                        invokeCallbackMethod(listener, true)
                    }

                    // 当 SDK 需要数字输入时调用 (例如小费金额)
                    override fun onNumericInput(inputType: NumericInputType?, listener: DeviceInteractionListener.NumericInputListener?) {
                        Log.i(TAG, "SDK Request Numeric Input: type=$inputType")
                        invokeCallbackMethod(listener, "0")
                    }

                    // 当 SDK 需要选择应用 (多应用卡片) 时调用
                    override fun onSelectApplication(applications: Array<String>?, listener: DeviceInteractionListener.SelectChoiceListener?) {
                        Log.i(TAG, "SDK Request Select Application: ${applications?.contentToString()}")
                        if (applications != null && applications.isNotEmpty() && listener != null) {
                            Log.i(TAG, "Auto-selecting first application (index 0): ${applications[0]}")
                            // selectChoice 方法需要的是选项索引 (int)，不是字符串
                            invokeCallbackMethod(listener, 0)  // 选择第一个应用
                        }
                    }

                    override fun onDisplayText(text: String?) {
                        Log.i(TAG, "SDK Display Text: $text")
                    }

                    override fun onRemoveCard() {
                        Log.i(TAG, "SDK: Please remove card")
                    }

                    override fun onCardRemoved() {
                        Log.i(TAG, "SDK: Card removed")
                    }
                }
                
                Log.i(TAG, "Calling vtp.processSaleRequest...")
                vtp.processSaleRequest(saleRequest, object : SaleRequestListener {
                    override fun onSaleRequestCompleted(response: SaleResponse?) {
                        Log.i(TAG, "onSaleRequestCompleted: response=${response}")
                        Log.i(TAG, "Transaction status: ${response?.transactionStatus}")
                        mainHandler.post {
                            result.success(buildSaleResponseMap(response))
                        }
                    }
                    
                    override fun onSaleRequestError(exception: Exception?) {
                        Log.e(TAG, "onSaleRequestError: ${exception?.message}", exception)
                        mainHandler.post {
                            result.success(mapOf(
                                "transactionStatus" to "error",
                                "errorMessage" to (exception?.message ?: "Unknown error")
                            ))
                        }
                    }
                }, interactionListener)
                Log.i(TAG, "processSaleRequest called, waiting for callback...")
            } catch (e: Exception) {
                Log.e(TAG, "processSale exception: ${e.message}", e)
                mainHandler.post {
                    result.error("SALE_ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun processRefund(call: MethodCall, result: Result) {
        if (!vtp.isInitialized) {
            result.error("NOT_INITIALIZED", "SDK is not initialized", null)
            return
        }
        
        try {
            val requestMap = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val refundRequest = buildRefundRequest(requestMap)
            
            setupStatusListener()
            
            vtp.processRefundRequest(refundRequest, object : RefundRequestListener {
                override fun onRefundRequestCompleted(response: RefundResponse?) {
                    mainHandler.post {
                        result.success(buildRefundResponseMap(response))
                    }
                }
                
                override fun onRefundRequestError(exception: Exception?) {
                    mainHandler.post {
                        result.success(mapOf(
                            "transactionStatus" to "error",
                            "errorMessage" to (exception?.message ?: "Unknown error")
                        ))
                    }
                }
            }, null)
        } catch (e: Exception) {
            result.error("REFUND_ERROR", e.message, null)
        }
    }

    // Linked refund - uses original transaction ID instead of card swipe
    private fun processLinkedRefund(call: MethodCall, result: Result) {
        Log.i(TAG, "processLinkedRefund called")
        
        if (!vtp.isInitialized) {
            Log.e(TAG, "processLinkedRefund: SDK not initialized")
            result.error("NOT_INITIALIZED", "SDK is not initialized", null)
            return
        }
        
        try {
            val requestMap = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val transactionId = requestMap["transactionId"] as? String
            val amount = (requestMap["transactionAmount"] as? Number)?.toDouble() ?: 0.0
            
            if (transactionId.isNullOrEmpty()) {
                result.error("INVALID_REQUEST", "transactionId is required for linked refund", null)
                return
            }
            
            Log.i(TAG, "Linked refund: transactionId=$transactionId, amount=$amount")
            
            // Build refund request with original transaction ID
            val refundRequest = RefundRequest()
            refundRequest.transactionAmount = java.math.BigDecimal(amount)
            refundRequest.referenceNumber = requestMap["referenceNumber"] as? String 
                ?: System.currentTimeMillis().toString()
            refundRequest.laneNumber = ((requestMap["laneNumber"] as? Number)?.toInt() ?: 1).toString()
            
            // Try to set the original transaction ID using reflection
            try {
                val methods = refundRequest.javaClass.methods
                for (method in methods) {
                    if (method.name.contains("OriginalTransaction", ignoreCase = true) ||
                        method.name.contains("OriginalReference", ignoreCase = true)) {
                        Log.d(TAG, "Found method: ${method.name}")
                        if (method.parameterTypes.size == 1 && method.parameterTypes[0] == String::class.java) {
                            method.invoke(refundRequest, transactionId)
                            Log.i(TAG, "Set original transaction ID via ${method.name}")
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not set originalTransactionId: ${e.message}")
            }
            
            setupStatusListener()
            
            Log.i(TAG, "Calling vtp.processRefundRequest with linked transaction...")
            vtp.processRefundRequest(refundRequest, object : RefundRequestListener {
                override fun onRefundRequestCompleted(response: RefundResponse?) {
                    Log.i(TAG, "onRefundRequestCompleted: response=$response")
                    mainHandler.post {
                        result.success(buildRefundResponseMap(response))
                    }
                }
                
                override fun onRefundRequestError(exception: Exception?) {
                    Log.e(TAG, "onRefundRequestError: ${exception?.message}", exception)
                    mainHandler.post {
                        result.success(mapOf(
                            "transactionStatus" to "error",
                            "errorMessage" to (exception?.message ?: "Unknown error")
                        ))
                    }
                }
            }, null)
        } catch (e: Exception) {
            Log.e(TAG, "processLinkedRefund exception: ${e.message}", e)
            result.error("LINKED_REFUND_ERROR", e.message, null)
        }
    }

    private fun processVoid(call: MethodCall, result: Result) {
        if (!vtp.isInitialized) {
            result.error("NOT_INITIALIZED", "SDK is not initialized", null)
            return
        }
        
        try {
            val requestMap = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val voidRequest = buildVoidRequest(requestMap)
            
            vtp.processVoidRequest(voidRequest, object : VoidRequestListener {
                override fun onVoidRequestCompleted(response: VoidResponse?) {
                    mainHandler.post {
                        result.success(buildVoidResponseMap(response))
                    }
                }
                
                override fun onVoidRequestError(exception: Exception?) {
                    mainHandler.post {
                        result.success(mapOf(
                            "transactionStatus" to "error",
                            "errorMessage" to (exception?.message ?: "Unknown error")
                        ))
                    }
                }
            })
        } catch (e: Exception) {
            result.error("VOID_ERROR", e.message, null)
        }
    }

    private fun processAuthorization(call: MethodCall, result: Result) {
        if (!vtp.isInitialized) {
            result.error("NOT_INITIALIZED", "SDK is not initialized", null)
            return
        }
        
        try {
            val requestMap = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val authRequest = buildAuthorizationRequest(requestMap)
            
            setupStatusListener()
            
            vtp.processAuthorizationRequest(authRequest, object : AuthorizationRequestListener {
                override fun onAuthorizationRequestCompleted(response: AuthorizationResponse?) {
                    mainHandler.post {
                        result.success(buildAuthorizationResponseMap(response))
                    }
                }
                
                override fun onAuthorizationRequestError(exception: Exception?) {
                    mainHandler.post {
                        result.success(mapOf(
                            "transactionStatus" to "error",
                            "errorMessage" to (exception?.message ?: "Unknown error")
                        ))
                    }
                }
            }, null)
        } catch (e: Exception) {
            result.error("AUTH_ERROR", e.message, null)
        }
    }

    private fun cancelTransaction(result: Result) {
        try {
            vtp.cancelCurrentFlow()
            result.success(null)
        } catch (e: Exception) {
            result.error("CANCEL_ERROR", e.message, null)
        }
    }

    private fun getDeviceInfo(result: Result) {
        try {
            val device = vtp.device
            if (device != null) {
                result.success(mapOf(
                    "description" to device.toString(),
                    "model" to (device.javaClass.simpleName ?: "Unknown"),
                    "serialNumber" to "",
                    "firmwareVersion" to ""
                ))
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            result.error("DEVICE_INFO_ERROR", e.message, null)
        }
    }

    private fun setupStatusListener() {
        vtp.setStatusListener { status: VtpStatus ->
            mainHandler.post {
                statusEventSink?.success(status.name)
            }
        }
    }

    // Configuration builders
    private fun buildConfiguration(configMap: Map<*, *>?): Configuration {
        val config = Configuration()
        
        if (configMap != null) {
            // Application Configuration
            val appConfigMap = configMap["applicationConfiguration"] as? Map<*, *>
            val appConfig = ApplicationConfiguration()
            appConfig.idlePrompt = appConfigMap?.get("idlePrompt") as? String ?: "triPOS Flutter"
            val modeStr = appConfigMap?.get("applicationMode") as? String
            appConfig.applicationMode = if (modeStr == "production") {
                ApplicationMode.Production
            } else {
                ApplicationMode.TestCertification
            }
            config.applicationConfiguration = appConfig
            
            // Host Configuration
            val hostConfigMap = configMap["hostConfiguration"] as? Map<*, *>
            val hostConfig = HostConfiguration()
            hostConfig.acceptorId = hostConfigMap?.get("acceptorId") as? String ?: ""
            hostConfig.accountId = hostConfigMap?.get("accountId") as? String ?: ""
            hostConfig.accountToken = hostConfigMap?.get("accountToken") as? String ?: ""
            hostConfig.applicationId = hostConfigMap?.get("applicationId") as? String ?: "8414"
            hostConfig.applicationName = hostConfigMap?.get("applicationName") as? String ?: "triPOS Flutter"
            hostConfig.applicationVersion = hostConfigMap?.get("applicationVersion") as? String ?: "1.0.0"
            hostConfig.setPaymentProcessor(PaymentProcessor.Worldpay)
            hostConfig.storeCardId = hostConfigMap?.get("storeCardId") as? String
            hostConfig.storeCardPassword = hostConfigMap?.get("storeCardPassword") as? String
            hostConfig.vaultId = hostConfigMap?.get("vaultId") as? String
            config.hostConfiguration = hostConfig
            
            // Device Configuration
            val deviceConfigMap = configMap["deviceConfiguration"] as? Map<*, *>
            Log.d(TAG, "deviceConfigMap: $deviceConfigMap")
            val deviceConfig = DeviceConfiguration()
            val deviceTypeStr = deviceConfigMap?.get("deviceType") as? String
            Log.d(TAG, "deviceTypeStr from config: '$deviceTypeStr'")
            
            // Log available DeviceType values for debugging
            val availableTypes = DeviceType.values().toList()
            Log.d(TAG, "Available DeviceType values: ${availableTypes.map { it.name }}")
            
            // Map the device type - use IngenicoRuaBluetooth for Moby 5500 Bluetooth
            val resolvedType = when {
                deviceTypeStr?.contains("Moby5500", ignoreCase = true) == true -> {
                    Log.d(TAG, "Mapping Moby5500 -> IngenicoRuaBluetooth")
                    DeviceType.IngenicoRuaBluetooth
                }
                deviceTypeStr?.contains("Moby8500", ignoreCase = true) == true -> {
                    Log.d(TAG, "Mapping Moby8500 -> IngenicoRuaBluetooth")
                    DeviceType.IngenicoRuaBluetooth
                }
                else -> parseDeviceType(deviceTypeStr)
            }
            
            deviceConfig.setDeviceType(resolvedType)
            Log.d(TAG, "Final deviceConfig.deviceType: ${deviceConfig.deviceType.name}")
            
            deviceConfig.terminalId = deviceConfigMap?.get("terminalId") as? String ?: "1234"
            deviceConfig.terminalType = TerminalType.Mobile
            deviceConfig.identifier = deviceConfigMap?.get("identifier") as? String
            deviceConfig.isContactlessAllowed = deviceConfigMap?.get("contactlessAllowed") as? Boolean ?: true
            deviceConfig.isKeyedEntryAllowed = deviceConfigMap?.get("keyedEntryAllowed") as? Boolean ?: true
            deviceConfig.isHeartbeatEnabled = deviceConfigMap?.get("heartbeatEnabled") as? Boolean ?: true
            deviceConfig.isBarcodeReaderEnabled = deviceConfigMap?.get("barcodeReaderEnabled") as? Boolean ?: true
            val sleepTimeout = deviceConfigMap?.get("sleepTimeoutSeconds") as? Number ?: 300
            deviceConfig.sleepTimeoutSeconds = BigDecimal(sleepTimeout.toInt())
            config.deviceConfiguration = deviceConfig
            
            // Transaction Configuration
            // NOTE: Tips and Cashback disabled to avoid DeviceInteractionListener null errors
            // These features require UI callbacks that are not yet implemented
            val txnConfigMap = configMap["transactionConfiguration"] as? Map<*, *>
            val txnConfig = TransactionConfiguration()
            txnConfig.isEmvAllowed = txnConfigMap?.get("emvAllowed") as? Boolean ?: true
            txnConfig.isTipAllowed = false  // Disabled - requires DeviceInteractionListener
            txnConfig.isTipEntryAllowed = false  // Disabled - requires DeviceInteractionListener
            txnConfig.isDebitAllowed = txnConfigMap?.get("debitAllowed") as? Boolean ?: true
            txnConfig.isCashbackAllowed = false  // Disabled - requires DeviceInteractionListener
            txnConfig.isCashbackEntryAllowed = false  // Disabled - requires DeviceInteractionListener
            txnConfig.isGiftCardAllowed = txnConfigMap?.get("giftCardAllowed") as? Boolean ?: true
            txnConfig.isQuickChipAllowed = txnConfigMap?.get("quickChipAllowed") as? Boolean ?: true
            txnConfig.isAmountConfirmationEnabled = false  // Disabled - requires DeviceInteractionListener
            txnConfig.setDuplicateTransactionsAllowed(txnConfigMap?.get("duplicateTransactionsAllowed") as? Boolean ?: true)
            txnConfig.isPartialApprovalAllowed = txnConfigMap?.get("partialApprovalAllowed") as? Boolean ?: false
            txnConfig.currencyCode = CurrencyCode.USD
            txnConfig.addressVerificationCondition = AddressVerificationCondition.Keyed
            config.transactionConfiguration = txnConfig
            
            // Store and Forward Configuration
            val safConfigMap = configMap["storeAndForwardConfiguration"] as? Map<*, *>
            val safConfig = StoreAndForwardConfiguration()
            safConfig.numberOfDaysToRetainProcessedTransactions = 
                (safConfigMap?.get("numberOfDaysToRetainProcessedTransactions") as? Number)?.toInt() ?: 7
            safConfig.setShouldTransactionsBeAutomaticallyForwarded(
                safConfigMap?.get("shouldTransactionsBeAutomaticallyForwarded") as? Boolean ?: true)
            safConfig.isStoringTransactionsAllowed = 
                safConfigMap?.get("storingTransactionsAllowed") as? Boolean ?: true
            safConfig.transactionAmountLimit = 
                (safConfigMap?.get("transactionAmountLimit") as? Number)?.toInt() ?: 100
            safConfig.unprocessedTotalAmountLimit = 
                (safConfigMap?.get("unprocessedTotalAmountLimit") as? Number)?.toInt() ?: 1000
            config.storeAndForwardConfiguration = safConfig
        }
        
        return config
    }

    private fun parseDeviceType(deviceTypeStr: String?): DeviceType {
        Log.d(TAG, "parseDeviceType called with: '$deviceTypeStr'")
        Log.d(TAG, "Available DeviceType values: ${DeviceType.values().map { it.name }}")
        
        if (deviceTypeStr.isNullOrEmpty() || deviceTypeStr == "none") {
            Log.w(TAG, "Device type is null/empty/none, returning Null")
            return DeviceType.Null
        }
        
        // Explicit mapping for known device types
        val normalizedInput = deviceTypeStr.lowercase().replace("_", "").replace("-", "")
        
        val result = DeviceType.values().find { enumValue ->
            val normalizedEnum = enumValue.name.lowercase().replace("_", "")
            normalizedEnum == normalizedInput ||
            // Handle common naming variations
            (normalizedInput.contains("moby5500") && normalizedEnum.contains("moby5500")) ||
            (normalizedInput.contains("moby8500") && normalizedEnum.contains("moby8500")) ||
            (normalizedInput.contains("chipper") && normalizedEnum.contains("chipper")) ||
            (normalizedInput.contains("lane3000") && normalizedEnum.contains("lane3000")) ||
            (normalizedInput.contains("lane5000") && normalizedEnum.contains("lane5000")) ||
            (normalizedInput.contains("lane7000") && normalizedEnum.contains("lane7000")) ||
            (normalizedInput.contains("lane8000") && normalizedEnum.contains("lane8000"))
        } ?: DeviceType.Null
        
        Log.d(TAG, "Resolved DeviceType: ${result.name}")
        return result
    }
    
    /**
     * Helper function to detect device type/model from Bluetooth identifier.
     * Useful as fallback when SDK returns NULL for device info.
     */
    private fun _detectDeviceTypeFromIdentifier(identifier: String?): String? {
        if (identifier.isNullOrEmpty()) return null
        
        val upperIdentifier = identifier.uppercase()
        return when {
            upperIdentifier.contains("MOB55") || upperIdentifier.contains("MOBY55") -> "Moby 5500"
            upperIdentifier.contains("MOB85") || upperIdentifier.contains("MOBY85") -> "Moby 8500"
            upperIdentifier.contains("LANE3") -> "Lane 3000"
            upperIdentifier.contains("LANE5") -> "Lane 5000"
            upperIdentifier.contains("LANE7") -> "Lane 7000"
            upperIdentifier.contains("LANE8") -> "Lane 8000"
            upperIdentifier.contains("CHIPPER") -> "BBPos Chipper"
            else -> identifier  // Use identifier as model name
        }
    }

    // Request builders
    private fun buildSaleRequest(requestMap: Map<*, *>): SaleRequest {
        val request = SaleRequest()
        request.transactionAmount = BigDecimal((requestMap["transactionAmount"] as? Number)?.toDouble() ?: 0.0)
        request.laneNumber = requestMap["laneNumber"] as? String ?: "1"
        request.referenceNumber = requestMap["referenceNumber"] as? String ?: ""
        request.clerkNumber = requestMap["clerkNumber"] as? String
        request.shiftID = requestMap["shiftId"] as? String
        request.ticketNumber = requestMap["ticketNumber"] as? String
        request.cardholderPresentCode = CardHolderPresentCode.Present
        
        // Use reflection for optional setters that may not exist
        try {
            request.javaClass.getMethod("setKeyedOnly", Boolean::class.javaPrimitiveType)
                .invoke(request, requestMap["keyedOnly"] as? Boolean ?: false)
        } catch (e: Exception) { /* Method not available */ }
        
        (requestMap["convenienceFeeAmount"] as? Number)?.let {
            request.convenienceFeeAmount = BigDecimal(it.toDouble())
        }
        (requestMap["salesTaxAmount"] as? Number)?.let {
            request.salesTaxAmount = BigDecimal(it.toDouble())
        }
        (requestMap["tipAmount"] as? Number)?.let {
            request.tipAmount = BigDecimal(it.toDouble())
        }
        (requestMap["surchargeFeeAmount"] as? Number)?.let {
            request.surchargeFeeAmount = BigDecimal(it.toDouble())
        }
        
        return request
    }

    private fun buildRefundRequest(requestMap: Map<*, *>): RefundRequest {
        val request = RefundRequest()
        request.transactionAmount = BigDecimal((requestMap["transactionAmount"] as? Number)?.toDouble() ?: 0.0)
        request.laneNumber = requestMap["laneNumber"] as? String ?: "1"
        request.referenceNumber = requestMap["referenceNumber"] as? String ?: ""
        request.clerkNumber = requestMap["clerkNumber"] as? String
        request.shiftID = requestMap["shiftId"] as? String
        request.ticketNumber = requestMap["ticketNumber"] as? String
        request.cardholderPresentCode = CardHolderPresentCode.Present
        
        (requestMap["convenienceFeeAmount"] as? Number)?.let {
            request.convenienceFeeAmount = BigDecimal(it.toDouble())
        }
        (requestMap["salesTaxAmount"] as? Number)?.let {
            request.salesTaxAmount = BigDecimal(it.toDouble())
        }
        
        return request
    }

    private fun buildVoidRequest(requestMap: Map<*, *>): VoidRequest {
        val request = VoidRequest()
        request.transactionID = requestMap["transactionId"] as? String ?: ""
        request.transactionAmount = BigDecimal((requestMap["transactionAmount"] as? Number)?.toDouble() ?: 0.0)
        request.laneNumber = requestMap["laneNumber"] as? String ?: "1"
        request.referenceNumber = requestMap["referenceNumber"] as? String ?: ""
        request.clerkNumber = requestMap["clerkNumber"] as? String
        request.shiftID = requestMap["shiftId"] as? String
        request.ticketNumber = requestMap["ticketNumber"] as? String
        request.cardholderPresentCode = CardHolderPresentCode.Present
        request.marketCode = MarketCode.Retail
        
        return request
    }

    private fun buildAuthorizationRequest(requestMap: Map<*, *>): AuthorizationRequest {
        val request = AuthorizationRequest()
        request.transactionAmount = BigDecimal((requestMap["transactionAmount"] as? Number)?.toDouble() ?: 0.0)
        request.laneNumber = requestMap["laneNumber"] as? String ?: "1"
        request.referenceNumber = requestMap["referenceNumber"] as? String ?: ""
        request.clerkNumber = requestMap["clerkNumber"] as? String
        request.shiftID = requestMap["shiftId"] as? String
        request.ticketNumber = requestMap["ticketNumber"] as? String
        request.cardholderPresentCode = CardHolderPresentCode.Present
        
        // Use reflection for optional setters
        try {
            request.javaClass.getMethod("setKeyedOnly", Boolean::class.javaPrimitiveType)
                .invoke(request, requestMap["keyedOnly"] as? Boolean ?: false)
        } catch (e: Exception) { /* Method not available */ }
        
        (requestMap["convenienceFeeAmount"] as? Number)?.let {
            request.convenienceFeeAmount = BigDecimal(it.toDouble())
        }
        (requestMap["salesTaxAmount"] as? Number)?.let {
            request.salesTaxAmount = BigDecimal(it.toDouble())
        }
        
        return request
    }

    // Response builders - using reflection for safe access
    private fun buildSaleResponseMap(response: SaleResponse?): Map<String, Any?> {
        if (response == null) {
            Log.e(TAG, "buildSaleResponseMap: response is NULL")
            return mapOf("transactionStatus" to "error", "errorMessage" to "Null response")
        }
        
        // Enhanced logging to debug Express connection issues
        Log.i(TAG, "=== SALE RESPONSE DETAILS ===")
        Log.i(TAG, "TransactionStatus: ${response.transactionStatus?.name}")
        Log.i(TAG, "ApprovedAmount: ${response.approvedAmount}")
        Log.i(TAG, "TransactionAmount: ${getPropertySafe(response, "transactionAmount")}")
        
        // Log host response details (Express response)
        val host = response.host
        if (host != null) {
            Log.i(TAG, "=== HOST (EXPRESS) RESPONSE ===")
            Log.i(TAG, "ExpressResponseCode: ${getPropertySafe(host, "expressResponseCode")}")
            Log.i(TAG, "ExpressResponseMessage: ${getPropertySafe(host, "expressResponseMessage")}")
            Log.i(TAG, "ExpressTransactionStatus: ${getPropertySafe(host, "transactionStatus")}")
            Log.i(TAG, "TransactionID: ${getPropertySafe(host, "transactionId")}")
            Log.i(TAG, "ApprovalNumber: ${getPropertySafe(host, "approvalNumber")}")
            Log.i(TAG, "GatewayMessage: ${getPropertySafe(host, "gatewayMessage")}")
            Log.i(TAG, "HostResponseCode: ${getPropertySafe(host, "hostResponseCode")}")
            Log.i(TAG, "HostResponseMessage: ${getPropertySafe(host, "hostResponseMessage")}")
            Log.i(TAG, "ProcessorResponseCode: ${getPropertySafe(host, "processorResponseCode")}")
            Log.i(TAG, "ProcessorResponseMessage: ${getPropertySafe(host, "processorResponseMessage")}")
        } else {
            Log.w(TAG, "Host response is NULL - Express may not have been reached")
        }
        
        // Check for any errors
        val errorMessage = getPropertySafe(response, "errorMessage")
        val errors = getPropertySafe(response, "errors")
        if (errorMessage != null) Log.e(TAG, "ErrorMessage: $errorMessage")
        if (errors != null) Log.e(TAG, "Errors: $errors")
        
        // Check if this is a stored (offline) transaction
        val isStoredTransaction = response.transactionStatus?.name?.contains("Merchant", ignoreCase = true) == true
        
        return mapOf(
            "transactionStatus" to response.transactionStatus?.name?.lowercase(),
            "approvedAmount" to response.approvedAmount?.toDouble(),
            "cashbackAmount" to response.cashbackAmount?.toDouble(),
            "tipAmount" to response.tipAmount?.toDouble(),
            "tpId" to getPropertySafe(response, "tpId"),
            "referenceNumber" to getPropertySafe(response, "referenceNumber", "ReferenceNumber"),
            "storedTransactionId" to getPropertySafe(response, "storedTransactionId", "StoredTransactionId", "safTransactionId"),
            "isStoredTransaction" to isStoredTransaction,
            "host" to buildHostResponseMap(response.host),
            "card" to buildCardInfoMap(response),
            "emv" to buildEmvInfoMap(response),
            "signatureData" to getPropertySafe(response, "signatureData"),
            "errorMessage" to errorMessage
        )
    }

    private fun buildRefundResponseMap(response: RefundResponse?): Map<String, Any?> {
        if (response == null) {
            return mapOf("transactionStatus" to "error", "errorMessage" to "Null response")
        }
        
        return mapOf(
            "transactionStatus" to response.transactionStatus?.name?.lowercase(),
            "approvedAmount" to response.approvedAmount?.toDouble(),
            "tpId" to getPropertySafe(response, "tpId"),
            "host" to buildHostResponseMap(response.host),
            "card" to buildCardInfoMap(response),
            "emv" to buildEmvInfoMap(response)
        )
    }

    private fun buildVoidResponseMap(response: VoidResponse?): Map<String, Any?> {
        if (response == null) {
            return mapOf("transactionStatus" to "error", "errorMessage" to "Null response")
        }
        
        return mapOf(
            "transactionStatus" to response.transactionStatus?.name?.lowercase(),
            "approvedAmount" to response.approvedAmount?.toDouble(),
            "tpId" to getPropertySafe(response, "tpId"),
            "host" to buildHostResponseMap(response.host)
        )
    }

    private fun buildAuthorizationResponseMap(response: AuthorizationResponse?): Map<String, Any?> {
        if (response == null) {
            return mapOf("transactionStatus" to "error", "errorMessage" to "Null response")
        }
        
        return mapOf(
            "transactionStatus" to response.transactionStatus?.name?.lowercase(),
            "approvedAmount" to response.approvedAmount?.toDouble(),
            "tpId" to getPropertySafe(response, "tpId"),
            "host" to buildHostResponseMap(response.host),
            "card" to buildCardInfoMap(response),
            "emv" to buildEmvInfoMap(response)
        )
    }

    private fun getPropertySafe(obj: Any, propertyName: String): Any? {
        return try {
            val getterName = "get${propertyName.replaceFirstChar { it.uppercase() }}"
            obj.javaClass.getMethod(getterName).invoke(obj)
        } catch (e: Exception) {
            try {
                // Try direct field access
                val field = obj.javaClass.getDeclaredField(propertyName)
                field.isAccessible = true
                field.get(obj)
            } catch (e2: Exception) {
                null
            }
        }
    }

    // Vararg version to try multiple property names
    private fun getPropertySafe(obj: Any, vararg propertyNames: String): Any? {
        for (name in propertyNames) {
            val result = getPropertySafe(obj, name)
            if (result != null) return result
        }
        return null
    }

    private fun buildHostResponseMap(host: Any?): Map<String, Any?>? {
        if (host == null) return null
        
        return try {
            mapOf(
                "transactionId" to getFieldSafe(host, "TransactionID", "transactionId", "transactionID"),
                "authCode" to getFieldSafe(host, "AuthCode", "AuthorizationCode", "authorizationCode"),
                "responseCode" to getFieldSafe(host, "ResponseCode", "responseCode"),
                "responseMessage" to getFieldSafe(host, "ResponseMessage", "responseMessage"),
                "approvalNumber" to getFieldSafe(host, "ApprovalNumber", "approvalNumber")
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error building host response map: ${e.message}")
            null
        }
    }

    private fun buildCardInfoMap(response: Any?): Map<String, Any?>? {
        if (response == null) return null
        
        return try {
            mapOf(
                "maskedCardNumber" to getFieldSafe(response, "AccountNumber", "MaskedAccountNumber", "maskedCardNumber", "CardNumber"),
                "cardBrand" to getFieldSafe(response, "CardLogo", "cardLogo", "CardBrand"),
                "entryMode" to getFieldSafe(response, "EntryMode", "entryMode")?.toString()?.lowercase()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error building card info map: ${e.message}")
            null
        }
    }

    // Helper to try multiple possible field/method names
    private fun getFieldSafe(obj: Any, vararg fieldNames: String): Any? {
        val objClass = obj.javaClass
        
        for (fieldName in fieldNames) {
            // Try getter method (getXxx)
            try {
                val getterName = "get$fieldName"
                val method = objClass.getMethod(getterName)
                val result = method.invoke(obj)
                if (result != null) return result
            } catch (e: Exception) { /* Try next */ }
            
            // Try getter with lowercase first char
            try {
                val getterName = "get${fieldName.replaceFirstChar { it.uppercase() }}"
                val method = objClass.getMethod(getterName)
                val result = method.invoke(obj)
                if (result != null) return result
            } catch (e: Exception) { /* Try next */ }
            
            // Try direct field access
            try {
                val field = objClass.getDeclaredField(fieldName)
                field.isAccessible = true
                val result = field.get(obj)
                if (result != null) return result
            } catch (e: Exception) { /* Try next */ }
            
            // Try lowercase field name
            try {
                val field = objClass.getDeclaredField(fieldName.lowercase())
                field.isAccessible = true
                val result = field.get(obj)
                if (result != null) return result
            } catch (e: Exception) { /* Try next */ }
        }
        
        return null
    }

    private fun buildEmvInfoMap(response: Any?): Map<String, Any?>? {
        if (response == null) return null
        
        return try {
            val responseClass = response.javaClass
            val emv = responseClass.getMethod("getEmv").invoke(response)
            if (emv != null) {
                val emvClass = emv.javaClass
                mapOf(
                    "applicationId" to (emvClass.getMethod("getAid").invoke(emv) as? String),
                    "applicationLabel" to (emvClass.getMethod("getApplicationLabel").invoke(emv) as? String)
                )
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error building EMV info map: ${e.message}")
            null
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        statusEventChannel.setStreamHandler(null)
        deviceEventChannel.setStreamHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ==================== Store-and-Forward Methods ====================

    private fun getStoredTransactions(result: Result) {
        try {
            val records = vtp.allStoredTransactions ?: emptyList()
            val mapped = records.map { mapStoredTransactionRecord(it) }
            result.success(mapped)
        } catch (e: Exception) {
            Log.e(TAG, "getStoredTransactions error: ${e.message}")
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    private fun getStoredTransactionByTpId(call: MethodCall, result: Result) {
        val tpId = call.argument<String>("tpId")
        if (tpId == null) {
            result.success(null)
            return
        }

        try {
            val record = vtp.getStoredTransactionByTpId(tpId)
            if (record != null) {
                result.success(mapStoredTransactionRecord(record))
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "getStoredTransactionByTpId error: ${e.message}")
            result.success(null)
        }
    }

    private fun getStoredTransactionsByState(call: MethodCall, result: Result) {
        val stateName = call.argument<String>("state")
        if (stateName == null) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }

        try {
            val state = mapStringToStoredTransactionState(stateName)
            val records = vtp.getStoredTransactionsWithState(state) ?: emptyList()
            val mapped = records.map { mapStoredTransactionRecord(it) }
            result.success(mapped)
        } catch (e: Exception) {
            Log.e(TAG, "getStoredTransactionsByState error: ${e.message}")
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    private fun forwardTransaction(call: MethodCall, result: Result) {
        val tpId = call.argument<String>("tpId")
        if (tpId == null) {
            result.success(mapOf("isApproved" to false, "errorMessage" to "Missing tpId"))
            return
        }

        try {
            val request = com.vantiv.triposmobilesdk.requests.ManuallyForwardRequest()
            request.tpId = tpId

            // Note: ManuallyForwardRequest may not have these properties in all SDK versions
            // Only set tpId which is the required field

            vtp.processManuallyForwardRequest(request, object : com.vantiv.triposmobilesdk.ManuallyForwardRequestListener {
                override fun onManuallyForwardRequestCompleted(response: com.vantiv.triposmobilesdk.responses.ManuallyForwardResponse?) {
                    val map = mapOf(
                        "isApproved" to (response?.transactionStatus?.name?.lowercase() == "approved"),
                        "transactionId" to tpId,  // Use the request tpId
                        "referenceNumber" to null,
                        "wasProcessedOnline" to true,  // Assume online if completed successfully
                        "transactionStatus" to response?.transactionStatus?.name?.lowercase()
                    )
                    mainHandler.post { result.success(map) }
                }

                override fun onManuallyForwardRequestError(exception: Exception?) {
                    val map = mapOf(
                        "isApproved" to false,
                        "errorMessage" to (exception?.message ?: "Forward failed")
                    )
                    mainHandler.post { result.success(map) }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "forwardTransaction error: ${e.message}")
            result.success(mapOf("isApproved" to false, "errorMessage" to e.message))
        }
    }

    private fun deleteStoredTransaction(call: MethodCall, result: Result) {
        val tpId = call.argument<String>("tpId")
        if (tpId == null) {
            result.success(false)
            return
        }

        try {
            vtp.deleteStoredTransactionWithStateStored(tpId)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "deleteStoredTransaction error: ${e.message}")
            result.success(false)
        }
    }

    private fun mapStoredTransactionRecord(record: com.vantiv.triposmobilesdk.storeandforward.StoredTransactionRecord): Map<String, Any?> {
        // Use reflection to safely get properties that may not exist in all SDK versions
        fun getProperty(name: String): Any? = try {
            record.javaClass.getMethod("get${name.replaceFirstChar { it.uppercase() }}").invoke(record)
        } catch (e: Exception) { null }
        
        // 基本信息
        val createdOn = getProperty("createdOn")?.toString()
        
        // 卡片信息
        val accountNumber = getProperty("accountNumber")?.toString()
        val cardHolderName = getProperty("cardHolderName")?.toString()
        val cardLogo = getProperty("cardLogo")?.toString()
        val expirationDate = getProperty("expirationDate")?.toString()
        val binValue = getProperty("binValue")?.toString()  // BIN (Bank Identification Number)
        val applicationLabel = getProperty("applicationLabel")?.toString()  // EMV 应用标签
        
        // 输入方式和设备信息
        val entryMode = getProperty("entryMode")?.toString()
        val deviceSerialNumber = getProperty("deviceSerialNumber")?.toString()
        
        // 操作员/终端信息
        val clerkId = getProperty("clerkId")?.toString()
        val terminalId = getProperty("terminalId")?.toString()
        val laneId = getProperty("laneId")?.toString()
        
        // 交易追踪信息
        val invoiceNumber = getProperty("invoiceNumber")?.toString()
        val referenceNumber = getProperty("referenceNumber")?.toString()
        val approvalCode = getProperty("approvalCode")?.toString()
        val transactionId = getProperty("transactionId")?.toString()
        
        // Get last 4 digits from account number
        val lastFourDigits = accountNumber?.takeLast(4)
        
        return mapOf(
            // 基本信息
            "tpId" to record.tpId,
            "state" to record.state?.name?.lowercase(),
            "totalAmount" to record.totalAmount?.toDouble(),
            "createdOn" to createdOn,
            "transactionType" to record.transactionType?.name,
            
            // 卡片信息
            "lastFourDigits" to lastFourDigits,
            "accountNumber" to accountNumber,
            "cardHolderName" to cardHolderName,
            "cardLogo" to cardLogo,
            "expirationDate" to expirationDate,
            "binValue" to binValue,
            "applicationLabel" to applicationLabel,
            
            // 设备信息
            "entryMode" to entryMode,
            "deviceSerialNumber" to deviceSerialNumber,
            
            // 操作员/终端信息
            "clerkId" to clerkId,
            "terminalId" to terminalId,
            "laneId" to laneId,
            
            // 交易追踪
            "invoiceNumber" to invoiceNumber,
            "referenceNumber" to referenceNumber,
            "approvalCode" to approvalCode,
            "transactionId" to transactionId
        )
    }

    private fun mapStringToStoredTransactionState(stateName: String): com.vantiv.triposmobilesdk.storeandforward.StoredTransactionState {
        return when (stateName.lowercase()) {
            "stored" -> com.vantiv.triposmobilesdk.storeandforward.StoredTransactionState.Stored
            "storedpendinggenac2" -> com.vantiv.triposmobilesdk.storeandforward.StoredTransactionState.StoredPendingGenac2
            "processing" -> com.vantiv.triposmobilesdk.storeandforward.StoredTransactionState.Processing
            "processed" -> com.vantiv.triposmobilesdk.storeandforward.StoredTransactionState.Processed
            "deleted" -> com.vantiv.triposmobilesdk.storeandforward.StoredTransactionState.Deleted
            else -> com.vantiv.triposmobilesdk.storeandforward.StoredTransactionState.Stored
        }
    }
}
