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
    try {
      await methodChannel.invokeMethod('initialize', config.toMap());
    } on PlatformException catch (e) {
      throw Exception('SDK初始化失败: ${e.message ?? e.code}');
    }
  }

  @override
  Future<List<TriposDevice>> scanDevices() async {
    try {
      final List<dynamic>? devices = await methodChannel
          .invokeMethod<List<dynamic>>('scanDevices');
      return devices?.map((e) => TriposDevice.fromMap(e as Map)).toList() ?? [];
    } on PlatformException catch (e) {
      throw Exception('设备扫描失败: ${e.message ?? e.code}');
    }
  }

  @override
  Future<bool> connectDevice(TriposDevice device) async {
    try {
      final bool? result = await methodChannel.invokeMethod<bool>(
        'connectDevice',
        device.toMap(),
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('设备连接失败: ${e.message ?? e.code}');
    }
  }

  @override
  Future<PaymentResponse> processPayment(PaymentRequest request) async {
    try {
      final Map<dynamic, dynamic>? result = await methodChannel
          .invokeMethod<Map<dynamic, dynamic>>(
            'processPayment',
            request.toMap(),
          );
      if (result == null) throw Exception('支付失败: 无响应数据');
      return PaymentResponse.fromMap(result);
    } on PlatformException catch (e) {
      throw Exception('支付处理失败: ${e.message ?? e.code}');
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      final bool? result = await methodChannel.invokeMethod<bool>('disconnect');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('断开连接失败: ${e.message ?? e.code}');
    }
  }

  @override
  Future<bool> cancelPayment() async {
    try {
      final bool? result = await methodChannel.invokeMethod<bool>('cancelPayment');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('取消支付失败: ${e.message ?? e.code}');
    }
  }
}
