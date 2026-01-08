/// Response models for triPOS Mobile SDK transactions

import 'enums.dart';

/// 判断交易状态是否为批准状态
/// 根据 SDK 的 VTPTransactionStatusUtility.isTransactionStatusApproved 逻辑
bool _isStatusApproved(TransactionStatus status) {
  return status == TransactionStatus.approved ||
      status == TransactionStatus.partiallyApproved ||
      status == TransactionStatus.approvedExceptCashback ||
      status == TransactionStatus.approvedByMerchant;
}

/// Host response information
class HostResponse {
  /// Transaction ID from host
  final String? transactionId;

  /// Reference number
  final String? referenceNumber;

  /// Auth code
  final String? authCode;

  /// Response code
  final String? responseCode;

  /// Response message
  final String? responseMessage;

  /// Trace number
  final String? traceNumber;

  /// Batch number
  final String? batchNumber;

  /// Express response code (iOS/Android)
  final String? expressResponseCode;

  /// Express response message (iOS/Android)
  final String? expressResponseMessage;

  /// Host response code (iOS/Android)
  final String? hostResponseCode;

  /// Host response message (iOS/Android)
  final String? hostResponseMessage;

  /// Processor name (iOS)
  final String? processorName;

  const HostResponse({
    this.transactionId,
    this.referenceNumber,
    this.authCode,
    this.responseCode,
    this.responseMessage,
    this.traceNumber,
    this.batchNumber,
    this.expressResponseCode,
    this.expressResponseMessage,
    this.hostResponseCode,
    this.hostResponseMessage,
    this.processorName,
  });

  factory HostResponse.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const HostResponse();
    return HostResponse(
      transactionId: map['transactionId'] as String?,
      referenceNumber: map['referenceNumber'] as String?,
      authCode: map['authCode'] ?? map['approvalNumber'] as String?,
      responseCode: map['responseCode'] as String?,
      responseMessage: map['responseMessage'] as String?,
      traceNumber: map['traceNumber'] as String?,
      batchNumber: map['batchNumber'] as String?,
      expressResponseCode: map['expressResponseCode'] as String?,
      expressResponseMessage: map['expressResponseMessage'] as String?,
      hostResponseCode: map['hostResponseCode'] as String?,
      hostResponseMessage: map['hostResponseMessage'] as String?,
      processorName: map['processorName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'transactionId': transactionId,
    'referenceNumber': referenceNumber,
    'authCode': authCode,
    'responseCode': responseCode,
    'responseMessage': responseMessage,
    'traceNumber': traceNumber,
    'batchNumber': batchNumber,
    'expressResponseCode': expressResponseCode,
    'expressResponseMessage': expressResponseMessage,
    'hostResponseCode': hostResponseCode,
    'hostResponseMessage': hostResponseMessage,
    'processorName': processorName,
  };
}

/// Card information from transaction
class CardInfo {
  /// Masked card number
  final String? maskedCardNumber;

  /// Card holder name
  final String? cardHolderName;

  /// Card type
  final CardType? cardType;

  /// Expiration month
  final String? expirationMonth;

  /// Expiration year
  final String? expirationYear;

  /// Entry mode
  final EntryMode? entryMode;

  /// Card brand (Visa, Mastercard, etc.)
  final String? cardBrand;

  const CardInfo({
    this.maskedCardNumber,
    this.cardHolderName,
    this.cardType,
    this.expirationMonth,
    this.expirationYear,
    this.entryMode,
    this.cardBrand,
  });

  factory CardInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CardInfo();
    return CardInfo(
      maskedCardNumber: map['maskedCardNumber'] as String?,
      cardHolderName: map['cardHolderName'] as String?,
      cardType: _parseCardType(map['cardType'] as String?),
      expirationMonth: map['expirationMonth'] as String?,
      expirationYear: map['expirationYear'] as String?,
      entryMode: _parseEntryMode(map['entryMode'] as String?),
      cardBrand: map['cardBrand'] as String?,
    );
  }

  static CardType? _parseCardType(String? value) {
    if (value == null) return null;
    return CardType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CardType.credit,
    );
  }

  static EntryMode? _parseEntryMode(String? value) {
    if (value == null) return null;
    return EntryMode.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => EntryMode.magStripe,
    );
  }

  Map<String, dynamic> toMap() => {
    'maskedCardNumber': maskedCardNumber,
    'cardHolderName': cardHolderName,
    'cardType': cardType?.name,
    'expirationMonth': expirationMonth,
    'expirationYear': expirationYear,
    'entryMode': entryMode?.name,
    'cardBrand': cardBrand,
  };
}

/// EMV information from transaction
class EmvInfo {
  /// Application ID
  final String? applicationId;

  /// Application label
  final String? applicationLabel;

  /// Cryptogram type
  final String? cryptogramType;

  /// Cryptogram value
  final String? cryptogram;

  const EmvInfo({
    this.applicationId,
    this.applicationLabel,
    this.cryptogramType,
    this.cryptogram,
  });

  factory EmvInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EmvInfo();
    return EmvInfo(
      applicationId: map['applicationId'] as String?,
      applicationLabel: map['applicationLabel'] as String?,
      cryptogramType: map['cryptogramType'] as String?,
      cryptogram: map['cryptogram'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'applicationId': applicationId,
    'applicationLabel': applicationLabel,
    'cryptogramType': cryptogramType,
    'cryptogram': cryptogram,
  };
}

/// Base transaction response
abstract class TransactionResponse {
  /// Whether the transaction was approved
  final bool isApproved;

  /// Transaction status
  final TransactionStatus transactionStatus;

  /// Approved amount
  final double? approvedAmount;

  /// Host response details
  final HostResponse? host;

  /// Card information
  final CardInfo? card;

  /// EMV information
  final EmvInfo? emv;

  /// Error message if failed
  final String? errorMessage;

  /// Signature data (base64 encoded)
  final String? signatureData;

  /// triPOS transaction ID
  final String? tpId;

  /// Raw response data
  final Map<String, dynamic>? rawResponse;

  const TransactionResponse({
    this.isApproved = false,
    this.transactionStatus = TransactionStatus.error,
    this.approvedAmount,
    this.host,
    this.card,
    this.emv,
    this.errorMessage,
    this.signatureData,
    this.tpId,
    this.rawResponse,
  });
}

/// Sale transaction response
class SaleResponse extends TransactionResponse {
  /// Cashback amount
  final double? cashbackAmount;

  /// Tip amount
  final double? tipAmount;

  /// Reference number used for the transaction
  final String? referenceNumber;

  /// Stored transaction ID (for offline/S&F transactions)
  final String? storedTransactionId;

  /// Whether this was an offline (Store-and-Forward) transaction
  final bool isStoredTransaction;

  const SaleResponse({
    super.isApproved,
    super.transactionStatus,
    super.approvedAmount,
    super.host,
    super.card,
    super.emv,
    super.errorMessage,
    super.signatureData,
    super.tpId,
    super.rawResponse,
    this.cashbackAmount,
    this.tipAmount,
    this.referenceNumber,
    this.storedTransactionId,
    this.isStoredTransaction = false,
  });

  factory SaleResponse.fromMap(Map<String, dynamic> map) {
    final transactionStatus = _parseTransactionStatus(
      map['transactionStatus'] as String?,
    );
    return SaleResponse(
      isApproved: _isStatusApproved(transactionStatus),
      transactionStatus: transactionStatus,
      approvedAmount: (map['approvedAmount'] as num?)?.toDouble(),
      host: HostResponse.fromMap(_toStringDynamicMap(map['host'])),
      card: CardInfo.fromMap(_toStringDynamicMap(map['card'])),
      emv: EmvInfo.fromMap(_toStringDynamicMap(map['emv'])),
      errorMessage: map['errorMessage'] as String?,
      signatureData: map['signatureData'] as String?,
      tpId: map['tpId'] as String?,
      rawResponse: map,
      cashbackAmount: (map['cashbackAmount'] as num?)?.toDouble(),
      tipAmount: (map['tipAmount'] as num?)?.toDouble(),
      referenceNumber: map['referenceNumber'] as String?,
      storedTransactionId: map['storedTransactionId'] as String?,
      isStoredTransaction: map['isStoredTransaction'] as bool? ?? false,
    );
  }

  static TransactionStatus _parseTransactionStatus(String? value) {
    if (value == null) return TransactionStatus.error;
    return TransactionStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TransactionStatus.error,
    );
  }
}

/// Helper to safely convert platform channel Map<Object?, Object?> to Map<String, dynamic>
Map<String, dynamic>? _toStringDynamicMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return null;
}

/// Refund transaction response
class RefundResponse extends TransactionResponse {
  const RefundResponse({
    super.isApproved,
    super.transactionStatus,
    super.approvedAmount,
    super.host,
    super.card,
    super.emv,
    super.errorMessage,
    super.signatureData,
    super.tpId,
    super.rawResponse,
  });

  factory RefundResponse.fromMap(Map<String, dynamic> map) {
    final transactionStatus = _parseTransactionStatus(
      map['transactionStatus'] as String?,
    );
    return RefundResponse(
      isApproved: _isStatusApproved(transactionStatus),
      transactionStatus: transactionStatus,
      approvedAmount: (map['approvedAmount'] as num?)?.toDouble(),
      host: HostResponse.fromMap(_toStringDynamicMap(map['host'])),
      card: CardInfo.fromMap(_toStringDynamicMap(map['card'])),
      emv: EmvInfo.fromMap(_toStringDynamicMap(map['emv'])),
      errorMessage: map['errorMessage'] as String?,
      signatureData: map['signatureData'] as String?,
      tpId: map['tpId'] as String?,
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
}

/// Void transaction response
class VoidResponse extends TransactionResponse {
  const VoidResponse({
    super.isApproved,
    super.transactionStatus,
    super.approvedAmount,
    super.host,
    super.card,
    super.emv,
    super.errorMessage,
    super.signatureData,
    super.tpId,
    super.rawResponse,
  });

  factory VoidResponse.fromMap(Map<String, dynamic> map) {
    final transactionStatus = _parseTransactionStatus(
      map['transactionStatus'] as String?,
    );
    return VoidResponse(
      isApproved: _isStatusApproved(transactionStatus),
      transactionStatus: transactionStatus,
      approvedAmount: (map['approvedAmount'] as num?)?.toDouble(),
      host: HostResponse.fromMap(_toStringDynamicMap(map['host'])),
      card: CardInfo.fromMap(_toStringDynamicMap(map['card'])),
      emv: EmvInfo.fromMap(_toStringDynamicMap(map['emv'])),
      errorMessage: map['errorMessage'] as String?,
      signatureData: map['signatureData'] as String?,
      tpId: map['tpId'] as String?,
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
}

/// Authorization transaction response
class AuthorizationResponse extends TransactionResponse {
  const AuthorizationResponse({
    super.isApproved,
    super.transactionStatus,
    super.approvedAmount,
    super.host,
    super.card,
    super.emv,
    super.errorMessage,
    super.signatureData,
    super.tpId,
    super.rawResponse,
  });

  factory AuthorizationResponse.fromMap(Map<String, dynamic> map) {
    final transactionStatus = _parseTransactionStatus(
      map['transactionStatus'] as String?,
    );
    return AuthorizationResponse(
      isApproved: _isStatusApproved(transactionStatus),
      transactionStatus: transactionStatus,
      approvedAmount: (map['approvedAmount'] as num?)?.toDouble(),
      host: HostResponse.fromMap(_toStringDynamicMap(map['host'])),
      card: CardInfo.fromMap(_toStringDynamicMap(map['card'])),
      emv: EmvInfo.fromMap(_toStringDynamicMap(map['emv'])),
      errorMessage: map['errorMessage'] as String?,
      signatureData: map['signatureData'] as String?,
      tpId: map['tpId'] as String?,
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
}

/// Device information
class DeviceInfo {
  /// Device description
  final String? description;

  /// Device model
  final String? model;

  /// Device serial number
  final String? serialNumber;

  /// Firmware version
  final String? firmwareVersion;

  const DeviceInfo({
    this.description,
    this.model,
    this.serialNumber,
    this.firmwareVersion,
  });

  factory DeviceInfo.fromMap(Map<String, dynamic> map) => DeviceInfo(
    description: map['description'] as String?,
    model: map['model'] as String?,
    serialNumber: map['serialNumber'] as String?,
    firmwareVersion: map['firmwareVersion'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'description': description,
    'model': model,
    'serialNumber': serialNumber,
    'firmwareVersion': firmwareVersion,
  };
}

/// Create token response
class CreateTokenResponse {
  /// Transaction status
  final String transactionStatus;

  /// Token ID generated
  final String? tokenId;

  /// BIN
  final String? bin;

  /// Card Logo
  final String? cardLogo;

  /// Error message
  final String? errorMessage;

  const CreateTokenResponse({
    this.transactionStatus = 'unknown',
    this.tokenId,
    this.bin,
    this.cardLogo,
    this.errorMessage,
  });

  factory CreateTokenResponse.fromMap(Map<String, dynamic> map) {
    return CreateTokenResponse(
      transactionStatus: map['transactionStatus'] as String? ?? 'unknown',
      tokenId: map['tokenId'] as String?,
      bin: map['bin'] as String?,
      cardLogo: map['cardLogo'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'transactionStatus': transactionStatus,
    'tokenId': tokenId,
    'bin': bin,
    'cardLogo': cardLogo,
    'errorMessage': errorMessage,
  };
}

/// Sale with Token response (similar to SaleResponse)
class SaleWithTokenResponse extends TransactionResponse {
  /// Cashback amount
  final double? cashbackAmount;

  /// Tip amount
  final double? tipAmount;

  const SaleWithTokenResponse({
    super.isApproved,
    super.transactionStatus,
    super.approvedAmount,
    super.host,
    super.card,
    super.emv,
    super.errorMessage,
    super.signatureData,
    super.tpId,
    super.rawResponse,
    this.cashbackAmount,
    this.tipAmount,
  });

  factory SaleWithTokenResponse.fromMap(Map<String, dynamic> map) {
    final transactionStatus = _parseTransactionStatus(
      map['transactionStatus'] as String?,
    );
    return SaleWithTokenResponse(
      isApproved: _isStatusApproved(transactionStatus),
      transactionStatus: transactionStatus,
      approvedAmount: (map['approvedAmount'] as num?)?.toDouble(),
      host: HostResponse.fromMap(_toStringDynamicMap(map['host'])),
      card: CardInfo.fromMap(_toStringDynamicMap(map['card'])),
      emv: EmvInfo.fromMap(_toStringDynamicMap(map['emv'])),
      errorMessage: map['errorMessage'] as String?,
      signatureData: map['signatureData'] as String?,
      tpId: map['tpId'] as String?,
      rawResponse: map,
      cashbackAmount: (map['cashbackAmount'] as num?)?.toDouble(),
      tipAmount: (map['tipAmount'] as num?)?.toDouble(),
    );
  }

  static TransactionStatus _parseTransactionStatus(String? value) {
    if (value == null) return TransactionStatus.error;
    return TransactionStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TransactionStatus.error,
    );
  }
}
