import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/configuration.dart';
import 'models/requests.dart';
import 'models/responses.dart';
import 'tripos_mobile_platform_interface.dart';

/// Method channel implementation of [TriposMobilePlatform]
class MethodChannelTriposMobile extends TriposMobilePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('tripos_mobile');

  /// Event channel for status updates
  @visibleForTesting
  final statusEventChannel = const EventChannel('tripos_mobile/status');

  /// Event channel for device events
  @visibleForTesting
  final deviceEventChannel = const EventChannel('tripos_mobile/device');

  Stream<String>? _statusStream;
  Stream<Map<String, dynamic>>? _deviceEventStream;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<String?> getSdkVersion() async {
    final version = await methodChannel.invokeMethod<String>('getSdkVersion');
    return version;
  }

  @override
  Future<List<String>> scanBluetoothDevices(
    TriposConfiguration configuration,
  ) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'scanBluetoothDevices',
      configuration.toMap(),
    );
    return result?.cast<String>() ?? [];
  }

  @override
  Future<bool> initialize(TriposConfiguration configuration) async {
    final result = await methodChannel.invokeMethod<bool>(
      'initialize',
      configuration.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<bool> isInitialized() async {
    final result = await methodChannel.invokeMethod<bool>('isInitialized');
    return result ?? false;
  }

  @override
  Future<void> deinitialize() async {
    await methodChannel.invokeMethod<void>('deinitialize');
  }

  @override
  Future<SaleResponse> processSale(SaleRequest request) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'processSale',
      request.toMap(),
    );
    return SaleResponse.fromMap(Map<String, dynamic>.from(result ?? {}));
  }

  @override
  Future<RefundResponse> processRefund(RefundRequest request) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'processRefund',
      request.toMap(),
    );
    return RefundResponse.fromMap(Map<String, dynamic>.from(result ?? {}));
  }

  @override
  Future<VoidResponse> processVoid(VoidRequest request) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'processVoid',
      request.toMap(),
    );
    return VoidResponse.fromMap(Map<String, dynamic>.from(result ?? {}));
  }

  @override
  Future<AuthorizationResponse> processAuthorization(
    AuthorizationRequest request,
  ) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'processAuthorization',
      request.toMap(),
    );
    return AuthorizationResponse.fromMap(
      Map<String, dynamic>.from(result ?? {}),
    );
  }

  @override
  Future<void> cancelTransaction() async {
    await methodChannel.invokeMethod<void>('cancelTransaction');
  }

  @override
  Future<DeviceInfo?> getDeviceInfo() async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getDeviceInfo',
    );
    if (result == null) return null;
    return DeviceInfo.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Stream<String> get statusStream {
    _statusStream ??= statusEventChannel.receiveBroadcastStream().map(
      (event) => event.toString(),
    );
    return _statusStream!;
  }

  @override
  Stream<Map<String, dynamic>> get deviceEventStream {
    _deviceEventStream ??= deviceEventChannel.receiveBroadcastStream().map(
      (event) =>
          event is Map ? Map<String, dynamic>.from(event) : <String, dynamic>{},
    );
    return _deviceEventStream!;
  }
}
