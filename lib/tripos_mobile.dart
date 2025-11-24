import 'tripos_mobile_platform_interface.dart';

class TriposMobile {
  Future<String?> getPlatformVersion() {
    return TriposMobilePlatform.instance.getPlatformVersion();
  }

  Future<void> initialize(TriposConfiguration config) {
    return TriposMobilePlatform.instance.initialize(config);
  }

  Future<List<TriposDevice>> scanDevices() {
    return TriposMobilePlatform.instance.scanDevices();
  }

  Future<bool> connectDevice(TriposDevice device) {
    return TriposMobilePlatform.instance.connectDevice(device);
  }

  Future<PaymentResponse> processPayment(PaymentRequest request) {
    return TriposMobilePlatform.instance.processPayment(request);
  }
}
