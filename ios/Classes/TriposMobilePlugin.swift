import Flutter
import UIKit
import CoreBluetooth
import triPOSMobileSDK

public class TriposMobilePlugin: NSObject, FlutterPlugin, FlutterStreamHandler, VTPDelegate, VTPDeviceInteractionDelegate, CBCentralManagerDelegate {
    
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
    private var savedStoreForwardConfig: VTPStoreAndForwardConfiguration?
    private var isProductionMode: Bool = false
    
    // Device Scanning
    private var scanResult: FlutterResult?
    
    // Bluetooth Manager for status checking
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
        
        // Note: Store and Forward configuration removed due to iOS SDK API uncertainties
        // If needed, it can be added later with correct iOS SDK enumeration names
        
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
        
        // Apply Store and Forward configuration
        if let storeForwardConfig = savedStoreForwardConfig {
            vtpConfig.storeAndForwardConfiguration = storeForwardConfig
        }
        
        try vtp?.initialize(with: vtpConfig)
    }
    
    // MARK: - 2. Scan Devices (Updated to match Android logic)
    private func scanDevices(result: @escaping FlutterResult) {
        // 1. 检查蓝牙权限和状态 (对应 Android 的 Permission & Adapter check)
        // iOS 的权限状态由 CBCentralManager 管理
        if bluetoothManager == nil {
            bluetoothManager = CBCentralManager(delegate: self, queue: nil)
            // Manager 初始化需要时间，暂时无法立即检查状态，
            // 但如果蓝牙未授权，后续 SDK 调用会失败或系统会弹窗
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

        // 2. 检查 SDK 是否初始化 (对应 Android 的 sharedVtp == null)
        guard let hostConfig = self.savedHostConfig else {
            result(FlutterError(code: "SDK_ERROR", message: "SDK not initialized", details: nil))
            return
        }
        
        self.scanResult = result

        // 3. 准备配置 (对应 Android 的 config setup)
        let scanConfig = VTPConfiguration()
        scanConfig.hostConfiguration = hostConfig
        
        if let appConfig = self.savedAppConfig {
            scanConfig.applicationConfiguration = appConfig
        }
        
        // 4. 关键配置：指定设备类型 (对应 Android 的 deviceConfig.setDeviceType)
        // 必须指定扫描 Moby (RUA) 蓝牙设备，否则 SDK 不知道扫什么
        let deviceConfig = VTPDeviceConfiguration()
        deviceConfig.deviceType = VTPDeviceTypeIngenicoMobyBluetooth // Moby 5500 对应类型
        scanConfig.deviceConfiguration = deviceConfig
        
        print("[\(Self.TAG)] Starting SDK Bluetooth Scan with device type: IngenicoMobyBluetooth...")

        // 5. 在后台线程调用 SDK (对应 Android 的 Thread { ... }.start())
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let vtp = self.vtp else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SDK_ERROR", message: "VTP instance is nil", details: nil))
                        self.scanResult = nil
                    }
                    return
                }
                
                // 如果之前有连接，为了保险起见先清理状态（可选，参考之前的逻辑）
                if vtp.isConnectedToDevice {
                    try? vtp.closeSession()
                }
                
                // 调用扫描
                try vtp.scanForDevices(with: scanConfig)
                
                // 注意：iOS SDK 扫描是异步的，不会立即返回结果
                // 结果会在 onReturnBluetoothScanResults 代理方法中回调
                
            } catch {
                let nsError = error as NSError
                
                // 切换回主线程报错
                DispatchQueue.main.async {
                    print("[\(Self.TAG)] Scan Failed: \(error)")
                    
                    // 处理 "Already Connected" 特殊错误 (Code 2147483647)
                    if nsError.code == 2147483647 {
                        // 尝试重置后重试 (简略版)
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
        
        // Check if transaction was stored offline
        var isOffline = false
        if let stored = response.value(forKey: "isStored") as? Bool {
            isOffline = stored
        }
        
        if isOffline {
            print("[\(Self.TAG)] ⚠️ Transaction stored offline - will be forwarded when connection available")
        }
        
        return [
            "isApproved": isApproved,
            "authCode": authCode,
            "transactionId": transactionId,
            "message": message,
            "amount": amount,
            "isOffline": isOffline,
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
    
    // MARK: - VTPDelegate Scan Callback
    
    // 对应 Android 的 onScanRequestCompleted
    public func onReturnBluetoothScanResults(_ devices: [Any]!) {
        print("[\(Self.TAG)] Scan completed, found \(devices?.count ?? 0) devices")
        
        var devicesList: [[String: String]] = []
        
        // 支付设备名称关键词列表（与 Android 完全一致）
        let paymentDeviceKeywords = [
            "moby", "ingenico", "icmp", "lane", "tablet",
            "vantiv", "worldpay", "tripos", "rba", "rua"
        ]
        
        if let foundDevices = devices {
            for item in foundDevices {
                // iOS SDK 返回的通常是对象，我们尝试解析它
                if let deviceObj = item as? NSObject {
                    // 获取 Identifier (iOS 上是 UUID)
                    let identifier = deviceObj.value(forKey: "identifier") as? String ?? ""
                    
                    // 获取 Name (通常在 description 或 deviceName 属性中)
                    var name = deviceObj.value(forKey: "description") as? String 
                    
                    if name == nil || name!.isEmpty {
                        // 尝试备用字段
                        name = deviceObj.value(forKey: "name") as? String
                    }
                    
                    if name == nil || name!.isEmpty {
                        name = "Unknown Device"
                    }
                    
                    // 过滤：只保留支付设备（与 Android 逻辑一致）
                    let isPaymentDevice = paymentDeviceKeywords.contains { keyword in
                        name!.lowercased().contains(keyword)
                    }
                    
                    if !identifier.isEmpty && isPaymentDevice {
                        devicesList.append([
                            "name": name!,
                            "identifier": identifier
                        ])
                        print("[\(Self.TAG)] ✓ Payment device found: \(name!) (\(identifier))")
                    } else if !identifier.isEmpty {
                        print("[\(Self.TAG)] ✗ Filtered out non-payment device: \(name!)")
                    }
                }
            }
        }
        
        // 确保在主线程回调 Flutter
        DispatchQueue.main.async {
            if let callback = self.scanResult {
                print("[\(Self.TAG)] Returning \(devicesList.count) payment devices (filtered from \(devices?.count ?? 0) total)")
                callback(devicesList)
                self.scanResult = nil // 清空回调防止重复调用
            }
        }
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
    
    // MARK: - CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Required method for CBCentralManagerDelegate conformance
        // We use this to check Bluetooth state before scanning
    }
}