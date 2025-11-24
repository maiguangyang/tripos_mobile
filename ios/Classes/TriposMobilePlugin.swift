import Flutter
import UIKit

// 注意：如果你已经导入了 Worldpay 的 SDK，请取消下面这行的注释
// import TriPOS

public class TriposMobilePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    // 用于保存 Flutter 传过来的 EventSink，用来给 Flutter 发消息（如：请插卡）
    var eventSink: FlutterEventSink?
    
    // 保存初始化配置
    var savedConfig: [String: String]?

    // 插件注册入口
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 1. 注册方法通道 (MethodChannel)
        let channel = FlutterMethodChannel(name: "tripos_mobile", binaryMessenger: registrar.messenger())
        
        // 2. 注册事件通道 (EventChannel)
        let eventChannel = FlutterEventChannel(name: "tripos_mobile/events", binaryMessenger: registrar.messenger())
        
        let instance = TriposMobilePlugin()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    // 处理来自 Flutter 的方法调用
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            
        // --- 1. 修复了这里：获取系统版本 ---
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "initialize":
            if let config = call.arguments as? [String: String] {
                self.savedConfig = config
                print("[iOS] TriPOS Initialized with: \(config["applicationId"] ?? "unknown")")
                result(nil) // 成功返回 null
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Configuration is null", details: nil))
            }
            
        case "scanDevices":
            // iOS 扫描通常需要 CBCentralManager
            // 这里模拟发现一个设备，防止报错
            let mockDevice = [
                "name": "Simulated Moby 5500",
                "identifier": "UUID-SIMULATED-1234"
            ]
            // 模拟延时
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                result([mockDevice])
            }
            
        case "connectDevice":
            guard let args = call.arguments as? [String: String],
                  let identifier = args["identifier"] else {
                result(FlutterError(code: "ARGS_ERROR", message: "Device identifier missing", details: nil))
                return
            }
            connectDevice(identifier: identifier, result: result)
            
        case "processPayment":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "ARGS_ERROR", message: "Payment arguments missing", details: nil))
                return
            }
            processPayment(args: args, result: result)
            
        case "disconnect":
            // 执行断开逻辑
            self.sendEvent(type: "disconnected", message: "Device disconnected")
            result(true)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 模拟连接逻辑
    func connectDevice(identifier: String, result: @escaping FlutterResult) {
        print("[iOS] Connecting to \(identifier)...")
        
        // 模拟连接耗时
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 1. 通知 Flutter 连接成功
            self.sendEvent(type: "connected", message: nil)
            // 2. 返回方法结果
            result(true)
        }
    }
    
    // MARK: - 模拟支付逻辑
    func processPayment(args: [String: Any], result: @escaping FlutterResult) {
        let amount = args["amount"] as? Double ?? 0.0
        print("[iOS] Processing payment for $\(amount)")
        
        // 1. 模拟 SDK 要求插卡 (通过 EventChannel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendEvent(type: "message", message: "请插入芯片卡 (Simulated)")
        }
        
        // 2. 模拟处理中
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.sendEvent(type: "message", message: "正在授权...")
        }
        
        // 3. 模拟交易完成 (返回最终结果给 MethodChannel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            let response: [String: Any] = [
                "isApproved": true,
                "authCode": "IOS_AUTH_01",
                "transactionId": "TRANS_UUID_\(Int(Date().timeIntervalSince1970))",
                "message": "Approved"
            ]
            result(response)
        }
    }
    
    // MARK: - EventChannel 代理方法
    // 当 Flutter 端开始监听 .events 时调用
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    // 当 Flutter 端取消监听时调用
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    // 辅助方法：发送事件给 Flutter
    func sendEvent(type: String, message: String?) {
        guard let sink = eventSink else { return }
        sink(["type": type, "message": message ?? ""])
    }
}