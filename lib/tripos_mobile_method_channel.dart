import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'tripos_mobile_platform_interface.dart';

class MethodChannelTriposMobile extends TriposMobilePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('tripos_mobile');

  // 添加 EventChannel
  final eventChannel = const EventChannel('tripos_mobile/events');

  @override
  Stream<TriposEvent> get events {
    return eventChannel.receiveBroadcastStream().map((dynamic event) {
      final Map<dynamic, dynamic> map = event;
      return TriposEvent(
        type: map['type'],
        message: map['message'],
        data: map['data'],
      );
    });
  }

  @override
  Future<String?> getPlatformVersion() async {
    return await methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  @override
  Future<void> initialize(TriposConfiguration config) async {
    await methodChannel.invokeMethod('initialize', config.toMap());
  }

  @override
  Future<List<TriposDevice>> scanDevices() async {
    final List<dynamic>? devices = await methodChannel
        .invokeMethod<List<dynamic>>('scanDevices');
    return devices?.map((e) => TriposDevice.fromMap(e as Map)).toList() ?? [];
  }

  @override
  Future<bool> connectDevice(TriposDevice device) async {
    final bool? result = await methodChannel.invokeMethod<bool>(
      'connectDevice',
      device.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<PaymentResponse> processPayment(PaymentRequest request) async {
    final Map<dynamic, dynamic>? result = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('processPayment', request.toMap());
    if (result == null) throw Exception('Payment failed: No response');
    return PaymentResponse.fromMap(result);
  }

  @override
  Future<bool> disconnect() async {
    final bool? result = await methodChannel.invokeMethod<bool>('disconnect');
    return result ?? false;
  }
}
