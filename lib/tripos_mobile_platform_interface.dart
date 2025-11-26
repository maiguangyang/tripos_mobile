import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'tripos_mobile_method_channel.dart';

abstract class TriposMobilePlatform extends PlatformInterface {
  TriposMobilePlatform() : super(token: _token);
  static final Object _token = Object();
  static TriposMobilePlatform _instance = MethodChannelTriposMobile();
  static TriposMobilePlatform get instance => _instance;
  static set instance(TriposMobilePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // 添加事件流：用于接收 "请插卡"、"连接成功" 等消息
  Stream<TriposEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  Future<void> initialize(TriposConfiguration config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<List<TriposDevice>> scanDevices() {
    throw UnimplementedError('scanDevices() has not been implemented.');
  }

  Future<bool> connectDevice(TriposDevice device) {
    throw UnimplementedError('connectDevice() has not been implemented.');
  }

  Future<PaymentResponse> processPayment(PaymentRequest request) {
    throw UnimplementedError('processPayment() has not been implemented.');
  }

  Future<bool> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

// 修正配置参数以匹配 SDK (PDF Page 30)
class TriposConfiguration {
  final String acceptorId;
  final String accountId;
  final String accountToken;
  final String applicationId; // e.g. "12345"
  final String applicationName; // e.g. "MyPosApp"
  final String applicationVersion; // e.g. "1.0.0"
  final bool isProduction; // Production vs Test mode

  // Store and Forward (Offline Payment) Configuration
  final String storeMode; // "Auto", "Manual", "Disabled"
  final double offlineAmountLimit; // Single transaction limit for offline
  final int retentionDays; // Days to retain offline transactions

  TriposConfiguration({
    required this.acceptorId,
    required this.accountId,
    required this.accountToken,
    this.applicationId = "12345",
    this.applicationName = "FlutterApp",
    this.applicationVersion = "1.0.0",
    this.isProduction = false, // Default to test mode for safety
    this.storeMode = "Auto", // Default to Auto mode
    this.offlineAmountLimit = 100.00, // Default $100 limit
    this.retentionDays = 7, // Default 7 days retention
  });

  Map<String, dynamic> toMap() {
    return {
      'acceptorId': acceptorId,
      'accountId': accountId,
      'accountToken': accountToken,
      'applicationId': applicationId,
      'applicationName': applicationName,
      'applicationVersion': applicationVersion,
      'isProduction': isProduction,
      'storeMode': storeMode,
      'offlineAmountLimit': offlineAmountLimit,
      'retentionDays': retentionDays,
    };
  }
}

// 定义事件模型
class TriposEvent {
  final String type; // 'message', 'error', 'connected'
  final String? message; // 显示给用户的文本，如 "请插卡"
  final Map<dynamic, dynamic>? data;

  TriposEvent({required this.type, this.message, this.data});
}

// TriposDevice, PaymentRequest, PaymentResponse 保持你原来的代码即可
class TriposDevice {
  final String name;
  final String identifier;
  TriposDevice({required this.name, required this.identifier});
  factory TriposDevice.fromMap(Map<dynamic, dynamic> map) {
    return TriposDevice(
      name: map['name'] as String? ?? 'Unknown',
      identifier: map['identifier'] as String? ?? '',
    );
  }
  Map<String, dynamic> toMap() => {'name': name, 'identifier': identifier};
}

class PaymentRequest {
  final double amount;

  PaymentRequest({required this.amount});

  Map<String, dynamic> toMap() => {'amount': amount};
}

class PaymentResponse {
  final String transactionId;
  final bool isApproved;
  final String? message;
  final String? authCode;
  final String? amount; // Authorized amount
  final String? rawResponse; // Raw SDK response for debugging
  final bool isOffline; // True if transaction was stored offline

  PaymentResponse({
    required this.transactionId,
    required this.isApproved,
    this.message,
    this.authCode,
    this.amount,
    this.rawResponse,
    this.isOffline = false,
  });

  factory PaymentResponse.fromMap(Map<dynamic, dynamic> map) {
    return PaymentResponse(
      transactionId: map['transactionId'] as String? ?? '',
      isApproved: map['isApproved'] as bool? ?? false,
      message: map['message'] as String?,
      authCode: map['authCode'] as String?,
      amount: map['amount'] as String?,
      rawResponse: map['rawResponse'] as String?,
      isOffline: map['isOffline'] as bool? ?? false,
    );
  }
}
