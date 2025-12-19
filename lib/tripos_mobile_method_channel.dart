import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/configuration.dart';
import 'models/enums.dart';
import 'models/requests.dart';
import 'models/responses.dart';
import 'models/stored_transaction.dart';
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

  Stream<VtpStatus>? _statusStream;
  Stream<DeviceEvent>? _deviceEventStream;

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
  Future<RefundResponse> processLinkedRefund(
    LinkedRefundRequest request,
  ) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'processLinkedRefund',
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
  Stream<VtpStatus> get statusStream {
    _statusStream ??= statusEventChannel.receiveBroadcastStream().map(
      (event) => _parseVtpStatus(event.toString()),
    );
    return _statusStream!;
  }

  /// 解析状态字符串为 VtpStatus 枚举
  /// Android SDK 发送 PascalCase (如 RunningSale)
  /// Dart 枚举使用 camelCase (如 runningSale)
  VtpStatus _parseVtpStatus(String status) {
    debugPrint('[VtpStatus] Raw: "$status"');

    // SDK 发送 PascalCase，Dart 枚举是 camelCase
    // 两者转为 lowercase 后比较即可
    final statusLower = status.toLowerCase();

    for (final value in VtpStatus.values) {
      if (value.name.toLowerCase() == statusLower) {
        debugPrint('[VtpStatus] Matched: ${value.name}');
        return value;
      }
    }

    debugPrint('[VtpStatus] No match found for: $status');
    return VtpStatus.none;
  }

  @override
  Stream<DeviceEvent> get deviceEventStream {
    _deviceEventStream ??= deviceEventChannel.receiveBroadcastStream().map(
      (event) => event is Map
          ? DeviceEvent.fromMap(Map<String, dynamic>.from(event))
          : DeviceEvent(type: DeviceEventType.unknown),
    );
    return _deviceEventStream!;
  }

  // ==================== Store-and-Forward Methods ====================

  @override
  Future<List<StoredTransactionRecord>> getStoredTransactions() async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'getStoredTransactions',
    );
    if (result == null) return [];
    return result
        .map(
          (e) => StoredTransactionRecord.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<StoredTransactionRecord?> getStoredTransactionByTpId(
    String tpId,
  ) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getStoredTransactionByTpId',
      {'tpId': tpId},
    );
    if (result == null) return null;
    return StoredTransactionRecord.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<List<StoredTransactionRecord>> getStoredTransactionsByState(
    StoredTransactionState state,
  ) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'getStoredTransactionsByState',
      {'state': state.name},
    );
    if (result == null) return [];
    return result
        .map(
          (e) => StoredTransactionRecord.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<ForwardTransactionResponse> forwardTransaction(
    ForwardTransactionRequest request,
  ) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'forwardTransaction',
      request.toMap(),
    );
    if (result == null) {
      return const ForwardTransactionResponse(
        isApproved: false,
        errorMessage: 'No response from SDK',
      );
    }
    return ForwardTransactionResponse.fromMap(
      Map<String, dynamic>.from(result),
    );
  }

  @override
  Future<bool> deleteStoredTransaction(String tpId) async {
    final result = await methodChannel.invokeMethod<bool>(
      'deleteStoredTransaction',
      {'tpId': tpId},
    );
    return result ?? false;
  }
}
