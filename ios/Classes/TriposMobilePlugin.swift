import Flutter
import UIKit
import CoreBluetooth

// TODO: Import triPOS SDK when available
// import triPOSMobileSDK

public class TriposMobilePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    // MARK: - Constants
    private static let TAG = "TriPOSMobile"
    
    // MARK: - State Management
    private var eventSink: FlutterEventSink?
    
    // triPOS SDK instance (to be used when real SDK is integrated)
    // private var sharedVTP: VTP?
    
    // Configuration storage
    private var savedHostConfig: [String: Any]?
    private var savedAppConfig: [String: Any]?
    private var isProductionMode: Bool = false
    private var connectedDevice: [String: String]?
    
    // Bluetooth manager for device scanning
    private var bluetoothManager: CBCentralManager?
    private var discoveredDevices: [[String: String]] = []
    private var scanCompletion: FlutterResult?
    
    // MARK: - Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tripos_mobile", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "tripos_mobile/events", binaryMessenger: registrar.messenger())
        
        let instance = TriposMobilePlugin()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
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
    
    // MARK: - Initialize SDK
    private func initializeSdk(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let config = call.arguments as? [String: Any] else {
            print("[\(Self.TAG)] Error: Configuration is null")
            result(FlutterError(code: "ARGS_ERROR", message: "Configuration is null", details: nil))
            return
        }
        
        print("[\(Self.TAG)] Initializing triPOS SDK...")
        
        // Validate required parameters
        guard let acceptorId = config["acceptorId"] as? String,
              let accountId = config["accountId"] as? String,
              let accountToken = config["accountToken"] as? String,
              !acceptorId.isEmpty,
              !accountId.isEmpty,
              !accountToken.isEmpty else {
            print("[\(Self.TAG)] Error: Missing required credentials")
            result(FlutterError(code: "INVALID_CONFIG", 
                               message: "Missing required credentials (acceptorId, accountId, or accountToken)", 
                               details: nil))
            return
        }
        
        // Get production mode
        isProductionMode = config["isProduction"] as? Bool ?? false
        print("[\(Self.TAG)] Production mode: \(isProductionMode)")
        
        // Save host configuration
        savedHostConfig = [
            "acceptorId": acceptorId,
            "accountId": accountId,
            "accountToken": accountToken,
            "applicationId": config["applicationId"] as? String ?? "12345",
            "applicationName": config["applicationName"] as? String ?? "FlutterPlugin",
            "applicationVersion": config["applicationVersion"] as? String ?? "1.0.0"
        ]
        
        // Save application configuration
        savedAppConfig = [
            "isProduction": isProductionMode
        ]
        
        print("[\(Self.TAG)] Host configuration created")
        print("[\(Self.TAG)] Application configuration created")
        
        // TODO: Initialize actual triPOS SDK when available
        // sharedVTP = VTP.shared()
        // Configure with savedHostConfig and savedAppConfig
        
        print("[\(Self.TAG)] SDK initialized successfully")
        result(nil)
    }
    
    // MARK: - Scan Devices
    private func scanDevices(result: @escaping FlutterResult) {
        print("[\(Self.TAG)] Scanning for devices...")
        
        // TODO: When real SDK is available, use SDK's device scanning
        // For now, simulate iOS Bluetooth scanning
        
        // Note: Bluetooth permissions are handled in Info.plist
        // NSBluetoothAlwaysUsageDescription or NSBluetoothPeripheralUsageDescription
        
        // Simulate finding devices (replace with real Bluetooth scan)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockDevices: [[String: String]] = [
                ["name": "Moby 5500", "identifier": "00:11:22:33:44:55"],
                ["name": "Ingenico RBA", "identifier": "AA:BB:CC:DD:EE:FF"]
            ]
            print("[\(Self.TAG)] Found \(mockDevices.count) devices")
            result(mockDevices)
        }
    }
    
    // MARK: - Connect Device
    private func connectDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let deviceMap = call.arguments as? [String: Any],
              let identifier = deviceMap["identifier"] as? String else {
            print("[\(Self.TAG)] Error: Device identifier missing")
            result(FlutterError(code: "ARGS_ERROR", message: "Device identifier missing", details: nil))
            return
        }
        
        let name = deviceMap["name"] as? String ?? "Unknown"
        print("[\(Self.TAG)] Connecting to device: \(name) (\(identifier))")
        
        // Simulate connection on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // TODO: Replace with actual SDK connection
            // Configure triPOS SDK with device settings
            // Handle Bluetooth vs TCP/IP connection
            
            // Simulate connection delay
            Thread.sleep(forTimeInterval: 1.5)
            
            // Simulate successful connection
            DispatchQueue.main.async {
                self.connectedDevice = ["name": name, "identifier": identifier]
                print("[\(Self.TAG)] Device connected: \(name)")
                self.sendEvent(type: "connected", message: "Connected to \(name)")
                result(true)
            }
        }
    }
    
    // MARK: - Process Payment
    private func processPayment(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard connectedDevice != nil else {
            print("[\(Self.TAG)] Error: No device connected")
            result(FlutterError(code: "SDK_ERROR", message: "SDK not initialized or device not connected", details: nil))
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let amount = args["amount"] as? Double else {
            print("[\(Self.TAG)] Error: Payment amount missing")
            result(FlutterError(code: "ARGS_ERROR", message: "Payment amount missing", details: nil))
            return
        }
        
        print("[\(Self.TAG)] Processing payment for amount: \(amount)")
        
        // TODO: Replace with actual SDK payment processing
        // Create SaleRequest with amount
        // Process through triPOS SDK
        // Use reflection to parse SaleResponse
        
        // Simulate payment flow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendEvent(type: "message", message: "请插入芯片卡")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.sendEvent(type: "message", message: "正在授权...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            // Simulate successful payment response
            let response: [String: Any] = [
                "isApproved": true,
                "authCode": "IOS_AUTH_\(Int.random(in: 1000...9999))",
                "transactionId": "TRANS_\(Int(Date().timeIntervalSince1970))",
                "message": "Approved",
                "amount": String(format: "%.2f", amount),
                "rawResponse": "Mock iOS response for amount: \(amount)"
            ]
            
            print("[\(Self.TAG)] Payment response: isApproved=\(response["isApproved"] ?? false)")
            result(response)
        }
    }
    
    // MARK: - Disconnect
    private func disconnect(result: @escaping FlutterResult) {
        print("[\(Self.TAG)] Disconnecting device...")
        
        // TODO: Replace with actual SDK disconnect
        // sharedVTP?.deinitialize()
        
        connectedDevice = nil
        sendEvent(type: "disconnected", message: "Device disconnected")
        
        print("[\(Self.TAG)] Device disconnected successfully")
        result(true)
    }
    
    // MARK: - Event Channel Handler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("[\(Self.TAG)] Event stream listener attached")
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("[\(Self.TAG)] Event stream listener cancelled")
        return nil
    }
    
    // MARK: - Helper Methods
    private func sendEvent(type: String, message: String?) {
        guard let sink = eventSink else {
            print("[\(Self.TAG)] Warning: No event sink available")
            return
        }
        
        let event: [String: Any?] = [
            "type": type,
            "message": message,
            "data": nil
        ]
        
        DispatchQueue.main.async {
            sink(event)
            print("[\(Self.TAG)] Event sent: type=\(type), message=\(message ?? "nil")")
        }
    }
}