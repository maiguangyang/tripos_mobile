import 'package:flutter_test/flutter_test.dart';
import 'package:tripos_mobile/tripos_mobile.dart';
import 'package:tripos_mobile/tripos_mobile_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTriposMobilePlatform
    with MockPlatformInterfaceMixin
    implements TriposMobilePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> getSdkVersion() => Future.value('1.0.0');

  @override
  Future<List<String>> scanBluetoothDevices(
    TriposConfiguration configuration,
  ) => Future.value(['MockDevice1', 'MockDevice2']);

  @override
  Future<bool> initialize(TriposConfiguration configuration) =>
      Future.value(true);

  @override
  Future<bool> isInitialized() => Future.value(true);

  @override
  Future<void> deinitialize() => Future.value();

  @override
  Future<SaleResponse> processSale(SaleRequest request) => Future.value(
    SaleResponse(
      isApproved: true,
      transactionStatus: TransactionStatus.approved,
    ),
  );

  @override
  Future<RefundResponse> processRefund(RefundRequest request) => Future.value(
    RefundResponse(
      isApproved: true,
      transactionStatus: TransactionStatus.approved,
    ),
  );

  @override
  Future<RefundResponse> processLinkedRefund(LinkedRefundRequest request) =>
      Future.value(
        RefundResponse(
          isApproved: true,
          transactionStatus: TransactionStatus.approved,
        ),
      );

  @override
  Future<VoidResponse> processVoid(VoidRequest request) => Future.value(
    VoidResponse(
      isApproved: true,
      transactionStatus: TransactionStatus.approved,
    ),
  );

  @override
  Future<AuthorizationResponse> processAuthorization(
    AuthorizationRequest request,
  ) => Future.value(
    AuthorizationResponse(
      isApproved: true,
      transactionStatus: TransactionStatus.approved,
    ),
  );

  @override
  Future<void> cancelTransaction() => Future.value();

  @override
  Future<DeviceInfo?> getDeviceInfo() => Future.value(null);

  @override
  Stream<VtpStatus> get statusStream => Stream.empty();

  @override
  Stream<DeviceEvent> get deviceEventStream => Stream.empty();

  // Store-and-Forward mock implementations
  @override
  Future<List<StoredTransactionRecord>> getStoredTransactions() =>
      Future.value([]);

  @override
  Future<StoredTransactionRecord?> getStoredTransactionByTpId(String tpId) =>
      Future.value(null);

  @override
  Future<List<StoredTransactionRecord>> getStoredTransactionsByState(
    StoredTransactionState state,
  ) => Future.value([]);

  @override
  Future<ForwardTransactionResponse> forwardTransaction(
    ForwardTransactionRequest request,
  ) => Future.value(const ForwardTransactionResponse(isApproved: true));

  @override
  Future<bool> deleteStoredTransaction(String tpId) => Future.value(true);

  // SDK/Device separation mock implementations
  @override
  Future<Map<String, dynamic>> initializeSdk(TriposConfiguration config) =>
      Future.value({'success': true, 'message': 'Mock SDK initialized'});

  @override
  Future<Map<String, dynamic>> connectDevice(
    String identifier, {
    DeviceType? deviceType,
  }) => Future.value({
    'success': true,
    'description': 'Mock Device',
    'model': 'Mock Model',
    'serialNumber': 'MOCK123',
  });

  @override
  Future<Map<String, dynamic>> disconnectDevice() =>
      Future.value({'success': true, 'message': 'Device disconnected'});

  @override
  Future<bool> isDeviceConnected() => Future.value(true);
}

void main() {
  final TriposMobilePlatform initialPlatform = TriposMobilePlatform.instance;

  test('$MethodChannelTriposMobile is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTriposMobile>());
  });

  test('getPlatformVersion', () async {
    TriposMobile triposMobilePlugin = TriposMobile();
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    expect(await triposMobilePlugin.getPlatformVersion(), '42');
  });

  test('scanBluetoothDevices returns mock devices', () async {
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    final config = TriposConfiguration(
      hostConfiguration: HostConfiguration(
        acceptorId: 'test',
        accountId: 'test',
        accountToken: 'test',
      ),
    );

    final devices = await fakePlatform.scanBluetoothDevices(config);
    expect(devices, ['MockDevice1', 'MockDevice2']);
  });

  test('initialize returns true', () async {
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    final config = TriposConfiguration(
      hostConfiguration: HostConfiguration(
        acceptorId: 'test',
        accountId: 'test',
        accountToken: 'test',
      ),
    );

    final result = await fakePlatform.initialize(config);
    expect(result, true);
  });

  // ============= Separated API Tests (NEW) =============

  group('SDK/Device Separation API', () {
    late MockTriposMobilePlatform fakePlatform;
    late TriposConfiguration testConfig;

    setUp(() {
      fakePlatform = MockTriposMobilePlatform();
      TriposMobilePlatform.instance = fakePlatform;
      testConfig = TriposConfiguration(
        hostConfiguration: HostConfiguration(
          acceptorId: 'test',
          accountId: 'test',
          accountToken: 'test',
        ),
      );
    });

    test('initializeSdk returns success', () async {
      final result = await fakePlatform.initializeSdk(testConfig);
      expect(result['success'], true);
      expect(result['message'], contains('initialized'));
    });

    test('connectDevice returns success with device info', () async {
      final result = await fakePlatform.connectDevice(
        'MOB55-12345',
        deviceType: DeviceType.ingenicoMoby5500,
      );
      expect(result['success'], true);
      expect(result['model'], isNotNull);
      expect(result['serialNumber'], isNotNull);
    });

    test('disconnectDevice returns success', () async {
      final result = await fakePlatform.disconnectDevice();
      expect(result['success'], true);
    });

    test('isDeviceConnected returns boolean', () async {
      final result = await fakePlatform.isDeviceConnected();
      expect(result, isA<bool>());
    });

    test('Full separated API flow', () async {
      // Step 1: Initialize SDK (without device)
      final initResult = await fakePlatform.initializeSdk(testConfig);
      expect(initResult['success'], true);

      // Step 2: Scan for devices (mock returns devices)
      final devices = await fakePlatform.scanBluetoothDevices(testConfig);
      expect(devices, isNotEmpty);

      // Step 3: Connect to device
      final connectResult = await fakePlatform.connectDevice(devices.first);
      expect(connectResult['success'], true);

      // Step 4: Check connection status
      final isConnected = await fakePlatform.isDeviceConnected();
      expect(isConnected, true);

      // Step 5: Disconnect device
      final disconnectResult = await fakePlatform.disconnectDevice();
      expect(disconnectResult['success'], true);
    });
  });
}
