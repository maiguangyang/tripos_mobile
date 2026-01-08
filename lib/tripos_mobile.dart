/// triPOS Mobile SDK Flutter Plugin
///
/// A Flutter plugin for integrating Worldpay triPOS Mobile Android SDK
/// for payment processing with Bluetooth card readers.
library tripos_mobile;

export 'models/configuration.dart';
export 'models/enums.dart';
export 'models/requests.dart';
export 'models/responses.dart';
export 'tripos_mobile_platform_interface.dart';

import 'models/configuration.dart';
import 'models/enums.dart';
import 'models/requests.dart';
import 'models/responses.dart';
import 'tripos_mobile_platform_interface.dart';

/// Main triPOS Mobile SDK plugin class
///
/// Use this class to interact with the triPOS Mobile SDK for payment processing.
///
/// Example:
/// ```dart
/// final tripos = TriposMobile();
///
/// // Configure the SDK
/// final config = TriposConfiguration(
///   hostConfiguration: HostConfiguration(
///     acceptorId: 'your_acceptor_id',
///     accountId: 'your_account_id',
///     accountToken: 'your_token',
///   ),
/// );
///
/// // Scan for Bluetooth devices
/// final devices = await tripos.scanBluetoothDevices(config);
///
/// // Update config with selected device
/// final updatedConfig = config.copyWith(
///   deviceConfiguration: config.deviceConfiguration.copyWith(
///     identifier: devices.first,
///   ),
/// );
///
/// // Initialize SDK
/// await tripos.initialize(updatedConfig);
///
/// // Process a sale
/// final response = await tripos.processSale(
///   SaleRequest(transactionAmount: 10.00),
/// );
/// ```
class TriposMobile {
  /// Get platform version
  Future<String?> getPlatformVersion() {
    return TriposMobilePlatform.instance.getPlatformVersion();
  }

  /// Get SDK version
  Future<String?> getSdkVersion() {
    return TriposMobilePlatform.instance.getSdkVersion();
  }

  /// Scan for available Bluetooth devices
  ///
  /// Returns a list of device identifiers (e.g., "MOB55-12345")
  Future<List<String>> scanBluetoothDevices(TriposConfiguration configuration) {
    return TriposMobilePlatform.instance.scanBluetoothDevices(configuration);
  }

  /// Initialize the SDK with the provided configuration
  ///
  /// Returns true if initialization was successful
  Future<bool> initialize(TriposConfiguration configuration) {
    return TriposMobilePlatform.instance.initialize(configuration);
  }

  /// Check if the SDK is currently initialized
  Future<bool> isInitialized() {
    return TriposMobilePlatform.instance.isInitialized();
  }

  /// Deinitialize the SDK and release resources
  Future<void> deinitialize() {
    return TriposMobilePlatform.instance.deinitialize();
  }

  /// Process a sale transaction
  ///
  /// Initiates a card payment for the specified amount.
  /// The user will be prompted to insert/swipe/tap their card.
  Future<SaleResponse> processSale(SaleRequest request) {
    return TriposMobilePlatform.instance.processSale(request);
  }

  /// Process a refund transaction
  ///
  /// Initiates a refund for the specified amount.
  Future<RefundResponse> processRefund(RefundRequest request) {
    return TriposMobilePlatform.instance.processRefund(request);
  }

  /// Process a linked refund (no card required)
  ///
  /// Uses the original transaction ID to refund.
  /// No card swipe/insert/tap needed.
  Future<RefundResponse> processLinkedRefund(LinkedRefundRequest request) {
    return TriposMobilePlatform.instance.processLinkedRefund(request);
  }

  /// Process a void transaction
  ///
  /// Voids a previous transaction by its transaction ID.
  Future<VoidResponse> processVoid(VoidRequest request) {
    return TriposMobilePlatform.instance.processVoid(request);
  }

  /// Process an authorization transaction
  ///
  /// Authorizes a card payment without capturing the funds.
  Future<AuthorizationResponse> processAuthorization(
    AuthorizationRequest request,
  ) {
    return TriposMobilePlatform.instance.processAuthorization(request);
  }

  /// Cancel the current transaction in progress
  Future<void> cancelTransaction() {
    return TriposMobilePlatform.instance.cancelTransaction();
  }

  /// Get information about the connected device
  Future<DeviceInfo?> getDeviceInfo() {
    return TriposMobilePlatform.instance.getDeviceInfo();
  }

  /// Create a token (Omnitoken) without processing a sale
  ///
  /// This method is used for "Tokenize Only" flow.
  /// The user will be prompted to insert/swipe/tap their card.
  /// The returned token can be used for blacklist checks or future transactions.
  Future<CreateTokenResponse> createToken(CreateTokenRequest request) {
    return TriposMobilePlatform.instance.createToken(request);
  }

  /// Process a sale using a previously created token
  ///
  /// Uses the token ID instead of reading the card again.
  /// Used after [createToken] when the token is validated.
  Future<SaleWithTokenResponse> processSaleWithToken(
    SaleWithTokenRequest request,
  ) {
    return TriposMobilePlatform.instance.processSaleWithToken(request);
  }

  /// Stream of transaction status updates
  ///
  /// Listen to this stream to receive real-time updates during
  /// transaction processing. Returns VtpStatus enum values.
  Stream<VtpStatus> get statusStream {
    return TriposMobilePlatform.instance.statusStream;
  }

  /// Stream of device connection events
  ///
  /// Listen to this stream to receive device connection/disconnection events.
  Stream<DeviceEvent> get deviceEventStream {
    return TriposMobilePlatform.instance.deviceEventStream;
  }
}
