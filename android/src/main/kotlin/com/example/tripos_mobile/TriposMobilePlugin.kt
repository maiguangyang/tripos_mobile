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
            "initialize" -> initialize(call, result)
            "isInitialized" -> result.success(vtp.isInitialized)
            "deinitialize" -> deinitialize(result)
            "processSale" -> processSale(call, result)
            "processRefund" -> processRefund(call, result)
            "processLinkedRefund" -> processLinkedRefund(call, result)
            "processVoid" -> processVoid(call, result)
            "processAuthorization" -> processAuthorization(call, result)
            "cancelTransaction" -> cancelTransaction(result)
            "getDeviceInfo" -> getDeviceInfo(result)
            else -> result.notImplemented()
        }
    }

    private fun scanBluetoothDevices(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context is not available", null)
            return
        }
        
        try {
            val configMap = call.arguments as? Map<*, *>
            val config = buildConfiguration(configMap)
            
            Log.i(TAG, "Starting Bluetooth scan...")
            
            vtp.scanBluetoothDevicesWithConfiguration(ctx, config, object : BluetoothScanRequestListener {
                override fun onScanRequestCompleted(devices: ArrayList<String>?) {
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

    private fun initialize(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context is not available", null)
            return
        }
        
        try {
            val configMap = call.arguments as? Map<*, *>
            val config = buildConfiguration(configMap)
            currentConfiguration = config
            
            val connectionListener = object : DeviceConnectionListener {
                override fun onConnected(device: Device?, description: String?, model: String?, serialNumber: String?) {
                    Log.i(TAG, "Device connected: $description, $model, $serialNumber")
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
                    mainHandler.post {
                        deviceEventSink?.success(mapOf("event" to "disconnected"))
                    }
                }
                
                override fun onError(exception: Exception?) {
                    Log.e(TAG, "Device error: ${exception?.message}")
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
                    vtp.initialize(ctx, config, connectionListener, null)
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

    private fun processSale(call: MethodCall, result: Result) {
        Log.i(TAG, "processSale called")
        
        if (!vtp.isInitialized) {
            Log.e(TAG, "processSale: SDK not initialized")
            result.error("NOT_INITIALIZED", "SDK is not initialized", null)
            return
        }
        
        try {
            // Cancel any ongoing transaction first
            try {
                vtp.cancelCurrentFlow()
                Log.d(TAG, "Cancelled any previous flow")
            } catch (e: Exception) {
                Log.d(TAG, "No flow to cancel: ${e.message}")
            }
            
            val requestMap = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val saleRequest = buildSaleRequest(requestMap)
            Log.i(TAG, "Sale request built: amount=${saleRequest.transactionAmount}")
            
            setupStatusListener()
            
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
            }, null)
            Log.i(TAG, "processSaleRequest called, waiting for callback...")
        } catch (e: Exception) {
            Log.e(TAG, "processSale exception: ${e.message}", e)
            result.error("SALE_ERROR", e.message, null)
        }
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
                (safConfigMap?.get("numberOfDaysToRetainProcessedTransactions") as? Number)?.toInt() ?: 1
            safConfig.setShouldTransactionsBeAutomaticallyForwarded(
                safConfigMap?.get("shouldTransactionsBeAutomaticallyForwarded") as? Boolean ?: false)
            safConfig.isStoringTransactionsAllowed = 
                safConfigMap?.get("storingTransactionsAllowed") as? Boolean ?: true
            safConfig.transactionAmountLimit = 
                (safConfigMap?.get("transactionAmountLimit") as? Number)?.toInt() ?: 50
            safConfig.unprocessedTotalAmountLimit = 
                (safConfigMap?.get("unprocessedTotalAmountLimit") as? Number)?.toInt() ?: 100
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
            return mapOf("transactionStatus" to "error", "errorMessage" to "Null response")
        }
        
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
            "signatureData" to getPropertySafe(response, "signatureData")
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
}
