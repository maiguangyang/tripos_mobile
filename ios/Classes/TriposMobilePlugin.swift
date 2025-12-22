import Flutter
import UIKit
import triPOSMobileSDK

/// Flutter plugin for Worldpay triPOS Mobile SDK
public class TriposMobilePlugin: NSObject, FlutterPlugin {
    
    // MARK: - Properties
    private var channel: FlutterMethodChannel?
    private var statusEventChannel: FlutterEventChannel?
    private var deviceEventChannel: FlutterEventChannel?
    
    private var statusEventSink: FlutterEventSink?
    var deviceEventSink: FlutterEventSink?  // Changed from private for DeviceEventStreamHandler access
    
    private var vtp: VTP?
    private var vtpConfiguration: VTPConfiguration?
    private var isDeviceReady = false
    
    // MARK: - FlutterPlugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tripos_mobile", binaryMessenger: registrar.messenger())
        let instance = TriposMobilePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Status Event Channel
        let statusEventChannel = FlutterEventChannel(name: "tripos_mobile/status", binaryMessenger: registrar.messenger())
        statusEventChannel.setStreamHandler(instance)
        instance.statusEventChannel = statusEventChannel
        
        // Device Event Channel
        let deviceEventChannel = FlutterEventChannel(name: "tripos_mobile/device", binaryMessenger: registrar.messenger())
        deviceEventChannel.setStreamHandler(DeviceEventStreamHandler(plugin: instance))
        instance.deviceEventChannel = deviceEventChannel
    }
    
    // MARK: - Method Channel Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "getSdkVersion":
            // iOS SDK doesn't expose version directly, return a placeholder
            result("triPOS Mobile iOS SDK")
            
        case "scanBluetoothDevices":
            scanBluetoothDevices(call: call, result: result)
            
        case "initialize":
            initialize(call: call, result: result)
            
        case "isInitialized":
            result(vtp?.isInitialized ?? false)
            
        case "deinitialize":
            deinitialize(result: result)
            
        case "processSale":
            processSale(call: call, result: result)
            
        case "processRefund":
            processRefund(call: call, result: result)
            
        case "processLinkedRefund":
            processLinkedRefund(call: call, result: result)
            
        case "processVoid":
            processVoid(call: call, result: result)
            
        case "processAuthorization":
            processAuthorization(call: call, result: result)
            
        case "cancelTransaction":
            cancelTransaction(result: result)
            
        case "getDeviceInfo":
            getDeviceInfo(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Bluetooth Scanning
    private var scanTimeoutTimer: Timer?
    
    /// Check if required Bluetooth permission key exists in Info.plist
    private func hasBluetoothPermissionKey() -> Bool {
        // Check for either key that allows Bluetooth usage
        let hasAlwaysKey = Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil
        let hasPeripheralKey = Bundle.main.object(forInfoDictionaryKey: "NSBluetoothPeripheralUsageDescription") != nil
        return hasAlwaysKey || hasPeripheralKey
    }
    
    private func scanBluetoothDevices(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // CRITICAL: Check if Info.plist has Bluetooth permission key BEFORE any SDK calls
        // If missing, iOS will crash the app when any CoreBluetooth API is accessed
        if !hasBluetoothPermissionKey() {
            result(FlutterError(
                code: "BLUETOOTH_PERMISSION_NOT_CONFIGURED",
                message: "Bluetooth permission not configured in Info.plist",
                details: "Add NSBluetoothAlwaysUsageDescription key to your app's Info.plist file with a usage description string."
            ))
            return
        }
        
        // Store result for callback first
        pendingScanResult = result
        
        // Set a 10 second timeout for scanning
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self, let pendingResult = self.pendingScanResult else { return }
            self.pendingScanResult = nil
            // Cleanup SDK state on timeout to allow rescan
            try? self.vtp?.deinitialize()
            self.isDeviceReady = false
            DispatchQueue.main.async {
                pendingResult([])  // Return empty array on timeout
            }
        }
        
        do {
            let config = buildConfiguration(from: call.arguments as? [String: Any])
            vtpConfiguration = config
            
            vtp = triPOSMobileSDK.sharedVtp() as? VTP
            
            // If already initialized/connected, deinitialize first before scanning
            if vtp?.isInitialized == true {
                try vtp?.deinitialize()
                isDeviceReady = false
            }
            
            vtp?.add(self)
            
            try vtp?.scanForDevices(with: config)
            
        } catch {
            scanTimeoutTimer?.invalidate()
            pendingScanResult = nil
            result(FlutterError(code: "SCAN_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private var pendingScanResult: FlutterResult?
    
    // MARK: - Initialize
    private func initialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            let config = buildConfiguration(from: call.arguments as? [String: Any])
            vtpConfiguration = config
            
            vtp = triPOSMobileSDK.sharedVtp() as? VTP
            
            // Always try to deinitialize first if SDK thinks it's initialized
            // Use try? to ignore errors - we don't care if deinitialize fails
            // This handles cases where SDK is in a bad state after device errors
            if vtp?.isInitialized == true {
                try? vtp?.deinitialize()
                isDeviceReady = false
                // Small delay to allow SDK to fully cleanup
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            vtp?.add(self)
            vtp?.setDeviceInteractionDelegate(self)
            
            isDeviceReady = false
            pendingInitResult = result
            
            // Send connecting event to Flutter
            sendDeviceEvent(["event": "connecting"])
            
            try vtp?.initialize(with: config)
            
        } catch {
            // If initialization still fails, try one more time after force deinitialize
            do {
                try? vtp?.deinitialize()
                Thread.sleep(forTimeInterval: 0.5)
                try vtp?.initialize(with: vtpConfiguration!)
            } catch {
                result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    private var pendingInitResult: FlutterResult?
    
    // MARK: - Deinitialize
    private func deinitialize(result: @escaping FlutterResult) {
        do {
            try vtp?.deinitialize()
            vtpConfiguration = nil
            isDeviceReady = false
            result(nil)
        } catch {
            result(FlutterError(code: "DEINIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Reset Device Helper
    /// Resets the device to cancel any ongoing transaction (similar to Android's cancelCurrentFlow)
    private func resetDevice() {
        guard let vtp = vtp, let device = vtp.device else { return }
        
        do {
            try device.reset()
            // Give device time to fully reset
            Thread.sleep(forTimeInterval: 0.5)
        } catch {
            // Continue anyway - reset errors are not critical
        }
    }
    
    // MARK: - Sale
    private func processSale(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let vtp = vtp, vtp.isInitialized else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK is not initialized", details: nil))
            return
        }
        
        guard isDeviceReady else {
            result(FlutterError(code: "DEVICE_NOT_READY", message: "Device is not connected", details: nil))
            return
        }
        
        if let device = vtp.device {
            do {
                try device.reset()
                Thread.sleep(forTimeInterval: 0.5)
            } catch {
                // Continue anyway - reset errors are not critical
            }
        }
        
        let request = buildSaleRequest(from: call.arguments as? [String: Any])
        
        vtp.processSaleRequest(request, completionHandler: { [weak self] response in
            DispatchQueue.main.async {
                result(self?.buildSaleResponseMap(from: response))
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                let nsError = error as NSError?
                result([
                    "transactionStatus": "error",
                    "errorMessage": error?.localizedDescription ?? "Unknown error",
                    "errorCode": nsError?.code ?? -1,
                    "errorDomain": nsError?.domain ?? "unknown"
                ])
            }
        })
    }
    
    // MARK: - Refund
    private func processRefund(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let vtp = vtp, vtp.isInitialized else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK is not initialized", details: nil))
            return
        }
        
        guard isDeviceReady else {
            result(FlutterError(code: "DEVICE_NOT_READY", message: "Device is not connected", details: nil))
            return
        }
        
        // Reset device to cancel any ongoing transaction
        resetDevice()
        
        let request = buildRefundRequest(from: call.arguments as? [String: Any])
        
        vtp.processRefundRequest(request, completionHandler: { [weak self] response in
            DispatchQueue.main.async {
                result(self?.buildRefundResponseMap(from: response))
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                result([
                    "transactionStatus": "error",
                    "errorMessage": error?.localizedDescription ?? "Unknown error"
                ])
            }
        })
    }
    
    // MARK: - Linked Refund
    private func processLinkedRefund(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let vtp = vtp, vtp.isInitialized else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK is not initialized", details: nil))
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let transactionId = args["transactionId"] as? String else {
            result(FlutterError(code: "INVALID_REQUEST", message: "transactionId is required", details: nil))
            return
        }
        
        // For linked refund, use VXP API directly
        guard let hostConfig = vtpConfiguration?.hostConfiguration else {
            result(FlutterError(code: "NO_CONFIG", message: "Host configuration not available", details: nil))
            return
        }
        
        let credentials = VXPCredentials(
            values: hostConfig.accountId,
            accountToken: hostConfig.accountToken,
            acceptorID: hostConfig.acceptorId
        )
        
        let application = VXPApplication(
            values: hostConfig.applicationId,
            applicationName: hostConfig.applicationName,
            applicationVersion: hostConfig.applicationVersion
        )
        
        let transaction = VXPTransaction()
        transaction.transactionID = transactionId
        
        let amount = args["transactionAmount"] as? Double ?? 0.0
        transaction.transactionAmount = NSDecimalNumber(value: amount)
        transaction.referenceNumber = args["referenceNumber"] as? String ?? "\(Int(Date().timeIntervalSince1970))"
        
        let terminal = VXPTerminal()
        terminal.terminalID = "1"
        terminal.cardPresentCode = VXPCardPresentCodePresent
        terminal.cardholderPresentCode = VXPCardHolderPresentCodePresent
        
        // Request type 4 = Refund
        guard let request = VXPRequest(requestType: VXPRequestType(4), credentials: credentials, application: application) else {
            result(FlutterError(code: "REQUEST_ERROR", message: "Failed to create VXP request", details: nil))
            return
        }
        
        request.transaction = transaction
        request.terminal = terminal
        
        let vxp = VXP()
        vxp.testCertification = vtpConfiguration?.applicationConfiguration.mode == VTPApplicationModeTestCertification
        
        vxp.send(request, timeout: 30000, completionHandler: { response in
            DispatchQueue.main.async {
                result([
                    "transactionStatus": response?.expressResponseCode.rawValue == 0 ? "approved" : "declined",
                    "transactionId": transactionId,
                    "responseMessage": response?.expressResponseMessage ?? ""
                ])
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                result([
                    "transactionStatus": "error",
                    "errorMessage": error?.localizedDescription ?? "Unknown error"
                ])
            }
        })
    }
    
    // MARK: - Void
    private func processVoid(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let transactionId = args["transactionId"] as? String else {
            result(FlutterError(code: "INVALID_REQUEST", message: "transactionId is required", details: nil))
            return
        }
        
        guard let hostConfig = vtpConfiguration?.hostConfiguration else {
            result(FlutterError(code: "NO_CONFIG", message: "Host configuration not available", details: nil))
            return
        }
        
        let credentials = VXPCredentials(
            values: hostConfig.accountId,
            accountToken: hostConfig.accountToken,
            acceptorID: hostConfig.acceptorId
        )
        
        let application = VXPApplication(
            values: hostConfig.applicationId,
            applicationName: hostConfig.applicationName,
            applicationVersion: hostConfig.applicationVersion
        )
        
        let transaction = VXPTransaction()
        transaction.transactionID = transactionId
        
        let amount = args["transactionAmount"] as? Double ?? 1.0
        transaction.transactionAmount = NSDecimalNumber(value: amount)
        transaction.referenceNumber = args["referenceNumber"] as? String ?? "\(Int(Date().timeIntervalSince1970))"
        
        let terminal = VXPTerminal()
        terminal.terminalID = "1"
        terminal.cardPresentCode = VXPCardPresentCodePresent
        terminal.cardholderPresentCode = VXPCardHolderPresentCodePresent
        terminal.cvvPresenceCode = VXPCVVPresenceCodeDefault
        terminal.terminalCapabilityCode = VXPTerminalCapabilityCodeDefault
        terminal.terminalEnvironmentCode = VXPTerminalEnvironmentCodeDefault
        terminal.motoECICode = VXPMotoECICodeNotUsed
        terminal.cardInputCode = VXPCardInputCodeMagstripeRead
        
        // Request type 15 = Credit Card Void
        guard let request = VXPRequest(requestType: VXPRequestType(15), credentials: credentials, application: application) else {
            result(FlutterError(code: "REQUEST_ERROR", message: "Failed to create VXP request", details: nil))
            return
        }
        
        request.transaction = transaction
        request.terminal = terminal
        
        let vxp = VXP()
        vxp.testCertification = vtpConfiguration?.applicationConfiguration.mode == VTPApplicationModeTestCertification
        
        vxp.send(request, timeout: 30000, completionHandler: { response in
            DispatchQueue.main.async {
                result([
                    "transactionStatus": response?.expressResponseCode.rawValue == 0 ? "approved" : "declined",
                    "transactionId": transactionId,
                    "responseMessage": response?.expressResponseMessage ?? ""
                ])
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                result([
                    "transactionStatus": "error",
                    "errorMessage": error?.localizedDescription ?? "Unknown error"
                ])
            }
        })
    }
    
    // MARK: - Authorization
    private func processAuthorization(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let vtp = vtp, vtp.isInitialized else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK is not initialized", details: nil))
            return
        }
        
        guard isDeviceReady else {
            result(FlutterError(code: "DEVICE_NOT_READY", message: "Device is not connected", details: nil))
            return
        }
        
        // Reset device to cancel any ongoing transaction
        resetDevice()
        
        let request = buildAuthorizationRequest(from: call.arguments as? [String: Any])
        
        vtp.processAuthorizationRequest(request, completionHandler: { [weak self] response in
            DispatchQueue.main.async {
                result(self?.buildAuthorizationResponseMap(from: response))
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                result([
                    "transactionStatus": "error",
                    "errorMessage": error?.localizedDescription ?? "Unknown error"
                ])
            }
        })
    }
    
    // MARK: - Cancel Transaction
    private func cancelTransaction(result: @escaping FlutterResult) {
        // Use device.reset() as iOS equivalent of Android's vtp.cancelCurrentFlow()
        guard let vtp = vtp, let device = vtp.device else {
            result(nil)
            return
        }
        
        do {
            try device.reset()
            result(nil)
        } catch {
            result(FlutterError(code: "CANCEL_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Get Device Info
    private func getDeviceInfo(result: @escaping FlutterResult) {
        guard let vtp = vtp, vtp.isConnectedToDevice else {
            result(nil)
            return
        }
        
        result([
            "description": "Connected Device",
            "model": "Unknown",
            "serialNumber": "",
            "isConnected": true
        ])
    }
    
    // MARK: - Configuration Builder
    private func buildConfiguration(from args: [String: Any]?) -> VTPConfiguration {
        let config = VTPConfiguration()
        
        // Application Configuration
        if let appConfig = args?["applicationConfiguration"] as? [String: Any] {
            config.applicationConfiguration.idlePrompt = appConfig["idlePrompt"] as? String ?? "triPOS Flutter"
            
            let modeStr = appConfig["applicationMode"] as? String ?? "testCertification"
            config.applicationConfiguration.mode = modeStr == "production" 
                ? VTPApplicationModeProduction 
                : VTPApplicationModeTestCertification
        }
        
        // Host Configuration
        if let hostConfig = args?["hostConfiguration"] as? [String: Any] {
            config.hostConfiguration.accountId = hostConfig["accountId"] as? String ?? ""
            config.hostConfiguration.acceptorId = hostConfig["acceptorId"] as? String ?? ""
            config.hostConfiguration.accountToken = hostConfig["accountToken"] as? String ?? ""
            config.hostConfiguration.applicationId = hostConfig["applicationId"] as? String ?? "8414"
            config.hostConfiguration.applicationName = hostConfig["applicationName"] as? String ?? "triPOS Flutter"
            config.hostConfiguration.applicationVersion = hostConfig["applicationVersion"] as? String ?? "1.0.0"
        }
        
        // Device Configuration
        if let deviceConfig = args?["deviceConfiguration"] as? [String: Any] {
            let deviceTypeStr = deviceConfig["deviceType"] as? String ?? "ingenicoMobyBluetooth"
            config.deviceConfiguration.deviceType = mapDeviceType(deviceTypeStr)
            
            config.deviceConfiguration.terminalType = VTPTerminalTypePointOfSale
            // Dart sends: keyedEntryAllowed, contactlessAllowed (not isKeyedEntryAllowed, isContactlessAllowed)
            config.deviceConfiguration.isKeyedEntryAllowed = deviceConfig["keyedEntryAllowed"] as? Bool ?? true
            config.deviceConfiguration.isContactlessEntryAllowed = deviceConfig["contactlessAllowed"] as? Bool ?? true
            config.deviceConfiguration.terminalId = deviceConfig["terminalId"] as? String ?? "00000000"
            
            // Dart sends: identifier (not deviceIdentifier)
            if let identifier = deviceConfig["identifier"] as? String {
                config.deviceConfiguration.identifier = identifier
            }
        } else {
            config.deviceConfiguration.deviceType = VTPDeviceTypeIngenicoMobyBluetooth
            config.deviceConfiguration.terminalType = VTPTerminalTypePointOfSale
            config.deviceConfiguration.isKeyedEntryAllowed = true
            config.deviceConfiguration.isContactlessEntryAllowed = true
        }
        
        // Transaction Configuration
        if let transConfig = args?["transactionConfiguration"] as? [String: Any] {
            config.transactionConfiguration.currencyCode = VTPCurrencyCodeUsd
            config.transactionConfiguration.marketCode = VTPMarketCodeRetail
            config.transactionConfiguration.arePartialApprovalsAllowed = transConfig["arePartialApprovalsAllowed"] as? Bool ?? false
            // Default to true to match Android - prevents "Duplicate" error on repeated transactions
            config.transactionConfiguration.areDuplicateTransactionsAllowed = transConfig["areDuplicateTransactionsAllowed"] as? Bool ?? true
            config.transactionConfiguration.isDebitAllowed = transConfig["isDebitAllowed"] as? Bool ?? true
            config.transactionConfiguration.isEmvAllowed = transConfig["isEmvAllowed"] as? Bool ?? true
            config.transactionConfiguration.isTipAllowed = transConfig["isTipAllowed"] as? Bool ?? false
            config.transactionConfiguration.shouldConfirmAmount = transConfig["shouldConfirmAmount"] as? Bool ?? false
        } else {
            config.transactionConfiguration.currencyCode = VTPCurrencyCodeUsd
            config.transactionConfiguration.marketCode = VTPMarketCodeRetail
            config.transactionConfiguration.isDebitAllowed = true
            config.transactionConfiguration.isEmvAllowed = true
            config.transactionConfiguration.areDuplicateTransactionsAllowed = true  // Match Android default
        }
        
        // Store and Forward Configuration
        // Note: Using deprecated isStoringTransactionsAllowed to match SwiftSampleApp behavior
        // transactionStoringMode may not work correctly on all SDK versions
        if let safConfig = args?["storeAndForwardConfiguration"] as? [String: Any] {
            config.storeAndForwardConfiguration.isStoringTransactionsAllowed = safConfig["storingTransactionsAllowed"] as? Bool ?? true
            config.storeAndForwardConfiguration.shouldTransactionsBeAutomaticallyForwarded = safConfig["shouldTransactionsBeAutomaticallyForwarded"] as? Bool ?? true
            config.storeAndForwardConfiguration.transactionAmountLimit = safConfig["transactionAmountLimit"] as? UInt ?? 100
            config.storeAndForwardConfiguration.unprocessedTotalAmountLimit = safConfig["unprocessedTotalAmountLimit"] as? UInt ?? 1000
            config.storeAndForwardConfiguration.numberOfDaysToRetainProcessedTransactions = safConfig["numberOfDaysToRetainProcessedTransactions"] as? UInt ?? 7
        } else {
            // Default values matching Dart layer
            config.storeAndForwardConfiguration.isStoringTransactionsAllowed = true
            config.storeAndForwardConfiguration.shouldTransactionsBeAutomaticallyForwarded = true
            config.storeAndForwardConfiguration.transactionAmountLimit = 100
            config.storeAndForwardConfiguration.unprocessedTotalAmountLimit = 1000
            config.storeAndForwardConfiguration.numberOfDaysToRetainProcessedTransactions = 7
        }
        
        return config
    }
    
    private func mapDeviceType(_ typeStr: String) -> VTPDeviceType {
        switch typeStr {
        case "ingenicoMobyBluetooth", "ingenicoMoby5500":
            return VTPDeviceTypeIngenicoMobyBluetooth
        case "ingenicoRbaBluetooth", "ingenicoRba":
            return VTPDeviceTypeIngenicoRba
        case "ingenicoUppTcpIp":
            return VTPDeviceTypeIngenicoUppTcpIp
        default:
            return VTPDeviceTypeIngenicoMobyBluetooth
        }
    }
    
    // MARK: - Request Builders
    private func buildSaleRequest(from args: [String: Any]?) -> VTPSaleRequest {
        let request = VTPSaleRequest()
        
        if let amount = args?["transactionAmount"] as? Double {
            request.transactionAmount = NSDecimalNumber(value: amount)
        }
        
        request.referenceNumber = args?["referenceNumber"] as? String 
            ?? "\(Int(Date().timeIntervalSince1970))"
        
        if let convenienceFee = args?["convenienceFeeAmount"] as? Double {
            request.convenienceFeeAmount = NSDecimalNumber(value: convenienceFee)
        }
        
        return request
    }
    
    private func buildRefundRequest(from args: [String: Any]?) -> VTPRefundRequest {
        let request = VTPRefundRequest()
        
        if let amount = args?["transactionAmount"] as? Double {
            request.transactionAmount = NSDecimalNumber(value: amount)
        }
        
        request.referenceNumber = args?["referenceNumber"] as? String
            ?? "\(Int(Date().timeIntervalSince1970))"
        
        return request
    }
    
    private func buildAuthorizationRequest(from args: [String: Any]?) -> VTPAuthorizationRequest {
        let request = VTPAuthorizationRequest()
        
        if let amount = args?["transactionAmount"] as? Double {
            request.transactionAmount = NSDecimalNumber(value: amount)
        }
        
        request.referenceNumber = args?["referenceNumber"] as? String
            ?? "\(Int(Date().timeIntervalSince1970))"
        
        return request
    }
    
    // MARK: - Response Builders
    private func buildSaleResponseMap(from response: VTPSaleResponse?) -> [String: Any?] {
        guard let response = response else {
            return ["transactionStatus": "error", "errorMessage": "No response"]
        }
        
        // Detect if transaction was stored (offline mode)
        // 1. wasTransactionStored is true
        // 2. tpId is present (store and forward transaction ID)
        // 3. transactionStatus is Unknown and wasProcessedOnline is false
        // 4. transactionStatus is ApprovedByMerchant (store and forward approved)
        let wasStored = response.wasTransactionStored
        let hasTpId = response.tpId != nil && !response.tpId.isEmpty
        let isOfflineUnknown = response.transactionStatus == VTPTransactionStatusUnknown && !response.wasProcessedOnline
        let isApprovedByMerchant = response.transactionStatus == VTPTransactionStatusApprovedByMerchant
        
        // Consider transaction as stored if any of these conditions are true
        let isStoredTransaction = wasStored || hasTpId || isOfflineUnknown || isApprovedByMerchant
        
        
        let isApproved = response.transactionStatus == VTPTransactionStatusApproved
        let isApprovedOrStored = isApproved || isStoredTransaction
        
        // Determine transaction status string
        let statusString: String
        if isStoredTransaction {
            statusString = "approvedByMerchant"
        } else if isApproved {
            statusString = "approved"
        } else {
            statusString = mapTransactionStatus(response.transactionStatus)
        }
        
        var map: [String: Any?] = [
            "isApproved": isApprovedOrStored,
            "transactionStatus": statusString,
            "approvedAmount": response.approvedAmount?.doubleValue,
            "referenceNumber": response.referenceNumber,
            "wasProcessedOnline": response.wasProcessedOnline,
            "wasPinVerified": response.wasPinVerified,
            "isSignatureRequired": response.isSignatureRequired,
            "paymentType": mapPaymentType(response.paymentType),
            // Store and Forward fields
            "wasTransactionStored": wasStored,
            "tpId": response.tpId  // Transaction ID for stored transactions
        ]
        
        if let host = response.host {
            map["transactionId"] = host.transactionID
            map["authorizationCode"] = host.approvalNumber
            // Add detailed error info from host response
            map["expressResponseCode"] = host.expressResponseCode
            map["expressResponseMessage"] = host.expressResponseMessage
            map["hostResponseCode"] = host.hostResponseCode
            map["hostResponseMessage"] = host.hostResponseMessage
            map["processorName"] = host.processorName
            // Build host sub-map for consistency with Android
            map["host"] = [
                "transactionId": host.transactionID,
                "approvalNumber": host.approvalNumber,
                "expressResponseCode": host.expressResponseCode,
                "expressResponseMessage": host.expressResponseMessage,
                "hostResponseCode": host.hostResponseCode,
                "hostResponseMessage": host.hostResponseMessage,
                "processorName": host.processorName,
                "expressTransactionDate": host.expressTransactionDate,
                "expressTransactionTime": host.expressTransactionTime
            ]
        }
        
        // If stored but no host transactionId, use tpId as fallback
        if wasStored && map["transactionId"] == nil {
            map["transactionId"] = response.tpId
        }
        
        if let card = response.card {
            map["maskedCardNumber"] = card.maskedAccountNumber
            map["cardHolderName"] = card.cardHolderName
            map["cardType"] = card.cardLogo
            // Build card sub-map for consistency with Android
            map["card"] = [
                "maskedAccountNumber": card.maskedAccountNumber,
                "cardHolderName": card.cardHolderName,
                "cardLogo": card.cardLogo
            ]
        }
        
        // Add errorMessage if transaction was declined/failed (but NOT if stored successfully)
        if response.transactionStatus != VTPTransactionStatusApproved && !wasStored {
            // Try to get error message from host response
            if let hostMessage = response.host?.hostResponseMessage, !hostMessage.isEmpty {
                map["errorMessage"] = hostMessage
            } else if let expressMessage = response.host?.expressResponseMessage, !expressMessage.isEmpty {
                map["errorMessage"] = expressMessage
            } else {
                map["errorMessage"] = "Transaction \(mapTransactionStatus(response.transactionStatus))"
            }
        }
        
        return map
    }
    
    private func buildRefundResponseMap(from response: VTPRefundResponse?) -> [String: Any?] {
        guard let response = response else {
            return ["transactionStatus": "error", "errorMessage": "No response"]
        }
        
        var map: [String: Any?] = [
            "isApproved": response.transactionStatus == VTPTransactionStatusApproved,
            "transactionStatus": mapTransactionStatus(response.transactionStatus),
            "approvedAmount": response.approvedAmount?.doubleValue,
            "referenceNumber": response.referenceNumber
        ]
        
        if let host = response.host {
            map["transactionId"] = host.transactionID
            map["expressResponseCode"] = host.expressResponseCode
            map["expressResponseMessage"] = host.expressResponseMessage
            map["hostResponseCode"] = host.hostResponseCode
            map["hostResponseMessage"] = host.hostResponseMessage
            map["host"] = [
                "transactionId": host.transactionID,
                "approvalNumber": host.approvalNumber,
                "expressResponseCode": host.expressResponseCode,
                "expressResponseMessage": host.expressResponseMessage,
                "hostResponseCode": host.hostResponseCode,
                "hostResponseMessage": host.hostResponseMessage
            ]
        }
        
        // Add errorMessage if transaction was declined/failed
        if response.transactionStatus != VTPTransactionStatusApproved {
            if let hostMessage = response.host?.hostResponseMessage, !hostMessage.isEmpty {
                map["errorMessage"] = hostMessage
            } else if let expressMessage = response.host?.expressResponseMessage, !expressMessage.isEmpty {
                map["errorMessage"] = expressMessage
            } else {
                map["errorMessage"] = "Transaction \(mapTransactionStatus(response.transactionStatus))"
            }
        }
        
        return map
    }
    
    private func buildAuthorizationResponseMap(from response: VTPAuthorizationResponse?) -> [String: Any?] {
        guard let response = response else {
            return ["transactionStatus": "error", "errorMessage": "No response"]
        }
        
        var map: [String: Any?] = [
            "isApproved": response.transactionStatus == VTPTransactionStatusApproved,
            "transactionStatus": mapTransactionStatus(response.transactionStatus),
            "approvedAmount": response.approvedAmount?.doubleValue,
            "referenceNumber": response.referenceNumber
        ]
        
        if let host = response.host {
            map["transactionId"] = host.transactionID
            map["authorizationCode"] = host.approvalNumber
            map["expressResponseCode"] = host.expressResponseCode
            map["expressResponseMessage"] = host.expressResponseMessage
            map["hostResponseCode"] = host.hostResponseCode
            map["hostResponseMessage"] = host.hostResponseMessage
            map["host"] = [
                "transactionId": host.transactionID,
                "approvalNumber": host.approvalNumber,
                "expressResponseCode": host.expressResponseCode,
                "expressResponseMessage": host.expressResponseMessage,
                "hostResponseCode": host.hostResponseCode,
                "hostResponseMessage": host.hostResponseMessage
            ]
        }
        
        // Add errorMessage if transaction was declined/failed
        if response.transactionStatus != VTPTransactionStatusApproved {
            if let hostMessage = response.host?.hostResponseMessage, !hostMessage.isEmpty {
                map["errorMessage"] = hostMessage
            } else if let expressMessage = response.host?.expressResponseMessage, !expressMessage.isEmpty {
                map["errorMessage"] = expressMessage
            } else {
                map["errorMessage"] = "Transaction \(mapTransactionStatus(response.transactionStatus))"
            }
        }
        
        return map
    }
    
    private func mapTransactionStatus(_ status: VTPTransactionStatus) -> String {
        switch status {
        case VTPTransactionStatusUnknown:
            return "unknown"
        case VTPTransactionStatusApproved:
            return "approved"
        case VTPTransactionStatusPartiallyApproved:
            return "partiallyApproved"
        case VTPTransactionStatusApprovedExceptCashback:
            return "approvedExceptCashback"
        case VTPTransactionStatusApprovedByMerchant:
            return "approvedByMerchant"
        case VTPTransactionStatusCallIssuer:
            return "callIssuer"
        case VTPTransactionStatusDeclined:
            return "declined"
        case VTPTransactionStatusNeedsToBeReversed:
            return "needsToBeReversed"
        case VTPDccRequested:
            return "dccRequested"
        default:
            return "unknown"
        }
    }
    
    private func mapPaymentType(_ type: VTPPaymentType) -> String {
        switch type {
        case VTPPaymentTypeCredit:
            return "credit"
        case VTPPaymentTypeDebit:
            return "debit"
        case VTPPaymentTypeGiftCard:
            return "gift"
        case VTPPaymentTypeEbt:
            return "ebt"
        default:
            return "unknown"
        }
    }
    
    /// Maps iOS VTPStatus to Android-compatible VtpStatus string names
    private func mapVtpStatus(_ status: VTPStatus) -> String {
        switch status {
        case VTPStatusNone:
            return "None"
        case VTPStatusInitializing:
            return "Initializing"
        case VTPStatusDeinitializing:
            return "Deinitializing"
        case VTPStatusRunningSale:
            return "RunningSale"
        case VTPStatusRunningRefund:
            return "RunningRefund"
        case VTPStatusRunningAuthorization:
            return "RunningAuthorization"
        case VTPStatusGettingCardInput:
            return "GettingCardInput"
        case VTPStatusProcessingCardInput:
            return "ProcessingCardInput"
        case VTPStatusGettingPaymentType:
            return "GettingPaymentType"
        case VTPStatusGettingTotalAmountConfirmation:
            return "GettingTotalAmountConfirmation"
        case VTPStatusGettingPin:
            return "GettingPin"
        case VTPStatusSendingToHost:
            return "SendingToHost"
        case VTPStatusFinalizing:
            return "Finalizing"
        case VTPStatusDone:
            return "Done"
        case VTPStatusGettingTipSelection:
            return "GettingTipSelection"
        case VTPStatusGettingTipEntry:
            return "GettingTipEntry"
        case VTPStatusGettingWantTip:
            return "GettingWantTip"
        case VTPStatusGettingCashbackSelection:
            return "GettingCashbackSelection"
        case VTPStatusGettingCashbackEntry:
            return "GettingCashbackEntry"
        case VTPStatusGettingWantCashback:
            return "GettingWantCashback"
        case VTPStatusGettingPostalCode:
            return "GettingPostalCode"
        case VTPStatusGettingSurchargeAmountConfirmation:
            return "GettingSurchargeAmountConfirmation"
        case VTPStatusGettingConvenienceFeeAmountConfirmation:
            return "GettingConvenienceFeeAmountConfirmation"
        case VTPStatusRunningGiftCardActivate:
            return "RunningGiftCardActivate"
        case VTPStatusRunningGiftCardBalanceInquiry:
            return "RunningGiftCardBalanceInquiry"
        case VTPStatusRunningGiftCardReload:
            return "RunningGiftCardReload"
        case VTPStatusRunningGiftCardBalanceTransfer:
            return "RunningGiftCardBalanceTransfer"
        case VTPStatusRunningGiftCardClose:
            return "RunningGiftCardClose"
        case VTPStatusRunningGiftCardUnload:
            return "RunningGiftCardUnload"
        case VTPStatusRunningEbtVoucherRequest:
            return "RunningEbtVoucherRequest"
        case VTPStatusRunningEbtCardBalanceInquiry:
            return "RunningEbtCardBalanceInquiry"
        case VTPStatusRunningDccConfirmation:
            return "RunningDccConfirmation"
        case VTPStatusRunningBINLookup:
            return "RunningBINLookup"
        case VTPStatusRunningHostedSurcharge:
            return "RunningHostedSurcharge"
        case VTPStatusGettingContinuingEmvTransaction:
            return "GettingContinuingEmvTransaction"
        case VTPStatusGettingFinalizingEmvTransaction:
            return "GettingFinalizingEmvTransaction"
        case VTPStatusInitializingDevicePool:
            return "InitializingDevicePool"
        case VTPStatusStartingSession:
            return "StartingSession"
        case VTPStatusClosingSession:
            return "ClosingSession"
        case VTPStatusStartedSession:
            return "StartedSession"
        case VTPStatusClosedSession:
            return "ClosedSession"
        default:
            return "Unknown"
        }
    }
    
    // MARK: - Event Sink Helpers
    func sendStatusEvent(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusEventSink?(status)
        }
    }
    
    func sendDeviceEvent(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.deviceEventSink?(event)
        }
    }
}

// MARK: - FlutterStreamHandler for Status Events
extension TriposMobilePlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        statusEventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        statusEventSink = nil
        return nil
    }
}

// MARK: - Device Event Stream Handler
class DeviceEventStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: TriposMobilePlugin?
    
    init(plugin: TriposMobilePlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Store eventSink in plugin for device events
        plugin?.deviceEventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.deviceEventSink = nil
        return nil
    }
}

// MARK: - VTPDelegate
extension TriposMobilePlugin: VTPDelegate {
    
    public func deviceDidConnect(_ description: String!, model: String!, serialNumber: String!) {
        isDeviceReady = true
        
        sendDeviceEvent([
            "event": "connected",
            "description": description ?? "",
            "model": model ?? "",
            "serialNumber": serialNumber ?? ""
        ])
        
        // Complete pending init if waiting
        if let pendingResult = pendingInitResult {
            DispatchQueue.main.async {
                pendingResult(true)
            }
            pendingInitResult = nil
        }
    }
    
    public func deviceDidConnect(_ description: String!, model: String!, serialNumber: String!, 
                                  firmwareVersion: String!, configurationVersion: String!, 
                                  batteryPercentage: String!, batteryLevel: String!) {
        isDeviceReady = true
        
        sendDeviceEvent([
            "event": "connected",
            "description": description ?? "",
            "model": model ?? "",
            "serialNumber": serialNumber ?? "",
            "firmwareVersion": firmwareVersion ?? "",
            "batteryPercentage": batteryPercentage ?? ""
        ])
        
        if let pendingResult = pendingInitResult {
            DispatchQueue.main.async {
                pendingResult(true)
            }
            pendingInitResult = nil
        }
    }
    
    public func deviceDidDisconnect() {
        isDeviceReady = false
        sendDeviceEvent(["event": "disconnected"])
    }
    
    public func deviceDidError(_ error: Error!) {
        sendDeviceEvent([
            "event": "error",
            "message": error?.localizedDescription ?? "Unknown error"
        ])
        
        // Cleanup SDK state after device error to prevent "already initialized" on retry
        isDeviceReady = false
        try? vtp?.deinitialize()
        
        if let pendingResult = pendingInitResult {
            DispatchQueue.main.async {
                pendingResult(FlutterError(code: "DEVICE_ERROR", message: error?.localizedDescription, details: nil))
            }
            pendingInitResult = nil
        }
    }
    
    public func deviceInitialization(inProgress currentProgress: Double, description: String!, 
                                      model: String!, serialNumber: String!, currentStep: String!) {
        sendDeviceEvent([
            "event": "initProgress",
            "progress": currentProgress,
            "description": description ?? "",
            "currentStep": currentStep ?? ""
        ])
    }
    
    public func deviceInitialization(inProgress currentProgress: Double, description: String!, 
                                      model: String!, serialNumber: String!, 
                                      initializationStatus: VTPInitializationStatus) {
        sendDeviceEvent([
            "event": "initProgress",
            "progress": currentProgress,
            "description": description ?? ""
        ])
    }
    
    public func statusDidChange(_ status: VTPStatus, description: String!) {
        let statusName = mapVtpStatus(status)
        sendStatusEvent(statusName)
    }
    
    public func onReturnBluetoothScanResults(_ devices: [VTPBluetoothDevice]!) {
        // Cancel timeout timer since we got results
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        
        guard let devices = devices else {
            pendingScanResult?([])
            pendingScanResult = nil
            return
        }
        
        let deviceList = devices.map { device -> String in
            return device.serialNumber ?? device.manufacturer ?? "Unknown Device"
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.pendingScanResult?(deviceList)
            self?.pendingScanResult = nil
        }
    }
    
    public func onReturnPairingConfirmation(_ ledSequence: [Any]!, deviceName: String!, 
                                             callback: VPDPairingConfirmationCallback!) {
        // Auto-confirm pairing
        callback.confirm()
    }
}

// MARK: - VTPDeviceInteractionDelegate
extension TriposMobilePlugin: VTPDeviceInteractionDelegate {
    
    // Called when SDK needs user to select from choices (Credit/Debit etc)
    public func onSelection(with choices: [Any]!, for selectionType: VTPSelectionType, 
                            completionHandler: VPDChoiceInputCompletionHandler!) {
        // Auto-select first choice (Credit)
        if choices?.count ?? 0 > 0 {
            completionHandler?(0)
        }
    }
    
    // Called when SDK needs amount confirmation
    public func onAmountConfirmation(_ amount: NSDecimalNumber!, 
                                      completionHandler: VPDYesNoInputCompletionHandler!) {
        completionHandler?(true)
    }
    
    // Called when SDK needs numeric input (e.g., tip amount)
    public func onNumericInput(_ numericInputType: VTPNumericInputType, 
                               completionHandler: VPDKeyboardNumericInputCompletionHandler!) {
        completionHandler?("0")
    }
    
    // Called when SDK needs user to select an application (multi-AID cards)
    public func onSelectApplication(_ applications: [Any]!, 
                                    completionHandler: VPDChoiceInputCompletionHandler!) {
        if applications?.count ?? 0 > 0 {
            completionHandler?(0)
        }
    }
    
    public func onDisplayText(_ text: String!) {
        // Display text is for UI prompts, not status updates
    }
    
    public func onDisplayText(_ text: String!, identifier: VTPTextIdentifier) {
        // Display text is for UI prompts, not status updates
    }
    
    public func onRemoveCard() {
        sendDeviceEvent(["event": "removeCard"])
    }
}

