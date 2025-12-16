import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models/configuration.dart';
import 'models/enums.dart';
import 'models/requests.dart';
import 'models/responses.dart';
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
  /// platform-specific class that extends [TriposMobilePlatform].
  static set instance(TriposMobilePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Get platform version
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
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
  Future<bool> initialize(TriposConfiguration configuration) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Check if SDK is initialized
  Future<bool> isInitialized() {
    throw UnimplementedError('isInitialized() has not been implemented.');
  }

  /// Deinitialize the SDK
  Future<void> deinitialize() {
    throw UnimplementedError('deinitialize() has not been implemented.');
  }

  /// Process a sale transaction
  Future<SaleResponse> processSale(SaleRequest request) {
    throw UnimplementedError('processSale() has not been implemented.');
  }

  /// Process a refund transaction
  Future<RefundResponse> processRefund(RefundRequest request) {
    throw UnimplementedError('processRefund() has not been implemented.');
  }

  /// Process a linked refund (using original transaction ID, no card required)
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

  /// Cancel the current transaction
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
}
