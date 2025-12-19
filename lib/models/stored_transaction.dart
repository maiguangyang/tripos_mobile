/// 离线存储交易相关模型

import 'enums.dart';

/// 离线存储交易状态（匹配 VTPStoreTransactionState）
enum StoredTransactionState {
  /// 已存储（等待转发）
  stored,

  /// 已存储（等待 EMV GENAC2）
  storedPendingGenac2,

  /// 正在处理/转发中
  processing,

  /// 已处理完成
  processed,

  /// 已删除
  deleted,
}

/// 离线存储交易记录（匹配 VTPStoreTransactionRecord / StoredTransactionRecord）
class StoredTransactionRecord {
  /// 交易 ID
  final String? tpId;

  /// 存储状态
  final StoredTransactionState state;

  /// 交易总金额
  final double? totalAmount;

  /// 创建时间
  final String? createdOn;

  /// 交易类型
  final String? transactionType;

  // ========== 卡片信息 ==========

  /// 卡号后四位
  final String? lastFourDigits;

  /// 完整卡号（通常被掩码）
  final String? accountNumber;

  /// 持卡人姓名
  final String? cardHolderName;

  /// 卡品牌 (Visa, Mastercard, etc.)
  final String? cardLogo;

  /// 卡有效期
  final String? expirationDate;

  /// BIN 号（银行识别号）
  final String? binValue;

  /// EMV 应用标签
  final String? applicationLabel;

  /// 卡类型
  final CardType? cardType;

  // ========== 设备信息 ==========

  /// 输入方式 (Swipe, Chip, Contactless, etc.)
  final String? entryMode;

  /// 设备序列号
  final String? deviceSerialNumber;

  // ========== 操作员/终端信息 ==========

  /// 操作员/收银员 ID
  final String? clerkId;

  /// 终端 ID
  final String? terminalId;

  /// 通道/柜台 ID
  final String? laneId;

  // ========== 交易追踪信息 ==========

  /// 发票号/订单号
  final String? invoiceNumber;

  /// 参考号
  final String? referenceNumber;

  /// 授权码
  final String? approvalCode;

  /// 交易 ID（来自处理器）
  final String? transactionId;

  /// 原始数据
  final Map<String, dynamic>? rawData;

  const StoredTransactionRecord({
    this.tpId,
    this.state = StoredTransactionState.stored,
    this.totalAmount,
    this.createdOn,
    this.transactionType,
    // 卡片信息
    this.lastFourDigits,
    this.accountNumber,
    this.cardHolderName,
    this.cardLogo,
    this.expirationDate,
    this.binValue,
    this.applicationLabel,
    this.cardType,
    // 设备信息
    this.entryMode,
    this.deviceSerialNumber,
    // 操作员信息
    this.clerkId,
    this.terminalId,
    this.laneId,
    // 交易追踪
    this.invoiceNumber,
    this.referenceNumber,
    this.approvalCode,
    this.transactionId,
    this.rawData,
  });

  /// 从 Map 创建
  factory StoredTransactionRecord.fromMap(Map<String, dynamic> map) {
    return StoredTransactionRecord(
      tpId: map['tpId'] as String?,
      state: _parseState(map['state'] as String?),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      createdOn: map['createdOn'] as String?,
      transactionType: map['transactionType'] as String?,
      // 卡片信息
      lastFourDigits: map['lastFourDigits'] as String?,
      accountNumber: map['accountNumber'] as String?,
      cardHolderName: map['cardHolderName'] as String?,
      cardLogo: map['cardLogo'] as String?,
      expirationDate: map['expirationDate'] as String?,
      binValue: map['binValue'] as String?,
      applicationLabel: map['applicationLabel'] as String?,
      cardType: _parseCardType(map['cardType'] as String?),
      // 设备信息
      entryMode: map['entryMode'] as String?,
      deviceSerialNumber: map['deviceSerialNumber'] as String?,
      // 操作员信息
      clerkId: map['clerkId'] as String?,
      terminalId: map['terminalId'] as String?,
      laneId: map['laneId'] as String?,
      // 交易追踪
      invoiceNumber: map['invoiceNumber'] as String?,
      referenceNumber: map['referenceNumber'] as String?,
      approvalCode: map['approvalCode'] as String?,
      transactionId: map['transactionId'] as String?,
      rawData: map,
    );
  }

  static StoredTransactionState _parseState(String? value) {
    if (value == null) return StoredTransactionState.stored;
    return StoredTransactionState.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => StoredTransactionState.stored,
    );
  }

  static CardType? _parseCardType(String? value) {
    if (value == null) return null;
    return CardType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CardType.credit,
    );
  }

  @override
  String toString() =>
      'StoredTransactionRecord(tpId: $tpId, state: $state, amount: $totalAmount)';
}

/// 手动转发交易响应
class ForwardTransactionResponse {
  /// 是否批准
  final bool isApproved;

  /// 交易 ID
  final String? transactionId;

  /// 参考号
  final String? referenceNumber;

  /// 是否在线处理
  final bool wasProcessedOnline;

  /// 交易状态
  final TransactionStatus? transactionStatus;

  /// 错误信息
  final String? errorMessage;

  /// 原始响应数据
  final Map<String, dynamic>? rawResponse;

  const ForwardTransactionResponse({
    this.isApproved = false,
    this.transactionId,
    this.referenceNumber,
    this.wasProcessedOnline = false,
    this.transactionStatus,
    this.errorMessage,
    this.rawResponse,
  });

  /// 从 Map 创建
  factory ForwardTransactionResponse.fromMap(Map<String, dynamic> map) {
    final transactionStatus = _parseTransactionStatus(
      map['transactionStatus'] as String?,
    );
    return ForwardTransactionResponse(
      isApproved:
          map['isApproved'] as bool? ??
          transactionStatus == TransactionStatus.approved,
      transactionId: map['transactionId'] as String?,
      referenceNumber: map['referenceNumber'] as String?,
      wasProcessedOnline: map['wasProcessedOnline'] as bool? ?? false,
      transactionStatus: transactionStatus,
      errorMessage: map['errorMessage'] as String?,
      rawResponse: map,
    );
  }

  static TransactionStatus _parseTransactionStatus(String? value) {
    if (value == null) return TransactionStatus.error;
    return TransactionStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TransactionStatus.error,
    );
  }

  @override
  String toString() =>
      'ForwardTransactionResponse(isApproved: $isApproved, transactionId: $transactionId)';
}

/// 手动转发请求
class ForwardTransactionRequest {
  /// 交易 ID（必填）
  final String tpId;

  /// 交易金额（可选，用于更新）
  final double? transactionAmount;

  /// 销售税金额
  final double? salesTaxAmount;

  /// 便利费金额
  final double? convenienceFeeAmount;

  const ForwardTransactionRequest({
    required this.tpId,
    this.transactionAmount,
    this.salesTaxAmount,
    this.convenienceFeeAmount,
  });

  /// 转换为 Map
  Map<String, dynamic> toMap() => {
    'tpId': tpId,
    if (transactionAmount != null) 'transactionAmount': transactionAmount,
    if (salesTaxAmount != null) 'salesTaxAmount': salesTaxAmount,
    if (convenienceFeeAmount != null)
      'convenienceFeeAmount': convenienceFeeAmount,
  };
}
