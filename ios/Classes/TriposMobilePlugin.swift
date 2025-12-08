import Flutter
import UIKit
import CoreBluetooth
import triPOSMobileSDK

public class TriposMobilePlugin: NSObject, FlutterPlugin, FlutterStreamHandler, VTPDelegate, CBCentralManagerDelegate {
    
    // MARK: - Constants
    private static let TAG = "TriPOSMobile"
    
    // MARK: - State Management
    private var eventSink: FlutterEventSink?
    private var resultCallback: FlutterResult?
    
    // SDK Instance
    private var vtp: VTP?
    
    // Configuration storage
    private var savedHostConfig: VTPHostConfiguration?
    private var savedAppConfig: VTPApplicationConfiguration?
    private var savedStoreForwardConfig: VTPStoreAndForwardConfiguration?
    private var isProductionMode: Bool = false
    
    private var scanResult: FlutterResult?
    private var bluetoothManager: CBCentralManager?
    
    // MARK: - Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tripos_mobile", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "tripos_mobile/events", binaryMessenger: registrar.messenger())
        
        let instance = TriposMobilePlugin()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        
        // Initialize VTP instance
        instance.vtp = triPOSMobileSDK.sharedVtp() as? VTP
        
        if let vtp = instance.vtp {
            vtp.add(instance)
            // Note: VTPDeviceInteractionDelegate removed due to protocol conformance issues
            // SDK will use default behavior for device interactions
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
        
        guard let acceptorId = configMap["acceptorId"] as? String, !acceptorId.isEmpty,
              let accountId = configMap["accountId"] as? String, !accountId.isEmpty,
              let accountToken = configMap["accountToken"] as? String, !accountToken.isEmpty else {
            result(FlutterError(code: "INVALID_CONFIG", message: "Missing required credentials", details: nil))
            return
        }
        
        print("[\(Self.TAG)] Initializing triPOS SDK...")
        
        let hostConfig = VTPHostConfiguration()
        hostConfig.acceptorId = acceptorId
        hostConfig.accountId = accountId
        hostConfig.accountToken = accountToken
        hostConfig.applicationId = configMap["applicationId"] as? String ?? "12345"
        hostConfig.applicationName = configMap["applicationName"] as? String ?? "FlutterPlugin"
        hostConfig.applicationVersion = configMap["applicationVersion"] as? String ?? "1.0.0"
        
        let appConfig = VTPApplicationConfiguration()
        isProductionMode = configMap["isProduction"] as? Bool ?? false
        appConfig.mode = isProductionMode ? VTPApplicationModeProduction : VTPApplicationModeTestCertification
        
        // Store and Forward - using reflection for safety
        let storeModeStr = configMap["storeMode"] as? String ?? "Auto"
        let offlineLimitDouble = configMap["offlineAmountLimit"] as? Double ?? 100.00
        let retentionDays = configMap["retentionDays"] as? Int ?? 7
        
        let sfConfig = VTPStoreAndForwardConfiguration()
        
        // Use reflection to safely set enum value (avoid compilation errors)
        let storeModeMapping: [String: Int] = [
            "Auto": 0,
            "Manual": 1,
            "Disabled": 2
        ]
        
        if let modeValue = storeModeMapping[storeModeStr] {
            sfConfig.setValue(modeValue, forKey: "transactionStoringMode")
        }
        
        sfConfig.transactionAmountLimit = UInt(offlineLimitDouble)
        sfConfig.numberOfDaysToRetainProcessedTransactions = UInt(retentionDays)
        
        self.savedHostConfig = hostConfig
        self.savedAppConfig = appConfig
        self.savedStoreForwardConfig = sfConfig
        
        do {
            try internalInitialize()
            if let vtp = self.vtp, vtp.isInitialized {
                print("[\(Self.TAG)] SDK Initialized successfully")
                result(true)
            } else {
                result(FlutterError(code: "INIT_FAILED", message: "SDK Initialization failed", details: nil))
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
        if let sfConfig = savedStoreForwardConfig {
            vtpConfig.storeAndForwardConfiguration = sfConfig
        }
        try vtp?.initialize(with: vtpConfig)
    }
    
    // MARK: - 2. Scan Devices
    private func scanDevices(result: @escaping FlutterResult) {
        if bluetoothManager == nil {
            bluetoothManager = CBCentralManager(delegate: self, queue: nil)
        }
        
        if let manager = bluetoothManager {
            if manager.state == .poweredOff {
                result(FlutterError(code: "BT_OFF", message: "Bluetooth is not enabled", details: nil))
                return
            }
            if manager.state == .unauthorized {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Bluetooth permission denied", details: nil))
                return
            }
        }

        guard let hostConfig = self.savedHostConfig else {
            result(FlutterError(code: "SDK_ERROR", message: "SDK not initialized", details: nil))
            return
        }
        
        self.scanResult = result

        let scanConfig = VTPConfiguration()
        scanConfig.hostConfiguration = hostConfig
        if let appConfig = self.savedAppConfig {
            scanConfig.applicationConfiguration = appConfig
        }
        
        let deviceConfig = VTPDeviceConfiguration()
        deviceConfig.deviceType = VTPDeviceTypeIngenicoMobyBluetooth
        scanConfig.deviceConfiguration = deviceConfig
        
        print("[\(Self.TAG)] Starting SDK Bluetooth Scan...")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let vtp = self.vtp else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SDK_ERROR", message: "VTP instance is nil", details: nil))
                        self.scanResult = nil
                    }
                    return
                }
                if vtp.isConnectedToDevice {
                    try? vtp.closeSession()
                }
                try vtp.scanForDevices(with: scanConfig)
            } catch {
                let nsError = error as NSError
                DispatchQueue.main.async {
                    if nsError.code == 2147483647 {
                        try? self.vtp?.deinitialize()
                        result(FlutterError(code: "SDK_BUSY", message: "SDK was busy, please try again", details: nil))
                    } else {
                        result(FlutterError(code: "SCAN_ERROR", message: error.localizedDescription, details: nil))
                    }
                    self.scanResult = nil
                }
            }
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
        let connectionInfo = VTPDeviceConnectionInfo()
        
        if isIp {
            connectionInfo.deviceType = VTPDeviceTypeIngenicoUppTcpIp
            let tcpConfig = VTPDeviceTcpIpConfiguration()
            tcpConfig.ipAddress = identifier
            tcpConfig.port = 12000
            connectionInfo.tcpIpConfiguration = tcpConfig
        } else {
            connectionInfo.deviceType = VTPDeviceTypeIngenicoMobyBluetooth
            connectionInfo.identifier = identifier
        }
        
        do {
            try vtp?.startSession(with: connectionInfo)
            result(true)
        } catch {
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
        
        let saleRequest = VTPSaleRequest()
        saleRequest.transactionAmount = NSDecimalNumber(value: amountDouble)
        saleRequest.referenceNumber = "TRANS_\(Int(Date().timeIntervalSince1970))"
        
        vtp?.processSaleRequest(saleRequest, completionHandler: { [weak self] (response: VTPSaleResponse?) in
            guard let self = self else { return }
            
            if let resp = response {
                let resultMap = self.parsePaymentResponse(response: resp)
                self.resultCallback?(resultMap)
            } else {
                self.resultCallback?(FlutterError(code: "UNKNOWN", message: "No response", details: nil))
            }
            self.resultCallback = nil
        }, errorHandler: { [weak self] (error: Error?) in
            guard let self = self else { return }
            let errorMsg = error?.localizedDescription ?? "Unknown error"
            self.resultCallback?(FlutterError(code: "SALE_ERROR", message: errorMsg, details: nil))
            self.resultCallback = nil
        })
    }
    
    private func parsePaymentResponse(response: VTPSaleResponse) -> [String: Any] {
        var isApproved = false
        if response.transactionStatus == VTPTransactionStatusApproved {
            isApproved = true
        }
        
        var isStored = false
        if let storedVal = response.value(forKey: "isStored") as? Bool {
            isStored = storedVal
        }
        if isStored { isApproved = true }
        
        let authCode = response.host?.approvalNumber ?? ""
        let transactionId = response.host?.transactionID ?? ""
        let message = isStored ? "Stored Offline" : (isApproved ? "Approved" : "Declined")
        let amount = response.approvedAmount?.stringValue ?? "0.00"
        
        return [
            "isApproved": isApproved,
            "authCode": authCode,
            "transactionId": transactionId,
            "message": message,
            "amount": amount,
            "isOffline": isStored,
            "rawResponse": response.description
        ]
    }
    
    // MARK: - 5. Disconnect
    private func disconnect(result: @escaping FlutterResult) {
        do {
            try vtp?.closeSession()
            result(true)
        } catch {
            result(FlutterError(code: "DISCONNECT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - VTPDelegate (General)
    public func onReturnBluetoothScanResults(_ devices: [Any]!) {
        print("[\(Self.TAG)] Scan completed, found \(devices?.count ?? 0) devices")
        var devicesList: [[String: String]] = []

        // 支付设备名称关键词列表（与 Android 完全一致）
        let paymentDeviceKeywords = [
            "mob", "ingenico", "icmp", "lane", "tablet",
            "vantiv", "worldpay", "tripos", "rba", "rua"
        ]
        
        if let foundDevices = devices {
            for item in foundDevices {
                if let deviceObj = item as? NSObject {
                    let identifier = deviceObj.value(forKey: "identifier") as? String ?? ""
                    var name = deviceObj.value(forKey: "description") as? String 
                    if name == nil { name = deviceObj.value(forKey: "name") as? String }
                    if name == nil { name = "Unknown Device" }

                    // 过滤：只保留支付设备（与 Android 逻辑一致）
                    let isPaymentDevice = paymentDeviceKeywords.contains { keyword in
                        name!.lowercased().contains(keyword)
                    }

                    if !identifier.isEmpty && isPaymentDevice {
                        devicesList.append(["name": name!, "identifier": identifier])
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            if let callback = self.scanResult {
                callback(devicesList)
                self.scanResult = nil
            }
        }
    }
    
    public func deviceDidConnect(_ description: String!, model: String!, serialNumber: String!, firmwareVersion: String!, configurationVersion: String!, batteryPercentage: String!, batteryLevel: String!) {
        let msg = "Device Connected: \(model ?? "") (\(serialNumber ?? ""))"
        print("[\(Self.TAG)] \(msg)")
        sendEvent(type: "connected", message: msg)
    }
    
    public func deviceDidDisconnect() {
        sendEvent(type: "disconnected", message: "Device Disconnected")
    }
    
    public func deviceDidError(_ error: Error!) {
        sendEvent(type: "error", message: error.localizedDescription)
    }
    
    public func deviceInitialization(inProgress currentProgress: Double, description: String!, model: String!, serialNumber: String!, initializationStatus: VTPInitializationStatus) {
        var statusStr = "Initializing"
        switch initializationStatus {
        case VTPInitializationStatusUpdatingFirmware: statusStr = "Updating Firmware"
        case VTPInitializationStatusUpdatingFiles: statusStr = "Updating Files"
        case VTPInitializationStatusConfiguringEmv: statusStr = "Configuring EMV"
        case VTPInitializationStatusRebootingDevice: statusStr = "Rebooting Device"
        default: statusStr = "Processing..."
        }
        let msg = String(format: "%@ (%.0f%%)", statusStr, currentProgress * 100)
        sendEvent(type: "message", message: msg)
    }
    
    // MARK: - VTPDeviceInteractionDelegate (Fixing Protocol Conformance)
    
    // 1. Amount Confirmation
    // 修复：参数类型改为 String! (对应 Obj-C 中的 "Description")
    @objc public func onAmountConfirmation(_ amountConfirmationType: String!, amount: NSDecimalNumber!, completionHandler: @escaping VPDYesNoInputCompletionHandler) {
        print("[\(Self.TAG)] Confirming amount: \(amount ?? 0) Type: \(amountConfirmationType ?? "")")
        // Auto-confirm
        completionHandler(true)
    }
    
    // 2. Choice Selection
    @objc public func onChoiceSelections(_ choices: [Any]!, selectionType: VTPSelectionType, completionHandler: @escaping VPDChoiceInputCompletionHandler) {
        completionHandler(0)
    }
    
    // 3. Numeric Input
    // 注意：numericInputType 是枚举
    @objc public func onNumericInput(_ numericInputType: VTPNumericInputType, completionHandler: @escaping VPDKeyboardNumericInputCompletionHandler) {
        completionHandler("")
    }
    
    // 4. Select Application
    @objc public func onSelectApplication(_ applications: [Any]!, completionHandler: @escaping VPDChoiceInputCompletionHandler) {
        completionHandler(0)
    }
    
    // 5. Display Text
    @objc public func onDisplayText(_ text: String!) {
        sendEvent(type: "message", message: text)
    }
    
    // 5.1 Display Text with Identifier (Overload that might be required)
    @objc public func onDisplayText(_ text: String!, identifier: VTPTextIdentifier) {
        sendEvent(type: "message", message: text)
    }
    
    // 6. Prompt User
    @objc public func onPromptUserForCard(_ prompt: String!) {
        sendEvent(type: "message", message: prompt ?? "Insert/Swipe Card")
    }
    
    // 6.1 Prompt with Barcode (可能需要实现)
    @objc public func onPromptUserForCard(withBarcode prompt: String!, barcodePrompt: String!) {
        sendEvent(type: "message", message: prompt ?? "Scan Barcode")
    }
    
    // 7. Remove Card
    @objc public func onRemoveCard() {
        sendEvent(type: "message", message: "Remove Card")
    }
    
    @objc public func onCardRemoved() {
        sendEvent(type: "message", message: "Card Removed")
    }
    
    // 8. Pairing Confirmation
    @objc public func onReturnPairingConfirmation(_ ledSequence: [Any]!, deviceName: String!, callback: (any VPDPairingConfirmationCallback)!) {
        print("[\(Self.TAG)] Confirming pairing for \(deviceName ?? "")")
        callback.confirm()
    }
    
    // 9. Wait
    @objc public func onWait(_ message: String!) {
        sendEvent(type: "message", message: message)
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
            sink(["type": type, "message": message ?? ""])
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}