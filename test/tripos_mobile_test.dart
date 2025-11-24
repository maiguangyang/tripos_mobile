import 'package:flutter_test/flutter_test.dart';
import 'package:tripos_mobile/tripos_mobile.dart';
import 'package:tripos_mobile/tripos_mobile_platform_interface.dart';
import 'package:tripos_mobile/tripos_mobile_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTriposMobilePlatform
    with MockPlatformInterfaceMixin
    implements TriposMobilePlatform {
  @override
  Stream<TriposEvent> get events => const Stream.empty();

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> initialize(TriposConfiguration config) async {}

  @override
  Future<List<TriposDevice>> scanDevices() async => [];

  @override
  Future<bool> connectDevice(TriposDevice device) async => true;

  @override
  Future<PaymentResponse> processPayment(PaymentRequest request) async {
    return PaymentResponse(transactionId: 'test', isApproved: true);
  }

  @override
  Future<bool> disconnect() async {
    return true;
  }
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

  test('initialize with production mode', () async {
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    final config = TriposConfiguration(
      acceptorId: 'test_acceptor',
      accountId: 'test_account',
      accountToken: 'test_token',
      isProduction: true,
    );

    await expectLater(fakePlatform.initialize(config), completes);
  });

  test('scanDevices returns empty list', () async {
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    final devices = await fakePlatform.scanDevices();
    expect(devices, isEmpty);
  });

  test('connectDevice returns true', () async {
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    final device = TriposDevice(name: 'Test Device', identifier: '00:00:00:00');
    final result = await fakePlatform.connectDevice(device);
    expect(result, isTrue);
  });

  test('processPayment returns successful response', () async {
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    final request = PaymentRequest(amount: 10.50);
    final response = await fakePlatform.processPayment(request);

    expect(response.isApproved, isTrue);
    expect(response.transactionId, equals('test'));
  });

  test('disconnect returns true', () async {
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    final result = await fakePlatform.disconnect();
    expect(result, isTrue);
  });

  test('events stream is empty', () async {
    MockTriposMobilePlatform fakePlatform = MockTriposMobilePlatform();
    TriposMobilePlatform.instance = fakePlatform;

    expect(fakePlatform.events, emits(isEmpty));
  });
}
