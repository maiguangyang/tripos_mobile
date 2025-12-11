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

import com.vantiv.triposmobilesdk.VTP
import com.vantiv.triposmobilesdk.triPOSMobileSDK
import com.vantiv.triposmobilesdk.Configuration
import com.vantiv.triposmobilesdk.ApplicationConfiguration
import com.vantiv.triposmobilesdk.HostConfiguration
import com.vantiv.triposmobilesdk.DeviceConfiguration
import com.vantiv.triposmobilesdk.TcpIpConfiguration
import com.vantiv.triposmobilesdk.TransactionConfiguration
import com.vantiv.triposmobilesdk.StoreAndForwardConfiguration
import com.vantiv.triposmobilesdk.BluetoothScanRequestListener
import com.vantiv.triposmobilesdk.DeviceConnectionListener
import com.vantiv.triposmobilesdk.DeviceInteractionListener
import com.vantiv.triposmobilesdk.SaleRequestListener
import com.vantiv.triposmobilesdk.enums.ApplicationMode
import com.vantiv.triposmobilesdk.enums.CardHolderPresentCode
import com.vantiv.triposmobilesdk.enums.CurrencyCode
import com.vantiv.triposmobilesdk.enums.DeviceType
import com.vantiv.triposmobilesdk.enums.PaymentProcessor
import com.vantiv.triposmobilesdk.enums.TerminalType
import com.vantiv.triposmobilesdk.requests.SaleRequest
import com.vantiv.triposmobilesdk.responses.SaleResponse

/**
 * A clean, sample-like implementation based on the official sampleapp SaleFragment flow.
 * Uses the same MethodChannel/EventChannel names as the original plugin.
 */
class TriposSamplePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "TriposSamplePlugin"
    }

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    private var vtp: VTP? = null
    private var eventSink: EventChannel.EventSink? = null
    private val uiHandler = Handler(Looper.getMainLooper())

    private var hostConfig: HostConfiguration? = null
    private var appConfig: ApplicationConfiguration? = null
    private var deviceConfig: DeviceConfiguration? = null
    private var txnConfig: TransactionConfiguration? = null
    private var safConfig: StoreAndForwardConfiguration? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "tripos_mobile")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "tripos_mobile/events")
        eventChannel.setStreamHandler(this)
        context = binding.applicationContext
        vtp = triPOSMobileSDK.getSharedVtp()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
            "initialize" -> initSdk(call.arguments as? Map<String, Any>, result)
            "scanDevices" -> scanDevices(result)
            "connectDevice" -> connectDevice(call.arguments as? Map<String, Any>, result)
            "processPayment" -> processPayment(call.arguments as? Map<String, Any>, result)
            "cancelPayment" -> cancelPayment(result)
            "disconnect" -> disconnect(result)
            else -> result.notImplemented()
        }
    }

    private fun initSdk(args: Map<String, Any>?, result: Result) {
        try {
            val acceptorId = args?.get("acceptorId") as? String ?: ""
            val accountId = args?.get("accountId") as? String ?: ""
            val accountToken = args?.get("accountToken") as? String ?: ""
            val isProduction = (args?.get("isProduction") as? Boolean) ?: false

            if (acceptorId.isEmpty() || accountId.isEmpty() || accountToken.isEmpty()) {
                result.error("INVALID_CONFIG", "Missing credentials", null)
                return
            }

            hostConfig = HostConfiguration().apply {
                setAcceptorId(acceptorId)
                setAccountId(accountId)
                setAccountToken(accountToken)
                setApplicationId((args?.get("applicationId") as? String) ?: "8414")
                setApplicationName((args?.get("applicationName") as? String) ?: "triPOS SampleApp")
                setApplicationVersion((args?.get("applicationVersion") as? String) ?: "0.0.0.0")
                setPaymentProcessor(PaymentProcessor.Worldpay)
            }

            appConfig = ApplicationConfiguration().apply {
                setIdlePrompt("triPOS Sample")
                setApplicationMode(if (isProduction) ApplicationMode.Production else ApplicationMode.TestCertification)
            }

            deviceConfig = DeviceConfiguration().apply {
                setContactlessAllowed(true)
                setDeviceType(DeviceType.Null) // will be replaced on connect
                setKeyedEntryAllowed(true)
                setTerminalId("1234")
                setTerminalType(TerminalType.Mobile)
                setHeartbeatEnabled(true)
                setBarcodeReaderEnabled(true)
                setSleepTimeoutSeconds(BigDecimal(300))
            }

            txnConfig = TransactionConfiguration().apply {
                setCurrencyCode(CurrencyCode.USD)
                setAmountConfirmationEnabled(true)
                setEmvAllowed(true)
                setTipAllowed(true)
                setTipEntryAllowed(true)
                setTipSelectionType(com.vantiv.triposmobilesdk.enums.TipSelectionType.Amount)
                setTipOptions(arrayOf(BigDecimal("1.00"), BigDecimal("2.00"), BigDecimal("3.00")))
                setDebitAllowed(true)
                setCashbackAllowed(true)
                setCashbackEntryAllowed(true)
                setCashbackEntryIncrement(5)
                setCashbackEntryMaximum(100)
                setCashbackOptions(arrayOf(BigDecimal("5.00"), BigDecimal("10.00"), BigDecimal("15.00")))
                setGiftCardAllowed(true)
                setQuickChipAllowed(true)
                setPreReadQuickChipPlaceHolderAmount(BigDecimal.ONE)
                setHealthcareSupported(true)
                setDynamicCurrencyConversionEnabled(true)
                setCustomAidSelectionEnabled(true)
                setDuplicateTransactionsAllowed(true)
                setShouldConfirmSurchargeAmount(true)
                setPartialApprovalAllowed(false)
            }

            safConfig = StoreAndForwardConfiguration().apply {
                setNumberOfDaysToRetainProcessedTransactions(1)
                setShouldTransactionsBeAutomaticallyForwarded(false)
                setStoringTransactionsAllowed(true)
                setTransactionAmountLimit(50)
                setUnprocessedTotalAmountLimit(100)
            }

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "initSdk error", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun cancelPayment(result: Result) {
        try {
            val method = vtp?.javaClass?.getMethod("cancelCurrentTransaction")
            method?.invoke(vtp)
            result.success(true)
        } catch (e: Exception) {
            result.error("CANCEL_ERROR", e.message, null)
        }
    }

    private fun scanDevices(result: Result) {
        // permissions
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasScan = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
            val hasConnect = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            if (!hasScan || !hasConnect) {
                result.error("PERMISSION_DENIED", "Need BLUETOOTH_SCAN and CONNECT", null); return
            }
        } else {
            val hasLoc = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!hasLoc) { result.error("PERMISSION_DENIED", "Need ACCESS_FINE_LOCATION", null); return }
        }
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter?.isEnabled != true) {
            result.error("BT_OFF", "Bluetooth is not enabled", null); return
        }
        if (vtp == null) vtp = triPOSMobileSDK.getSharedVtp()
        val cfg = buildConfigForScan()

        Thread {
            try {
                vtp!!.scanBluetoothDevicesWithConfiguration(context, cfg, object : BluetoothScanRequestListener {
                    override fun onScanRequestCompleted(devices: ArrayList<String>?) {
                        val list = ArrayList<Map<String, String>>()

                        // 支付设备名称关键词列表（用于过滤非支付设备）
                        val paymentDeviceKeywords = listOf(
                            "mob", "ingenico", "icmp", "lane", "tablet", 
                            "vantiv", "worldpay", "tripos", "rba", "rua"
                        )
                        
                        devices?.forEach { deviceString ->
                            val regex = Regex("(.+?)\\s*\\(([0-9A-Fa-f:]+)\\)")
                            val match = regex.find(deviceString)
                            val name = match?.groupValues?.get(1)?.trim() ?: deviceString
                            val mac = match?.groupValues?.get(2)?.trim() ?: deviceString

                            // 过滤：只保留支付设备
                            val isPaymentDevice = paymentDeviceKeywords.any { keyword ->
                                name.lowercase().contains(keyword)
                            }
                            
                            if (isPaymentDevice) {
                              list.add(mapOf("name" to name, "identifier" to mac))
                            }

                        }
                        uiHandler.post { result.success(list) }
                    }

                    override fun onScanRequestError(e: Exception?) {
                        uiHandler.post { result.error("SCAN_ERROR", e?.message ?: "scan error", null) }
                    }
                })
            } catch (e: Exception) {
                uiHandler.post { result.error("SCAN_EXCEPTION", e.message, null) }
            }
        }.start()
    }

    private fun connectDevice(args: Map<String, Any>?, result: Result) {
        try {
            if (hostConfig == null || appConfig == null || deviceConfig == null || txnConfig == null) {
                result.error("NOT_INIT", "Call initialize first", null); return
            }
            val identifier = args?.get("identifier") as? String ?: ""
            val isIp = (args?.get("isIp") as? Boolean) ?: false

            val devCfg = DeviceConfiguration().apply {
                setContactlessAllowed(true)
                setKeyedEntryAllowed(true)
                setTerminalType(TerminalType.Mobile)
                setHeartbeatEnabled(true)
                if (isIp) {
                    setDeviceType(DeviceType.IngenicoUppTcpIp)
                    val tcp = TcpIpConfiguration()
                    tcp.setIpAddress(identifier)
                    tcp.setPort(12000)
                    setTcpIpConfiguration(tcp)
                } else {
                    setDeviceType(DeviceType.IngenicoRuaBluetooth)
                    identifier.also { setIdentifier(it) }
                }
            }

            val config = Configuration().apply {
                setHostConfiguration(hostConfig)
                setApplicationConfiguration(appConfig)
                setDeviceConfiguration(devCfg)
                setTransactionConfiguration(txnConfig)
                setStoreAndForwardConfiguration(safConfig)
            }

            Thread {
                try {
                    if (vtp == null) vtp = triPOSMobileSDK.getSharedVtp()
                    if (vtp!!.isInitialized) vtp!!.deinitialize()
                    vtp!!.initialize(context, config, object : DeviceConnectionListener {
                        override fun onConnected(device: com.vantiv.triposmobilesdk.Device?, desc: String?, model: String?, serial: String?) {
                            sendEvent("connected", "Connected to $model ($serial)")
                            uiHandler.post { result.success(true) }
                        }

                        override fun onDisconnected(device: com.vantiv.triposmobilesdk.Device?) {
                            sendEvent("disconnected", "Device disconnected")
                        }

                        override fun onError(e: Exception?) {
                            sendEvent("error", "Connection error: ${e?.message}")
                        }

                        override fun onBatteryLow() { sendEvent("message", "WARNING: Battery Low") }
                        override fun onWarning(e: Exception?) { sendEvent("message", "Warning: ${e?.message}") }
                        override fun onConfirmPairing(ledSequences: MutableList<com.vantiv.triposmobilesdk.BTPairingLedSequence>?, deviceName: String?, listener: DeviceConnectionListener.ConfirmPairingListener?) {
                            sendEvent("message", "请在设备上确认配对")
                            listener?.confirmPairing()
                        }
                    })
                } catch (e: Exception) {
                    Log.e(TAG, "connectDevice failed", e)
                    uiHandler.post { result.error("CONNECT_ERROR", e.message, null) }
                }
            }.start()
        } catch (e: Exception) {
            result.error("CONNECT_EXCEPTION", e.message, null)
        }
    }

    private fun processPayment(args: Map<String, Any>?, result: Result) {
        if (vtp == null || !vtp!!.isInitialized) {
            result.error("NOT_INIT", "VTP not initialized", null); return
        }
        val amount = (args?.get("amount") as? Double) ?: 0.0
        val reference = (args?.get("referenceNumber") as? String) ?: "REF_${System.currentTimeMillis()}"
        val lane = (args?.get("laneNumber") as? String) ?: "1"
        val clerk = (args?.get("clerkNumber") as? String) ?: "123456"
        val shift = (args?.get("shiftID") as? String) ?: "1"
        val ticket = "5555"

        vtp!!.setStatusListener { status ->
            sendEvent("message", "Status: ${status.name}")
        }

        val saleRequest = SaleRequest().apply {
            setTransactionAmount(BigDecimal(amount))
            setLaneNumber(lane)
            setReferenceNumber(reference)
            setCardholderPresentCode(CardHolderPresentCode.Present)
            setClerkNumber(clerk)
            setShiftID(shift)
            setTicketNumber(ticket)
            setGiftProgramType(com.vantiv.triposmobilesdk.enums.GiftProgramType.Gift)
            setPinLessposConversionIndicator(false)
            setSurchargeFeeAmount(BigDecimal("1.00"))
        }

        try {
            vtp!!.processSaleRequest(saleRequest, object : SaleRequestListener {
                override fun onSaleRequestCompleted(saleResponse: SaleResponse) {
                    val map = mapOf(
                        "transactionId" to (saleResponse.host?.transactionID ?: ""),
                        "isApproved" to (saleResponse.transactionStatus == com.vantiv.triposmobilesdk.enums.TransactionStatus.Approved),
                        "message" to (saleResponse.host?.toString() ?: "Completed"),
                        "authCode" to (saleResponse.host?.approvalNumber ?: ""),
                        "amount" to (saleResponse.approvedAmount?.toString() ?: amount.toString()),
                        "isOffline" to false,
                        "rawResponse" to saleResponse.toString()
                    )
                    uiHandler.post { result.success(map) }
                }

                override fun onSaleRequestError(e: Exception) {
                    uiHandler.post { result.error("SALE_ERROR", e.message, null) }
                }
            }, buildDeviceListener())
        } catch (e: Exception) {
            result.error("SALE_EXCEPTION", e.message, null)
        }
    }

    private fun disconnect(result: Result) {
        try {
            vtp?.deinitialize()
            result.success(true)
        } catch (e: Exception) {
            result.error("DISCONNECT_ERROR", e.message, null)
        }
    }

    // --- Helpers ---
    private fun buildConfigForScan(): Configuration {
        val cfg = Configuration()
        hostConfig?.let { cfg.setHostConfiguration(it) }
        appConfig?.let { cfg.setApplicationConfiguration(it) }
        txnConfig?.let { cfg.setTransactionConfiguration(it) }
        val dev = DeviceConfiguration()
        dev.setDeviceType(DeviceType.IngenicoRuaBluetooth)
        cfg.setDeviceConfiguration(dev)
        return cfg
    }

    private fun buildDeviceListener(): DeviceInteractionListener = object : DeviceInteractionListener {
        override fun onAmountConfirmation(
            amountConfirmationType: com.vantiv.triposmobilesdk.enums.AmountConfirmationType?,
            amount: BigDecimal?,
            callback: DeviceInteractionListener.ConfirmAmountListener?
        ) {
            sendEvent("message", "Confirm amount: $amount")
            callback?.confirmAmount(true)
        }

        override fun onChoiceSelections(
            choices: Array<out String>?,
            selectionType: com.vantiv.triposmobilesdk.enums.SelectionType?,
            callback: DeviceInteractionListener.SelectChoiceListener?
        ) { callback?.selectChoice(0) }

        override fun onNumericInput(
            numericInputType: com.vantiv.triposmobilesdk.enums.NumericInputType?,
            callback: DeviceInteractionListener.NumericInputListener?
        ) { callback?.enterNumericInput("0") }

        override fun onSelectApplication(
            applications: Array<out String>?,
            callback: DeviceInteractionListener.SelectChoiceListener?
        ) { callback?.selectChoice(0) }

        override fun onPromptUserForCard(
            prompt: String?,
            displayTextIdentifiers: com.vantiv.triposmobilesdk.enums.DisplayTextIdentifiers?
        ) {
            sendEvent("readyForCard", prompt ?: "Insert/Swipe/Tap Card")
        }

        override fun onDisplayText(
            text: String?,
            displayTextIdentifiers: com.vantiv.triposmobilesdk.enums.DisplayTextIdentifiers?
        ) { sendEvent("message", text ?: "") }

        override fun onRemoveCard() { sendEvent("message", "Remove card") }
        override fun onCardRemoved() { sendEvent("message", "Card removed") }
        override fun onWait(message: String?) { sendEvent("message", message ?: "Please wait...") }
    }

    private fun sendEvent(type: String, msg: String?) {
        uiHandler.post { eventSink?.success(mapOf("type" to type, "message" to msg)) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        try { vtp?.deinitialize() } catch (_: Exception) {}
    }
}
