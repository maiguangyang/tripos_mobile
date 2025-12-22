import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models/configuration.dart';
import 'models/enums.dart';
import 'models/requests.dart';
import 'models/responses.dart';
import 'models/stored_transaction.dart';
import 'tripos_mobile_method_channel.dart';

/// Platform interface for triPOS Mobile SDK
abstract class TriposMobilePlatform extends PlatformInterface {
  /// Constructs a TriposMobilePlatform.
  TriposMobilePlatform() : super(token: _token);

  static final Object _token = Object();

  static TriposMobilePlatform _instance = MethodChannelTriposMobile();

  /// The default instance of [TriposMobilePlatform] to use.
  static TriposMobilePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TriposMobilePlatform] when
  /// they register themselves.
  static set instance(TriposMobilePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Get SDK version
  Future<String?> getSdkVersion() {
    throw UnimplementedError('getSdkVersion() has not been implemented.');
  }

  /// Scan for Bluetooth devices
  Future<List<String>> scanBluetoothDevices(TriposConfiguration configuration) {
    throw UnimplementedError(
      'scanBluetoothDevices() has not been implemented.',
    );
  }

  /// Initialize the SDK with configuration
  Future<bool> initialize(TriposConfiguration config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  // ===== NEW: Separated SDK Initialization and Device Connection =====

  /// Initialize SDK only (without connecting to a device).
  /// Call this before scanBluetoothDevices() and connectDevice().
  Future<Map<String, dynamic>> initializeSdk(TriposConfiguration config) {
    throw UnimplementedError('initializeSdk() has not been implemented.');
  }

  /// Connect to a specific device after SDK has been initialized.
  /// [identifier] is the Bluetooth address of the device.
  /// [deviceType] is optional, defaults to detecting from configuration.
  Future<Map<String, dynamic>> connectDevice(
    String identifier, {
    DeviceType? deviceType,
  }) {
    throw UnimplementedError('connectDevice() has not been implemented.');
  }

  /// Disconnect from current device without deinitializing SDK.
  /// SDK remains ready and can connect to another device.
  Future<Map<String, dynamic>> disconnectDevice() {
    throw UnimplementedError('disconnectDevice() has not been implemented.');
  }

  /// Check if a device is currently connected
  Future<bool> isDeviceConnected() {
    throw UnimplementedError('isDeviceConnected() has not been implemented.');
  }

  /// Deinitialize the SDK
  Future<void> deinitialize() {
    throw UnimplementedError('deinitialize() has not been implemented.');
  }

  /// Check if SDK is initialized
  Future<bool> isInitialized() {
    throw UnimplementedError('isInitialized() has not been implemented.');
  }

  /// Process a sale transaction
  Future<SaleResponse> processSale(SaleRequest request) {
    throw UnimplementedError('processSale() has not been implemented.');
  }

  /// Process a refund transaction (card required)
  Future<RefundResponse> processRefund(RefundRequest request) {
    throw UnimplementedError('processRefund() has not been implemented.');
  }

  /// Process a linked refund transaction (no card required)
  Future<RefundResponse> processLinkedRefund(LinkedRefundRequest request) {
    throw UnimplementedError('processLinkedRefund() has not been implemented.');
  }

  /// Process a void transaction
  Future<VoidResponse> processVoid(VoidRequest request) {
    throw UnimplementedError('processVoid() has not been implemented.');
  }

  /// Process an authorization transaction
  Future<AuthorizationResponse> processAuthorization(
    AuthorizationRequest request,
  ) {
    throw UnimplementedError(
      'processAuthorization() has not been implemented.',
    );
  }

  /// Cancel current transaction
  Future<void> cancelTransaction() {
    throw UnimplementedError('cancelTransaction() has not been implemented.');
  }

  /// Get connected device information
  Future<DeviceInfo?> getDeviceInfo() {
    throw UnimplementedError('getDeviceInfo() has not been implemented.');
  }

  /// Stream of transaction status updates
  Stream<VtpStatus> get statusStream {
    throw UnimplementedError('statusStream has not been implemented.');
  }

  /// Stream of device connection events
  Stream<DeviceEvent> get deviceEventStream {
    throw UnimplementedError('deviceEventStream has not been implemented.');
  }

  // ==================== Store-and-Forward Methods ====================

  /// 获取所有离线存储交易
  Future<List<StoredTransactionRecord>> getStoredTransactions() {
    throw UnimplementedError(
      'getStoredTransactions() has not been implemented.',
    );
  }

  /// 按 tpId 获取单个离线交易
  Future<StoredTransactionRecord?> getStoredTransactionByTpId(String tpId) {
    throw UnimplementedError(
      'getStoredTransactionByTpId() has not been implemented.',
    );
  }

  /// 按状态获取离线交易列表
  Future<List<StoredTransactionRecord>> getStoredTransactionsByState(
    StoredTransactionState state,
  ) {
    throw UnimplementedError(
      'getStoredTransactionsByState() has not been implemented.',
    );
  }

  /// 手动转发离线交易
  Future<ForwardTransactionResponse> forwardTransaction(
    ForwardTransactionRequest request,
  ) {
    throw UnimplementedError('forwardTransaction() has not been implemented.');
  }

  /// 删除离线存储交易
  Future<bool> deleteStoredTransaction(String tpId) {
    throw UnimplementedError(
      'deleteStoredTransaction() has not been implemented.',
    );
  }
}
