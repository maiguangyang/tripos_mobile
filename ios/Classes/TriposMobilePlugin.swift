import Flutter
import UIKit
import CoreBluetooth
import triPOSMobileSDK

public class TriposMobilePlugin: NSObject, FlutterPlugin, FlutterStreamHandler, VTPDelegate, VTPDeviceInteractionDelegate {
    
    // MARK: - Constants
    private static let TAG = "TriPOSMobile"
    
    // MARK: - State Management
    private var eventSink: FlutterEventSink?
    private var resultCallback: FlutterResult? // Used for processPayment callback
    
    // SDK Instance
    private var vtp: VTP?
    
    // Configuration storage
    private var savedHostConfig: VTPHostConfiguration?
    private var savedAppConfig: VTPApplicationConfiguration?
    private var isProductionMode: Bool = false
    
    // Device Scanning
    private var scanResult: FlutterResult?
    
    // MARK: - Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tripos_mobile", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "tripos_mobile/events", binaryMessenger: registrar.messenger())
        
        let instance = TriposMobilePlugin()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        
        // Initialize VTP instance
        instance.vtp = triPOSMobileSDK.sharedVtp() as? VTP
        
        // Set SDK delegate
        if let vtp = instance.vtp {
            vtp.add(instance) // Add as delegate
            vtp.setDeviceInteractionDelegate(instance) // Set interaction delegate
        }
    }
    
    // MARK: - Method Call Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "initialize":
            initializeSdk(call: call, result: result)
            
        case "scanDevices":
            scanDevices(result: result)
            
        case "connectDevice":
            connectDevice(call: call, result: result)
            
        case "processPayment":
            processPayment(call: call, result: result)
            
        case "disconnect":
            disconnect(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 1. Initialize SDK
    private func initializeSdk(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let configMap = call.arguments as? [String: Any] else {
            result(FlutterError(code: "ARGS_ERROR", message: "Config null", details: nil))
            return
        }
        
        // Validate required parameters
        guard let acceptorId = configMap["acceptorId"] as? String, !acceptorId.isEmpty,
              let accountId = configMap["accountId"] as? String, !accountId.isEmpty,
              let accountToken = configMap["accountToken"] as? String, !accountToken.isEmpty else {
            result(FlutterError(code: "INVALID_CONFIG", 
                               message: "Missing required credentials (acceptorId, accountId, or accountToken)", 
                               details: nil))
            return
        }
        
        print("[\(Self.TAG)] Initializing triPOS SDK...")
        
        // 1.1 Configure Host Configuration
        let hostConfig = VTPHostConfiguration()
        hostConfig.acceptorId = acceptorId
        hostConfig.accountId = accountId
        hostConfig.accountToken = accountToken
        hostConfig.applicationId = configMap["applicationId"] as? String ?? "12345"
        hostConfig.applicationName = configMap["applicationName"] as? String ?? "FlutterPlugin"
        hostConfig.applicationVersion = configMap["applicationVersion"] as? String ?? "1.0.0"
        
        // 1.2 Configure Application Configuration
        let appConfig = VTPApplicationConfiguration()
        isProductionMode = configMap["isProduction"] as? Bool ?? false
        appConfig.mode = isProductionMode ? VTPApplicationModeProduction : VTPApplicationModeTestCertification
        print("[\(Self.TAG)] Production mode: \(isProductionMode)")
        
        // Save config for later use
        self.savedHostConfig = hostConfig
        self.savedAppConfig = appConfig
        
        // 1.4 Call SDK Initialize
        do {
            try internalInitialize()
            
            // Verify initialization status
            if let vtp = self.vtp, vtp.isInitialized {
                print("[\(Self.TAG)] SDK Initialized successfully")
                result(nil) // Success returns nil in Dart
            } else {
                // Strict Production Check:
                // If isInitialized is false, it means the SDK failed to complete necessary setup 
                // (e.g. failed to download BIN table or connect to host).
                // We must block progress to ensure data integrity and security.
                print("[\(Self.TAG)] Error: SDK initialized but isInitialized=false")
                result(FlutterError(code: "INIT_FAILED", message: "SDK Initialization failed. Check network and credentials.", details: nil))
            }
        } catch {
            print("[\(Self.TAG)] Init Error: \(error)")
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func internalInitialize() throws {
        guard let hostConfig = savedHostConfig, let appConfig = savedAppConfig else {
            throw NSError(domain: "TriposMobile", code: -1, userInfo: [NSLocalizedDescriptionKey: "No saved configuration"])
        }
        
        let vtpConfig = VTPConfiguration()
        vtpConfig.hostConfiguration = hostConfig
        vtpConfig.applicationConfiguration = appConfig
        
        try vtp?.initialize(with: vtpConfig)
    }
    
    // MARK: - 2. Scan Devices (SDK Method)
    private func scanDevices(result: @escaping FlutterResult) {
        self.scanResult = result
        
        print("[\(Self.TAG)] Starting SDK Bluetooth scan...")
        
        // Check if already connected
        if let vtp = self.vtp, vtp.isConnectedToDevice {
            print("[\(Self.TAG)] Device already connected. Disconnecting before scan...")
            do {
                try vtp.closeSession()
            } catch {
                print("[\(Self.TAG)] Warning: Failed to close existing session: \(error)")
                // If closeSession fails (e.g. "No active session"), the SDK state is likely inconsistent.
                // Force a hard reset (deinit -> init) to clear the "connected" flag.
                print("[\(Self.TAG)] State inconsistent. Performing hard reset...")
                try? vtp.deinitialize()
                try? internalInitialize()
            }
        }
        
        // Create a temporary configuration for scanning
        let vtpConfig = VTPConfiguration()
        // Use ObjC enum name
        vtpConfig.deviceConfiguration.deviceType = VTPDeviceTypeIngenicoMobyBluetooth
        
        do {
            try vtp?.scanForDevices(with: vtpConfig)
            // Results will be returned in onReturnBluetoothScanResults
        } catch {
            let nsError = error as NSError
            // Code 2147483647 is the "already connected" error
            if nsError.code == 2147483647 {
                print("[\(Self.TAG)] Device stuck in connected state. Attempting hard reset...")
                do {
                    try vtp?.deinitialize()
                    try internalInitialize()
                    try vtp?.scanForDevices(with: vtpConfig)
                    return // Success on retry
                } catch {
                     print("[\(Self.TAG)] Hard reset failed: \(error)")
                }
            }
            
            print("[\(Self.TAG)] Scan Error: \(error)")
            result(FlutterError(code: "SCAN_ERROR", message: error.localizedDescription, details: nil))
            self.scanResult = nil
        }
    }
    
    // MARK: - 3. Connect Device
    private func connectDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let deviceMap = call.arguments as? [String: Any],
              let identifier = deviceMap["identifier"] as? String else {
            result(FlutterError(code: "ARGS", message: "Identifier required", details: nil))
            return
        }
        
        let isIp = deviceMap["isIp"] as? Bool ?? false
        let name = deviceMap["name"] as? String ?? "Unknown"
        print("[\(Self.TAG)] Connecting to device: \(name) (\(identifier))")
        
        let connectionInfo = VTPDeviceConnectionInfo()
        
        if isIp {
            connectionInfo.deviceType = VTPDeviceTypeIngenicoUppTcpIp
            let tcpConfig = VTPDeviceTcpIpConfiguration()
            tcpConfig.ipAddress = identifier
            tcpConfig.port = 12000
            connectionInfo.tcpIpConfiguration = tcpConfig
        } else {
            // Smart device type selection based on name
            // Removed RBA check as enum was not found/supported in this version
            connectionInfo.deviceType = VTPDeviceTypeIngenicoMobyBluetooth
            connectionInfo.identifier = identifier
        }
        
        do {
            try vtp?.startSession(with: connectionInfo)
            // Note: Connection success is reported via deviceDidConnect delegate
            result(true)
        } catch {
            print("[\(Self.TAG)] Connect Error: \(error)")
            result(FlutterError(code: "CONNECT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - 4. Process Payment
    private func processPayment(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let amountDouble = args["amount"] as? Double else {
            result(FlutterError(code: "ARGS", message: "Amount required", details: nil))
            return
        }
        
        self.resultCallback = result
        
        print("[\(Self.TAG)] Processing payment: \(amountDouble)")
        
        // 4.1 Configure Transaction
        // Assuming default configuration from init is sufficient.
        
        // 4.2 Create Sale Request
        let saleRequest = VTPSaleRequest()
        saleRequest.transactionAmount = NSDecimalNumber(value: amountDouble)
        saleRequest.referenceNumber = "REF_\(Int(Date().timeIntervalSince1970))"
        
        // 4.3 Process Sale
        vtp?.processSaleRequest(saleRequest, completionHandler: { [weak self] (response: VTPSaleResponse?) in
            guard let self = self else { return }
            
            if let resp = response {
                let resultMap = self.parseResponse(resp)
                print("[\(Self.TAG)] Payment finished: \(resultMap)")
                self.resultCallback?(resultMap)
            } else {
                self.resultCallback?(FlutterError(code: "UNKNOWN", message: "No response", details: nil))
            }
            self.resultCallback = nil
            
        }, errorHandler: { [weak self] (error: Error?) in
            guard let self = self else { return }
            let errorMsg = error?.localizedDescription ?? "Unknown error"
            print("[\(Self.TAG)] Payment Error: \(errorMsg)")
            self.resultCallback?(FlutterError(code: "SALE_ERROR", message: errorMsg, details: nil))
            self.resultCallback = nil
        })
    }
    
    private func parseResponse(_ response: VTPSaleResponse) -> [String: Any] {
        var isApproved = false
        if response.transactionStatus == VTPTransactionStatusApproved {
            isApproved = true
        }
        
        // Corrected property names based on VTPReceiptData+Extensions.swift
        let authCode = response.host?.approvalNumber ?? ""
        let transactionId = response.host?.transactionID ?? ""
        let message = response.host?.hostResponseCode ?? (isApproved ? "Approved" : "Declined")
        let amount = response.approvedAmount?.stringValue ?? "0.00"
        
        return [
            "isApproved": isApproved,
            "authCode": authCode,
            "transactionId": transactionId,
            "message": message,
            "amount": amount,
            "rawResponse": response.description
        ]
    }
    
    // MARK: - 5. Disconnect
    private func disconnect(result: @escaping FlutterResult) {
        do {
            try vtp?.closeSession()
            print("[\(Self.TAG)] Session closed")
            result(true)
        } catch {
            result(FlutterError(code: "DISCONNECT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - VTPDelegate Implementation
    
    // Scan Results
    public func onReturnBluetoothScanResults(_ devices: [VTPBluetoothDevice]!) {
        print("[\(Self.TAG)] Scan results received: \(devices?.count ?? 0) devices")
        
        guard let scanResult = self.scanResult else { return }
        
        let list = devices?.map { device -> [String: String] in
            return [
                "name": device.manufacturer ?? "Unknown Device",
                "identifier": device.serialNumber ?? ""
            ]
        } ?? []
        
        scanResult(list)
        self.scanResult = nil
    }
    
    public func deviceDidConnect(_ description: String!, model: String!, serialNumber: String!, firmwareVersion: String!, configurationVersion: String!, batteryPercentage: String!, batteryLevel: String!) {
        let msg = "Device Connected: \(model ?? "") (\(serialNumber ?? ""))"
        print("[\(Self.TAG)] \(msg)")
        sendEvent(type: "connected", message: msg)
    }
    
    // Fallback
    public func deviceDidConnect(_ description: String!, model: String!, serialNumber: String!) {
        let msg = "Device Connected: \(model ?? "") (\(serialNumber ?? ""))"
        print("[\(Self.TAG)] \(msg)")
        sendEvent(type: "connected", message: msg)
    }
    
    public func deviceDidDisconnect() {
        print("[\(Self.TAG)] Device Disconnected")
        sendEvent(type: "disconnected", message: "Device Disconnected")
    }
    
    public func deviceDidError(_ error: Error!) {
        print("[\(Self.TAG)] Device Error: \(error.localizedDescription)")
        sendEvent(type: "error", message: error.localizedDescription)
    }
    
    public func deviceInitialization(inProgress currentProgress: Double, description: String!, model: String!, serialNumber: String!, initializationStatus: VTPInitializationStatus) {
        var statusStr = "Initializing"
        
        // Use ObjC Enum cases
        switch initializationStatus {
        case VTPInitializationStatusUpdatingFirmware: statusStr = "Updating Firmware"
        case VTPInitializationStatusUpdatingFiles: statusStr = "Updating Files"
        case VTPInitializationStatusConfiguringEmv: statusStr = "Configuring EMV"
        case VTPInitializationStatusRebootingDevice: statusStr = "Rebooting Device"
        default: statusStr = "Processing..."
        }
        
        let msg = String(format: "%@ (%.0f%%)", statusStr, currentProgress * 100)
        print("[\(Self.TAG)] Init Progress: \(msg)")
        sendEvent(type: "message", message: msg)
    }
    
    public func onDisplayText(_ text: String!) {
        sendEvent(type: "message", message: text)
    }
    
    public func onDisplayText(_ text: String!, identifier: VTPTextIdentifier) {
        sendEvent(type: "message", message: text)
    }
    
    public func onPromptUserForCard(_ prompt: String!) {
        sendEvent(type: "message", message: prompt ?? "Please insert/swipe card")
    }
    
    public func onRemoveCard() {
        sendEvent(type: "message", message: "Please remove card")
    }
    
    // MARK: - VTPDeviceInteractionDelegate Additional Methods
    
    public func onAmountConfirmation(_ amount: NSDecimalNumber!) async -> Bool {
        // Auto-confirm amount for headless operation
        return true
    }
    
    public func onAmountConfirmation(withPrompt prompt: String!, completionHandler: @escaping VPDYesNoInputCompletionHandler) {
        // Auto-confirm amount
        completionHandler(true)
    }
    
    public func onNumericInput(_ numericInputType: VTPNumericInputType, completionHandler: @escaping VPDKeyboardNumericInputCompletionHandler) {
        // Return empty or default for numeric input as we can't prompt user easily
        completionHandler("")
    }
    
    public func onSelectApplication(_ applications: [Any], completionHandler: @escaping VPDChoiceInputCompletionHandler) {
        // Auto-select first application if available
        if !applications.isEmpty {
            completionHandler(0)
        } else {
            completionHandler(-1)
        }
    }
    
    public func onSelection(with choices: [Any], for selectionType: VTPSelectionType, completionHandler: @escaping VPDChoiceInputCompletionHandler) {
        // Auto-select first choice if available
        if !choices.isEmpty {
            completionHandler(0)
        } else {
            completionHandler(-1)
        }
    }
    
    public func onDisplayDccConfirmation(for foreignTransactionAmount: String, foreignCurrencyCode: String, conversionRate: String, transactionCurrencyCode: String, completionHandlder: @escaping VPDDccInputCompletionHandler, errorHandler: @escaping VPDErrorHandler) {
        // Auto-confirm DCC
        completionHandlder(true)
    }
    
    // Pairing Confirmation
    public func onReturnPairingConfirmation(_ ledSequence: [Any]!, deviceName: String!, callback: (any VPDPairingConfirmationCallback)!) {
        print("[\(Self.TAG)] Pairing confirmation required for \(deviceName ?? "")")
        callback.confirm()
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    private func sendEvent(type: String, message: String?) {
        guard let sink = eventSink else { return }
        DispatchQueue.main.async {
            sink([
                "type": type,
                "message": message ?? ""
            ])
        }
    }
}